# Step 7: Phase 4 AWS-Native CI/CD Pipeline Implementation

## 1. How It Was Done
In this step, we built `PipelineStack` (`lib/pipeline-stack.ts`) providing a fully AWS-native deployment pipeline alongside federated deployment capabilities:
- **AWS CodeStar Connection (`AWS::CodeStarConnections::Connection`)**:
  - Securely connects AWS CodePipeline to GitHub repository `FaizanMominGit/GroupNav-Infrastructure` on branch `master`.
- **AWS S3 Pipeline Artifact Bucket**:
  - Dedicated private S3 bucket (`groupnav-pipeline-artifacts-<account>-<region>`) with AES-256 S3-managed encryption, SSL transport enforcement (`enforceSSL: true`), versioning, and public access blocked completely.
- **AWS CodeBuild Serverless Build & Deploy Project (`GroupNav-Build-Test-Deploy`)**:
  - Runs in an AWS-managed container environment (`aws/codebuild/standard:7.0`).
  - Executes build phases:
    1. `install`: Installs project dependencies (`npm ci`).
    2. `pre_build`: Executes automated unit test suite (`npm test`).
    3. `build`: Synthesizes templates (`npx cdk synth`), deploys all stacks (`npx cdk deploy --all --require-approval never`), and executes `npm run export-config`.
  - Configured with least-privilege IAM permissions: permits assuming only the standard AWS CDK bootstrap roles (`cdk-hnb659fds-*-role`) and querying the CDK SSM parameter.
- **AWS CodePipeline (`GroupNav-Infrastructure-Pipeline`)**:
  - Two-stage continuous deployment pipeline entirely hosted and orchestrated inside AWS:
    1. **Source Stage**: Listens for changes on branch `master` via AWS CodeStar Connection.
    2. **TestAndDeploy Stage**: Invokes AWS CodeBuild to run tests, deploy stacks, and publish `client-config.json` artifact.
- **Automated Client Configuration Exporter (`scripts/export-client-config.ts`)**:
  - Dynamically discovers active CloudFormation stack outputs (`NetworkStack`, `AuthStack`, `DataStack`, `ComputeStack`, `PipelineStack`).
  - Queries AWS IoT Core ATS endpoint via `@aws-sdk/client-iot` `DescribeEndpointCommand`.
  - Writes directly to `client-config.json` without manual copy-pasting.

## 2. Why It Was Done This Way
- **AWS-Native Operational Control**: Deploying exclusively with AWS CodePipeline and CodeBuild ensures that all build logs, artifacts, and deployment executions reside securely within AWS IAM and CloudWatch boundaries.
- **Zero Static Secrets**: AWS CodePipeline and CodeBuild authenticate via IAM service roles, completely eliminating long-lived AWS access keys.
- **Least-Privilege Bootstrap Delegation**: CodeBuild does not require `AdministratorAccess`. It assumes the segregated CDK bootstrap roles with scoped trust.
- **Deterministic Configuration Artifacts**: Storing `client-config.json` in the versioned S3 artifact bucket and exporting it via CLI ensures the mobile/client team always consumes consistent, valid backend coordinates.

## 3. Verification Evidence

### 3.1 Automated Synthesis & Unit Testing
- Synthesized cleanly via `npx cdk synth PipelineStack`.
- Complete test suite passed (**29/29 tests passing across all 5 stacks**):
  - Verified AWS CodeStar Connection configuration for GitHub.
  - Verified S3 Artifact Bucket encryption, SSL enforcement, and public access blocks.
  - Verified CodeBuild project environment, buildspec commands, and scoped IAM policies.
  - Verified AWS CodePipeline multi-stage definition (`Source` and `TestAndDeploy`).
  - Verified CloudFormation outputs for Pipeline Name, Connection ARN, and Artifact Bucket.

### 3.2 Dynamic Config Export Verification
- Executed `npm run export-config` locally.
- Successfully discovered real-time stack outputs, including the active AWS IoT ATS endpoint (`a362o0ub4ypzaj-ats.iot.ap-south-1.amazonaws.com`).

### 3.3 Live Cloud Deployment Evidence
`PipelineStack` was successfully deployed to AWS `ap-south-1` (`CREATE_COMPLETE`):
- **Stack ARN**: `arn:aws:cloudformation:ap-south-1:325313611329:stack/PipelineStack/e5e0fe50-b03c-11f1-90a3-0a828426636d`
- **AWS CodePipeline ARN**: `arn:aws:codepipeline:ap-south-1:325313611329:GroupNav-Infrastructure-Pipeline`
- **AWS CodeStar Connection ARN**: `arn:aws:codestar-connections:ap-south-1:325313611329:connection/d8157624-26c4-4b54-b689-3bc221f82a96`
- **S3 Pipeline Artifact Bucket**: `groupnav-pipeline-artifacts-325313611329-ap-south-1`



