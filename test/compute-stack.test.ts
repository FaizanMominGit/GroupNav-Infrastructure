import * as cdk from 'aws-cdk-lib';
import { Template, Match } from 'aws-cdk-lib/assertions';
import { ComputeStack } from '../lib/compute-stack';

describe('ComputeStack', () => {
  let app: cdk.App;
  let stack: ComputeStack;
  let template: Template;

  beforeEach(() => {
    app = new cdk.App();
    stack = new ComputeStack(app, 'TestComputeStack', {
      env: { account: '123456789012', region: 'ap-south-1' },
    });
    template = Template.fromStack(stack);
  });

  test('provisions SQS Dead-Letter Queue with encryption', () => {
    template.hasResourceProperties('AWS::SQS::Queue', {
      QueueName: 'groupnav-telemetry-dlq',
      SqsManagedSseEnabled: true,
      MessageRetentionPeriod: 1209600, // 14 days
    });
  });

  test('provisions processTelemetry Lambda with VPC and Node 22 runtime', () => {
    template.hasResourceProperties('AWS::Lambda::Function', {
      FunctionName: 'groupnav-process-telemetry',
      Runtime: 'nodejs22.x',
      Timeout: 15,
      MemorySize: 256,
      Environment: {
        Variables: Match.objectLike({
          REDIS_PORT: Match.anyValue(),
          REDIS_ENDPOINT: Match.anyValue(),
          AURORA_CLUSTER_ENDPOINT: Match.anyValue(),
          AURORA_SECRET_ARN: Match.anyValue(),
        }),
      },
    });
  });

  test('provisions VPC Interface Endpoints for Secrets Manager and CloudWatch Logs ($0 NAT pattern)', () => {
    template.hasResourceProperties('AWS::EC2::VPCEndpoint', {
      VpcEndpointType: 'Interface',
      ServiceName: Match.stringLikeRegexp('.*secretsmanager.*'),
    });

    template.hasResourceProperties('AWS::EC2::VPCEndpoint', {
      VpcEndpointType: 'Interface',
      ServiceName: Match.stringLikeRegexp('.*logs.*'),
    });
  });

  test('provisions IoT Topic Rule for groupnav/+/telemetry with Lambda and SQS error actions', () => {
    template.hasResourceProperties('AWS::IoT::TopicRule', {
      TopicRulePayload: Match.objectLike({
        RuleDisabled: false,
        Sql: Match.stringLikeRegexp(".*groupnav/\\+/telemetry.*"),
        Actions: Match.arrayWith([
          Match.objectLike({
            Lambda: Match.anyValue(),
          }),
        ]),
        ErrorAction: Match.objectLike({
          Sqs: Match.anyValue(),
        }),
      }),
    });
  });

  test('exports decoupled CloudFormation outputs', () => {
    template.hasOutput('ProcessTelemetryLambdaArn', {});
    template.hasOutput('TelemetryDlqUrl', {});
    template.hasOutput('TelemetryDlqArn', {});
  });
});
