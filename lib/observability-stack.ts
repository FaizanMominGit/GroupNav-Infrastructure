import * as cdk from 'aws-cdk-lib';
import * as cloudwatch from 'aws-cdk-lib/aws-cloudwatch';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as iot from 'aws-cdk-lib/aws-iot';
import { Construct } from 'constructs';

export interface ObservabilityStackProps extends cdk.StackProps {
  lambdaFunctionName?: string;
  dlqQueueName?: string;
  iotRuleName?: string;
}

export class ObservabilityStack extends cdk.Stack {
  public readonly dashboard: cloudwatch.Dashboard;
  public readonly lambdaErrorAlarm: cloudwatch.Alarm;
  public readonly auroraConnectionAlarm: cloudwatch.Alarm;
  public readonly dlqAlarm: cloudwatch.Alarm;
  public readonly iotLoggingRole: iam.Role;

  constructor(scope: Construct, id: string, props?: ObservabilityStackProps) {
    super(scope, id, props);

    const lambdaFunctionName = props?.lambdaFunctionName || 'groupnav-process-telemetry';
    const dlqQueueName = props?.dlqQueueName || 'groupnav-telemetry-dlq';
    const iotRuleName = props?.iotRuleName || 'GroupNavTelemetryIngestionRule';

    // =========================================================================
    // 1. AWS IoT Core CloudWatch Logging
    // =========================================================================
    this.iotLoggingRole = new iam.Role(this, 'AWSIoTLoggingRole', {
      roleName: 'GroupNav-IoT-CloudWatch-Logging-Role',
      description: 'IAM role assumed by AWS IoT Core to publish connection and MQTT logs to CloudWatch',
      assumedBy: new iam.ServicePrincipal('iot.amazonaws.com'),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName('service-role/AWSIoTLogging'),
      ],
    });

    new iot.CfnLogging(this, 'IoTCoreLogging', {
      accountId: this.account,
      roleArn: this.iotLoggingRole.roleArn,
      defaultLogLevel: 'WARN',
    });

    // =========================================================================
    // 2. CloudWatch Alarms (Section 7)
    // =========================================================================
    // Alarm 1: Lambda Error Rate
    const lambdaErrorMetric = new cloudwatch.Metric({
      namespace: 'AWS/Lambda',
      metricName: 'Errors',
      dimensionsMap: {
        FunctionName: lambdaFunctionName,
      },
      statistic: 'Sum',
      period: cdk.Duration.minutes(5),
    });

    this.lambdaErrorAlarm = new cloudwatch.Alarm(this, 'LambdaErrorAlarm', {
      alarmName: 'GroupNav-LambdaErrorAlarm',
      alarmDescription: 'Fires when processTelemetry Lambda encounters 3 or more errors within 5 minutes',
      metric: lambdaErrorMetric,
      threshold: 3,
      evaluationPeriods: 1,
      comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_OR_EQUAL_TO_THRESHOLD,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
    });

    // Alarm 2: Aurora Connection Saturation
    const auroraConnectionMetric = new cloudwatch.Metric({
      namespace: 'AWS/RDS',
      metricName: 'DatabaseConnections',
      statistic: 'Average',
      period: cdk.Duration.minutes(5),
    });

    this.auroraConnectionAlarm = new cloudwatch.Alarm(this, 'AuroraConnectionSaturationAlarm', {
      alarmName: 'GroupNav-AuroraConnectionSaturationAlarm',
      alarmDescription: 'Fires when Aurora Serverless v2 PostgreSQL connection count reaches 40',
      metric: auroraConnectionMetric,
      threshold: 40,
      evaluationPeriods: 1,
      comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_OR_EQUAL_TO_THRESHOLD,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
    });

    // Alarm 3: Telemetry Dead-Letter Queue (DLQ) Accumulation
    const dlqMessageMetric = new cloudwatch.Metric({
      namespace: 'AWS/SQS',
      metricName: 'ApproximateNumberOfMessagesVisible',
      dimensionsMap: {
        QueueName: dlqQueueName,
      },
      statistic: 'Maximum',
      period: cdk.Duration.minutes(5),
    });

    this.dlqAlarm = new cloudwatch.Alarm(this, 'DeadLetterQueueAlarm', {
      alarmName: 'GroupNav-DeadLetterQueueAlarm',
      alarmDescription: 'Fires when failed or malformed telemetry messages accumulate in SQS DLQ',
      metric: dlqMessageMetric,
      threshold: 1,
      evaluationPeriods: 1,
      comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_OR_EQUAL_TO_THRESHOLD,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
    });

    // =========================================================================
    // 3. CloudWatch Operational Dashboard (Section 7)
    // =========================================================================
    this.dashboard = new cloudwatch.Dashboard(this, 'OperationalDashboard', {
      dashboardName: 'GroupNav-Operational-Dashboard',
    });

    // Header Widget
    const headerWidget = new cloudwatch.TextWidget({
      markdown: [
        '# GroupNav Operational Health & Real-Time Telemetry Dashboard',
        'Live tracking of MQTT ingestion, Lambda compute latency, ElastiCache Redis, and Aurora Serverless v2 PostGIS.',
      ].join('\n\n'),
      width: 24,
      height: 2,
    });

    // Row 1: IoT Ingestion & DLQ
    const iotPublishMetric = new cloudwatch.Metric({
      namespace: 'AWS/IoT',
      metricName: 'PublishIn.Success',
      statistic: 'Sum',
      period: cdk.Duration.minutes(1),
      label: 'MQTT Telemetry Publishes',
    });

    const iotRuleExecutedMetric = new cloudwatch.Metric({
      namespace: 'AWS/IoT',
      metricName: 'TopicRuleExecuted',
      dimensionsMap: { RuleName: iotRuleName },
      statistic: 'Sum',
      period: cdk.Duration.minutes(1),
      label: 'Topic Rule Executed',
    });

    const iotRuleFailedMetric = new cloudwatch.Metric({
      namespace: 'AWS/IoT',
      metricName: 'TopicRuleFailed',
      dimensionsMap: { RuleName: iotRuleName },
      statistic: 'Sum',
      period: cdk.Duration.minutes(1),
      label: 'Topic Rule Failed',
    });

    const iotGraphWidget = new cloudwatch.GraphWidget({
      title: 'AWS IoT Core: Telemetry Ingestion & Topic Rule Executions',
      left: [iotPublishMetric, iotRuleExecutedMetric],
      right: [iotRuleFailedMetric],
      width: 18,
      height: 6,
    });

    const dlqWidget = new cloudwatch.SingleValueWidget({
      title: 'Telemetry SQS DLQ Depth',
      metrics: [dlqMessageMetric],
      width: 6,
      height: 6,
    });

    // Row 2: Lambda Compute
    const lambdaInvocationsMetric = new cloudwatch.Metric({
      namespace: 'AWS/Lambda',
      metricName: 'Invocations',
      dimensionsMap: { FunctionName: lambdaFunctionName },
      statistic: 'Sum',
      period: cdk.Duration.minutes(1),
      label: 'Invocations',
    });

    const lambdaErrorsMetric = new cloudwatch.Metric({
      namespace: 'AWS/Lambda',
      metricName: 'Errors',
      dimensionsMap: { FunctionName: lambdaFunctionName },
      statistic: 'Sum',
      period: cdk.Duration.minutes(1),
      label: 'Errors',
    });

    const lambdaThrottlesMetric = new cloudwatch.Metric({
      namespace: 'AWS/Lambda',
      metricName: 'Throttles',
      dimensionsMap: { FunctionName: lambdaFunctionName },
      statistic: 'Sum',
      period: cdk.Duration.minutes(1),
      label: 'Throttles',
    });

    const lambdaExecWidget = new cloudwatch.GraphWidget({
      title: 'processTelemetry Lambda: Executions, Errors & Throttles',
      left: [lambdaInvocationsMetric],
      right: [lambdaErrorsMetric, lambdaThrottlesMetric],
      width: 12,
      height: 6,
    });

    const lambdaDurationAvg = new cloudwatch.Metric({
      namespace: 'AWS/Lambda',
      metricName: 'Duration',
      dimensionsMap: { FunctionName: lambdaFunctionName },
      statistic: 'Average',
      period: cdk.Duration.minutes(1),
      label: 'Avg Duration (ms)',
    });

    const lambdaDurationP95 = new cloudwatch.Metric({
      namespace: 'AWS/Lambda',
      metricName: 'Duration',
      dimensionsMap: { FunctionName: lambdaFunctionName },
      statistic: 'p95',
      period: cdk.Duration.minutes(1),
      label: 'p95 Duration (ms)',
    });

    const lambdaLatencyWidget = new cloudwatch.GraphWidget({
      title: 'processTelemetry Lambda: Execution Latency (ms)',
      left: [lambdaDurationAvg, lambdaDurationP95],
      width: 12,
      height: 6,
    });

    // Row 3: Stateful Tier (Redis & Aurora)
    const redisCpuMetric = new cloudwatch.Metric({
      namespace: 'AWS/ElastiCache',
      metricName: 'CPUUtilization',
      statistic: 'Average',
      period: cdk.Duration.minutes(1),
      label: 'Redis CPU %',
    });

    const redisMemoryMetric = new cloudwatch.Metric({
      namespace: 'AWS/ElastiCache',
      metricName: 'DatabaseMemoryUsagePercentage',
      statistic: 'Average',
      period: cdk.Duration.minutes(1),
      label: 'Redis Memory %',
    });

    const redisWidget = new cloudwatch.GraphWidget({
      title: 'ElastiCache Redis: Live Spatial Cache Utilization',
      left: [redisCpuMetric, redisMemoryMetric],
      width: 12,
      height: 6,
    });

    const auroraAcuMetric = new cloudwatch.Metric({
      namespace: 'AWS/RDS',
      metricName: 'ServerlessDatabaseCapacity',
      statistic: 'Average',
      period: cdk.Duration.minutes(1),
      label: 'Active ACUs',
    });

    const auroraCpuMetric = new cloudwatch.Metric({
      namespace: 'AWS/RDS',
      metricName: 'CPUUtilization',
      statistic: 'Average',
      period: cdk.Duration.minutes(1),
      label: 'Aurora CPU %',
    });

    const auroraWidget = new cloudwatch.GraphWidget({
      title: 'Aurora Serverless v2 PostgreSQL: Capacity (ACUs) & Connections',
      left: [auroraAcuMetric, auroraConnectionMetric],
      right: [auroraCpuMetric],
      width: 12,
      height: 6,
    });

    // Assemble Dashboard
    this.dashboard.addWidgets(headerWidget);
    this.dashboard.addWidgets(iotGraphWidget, dlqWidget);
    this.dashboard.addWidgets(lambdaExecWidget, lambdaLatencyWidget);
    this.dashboard.addWidgets(redisWidget, auroraWidget);

    // =========================================================================
    // 4. CloudFormation Outputs
    // =========================================================================
    new cdk.CfnOutput(this, 'DashboardName', {
      value: this.dashboard.dashboardName,
      description: 'CloudWatch Operational Dashboard Name',
      exportName: 'GroupNavDashboardName',
    });

    new cdk.CfnOutput(this, 'LambdaErrorAlarmArn', {
      value: this.lambdaErrorAlarm.alarmArn,
      description: 'CloudWatch Alarm ARN for Lambda Error Rate',
      exportName: 'GroupNavLambdaErrorAlarmArn',
    });

    new cdk.CfnOutput(this, 'AuroraConnectionAlarmArn', {
      value: this.auroraConnectionAlarm.alarmArn,
      description: 'CloudWatch Alarm ARN for Aurora Connection Saturation',
      exportName: 'GroupNavAuroraConnectionAlarmArn',
    });

    new cdk.CfnOutput(this, 'DlqAlarmArn', {
      value: this.dlqAlarm.alarmArn,
      description: 'CloudWatch Alarm ARN for Telemetry DLQ Accumulation',
      exportName: 'GroupNavDlqAlarmArn',
    });
  }
}
