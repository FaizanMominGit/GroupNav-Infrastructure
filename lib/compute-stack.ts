import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as nodejs from 'aws-cdk-lib/aws-lambda-nodejs';
import * as sqs from 'aws-cdk-lib/aws-sqs';
import * as iot from 'aws-cdk-lib/aws-iot';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as secretsmanager from 'aws-cdk-lib/aws-secretsmanager';
import * as path from 'path';
import { Construct } from 'constructs';

export interface ComputeStackProps extends cdk.StackProps {
  /**
   * Dedicated props if any.
   */
}

export class ComputeStack extends cdk.Stack {
  /** Dead-letter queue capturing failed or malformed telemetry */
  public readonly dlq: sqs.Queue;

  /** Lambda function processing IoT GPS telemetry */
  public readonly processTelemetryLambda: nodejs.NodejsFunction;

  /** IoT Topic Rule routing MQTT telemetry */
  public readonly topicRule: iot.CfnTopicRule;

  constructor(scope: Construct, id: string, props?: ComputeStackProps) {
    super(scope, id, props);

    // 1. Decoupled Imports via Fn::GetStackOutput
    // Reading VPC, Subnet, and Security Group IDs without Fn::Export coupling
    const vpcId = cdk.Fn.getStackOutput('NetworkStack', 'VpcId');
    const computeSubnetsString = cdk.Fn.getStackOutput('NetworkStack', 'PrivateComputeSubnetIds');
    const computeSgId = cdk.Fn.getStackOutput('NetworkStack', 'ComputeSecurityGroupId');

    // Reading DataStack outputs
    const redisEndpoint = cdk.Fn.getStackOutput('DataStack', 'RedisEndpoint');
    const redisPort = cdk.Fn.getStackOutput('DataStack', 'RedisPort');
    const auroraClusterEndpoint = cdk.Fn.getStackOutput('DataStack', 'AuroraClusterEndpoint');
    const auroraSecretArn = cdk.Fn.getStackOutput('DataStack', 'AuroraSecretArn');

    const computeSubnetIds = cdk.Fn.split(',', computeSubnetsString, 2);

    const vpc = ec2.Vpc.fromVpcAttributes(this, 'ImportedVpc', {
      vpcId: vpcId,
      vpcCidrBlock: '10.0.0.0/16',
      availabilityZones: cdk.Fn.getAzs(this.region),
      isolatedSubnetIds: computeSubnetIds,
    });

    const computeSg = ec2.SecurityGroup.fromSecurityGroupId(this, 'ImportedComputeSg', computeSgId);

    // 2. VPC Interface Endpoints (Section 5.4: $0 NAT Gateway approach)
    // Allows private Lambda to reach AWS APIs without an expensive NAT gateway
    const secretsManagerEndpoint = vpc.addInterfaceEndpoint('SecretsManagerVpcEndpoint', {
      service: ec2.InterfaceVpcEndpointAwsService.SECRETS_MANAGER,
      subnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [computeSg],
    });

    const logsEndpoint = vpc.addInterfaceEndpoint('CloudWatchLogsVpcEndpoint', {
      service: ec2.InterfaceVpcEndpointAwsService.CLOUDWATCH_LOGS,
      subnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [computeSg],
    });

    // 3. SQS Dead-Letter Queue (DLQ) (Section 5.3)
    this.dlq = new sqs.Queue(this, 'TelemetryDlq', {
      queueName: 'groupnav-telemetry-dlq',
      retentionPeriod: cdk.Duration.days(14),
      enforceSSL: true,
      encryption: sqs.QueueEncryption.SQS_MANAGED,
    });

    // 4. Lambda Function (Section 5.2)
    // Runs in private compute subnet, attached to ComputeSG, raw per-invocation DB lifecycle
    this.processTelemetryLambda = new nodejs.NodejsFunction(this, 'ProcessTelemetryFunction', {
      functionName: 'groupnav-process-telemetry',
      description: 'Ingests MQTT GPS telemetry into Redis (GEOADD) and Aurora (PostGIS)',
      entry: path.join(__dirname, '../lambda/process-telemetry/index.ts'),
      handler: 'handler',
      runtime: lambda.Runtime.NODEJS_22_X,
      timeout: cdk.Duration.seconds(15),
      memorySize: 256,
      vpc,
      vpcSubnets: {
        subnetType: ec2.SubnetType.PRIVATE_ISOLATED,
      },
      securityGroups: [computeSg],
      environment: {
        REDIS_ENDPOINT: redisEndpoint,
        REDIS_PORT: redisPort,
        AURORA_CLUSTER_ENDPOINT: auroraClusterEndpoint,
        AURORA_SECRET_ARN: auroraSecretArn,
      },
      bundling: {
        minify: true,
        sourceMap: true,
        externalModules: ['@aws-sdk/*', 'pg-native'],
      },
    });

    // Lambda needs to read the Aurora credentials secret
    const auroraSecret = secretsmanager.Secret.fromSecretCompleteArn(this, 'ImportedAuroraSecret', auroraSecretArn);
    auroraSecret.grantRead(this.processTelemetryLambda);

    // 5. AWS IoT Topic Rule (Section 5.3)
    // SQL: SELECT *, topic(2) as rider_id FROM 'groupnav/+/telemetry'
    // Target: Lambda Function
    // Error Action: SQS Dead-Letter Queue
    
    // IAM Role for IoT Rule to send failed messages to SQS DLQ
    const iotRuleRole = new iam.Role(this, 'IotRuleErrorRole', {
      assumedBy: new iam.ServicePrincipal('iot.amazonaws.com'),
      description: 'IAM role allowing AWS IoT to forward failed messages to SQS DLQ',
    });
    this.dlq.grantSendMessages(iotRuleRole);

    this.topicRule = new iot.CfnTopicRule(this, 'TelemetryTopicRule', {
      ruleName: 'groupnav_telemetry_ingestion_rule',
      topicRulePayload: {
        sql: "SELECT *, topic(2) as rider_id FROM 'groupnav/+/telemetry'",
        ruleDisabled: false,
        awsIotSqlVersion: '2016-03-23',
        description: 'Routes rider GPS telemetry to processTelemetry Lambda with SQS DLQ fallback',
        actions: [
          {
            lambda: {
              functionArn: this.processTelemetryLambda.functionArn,
            },
          },
        ],
        errorAction: {
          sqs: {
            queueUrl: this.dlq.queueUrl,
            roleArn: iotRuleRole.roleArn,
            useBase64: false,
          },
        },
      },
    });

    // Grant IoT permission to invoke processTelemetry Lambda
    new lambda.CfnPermission(this, 'IotInvokeTelemetryLambdaPermission', {
      action: 'lambda:InvokeFunction',
      functionName: this.processTelemetryLambda.functionArn,
      principal: 'iot.amazonaws.com',
      sourceArn: this.topicRule.attrArn,
    });

    // 6. Outputs
    new cdk.CfnOutput(this, 'ProcessTelemetryLambdaArn', {
      value: this.processTelemetryLambda.functionArn,
      description: 'ARN of the processTelemetry Lambda function',
    });

    new cdk.CfnOutput(this, 'TelemetryDlqUrl', {
      value: this.dlq.queueUrl,
      description: 'URL of the Telemetry SQS Dead-Letter Queue',
    });

    new cdk.CfnOutput(this, 'TelemetryDlqArn', {
      value: this.dlq.queueArn,
      description: 'ARN of the Telemetry SQS Dead-Letter Queue',
    });
  }
}
