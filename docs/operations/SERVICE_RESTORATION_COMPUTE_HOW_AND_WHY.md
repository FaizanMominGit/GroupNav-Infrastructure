# Service Restoration & Health Audit: Compute & Telemetry Ingestion Layer
> **Phase**: Operations & Environment Health  
> **Milestone**: Full Restoration of ComputeStack & Ingestion Services  
> **Date**: 2026-09-17  
> **Status**: Verified & Operational (`CREATE_COMPLETE`)

---

## 1. How It Was Done

### 1.1 Service Health Audit & Root Cause Analysis
A systematic audit across all AWS CloudFormation stacks and runtime resources in `ap-south-1` identified that while the base networking, authentication, observability, and data storage layers were fully active, `ComputeStack` was in `ROLLBACK_COMPLETE`:
- **Down Services Detected**:
  - `groupnav-process-telemetry` AWS Lambda function.
  - `groupnav-telemetry-dlq` Amazon SQS Dead-Letter Queue.
  - `groupnav_telemetry_ingestion_rule` AWS IoT Core MQTT topic rule.
  - Interface VPC Endpoints for `secretsmanager` and `logs` in the private compute subnets.
- **Root Cause**:
  Inspection of CloudFormation stack failure events revealed that resource creation failed on `ProcessTelemetryFunctionLogGroup330788B4` with `HandlerErrorCode: AlreadyExists`. An orphaned log group `/aws/lambda/groupnav-process-telemetry` remained in CloudWatch from a previous run. Because CloudFormation cannot overwrite unmanaged existing resources, it initiated an automatic rollback.

### 1.2 Execution Mechanics & Restoration Workflow
To restore the services cleanly without introducing hacks or invalid export states:
1. **Teardown of Rolled-Back Stack**:
   - Because CloudFormation prohibits direct updates on stacks in `ROLLBACK_COMPLETE`, the stack was deleted via AWS CLI (`aws cloudformation delete-stack --stack-name ComputeStack`).
   - We awaited full deletion with `aws cloudformation wait stack-delete-complete`.
2. **Conflict Removal**:
   - The colliding CloudWatch Log Group was pruned via AWS CLI (`aws logs delete-log-group --log-group-name /aws/lambda/groupnav-process-telemetry`).
   - Verified that zero colliding log groups remained under `/aws/lambda/groupnav*`.
3. **Clean Stack Provisioning via AWS CDK**:
   - Executed `npx cdk deploy ComputeStack --require-approval never`.
   - All 15 CloudFormation resources synthesized and deployed cleanly:
     - IAM execution roles with least-privilege policies.
     - SQS DLQ with 14-day retention and server-side encryption.
     - Dual Interface VPC Endpoints ensuring private connectivity without NAT Gateways.
     - Lambda function running Node.js 22 runtime inside private compute subnets.
     - IoT Topic Rule listening on `groupnav/+/telemetry` routing to Lambda with SQS DLQ error fallback.
4. **Client Configuration Refresh**:
   - Executed `npm run export-config` (`tsx scripts/export-client-config.ts`) to dynamically query active stack outputs from CloudFormation and update `client-config.json` with the new Lambda ARN, DLQ URL, Redis endpoint, and Aurora cluster endpoint.
5. **End-to-End Functional Ingestion Verification**:
   - Executed `npx tsx scripts/verify-phase3.ts` to simulate a real rider lifecycle: registering an ephemeral Cognito user, obtaining temporary AWS STS credentials, connecting over MQTT/WSS to AWS IoT Core, publishing valid telemetry, exercising DLQ error routing, and cleaning up the test user.

---

## 2. Why It Was Done This Way

### 2.1 Complete Stack Teardown vs. Ad-Hoc Manual Resources
Creating the Lambda function or SQS queue manually via the AWS Console would violate Infrastructure as Code (IaC) principles, leading to configuration drift and breaking downstream CDK references (`Fn::GetStackOutput`). Deleting the rolled-back stack and re-deploying through CDK ensures strict alignment with the repository's CDK architecture and maintains repeatable infrastructure.

### 2.2 Preserving Decoupled Stack Architecture
`ComputeStack` reads outputs from `NetworkStack` and `DataStack` via `cdk.Fn.getStackOutput` rather than direct construct references. This architectural design ensured that `ComputeStack` could be deleted, cleaned up, and redeployed without locking or impacting the running database or VPC resources.

### 2.3 Comprehensive Verification Over Simple Status Checks
Merely checking that the stack transitioned to `CREATE_COMPLETE` is insufficient to prove service health. Running the end-to-end integration test (`scripts/verify-phase3.ts`) confirmed the entire operational path: IAM authentication, IoT Core MQTT ingestion, Lambda execution, and DLQ handling.

---

## 3. Verification Evidence

### 3.1 CloudFormation Stack Status
All stacks across the project are in a healthy, complete state:
```
-------------------------------------------
|               ListStacks                |
+---------------------+-------------------+
|      StackName      |      Status       |
+---------------------+-------------------+
|  ComputeStack       |  CREATE_COMPLETE  |
|  ObservabilityStack |  CREATE_COMPLETE  |
|  DataStack          |  CREATE_COMPLETE  |
|  PipelineStack      |  UPDATE_COMPLETE  |
|  NetworkStack       |  CREATE_COMPLETE  |
|  AuthStack          |  CREATE_COMPLETE  |
|  CDKToolkit         |  CREATE_COMPLETE  |
+---------------------+-------------------+
```

### 3.2 ComputeStack Provisioning Outputs
- **ProcessTelemetryLambdaArn**: `arn:aws:lambda:ap-south-1:325313611329:function:groupnav-process-telemetry`
- **TelemetryDlqUrl**: `https://sqs.ap-south-1.amazonaws.com/325313611329/groupnav-telemetry-dlq`
- **TelemetryDlqArn**: `arn:aws:sqs:ap-south-1:325313611329:groupnav-telemetry-dlq`

### 3.3 End-to-End Telemetry Ingestion Test
Executing `npx tsx scripts/verify-phase3.ts` yielded 100% success:
- Fetched active outputs dynamically from CloudFormation.
- Authenticated rider via Cognito (`ap-south-1:4bbe33c6-41c8-c437-e778-89164c47bb7b`) and retrieved temporary STS session credentials.
- Connected to AWS IoT Core over MQTT and published GPS telemetry payload (`lat: 19.0760, lon: 72.8777, speed: 42.5 km/h`) to `groupnav/ap-south-1:4bbe33c6-41c8-c437-e778-89164c47bb7b/telemetry`.
- Verified Lambda invocation and triggered IoT Rule SQS DLQ error fallback with malformed payload.
- Cleaned up ephemeral Cognito identity.

### 3.4 Unit Test Suite
Executing `npm test` passed across all 6 test suites and 35 unit test assertions:
- `auth-stack.test.ts`: PASSED
- `network-stack.test.ts`: PASSED
- `data-stack.test.ts`: PASSED
- `compute-stack.test.ts`: PASSED
- `observability-stack.test.ts`: PASSED
- `pipeline-stack.test.ts`: PASSED
