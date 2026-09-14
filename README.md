# GroupNav Infrastructure

> Production-grade, real-time group location-tracking and telemetry infrastructure built on AWS with AWS CDK (TypeScript).

---

## 📌 Architecture Overview

GroupNav is designed for real-time mobile location sharing. Riders authenticate via **Amazon Cognito**, render vector maps using **Amazon Location Service**, and stream live GPS coordinates over MQTT to **AWS IoT Core**. Ingested coordinates are processed serverlessly via **AWS Lambda**, cached in **Amazon ElastiCache Redis** for sub-millisecond proximity queries, and durably stored in **Amazon Aurora Serverless v2 PostgreSQL** with **PostGIS** spatial indexing.

```mermaid
flowchart TD
    subgraph Client ["Mobile Client (Flutter) / Web App"]
        Rider["Rider Device"]
    end

    subgraph AuthLoc ["Identity & Mapping"]
        Cognito["Amazon Cognito\n(User Pool + Identity Pool)"]
        LocMap["Amazon Location Service\n(GroupNavMap + Geofences)"]
    end

    subgraph Ingestion ["Real-Time Ingestion Tier"]
        IoTCore["AWS IoT Core\n(MQTT Topic: groupnav/{riderId}/telemetry)"]
        TopicRule["IoT Topic Rule\n(SELECT *, topic(2) as rider_id)"]
        DLQ["Amazon SQS DLQ\n(groupnav-telemetry-dlq)"]
    end

    subgraph Compute ["Compute Tier ($0 NAT Gateway)"]
        VPC["Amazon VPC (Multi-AZ)"]
        Endpoints["VPC Endpoints\n(Secrets Manager, Logs, S3)"]
        Lambda["processTelemetry Lambda\n(Node.js 22 LTS, ARM64)"]
    end

    subgraph Storage ["Stateful Storage Tier"]
        Redis["Amazon ElastiCache Redis\n(GEOADD riders lon lat riderId)"]
        Aurora["Aurora Serverless v2 (PostgreSQL 16.8)\n(PostGIS spatial geometry: ST_MakePoint)"]
    end

    subgraph CICDObs ["CI/CD & Observability"]
        Pipeline["AWS CodePipeline & CodeBuild\n(Native Continuous Deployment)"]
        Dashboard["CloudWatch Dashboard & Alarms\n(GroupNav-Operational-Dashboard)"]
    end

    Rider -->|1. Authenticate| Cognito
    Rider -->|2. Fetch Map Tiles| LocMap
    Rider -->|3. Publish GPS MQTT| IoTCore
    IoTCore -->|Trigger| TopicRule
    TopicRule -->|Primary Action| Lambda
    TopicRule -->|Error Fallback| DLQ
    Lambda -->|PrivateLink| Endpoints
    Lambda -->|O(1) Live Spatial Cache| Redis
    Lambda -->|Durable Spatial History| Aurora
```

---

## 🧱 The 6 Infrastructure Stacks

The infrastructure is decoupled into six independently deployable, independently testable CDK stacks:

| Stack | File | Key Resources & Configurations |
|---|---|---|
| **`NetworkStack`** | [`lib/network-stack.ts`](lib/network-stack.ts) | Multi-AZ VPC (`10.0.0.0/16`), Public, Private Compute, and Isolated Data subnets. Security groups `ComputeSG` and `DataSG`. Gateway S3 and DynamoDB endpoints (**$0 NAT Gateway fee**). |
| **`AuthStack`** | [`lib/auth-stack.ts`](lib/auth-stack.ts) | Cognito User Pool, Cognito Identity Pool, Amazon Location Service Map (`GroupNavMap`) & Geofence Collection. Scoped authenticated rider IAM role with least-privilege map access. |
| **`DataStack`** | [`lib/data-stack.ts`](lib/data-stack.ts) | Single-node ElastiCache Redis cluster in isolated subnets. Aurora Serverless v2 PostgreSQL 16.8 cluster with PostGIS spatial extension (`MinCapacity: 0`, auto-pause enabled at 300s). AWS Secrets Manager for database credentials. |
| **`ComputeStack`** | [`lib/compute-stack.ts`](lib/compute-stack.ts) | `processTelemetry` Lambda (Node.js 22 LTS, ARM64) placed in private subnets. PrivateLink VPC Interface Endpoints for Secrets Manager and CloudWatch Logs. AWS IoT Core Topic Rule with Amazon SQS Dead-Letter Queue (DLQ). |
| **`PipelineStack`** | [`lib/pipeline-stack.ts`](lib/pipeline-stack.ts) | **100% AWS-Native CI/CD**: AWS CodePipeline, AWS CodeBuild serverless project, AWS S3 Artifact Bucket, and AWS CodeStar Connection linking to GitHub repository. |
| **`ObservabilityStack`** | [`lib/observability-stack.ts`](lib/observability-stack.ts) | CloudWatch Operational Dashboard (`GroupNav-Operational-Dashboard`) with 7 widgets tracking IoT, DLQ, Lambda latency/errors, Redis, and Aurora ACUs. CloudWatch Alarms on Lambda errors, Aurora saturation, and DLQ depth. Dedicated IoT CloudWatch Logging. |

---

## 📱 Mobile & Client Integration

All dynamic stack outputs, authentication pool IDs, and API endpoints are exported cleanly into a single unified JSON artifact: **[`client-config.json`](client-config.json)**.

### Regenerating Configuration
To refresh the client configuration directly from live CloudFormation stack outputs:
```bash
npm run export-config
```

### Configuration Schema:
```json
{
  "region": "ap-south-1",
  "cognito": {
    "userPoolId": "ap-south-1_JoK8Zlj1x",
    "userPoolClientId": "4ko1153kp0hl7q7oa402cqiqfi",
    "identityPoolId": "ap-south-1:0efa5668-5ed9-4ee6-9120-86f8cc2ae4cd"
  },
  "location": {
    "mapName": "GroupNavMap",
    "mapArn": "arn:aws:geo:ap-south-1:325313611329:map/GroupNavMap",
    "geofenceCollectionName": "GroupNavGeofenceCollection",
    "geofenceCollectionArn": "arn:aws:geo:ap-south-1:325313611329:geofence-collection/GroupNavGeofenceCollection"
  },
  "iot": {
    "endpoint": "a362o0ub4ypzaj-ats.iot.ap-south-1.amazonaws.com"
  },
  "compute": {
    "lambdaArn": "arn:aws:lambda:ap-south-1:325313611329:function:groupnav-process-telemetry",
    "dlqUrl": "https://sqs.ap-south-1.amazonaws.com/325313611329/groupnav-telemetry-dlq",
    "telemetryTopicPattern": "groupnav/{riderId}/telemetry"
  }
}
```

---

## 🧪 Testing & Verification Runbooks

### 1. Automated Unit Tests
Runs all 35 Jest unit tests across all 6 CDK stacks:
```bash
npm test
```

### 2. Live Cloud Verification Scripts
| Script | Command | Purpose |
|---|---|---|
| Phase 1 Verification | `npx tsx scripts/verify-phase1.ts` | Authenticates test user via Cognito, exchanges STS tokens, downloads Amazon Location Service map tiles. |
| Phase 3 Verification | `npx tsx scripts/verify-phase3.ts` | Connects over MQTT to IoT Core, publishes live telemetry, tests IoT Rule error action against SQS DLQ. |
| Phase 5 Verification | `npx tsx scripts/verify-phase5.ts` | Asserts CloudWatch Dashboard widget configurations and queries active CloudWatch Alarms. |

---

## 📖 Milestone Documentation

Detailed step-by-step engineering documentation explaining the **How**, **Why**, and **Verification Evidence** for every phase:

- [Step 1: Multi-Stack Initialization](docs/STEP_1_HOW_AND_WHY.md)
- [Step 2: Network Foundation & $0 NAT Fee Architecture](docs/STEP_2_HOW_AND_WHY.md)
- [Step 3: Cognito Identity & Location Security](docs/STEP_3_HOW_AND_WHY.md)
- [Step 4: Phase 1 Cloud Verification & Client Config Export](docs/STEP_4_HOW_AND_WHY.md)
- [Step 5: Stateful Data Layer (Redis & Aurora Serverless v2 PostGIS)](docs/STEP_5_HOW_AND_WHY.md)
- [Step 6: Telemetry Ingestion & Compute Pipeline](docs/STEP_6_HOW_AND_WHY.md)
- [Step 7: AWS-Native CI/CD Pipeline](docs/STEP_7_HOW_AND_WHY.md)
- [Step 8: CloudWatch Observability & Demo Guardrails](docs/STEP_8_HOW_AND_WHY.md)
- [Troubleshooting & Prevention Log](TROUBLESHOOTING_LOG.md)

---

## 🚀 Deployment Commands

```bash
# Synthesize CloudFormation templates
npx cdk synth

# Deploy all stacks
npx cdk deploy --all

# Deploy specific stack
npx cdk deploy ComputeStack
npx cdk deploy ObservabilityStack
```
