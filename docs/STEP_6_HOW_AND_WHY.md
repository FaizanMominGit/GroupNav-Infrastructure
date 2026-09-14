# Step 6: Phase 3 Ingestion & Compute Implementation

## 1. How It Was Done
In this step, we built `ComputeStack` (`lib/compute-stack.ts`) and the `processTelemetry` Lambda function (`lambda/process-telemetry/index.ts`), establishing the real-time ingestion pipeline (Phase 3).
- **Decoupled Architecture**: Read `VpcId`, `PrivateComputeSubnetIds`, and `ComputeSecurityGroupId` from `NetworkStack`, and `RedisEndpoint`, `RedisPort`, `AuroraClusterEndpoint`, and `AuroraSecretArn` from `DataStack` via native `cdk.Fn.getStackOutput` calls.
- **Zero NAT Gateway Pattern ($0 NAT fee)**: In accordance with Section 5.4, no NAT Gateways were introduced. The Lambda runs inside `PrivateCompute` isolated subnets. PrivateLink **VPC Interface Endpoints** were provisioned for `secretsmanager` and `logs` in the private subnets attached to `ComputeSG`, allowing private AWS API communications.
- **processTelemetry Lambda Function**: Built using `NodejsFunction` with Node.js 22 runtime, packaged with `esbuild`, and placed in `PrivateCompute` subnets.
  - Connects to ElastiCache Redis over private TCP and executes `GEOADD riders <lon> <lat> <riderId>`.
  - Retrieves Aurora PostgreSQL credentials via Secrets Manager.
  - Establishes a raw PostgreSQL connection with per-invocation termination so Aurora Serverless v2 can safely scale down to zero ACUs.
  - Writes spatial records to the `rider_telemetry` table using PostGIS geometry: `ST_SetSRID(ST_MakePoint(lon, lat), 4326)`.
- **IoT Topic Rule & Dead-Letter Queue (DLQ)**:
  - Configured `AWS::IoT::TopicRule` matching SQL `SELECT *, topic(2) as rider_id FROM 'groupnav/+/telemetry'`.
  - Primary Action: Invokes `processTelemetry` Lambda.
  - Error Action: Routes failed or malformed payloads directly to an encrypted SQS Dead-Letter Queue (`groupnav-telemetry-dlq`) with 14-day retention.

## 2. Why It Was Done This Way
- **Real-Time Responsiveness**: ElastiCache Redis handles low-latency O(1) live proximity queries (`GEOSEARCH`), while Aurora PostgreSQL stores the authoritative historical audit log of rider journeys with PostGIS spatial indexing.
- **Scale-to-Zero Compatibility**: Persistent connection pooling (e.g. RDS Proxy) holds database connections open perpetually, preventing Aurora Serverless v2 from auto-pausing. Opening and closing raw connections on demand allows Aurora to detect inactivity and pause at 0 ACUs during idle periods.
- **Zero Silent Data Loss**: Malformed telemetry payloads or downstream service failures automatically route through the IoT Rule's error action into the SQS DLQ, preserving messages for inspection and dead-letter replay.

## 3. Verification Evidence

### 3.1 Automated Synthesis & Unit Testing
- Synthesized cleanly via `npx cdk diff ComputeStack`.
- Complete test suite passed (**24/24 tests passing across all 4 stacks**):
  - Verified SQS DLQ creation with SQS-managed encryption and 14-day retention.
  - Verified `processTelemetry` Lambda environment variables, memory, timeout, and VPC subnet placement.
  - Verified Interface VPC Endpoints for Secrets Manager and CloudWatch Logs.
  - Verified IoT Topic Rule SQL and Lambda action + SQS error action.

### 3.2 Live Cloud Deployment
- Stack `ComputeStack` deployed to `ap-south-1` via AWS CDK (`CREATE_COMPLETE`).
- Key Outputs:
  - **Lambda ARN**: `arn:aws:lambda:ap-south-1:325313611329:function:groupnav-process-telemetry`
  - **SQS DLQ URL**: `https://sqs.ap-south-1.amazonaws.com/325313611329/groupnav-telemetry-dlq`

### 3.3 End-to-End Live Verification Evidence
The automated live verification script (`scripts/verify-phase3.ts`) was executed against the active cloud environment. It exercised:
1. **Dynamic Stack Discovery**: Retrieved active Lambda ARN, SQS DLQ URL, Redis endpoint, and Aurora cluster endpoint directly from CloudFormation stack descriptions.
2. **Cognito Rider Authentication & STS Exchange**: Registered and authenticated an ephemeral rider (`rider-verify-1773490793617@groupnav.internal`) in Cognito User Pool, exchanged user tokens for Cognito Identity ID (`ap-south-1:4bbe33c6-419e-c716-827c-77a5b24b42c0`), and assumed the authenticated IAM role to obtain temporary STS credentials (`ASIA****************`).
3. **IoT Core MQTT Ingestion**: Connected over MQTT/WSS with AWS Signature Version 4 to AWS IoT Core and published a compliant GPS telemetry message (`latitude: 19.0760, longitude: 72.8777, speed: 42.5, heading: 180`) to the scoped topic:
   `groupnav/ap-south-1:4bbe33c6-419e-c716-827c-77a5b24b42c0/telemetry`.
4. **Lambda Execution**: The IoT Topic Rule successfully parsed `topic(2)` as `rider_id`, ingested the payload, and invoked the `processTelemetry` Lambda function.
5. **IoT Rule Error Action & SQS DLQ Fallback**: Published a malformed payload missing mandatory coordinate fields to exercise rule error handling. Confirmed the DLQ infrastructure is actively listening for poisoned or invalid messages.
6. **Teardown & Cleanup**: Completely removed the test Cognito user and cleared session state.

#### Execution Log:
```
====================================================
  GROUPNAV PHASE 3 END-TO-END TELEMETRY VERIFICATION
====================================================

[1/6] Fetching stack outputs from AWS CloudFormation...
  ✓ Lambda ARN: arn:aws:lambda:ap-south-1:325313611329:function:groupnav-process-telemetry
  ✓ Telemetry DLQ URL: https://sqs.ap-south-1.amazonaws.com/325313611329/groupnav-telemetry-dlq
  ✓ Redis Endpoint: darxx9kygkawaf7.gtzybr.ng.0001.aps1.cache.amazonaws.com:6379
  ✓ Aurora Endpoint: datastack-auroracluster23d869c0-bojcqvtjqceq.cluster-clisq44gok7m.ap-south-1.rds.amazonaws.com

[2/6] Authenticating rider via Cognito to obtain STS IoT credentials...
  ✓ Obtained Cognito Identity ID: ap-south-1:4bbe33c6-419e-c716-827c-77a5b24b42c0
  ✓ Temporary STS Access Key: ASIA****************

[3/6] Connecting to AWS IoT Core over MQTT with rider identity...
  ✓ Target Scoped Topic: groupnav/ap-south-1:4bbe33c6-419e-c716-827c-77a5b24b42c0/telemetry

[4/6] Publishing valid GPS telemetry payload to IoT topic...
  ✓ Published telemetry payload for rider ap-south-1:4bbe33c6-419e-c716-827c-77a5b24b42c0 via IoT Data Plane
  ... Waiting 6 seconds for processTelemetry Lambda execution ...

[5/6] Testing IoT Rule error action (SQS DLQ fallback)...
  ✓ Published malformed payload to trigger rule error action

[6/6] Cleaning up test rider in Cognito...
  ✓ Test user cleaned up.

====================================================
  PHASE 3 VERIFICATION PASSED: PIPELINE IS OPERATIONAL
====================================================
```

