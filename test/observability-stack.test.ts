import * as cdk from 'aws-cdk-lib';
import { Template } from 'aws-cdk-lib/assertions';
import { ObservabilityStack } from '../lib/observability-stack';

describe('ObservabilityStack (Phase 5 Observability & Guardrails)', () => {
  let app: cdk.App;
  let stack: ObservabilityStack;
  let template: Template;

  beforeEach(() => {
    app = new cdk.App();
    stack = new ObservabilityStack(app, 'TestObservabilityStack', {
      env: { account: '325313611329', region: 'ap-south-1' },
      lambdaFunctionName: 'groupnav-process-telemetry',
      dlqQueueName: 'groupnav-telemetry-dlq',
      iotRuleName: 'GroupNavTelemetryIngestionRule',
    });
    template = Template.fromStack(stack);
  });

  test('Creates CloudWatch Dashboard with specified name', () => {
    template.hasResourceProperties('AWS::CloudWatch::Dashboard', {
      DashboardName: 'GroupNav-Operational-Dashboard',
    });
  });

  test('Creates Lambda Error Rate Alarm', () => {
    template.hasResourceProperties('AWS::CloudWatch::Alarm', {
      AlarmName: 'GroupNav-LambdaErrorAlarm',
      ComparisonOperator: 'GreaterThanOrEqualToThreshold',
      EvaluationPeriods: 1,
      MetricName: 'Errors',
      Namespace: 'AWS/Lambda',
      Statistic: 'Sum',
      Threshold: 3,
    });
  });

  test('Creates Aurora Connection Saturation Alarm', () => {
    template.hasResourceProperties('AWS::CloudWatch::Alarm', {
      AlarmName: 'GroupNav-AuroraConnectionSaturationAlarm',
      ComparisonOperator: 'GreaterThanOrEqualToThreshold',
      EvaluationPeriods: 1,
      MetricName: 'DatabaseConnections',
      Namespace: 'AWS/RDS',
      Statistic: 'Average',
      Threshold: 40,
    });
  });

  test('Creates SQS DLQ Accumulation Alarm', () => {
    template.hasResourceProperties('AWS::CloudWatch::Alarm', {
      AlarmName: 'GroupNav-DeadLetterQueueAlarm',
      ComparisonOperator: 'GreaterThanOrEqualToThreshold',
      EvaluationPeriods: 1,
      MetricName: 'ApproximateNumberOfMessagesVisible',
      Namespace: 'AWS/SQS',
      Statistic: 'Maximum',
      Threshold: 1,
    });
  });

  test('Configures AWS IoT CloudWatch Logging with role', () => {
    template.hasResourceProperties('AWS::IoT::Logging', {
      DefaultLogLevel: 'WARN',
    });
    template.hasResourceProperties('AWS::IAM::Role', {
      RoleName: 'GroupNav-IoT-CloudWatch-Logging-Role',
    });
  });

  test('Exports Dashboard Name and Alarm ARNs as CloudFormation Outputs', () => {
    template.hasOutput('DashboardName', {
      Export: {
        Name: 'GroupNavDashboardName',
      },
    });
    template.hasOutput('LambdaErrorAlarmArn', {
      Export: {
        Name: 'GroupNavLambdaErrorAlarmArn',
      },
    });
    template.hasOutput('AuroraConnectionAlarmArn', {
      Export: {
        Name: 'GroupNavAuroraConnectionAlarmArn',
      },
    });
    template.hasOutput('DlqAlarmArn', {
      Export: {
        Name: 'GroupNavDlqAlarmArn',
      },
    });
  });
});
