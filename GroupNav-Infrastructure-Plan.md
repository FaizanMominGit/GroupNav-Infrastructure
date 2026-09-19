# GroupNav Infrastructure Plan
### Bharat Builds Tour — AWS CDK (TypeScript) Deployment Guide

**Version:** 1.0
**Owner:** Infra/DevOps team
**Audience:** Backend engineers deploying the stack, Flutter team consuming outputs

---

## 1. Overview

GroupNav is a real-time group location-tracking app. Riders publish GPS telemetry over MQTT, the backend turns that into live positions and historical trips, and the Flutter client renders it on a map.

This document defines the infrastructure build order, the architecture decisions behind it, and the verification step for each phase. The guiding principle: **five independently deployable, independently testable stacks**, ordered so the mobile/client team is never blocked waiting on backend work.

| Stack | Depends on | Unblocks |
|---|---|---|
| 1. Network, Identity & Location | — | Flutter team can start integrating auth + maps |
| 2. Data Layer | Stack 1 (VPC, SGs) | — |
| 3. Ingestion & Compute | Stacks 1–2 | End-to-end telemetry pipeline |
| 4. CI/CD | Stack 1 (OIDC) | Team-wide rapid iteration |
| 5. Observability | Stacks 1–3 | Demo-day confidence |

---

## 2. Prerequisites

- AWS CLI v2 configured with an account that has sufficient hackathon credits
- Node.js 18+, AWS CDK v2 (`npm install -g aws-cdk`)
- `npx cdk init app --language typescript`, split into multiple stack files from day one (`NetworkStack`, `AuthStack`, `DataStack`, `ComputeStack`, `PipelineStack`, `ObservabilityStack`) rather than one monolith — this keeps blast radius small and `cdk diff` fast and legible on PRs.

---

## 3. Phase 1 — Network, Identity & Location Foundation

**Goal:** establish the network boundary and secure client access before any data flows.

### 3.1 VPC
- `MaxAzs: 2`
- Three subnet tiers:
  - **Public** — NAT/bastion only (bastion deployed temporarily, not left running)
  - **Private (with egress)** — compute (Lambda)
  - **Isolated** — no route to the internet at all (Redis, Aurora)

### 3.2 Cognito
- User Pool — rider registration/login
- Identity Pool — issues short-lived IAM credentials so mobile clients talk directly to IoT Core and Location Service without a proxy

### 3.3 Amazon Location Service
- **Map Resource**: `GroupNavMap` (`VectorEsriNavigation`) for high-contrast vector cartography.
- **Geofence Collection**: `GroupNavGeofenceCollection` for pack boundary and proximity monitoring.
- **Route Calculator**: `GroupNavRouteCalculator` (`dataSource: Esri`, `pricingPlan: RequestBasedUsage`) for multi-waypoint road-following geometry, road distances, and durations.
- **Place Index**: `GroupNavPlaceIndex` (`dataSource: Esri`, `pricingPlan: RequestBasedUsage`) for tactical address search, landmark geocoding, and autocomplete.
- **IAM Scoped Permissions**: Narrowly scoped on the Cognito **authenticated** role:
  - Map tiles: `geo:GetMapGlyphs`, `geo:GetMapSprites`, `geo:GetMapStyleDescriptor`, `geo:GetMapTile`.
  - Geofences: `geo:BatchEvaluateGeofences`, `geo:GetGeofence`, `geo:ListGeofences`.
  - Routing: `geo:CalculateRoute`, `geo:CalculateRouteMatrix` on Route Calculator ARN.
  - Places: `geo:SearchPlaceIndexForText`, `geo:SearchPlaceIndexForPosition`, `geo:SearchPlaceIndexForSuggestions` on Place Index ARN.

### 3.4 Security Groups (defined here, not deferred)
- `ComputeSG` — attached to Lambda
- `DataSG` — attached to Redis/Aurora, inbound restricted to `ComputeSG` only on ports `6379` and `5432`. No `0.0.0.0/0` inbound anywhere in the VPC.

### 3.5 Cross-stack references
- Use **`Fn::GetStackOutput`** (native CloudFormation intrinsic, CDK-supported) to pass `VpcId`, subnet IDs, and Security Group IDs from `NetworkStack` into downstream stacks.
- This replaces the old pattern of passing CDK constructs directly across stacks, which silently generates `Fn::Export`/`Fn::ImportValue` pairs and can deadlock (`"Export cannot be updated because it is in use"`) if the network stack ever needs to change.
- `Fn::GetStackOutput` reads a plain stack `Output` — no `Export` required — so CloudFormation never locks the producing stack. Works for same-account/same-region references (the common case here) as well as cross-account/region.

**Verify:**
```
cdk deploy NetworkStack AuthStack
```
Register a test user via AWS CLI, exchange for temporary IAM credentials, and confirm a map tile loads using those credentials.

---

## 4. Phase 2 — Data Layer

**Goal:** stateful stores, isolated from the internet, cost-aware by default.

### 4.1 Redis (ElastiCache)
- Deployed into Isolated subnets
- Used for `GEOADD` / `GEOSEARCH` — live position queries, O(1) lookups for "who's near me"

### 4.2 Aurora Serverless v2 (PostgreSQL)
- **PostGIS extension enabled** — needed for historical trip geometry and spatial queries beyond what Redis handles
- Engine version must be **PostgreSQL 15.7+ or 16.3+** (or 13.15+/14.12+) — true scale-to-zero auto-pause is only supported on these versions
- `MinCapacity: 0`, `SecondsUntilAutoPause: 300` (5 minutes) — valid range is 300–86,400 seconds
- **No RDS Proxy attached.** RDS Proxy (along with logical/binlog replication and Aurora Global Database) is a documented blocker for auto-pause — it holds connections open indefinitely and the cluster never sees zero activity.
- Credentials in Secrets Manager — never hardcoded, never output in plaintext `CfnOutput`

> **Demo-day caveat:** resume from a full pause takes up to ~15 seconds. A 5-minute auto-pause window is great for saving credits overnight/between work sessions, but if a judge hits the app cold, the first request will stall. Widen or disable auto-pause during the actual demo window; keep it aggressive only during development.

### 4.3 Security Groups
- `DataSG` (from Phase 1) applied to both Redis and Aurora — inbound only from `ComputeSG`

**Verify:** temporarily deploy a bastion host in the public subnet, confirm Redis/Postgres are reachable only from `ComputeSG`-tagged resources, confirm the PostGIS extension is active, then **destroy the bastion.**

---

## 5. Phase 3 — Ingestion & Compute

**Goal:** the real-time telemetry pipeline, MQTT → Lambda → Redis/Aurora.

### 5.1 IoT Core Policy
- Grants `iot:Connect`, `iot:Publish` to the Cognito authenticated role
- Scoped per-identity using IoT policy variables:
  `groupnav/${cognito-identity.amazonaws.com:sub}/telemetry`
  — this prevents one rider from publishing telemetry as another rider.

### 5.2 Lambda (`processTelemetry`)
- Node.js or Go, deployed in the **Private (with egress)** subnet, attached to `ComputeSG`
- Performs `GEOADD` in Redis and writes trip history to Aurora
- **Connection strategy:** open/close a raw Postgres connection per invocation (not a persistent pooler), so Aurora can actually reach zero ACU between bursts of activity. Watch `max_connections` under concurrent load — if a traffic spike from simultaneous testers exhausts connections, that's the tradeoff for enabling auto-pause. The Aurora Data API is an alternative (HTTP-based, no connection limit) if region/version support checks out.

### 5.3 IoT Topic Rule
```sql
SELECT * FROM 'groupnav/+/telemetry'
```
- Lambda action as the target
- **Error action** configured (e.g., SQS dead-letter queue) so malformed or failed messages are captured, not silently dropped

### 5.4 No NAT Gateway
A NAT Gateway costs ~$32/month plus data processing fees — real money against hackathon credits, and unnecessary here. Instead, provision **VPC Interface Endpoints (PrivateLink)** for every AWS API the Lambda calls:

| Endpoint | Why |
|---|---|
| `iot.data` (regional IoT data-plane endpoint) | Lambda may publish/subscribe back to IoT Core |
| `logs` | CloudWatch Logs writes |
| `secretsmanager` | Fetching Aurora credentials at invocation time |
| S3 (Gateway Endpoint, free) | Add preemptively — needed if you add Lambda layers or static asset pulls later |

Redis and Aurora need no endpoint — they're reached over plain TCP inside the VPC.

**Verify:** publish a test payload via the IoT Core test client. Confirm CloudWatch Logs show Lambda execution, confirm the coordinate lands in Redis (`redis-cli GEOPOS`) and/or Aurora, and confirm a deliberately malformed payload lands in the DLQ instead of disappearing.

---

## 6. Phase 4 — CI/CD

**Goal:** remove manual deploy bottlenecks without weakening security.

- **GitHub OIDC** identity provider — no long-lived AWS access keys stored in repo secrets.
- Scope the CI deploy role's IAM permissions to exactly what CDK needs for this account/region — not `AdministratorAccess`.
- Workflow (`.github/workflows/deploy.yml`):
  - On **pull request**: `npm run test` → `cdk synth` → `cdk diff`, posted as a PR comment
  - On **push to `main`**: `npm run test` → `cdk synth` → `cdk deploy --require-approval never`
- **Client config export:** use `CfnOutput` to publish the IoT ATS endpoint, Cognito Region/Pool IDs, and Location Service map name into a `client-config.json` build artifact the Flutter team pulls automatically — no manual copy-paste, no drift.

**Verify:** open a PR touching infra, confirm `cdk diff` posts to it. Merge, confirm the pipeline deploys automatically and `client-config.json` updates.

---

## 7. Phase 5 — Observability

**Goal:** don't find out the pipeline is broken during the demo.

- **CloudWatch Dashboard** (defined in CDK, versioned like everything else):
  - IoT Core message rate and errors
  - Lambda duration, error rate, throttles
  - Redis memory and CPU utilization
  - Aurora ACU utilization and connection count
- **Basic alarms** on Lambda error rate and Aurora connection saturation
- **IoT Core logging** to CloudWatch Logs, separate from Lambda logs, for MQTT-level debugging (auth failures, malformed topics)

**Verify:** trigger a deliberate Lambda error and confirm it shows up on the dashboard (and fires the alarm, if configured).

---

## 8. Summary Checklist

- [x] VPC with Public / Private-egress / Isolated subnets
- [x] Cognito User Pool + Identity Pool
- [x] Location Service Map + Geofence, scoped IAM policy
- [x] `ComputeSG` / `DataSG` defined and enforced
- [x] Cross-stack refs via `Fn::GetStackOutput`, not raw construct passing
- [x] Redis in Isolated subnet
- [x] Aurora Serverless v2 + PostGIS, `MinCapacity: 0`, auto-pause 300s, no RDS Proxy
- [x] Secrets Manager for DB credentials
- [x] IoT Core policy scoped per-identity
- [x] Lambda in Private-egress subnet, per-invocation DB connections
- [x] IoT Topic Rule with DLQ error action
- [x] No NAT Gateway — Interface Endpoints for `iot.data`, `logs`, `secretsmanager`; Gateway Endpoint for S3
- [x] AWS-Native CI/CD: AWS CodePipeline, CodeBuild, S3, CodeStar Connection
- [x] Automated build, test, and deploy pipeline
- [x] `client-config.json` artifact for Flutter team
- [x] CloudWatch Dashboard + alarms
- [ ] Wider/disabled Aurora auto-pause window set before the actual demo

