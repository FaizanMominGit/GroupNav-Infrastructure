import * as cdk from 'aws-cdk-lib';
import { Template, Match } from 'aws-cdk-lib/assertions';
import { PipelineStack } from '../lib/pipeline-stack';

describe('PipelineStack (Phase 4 AWS-Native CI/CD)', () => {
  let app: cdk.App;
  let stack: PipelineStack;
  let template: Template;

  beforeEach(() => {
    app = new cdk.App();
    stack = new PipelineStack(app, 'TestPipelineStack', {
      env: { account: '325313611329', region: 'ap-south-1' },
      githubOwner: 'FaizanMominGit',
      githubRepo: 'GroupNav-Infrastructure',
    });
    template = Template.fromStack(stack);
  });

  test('Creates AWS CodeStar Connection to GitHub', () => {
    template.hasResourceProperties('AWS::CodeStarConnections::Connection', {
      ConnectionName: 'GroupNavGitHubConnection',
      ProviderType: 'GitHub',
    });
  });

  test('Creates S3 Artifact Bucket with encryption and SSL enforcement', () => {
    template.hasResourceProperties('AWS::S3::Bucket', {
      BucketEncryption: {
        ServerSideEncryptionConfiguration: [
          {
            ServerSideEncryptionByDefault: {
              SSEAlgorithm: 'AES256',
            },
          },
        ],
      },
      PublicAccessBlockConfiguration: {
        BlockPublicAcls: true,
        BlockPublicPolicy: true,
        IgnorePublicAcls: true,
        RestrictPublicBuckets: true,
      },
    });
  });

  test('Creates AWS CodeBuild project executing tests and cdk deploy', () => {
    template.hasResourceProperties('AWS::CodeBuild::Project', {
      Name: 'GroupNav-Build-Test-Deploy',
      Environment: {
        ComputeType: 'BUILD_GENERAL1_SMALL',
        Image: 'aws/codebuild/standard:7.0',
        Type: 'LINUX_CONTAINER',
      },
    });
  });

  test('Creates AWS CodePipeline with Source and TestAndDeploy stages', () => {
    template.hasResourceProperties('AWS::CodePipeline::Pipeline', {
      Name: 'GroupNav-Infrastructure-Pipeline',
      Stages: Match.arrayWith([
        Match.objectLike({
          Name: 'Source',
          Actions: Match.arrayWith([
            Match.objectLike({
              ActionTypeId: {
                Category: 'Source',
                Owner: 'AWS',
                Provider: 'CodeStarSourceConnection',
              },
              Name: 'GitHubSource',
            }),
          ]),
        }),
        Match.objectLike({
          Name: 'TestAndDeploy',
          Actions: Match.arrayWith([
            Match.objectLike({
              ActionTypeId: {
                Category: 'Build',
                Owner: 'AWS',
                Provider: 'CodeBuild',
              },
              Name: 'RunTestsAndCdkDeploy',
            }),
          ]),
        }),
      ]),
    });
  });

  test('Exports Pipeline Name, Connection ARN, and Artifact Bucket as CloudFormation Outputs', () => {
    template.hasOutput('CodePipelineName', {
      Export: {
        Name: 'GroupNavCodePipelineName',
      },
    });
    template.hasOutput('GitHubConnectionArn', {
      Export: {
        Name: 'GroupNavGitHubConnectionArn',
      },
    });
    template.hasOutput('ArtifactBucketName', {
      Export: {
        Name: 'GroupNavPipelineArtifactBucketName',
      },
    });
  });
});
