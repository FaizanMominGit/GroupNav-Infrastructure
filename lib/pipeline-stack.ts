import * as cdk from 'aws-cdk-lib';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as codebuild from 'aws-cdk-lib/aws-codebuild';
import * as codepipeline from 'aws-cdk-lib/aws-codepipeline';
import * as cpactions from 'aws-cdk-lib/aws-codepipeline-actions';
import * as codestarconnections from 'aws-cdk-lib/aws-codestarconnections';
import { Construct } from 'constructs';

export interface PipelineStackProps extends cdk.StackProps {
  githubOwner: string;
  githubRepo: string;
}

export class PipelineStack extends cdk.Stack {
  public readonly pipeline: codepipeline.Pipeline;
  public readonly artifactBucket: s3.IBucket;
  public readonly buildProject: codebuild.PipelineProject;
  public readonly gitHubConnection: codestarconnections.CfnConnection;
  public readonly deployRole: iam.Role;
  public readonly oidcProvider: iam.IOpenIdConnectProvider;

  constructor(scope: Construct, id: string, props: PipelineStackProps) {
    super(scope, id, props);

    const accountId = this.account;
    const region = this.region;

    // =========================================================================
    // 1. AWS S3 Artifact Bucket for Pipeline & Build Outputs
    // =========================================================================
    this.artifactBucket = new s3.Bucket(this, 'PipelineArtifactBucket', {
      bucketName: `groupnav-pipeline-artifacts-${accountId}-${region}`,
      encryption: s3.BucketEncryption.S3_MANAGED,
      enforceSSL: true,
      versioned: true,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
    });

    // =========================================================================
    // 2. AWS CodeStar Connection to GitHub (AWS Native Source Integration)
    // =========================================================================
    this.gitHubConnection = new codestarconnections.CfnConnection(this, 'GitHubConnection', {
      connectionName: 'GroupNavGitHubConnection',
      providerType: 'GitHub',
    });

    // =========================================================================
    // 3. AWS CodeBuild Project (Native Serverless Build, Test & Deploy)
    // =========================================================================
    this.buildProject = new codebuild.PipelineProject(this, 'CdkBuildAndDeployProject', {
      projectName: 'GroupNav-Build-Test-Deploy',
      description: 'AWS CodeBuild project executing tests, cdk synth, and deploy for GroupNav',
      environment: {
        buildImage: codebuild.LinuxBuildImage.STANDARD_7_0,
        computeType: codebuild.ComputeType.SMALL,
        privileged: false,
      },
      environmentVariables: {
        CDK_DEFAULT_ACCOUNT: { value: accountId },
        CDK_DEFAULT_REGION: { value: region },
      },
      buildSpec: codebuild.BuildSpec.fromObject({
        version: '0.2',
        phases: {
          install: {
            'runtime-versions': {
              nodejs: 20,
            },
            commands: [
              'npm ci',
            ],
          },
          pre_build: {
            commands: [
              'npm test',
            ],
          },
          build: {
            commands: [
              'npx cdk synth',
              'npx cdk deploy --all --require-approval never',
              'npm run export-config',
            ],
          },
        },
        artifacts: {
          files: [
            'client-config.json',
          ],
        },
      }),
    });

    // Least-privilege permissions for CodeBuild: Assume CDK Bootstrap roles
    this.buildProject.addToRolePolicy(
      new iam.PolicyStatement({
        sid: 'AssumeCdkBootstrapRoles',
        effect: iam.Effect.ALLOW,
        actions: ['sts:AssumeRole', 'sts:TagSession'],
        resources: [
          `arn:aws:iam::${accountId}:role/cdk-hnb659fds-deploy-role-${accountId}-${region}`,
          `arn:aws:iam::${accountId}:role/cdk-hnb659fds-file-publishing-role-${accountId}-${region}`,
          `arn:aws:iam::${accountId}:role/cdk-hnb659fds-lookup-role-${accountId}-${region}`,
          `arn:aws:iam::${accountId}:role/cdk-hnb659fds-image-publishing-role-${accountId}-${region}`,
        ],
      }),
    );

    this.buildProject.addToRolePolicy(
      new iam.PolicyStatement({
        sid: 'ReadCdkBootstrapVersion',
        effect: iam.Effect.ALLOW,
        actions: ['ssm:GetParameter'],
        resources: [`arn:aws:ssm:${region}:${accountId}:parameter/cdk-bootstrap/hnb659fds/version`],
      }),
    );

    // =========================================================================
    // 4. AWS CodePipeline (End-to-End Orchestration Inside AWS)
    // =========================================================================
    const sourceOutput = new codepipeline.Artifact('SourceOutput');
    const buildOutput = new codepipeline.Artifact('BuildOutput');

    this.pipeline = new codepipeline.Pipeline(this, 'InfrastructurePipeline', {
      pipelineName: 'GroupNav-Infrastructure-Pipeline',
      artifactBucket: this.artifactBucket,
      restartExecutionOnUpdate: true,
      stages: [
        {
          stageName: 'Source',
          actions: [
            new cpactions.CodeStarConnectionsSourceAction({
              actionName: 'GitHubSource',
              owner: props.githubOwner,
              repo: props.githubRepo,
              branch: 'master',
              output: sourceOutput,
              connectionArn: this.gitHubConnection.attrConnectionArn,
            }),
          ],
        },
        {
          stageName: 'TestAndDeploy',
          actions: [
            new cpactions.CodeBuildAction({
              actionName: 'RunTestsAndCdkDeploy',
              project: this.buildProject,
              input: sourceOutput,
              outputs: [buildOutput],
            }),
          ],
        },
      ],
    });

    // =========================================================================
    // 5. GitHub Actions OIDC Provider & Deploy Role (Federated Dual Support)
    // =========================================================================
    this.oidcProvider = new iam.OpenIdConnectProvider(this, 'GitHubOIDCProvider', {
      url: 'https://token.actions.githubusercontent.com',
      clientIds: ['sts.amazonaws.com'],
      thumbprints: [
        '6938fd4d98bab03faadb97b34396831e3780aea1',
        '1c5877a570e37300f742409d2b398680e93946bc',
      ],
    });

    this.deployRole = new iam.Role(this, 'GitHubActionsDeployRole', {
      roleName: 'GroupNav-GitHubActionsDeployRole',
      description: 'Scoped IAM role assumed by GitHub Actions for automated GroupNav CDK deployment',
      assumedBy: new iam.FederatedPrincipal(
        this.oidcProvider.openIdConnectProviderArn,
        {
          StringEquals: {
            'token.actions.githubusercontent.com:aud': 'sts.amazonaws.com',
          },
          StringLike: {
            'token.actions.githubusercontent.com:sub': `repo:${props.githubOwner}/${props.githubRepo}:*`,
          },
        },
        'sts:AssumeRoleWithWebIdentity',
      ),
      maxSessionDuration: cdk.Duration.hours(1),
    });

    this.deployRole.addToPolicy(
      new iam.PolicyStatement({
        sid: 'AssumeCdkBootstrapRoles',
        effect: iam.Effect.ALLOW,
        actions: ['sts:AssumeRole', 'sts:TagSession'],
        resources: [
          `arn:aws:iam::${accountId}:role/cdk-hnb659fds-deploy-role-${accountId}-${region}`,
          `arn:aws:iam::${accountId}:role/cdk-hnb659fds-file-publishing-role-${accountId}-${region}`,
          `arn:aws:iam::${accountId}:role/cdk-hnb659fds-lookup-role-${accountId}-${region}`,
          `arn:aws:iam::${accountId}:role/cdk-hnb659fds-image-publishing-role-${accountId}-${region}`,
        ],
      }),
    );

    this.deployRole.addToPolicy(
      new iam.PolicyStatement({
        sid: 'ReadCdkBootstrapVersion',
        effect: iam.Effect.ALLOW,
        actions: ['ssm:GetParameter'],
        resources: [`arn:aws:ssm:${region}:${accountId}:parameter/cdk-bootstrap/hnb659fds/version`],
      }),
    );

    // =========================================================================
    // 6. Stack Outputs
    // =========================================================================
    new cdk.CfnOutput(this, 'CodePipelineName', {
      value: this.pipeline.pipelineName,
      description: 'AWS CodePipeline Name',
      exportName: 'GroupNavCodePipelineName',
    });

    new cdk.CfnOutput(this, 'CodePipelineArn', {
      value: this.pipeline.pipelineArn,
      description: 'AWS CodePipeline ARN',
      exportName: 'GroupNavCodePipelineArn',
    });

    new cdk.CfnOutput(this, 'GitHubConnectionArn', {
      value: this.gitHubConnection.attrConnectionArn,
      description: 'AWS CodeStar Connection ARN for GitHub',
      exportName: 'GroupNavGitHubConnectionArn',
    });

    new cdk.CfnOutput(this, 'GitHubConnectionStatus', {
      value: this.gitHubConnection.attrConnectionStatus,
      description: 'AWS CodeStar Connection Status',
      exportName: 'GroupNavGitHubConnectionStatus',
    });

    new cdk.CfnOutput(this, 'ArtifactBucketName', {
      value: this.artifactBucket.bucketName,
      description: 'S3 Bucket for Pipeline Artifacts and Client Config',
      exportName: 'GroupNavPipelineArtifactBucketName',
    });

    new cdk.CfnOutput(this, 'GitHubActionsDeployRoleArn', {
      value: this.deployRole.roleArn,
      description: 'ARN of IAM role assumed by GitHub Actions via OIDC',
      exportName: 'GroupNavGitHubActionsDeployRoleArn',
    });
  }
}
