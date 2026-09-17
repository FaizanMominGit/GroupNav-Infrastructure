# Step 8: Phase 5 Observability & Demo-Day Guardrails Implementation

## 1. How It Was Done
In this step, we built `ObservabilityStack` (`lib/observability-stack.ts`) establishing end-to-end telemetry monitoring, automated alerting, and audit logging:
- **CloudWatch Operational Dashboard (`GroupNav-Operational-Dashboard`)**:
  - Defined declaratively in AWS CDK to track operational health across all architectural tiers:
    - **Header & Info**: Title and architectural component scope.
    - **Row 1 (IoT Core & DLQ)**:
      - Line graph for MQTT message publishes (`PublishIn.Success`), rule executions (`TopicRuleExecuted`), and failed rule evaluations (`TopicRuleFailed`).
      - Single-value counter displaying dead-letter queue depth (`ApproximateNumberOfMessagesVisible` on `groupnav-telemetry-dlq`).
    - **Row 2 (Ingestion Compute)**:
      - Execution throughput graph for `processTelemetry` Lambda showing `Invocations`, `Errors`, and `Throttles`.
      - Latency graph tracking Average Duration and p95 Duration in milliseconds.
    - **Row 3 (Stateful Tier)**:
      - ElastiCache Redis utilization graph displaying `CPUUtilization` and `DatabaseMemoryUsagePercentage`.
      - Aurora Serverless v2 PostgreSQL graph displaying active `ServerlessDatabaseCapacity` (ACUs), `DatabaseConnections`, and `CPUUtilization`.
- **Automated CloudWatch Metric Alarms**:
  - **`GroupNav-LambdaErrorAlarm`**: Triggers if `processTelemetry` encounters 3 or more errors within a 5-minute evaluation period.
  - **`GroupNav-AuroraConnectionSaturationAlarm`**: Triggers if active Aurora connections reach 40 (preventing connection exhaustion against Aurora limits).
  - **`GroupNav-DeadLetterQueueAlarm`**: Triggers if any malformed or poisoned telemetry messages accumulate in the DLQ (`>= 1` message in 5 minutes).
  - All alarms configured with `treatMissingData: NOT_BREACHING` to avoid false alerts during idle periods when zero traffic flows.
- **AWS IoT Core CloudWatch Logging**:
  - Created IAM Role `AWSIoTLoggingRole` (`GroupNav-IoT-CloudWatch-Logging-Role`) assumed by `iot.amazonaws.com` with managed policy `service-role/AWSIoTLogging`.
  - Configured `AWS::IoT::Logging` setting default account-level log verbosity to `WARN` to capture protocol-level MQTT authentication rejections and malformed topic attempts without excessive CloudWatch ingestion costs.

## 2. Why It Was Done This Way
- **Version-Controlled Observability**: Rather than manually clicking in the AWS Console, the operational dashboard and alarms are codified in CDK, ensuring complete parity between environments and zero configuration drift.
- **Three-Tier Visibility**: Real-time group navigation systems require instantaneous feedback across the entire lifecycle: (1) ingestion at IoT Core, (2) compute processing in Lambda, and (3) live/durable storage in Redis and Aurora.
- **Scale-to-Zero Guardrails**: With Aurora Serverless v2 configured to auto-pause to 0 ACUs during idle intervals, the dashboard's `ServerlessDatabaseCapacity` widget provides real-time verification of auto-pause and scale-up dynamics.
- **Cost-Conscious Alerting**: Using 5-minute evaluation periods and `NOT_BREACHING` for missing data prevents transient alert noise and avoids paying for high-resolution 10-second alarm fees while maintaining full operational visibility.

## 3. Verification Evidence

### 3.1 Automated Synthesis & Unit Testing
- Synthesized cleanly via `npx cdk diff ObservabilityStack`.
- Complete test suite passed (**36/36 tests passing across all 6 stacks**):
  - Verified CloudWatch Dashboard resource and widget structure.
  - Verified Lambda error rate alarm, Aurora connection saturation alarm, and DLQ accumulation alarm.
  - Verified AWS IoT CloudWatch logging role and logging configuration.
  - Verified CloudFormation outputs for Dashboard Name and Alarm ARNs.

### 3.2 Live Cloud Verification Evidence
`ObservabilityStack` was deployed to AWS `ap-south-1` (`CREATE_COMPLETE`), and verified using `scripts/verify-phase5.ts`:
- **Stack ARN**: `arn:aws:cloudformation:ap-south-1:325313611329:stack/ObservabilityStack/457a5050-b042-11f1-94f4-0a221da95f4d`
- **Dashboard Verified**: `GroupNav-Operational-Dashboard` actively configured with 7 widgets:
  1. Operational Overview Text & Scope Header
  2. AWS IoT Core Telemetry Ingestion & Topic Rule Executions
  3. Telemetry SQS Dead-Letter Queue Depth
  4. processTelemetry Lambda Executions, Errors & Throttles
  5. processTelemetry Lambda Execution Latency (Avg & p95)
  6. ElastiCache Redis Spatial Cache CPU & Memory Utilization
  7. Aurora Serverless v2 PostgreSQL Capacity (ACUs) & Connections
- **Alarms Verified Active in CloudWatch**:
  1. `GroupNav-LambdaErrorAlarm`: Errors $\ge 3$ within 5 minutes.
  2. `GroupNav-AuroraConnectionSaturationAlarm`: DatabaseConnections $\ge 40$ within 5 minutes.
  3. `GroupNav-DeadLetterQueueAlarm`: ApproximateNumberOfMessagesVisible $\ge 1$ within 5 minutes.
- **AWS IoT Core Logging Verified**: `AWSIoTLoggingRole` and `IoTCoreLogging` enabled at default log level `WARN`.

