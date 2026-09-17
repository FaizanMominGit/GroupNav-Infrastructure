# GroupNav Engineering Documentation Index

Welcome to the **GroupNav Engineering Documentation**. This directory maintains the complete record of architectural decisions, implementation mechanics, technical tradeoffs, and verification evidence across the AWS CDK cloud backend, Flutter mobile client, UI design system, and operational runbooks.

---

## 🗂️ Documentation Directory Structure

```
docs/
├── README.md                                         # This master index
├── infrastructure/                                   # AWS CDK Cloud Stacks & Backend Milestones
│   ├── STEP_1_HOW_AND_WHY.md                         # CDK Multi-Stack Architecture & Init
│   ├── STEP_2_HOW_AND_WHY.md                         # NetworkStack & $0 NAT Fee Architecture
│   ├── STEP_3_HOW_AND_WHY.md                         # AuthStack (Cognito & Location Security)
│   ├── STEP_4_HOW_AND_WHY.md                         # Cloud Verification & Client Config Export
│   ├── STEP_5_HOW_AND_WHY.md                         # DataStack (Redis & Aurora PostGIS)
│   ├── STEP_6_HOW_AND_WHY.md                         # ComputeStack (IoT Ingestion & Lambda)
│   ├── STEP_7_HOW_AND_WHY.md                         # PipelineStack (AWS-Native CI/CD)
│   └── STEP_8_HOW_AND_WHY.md                         # ObservabilityStack (CloudWatch & Alarms)
├── mobile/                                           # Flutter Mobile App Features & Architecture
│   ├── STEP_1_PACK_AUTH_DECOUPLING_HOW_AND_WHY.md    # Decoupling Pack Rooms from Rider Identity
│   ├── STEP_2_REAL_HARDWARE_GPS_HOW_AND_WHY.md       # Real Hardware GPS with Mock Fallback
│   ├── STEP_3_AWS_IOT_MQTT_HOW_AND_WHY.md            # AWS IoT Core Real-Time MQTT Telemetry
│   ├── STEP_4_PACK_ROOM_LIFECYCLE_HOW_AND_WHY.md     # Pack Room Lifecycle & Solo Mode
│   ├── STEP_5_TRIP_RECORDING_EXPORT_HOW_AND_WHY.md   # Trip Recording & GPX/GeoJSON File Export
│   └── STEP_6_FINAL_FUNCTIONAL_APP_HOW_AND_WHY.md    # End-to-End Mobile App Integration
├── ui/                                               # UI Refresh & Stitch Design System
│   ├── UI_REFRESH_HOW_AND_WHY.md                     # Comprehensive UI Refresh Architecture
│   ├── UI_STEP_1_HOW_AND_WHY.md                      # Stitch Theme Tokens & Foundation
│   ├── UI_STEP_2_HOW_AND_WHY.md                      # Atomic Widgets & Reusable Components
│   ├── UI_STEP_3_HOW_AND_WHY.md                      # Auth Screen & Pilot Call-sign HUD
│   ├── UI_STEP_4_HOW_AND_WHY.md                      # Map HUD & Real-Time Convoy Telemetry
│   ├── UI_STEP_5_HOW_AND_WHY.md                      # Pack Management & Room Formation
│   └── UI_STEP_6_HOW_AND_WHY.md                      # Trip History & GPX Route Replay
└── operations/                                       # Operational Runbooks & Cost Management
    └── SERVICE_SUSPENSION_AND_RESTORE_HOW_AND_WHY.md # Cost Optimization & Teardown/Restore Guide
```

---

## ☁️ 1. AWS CDK Infrastructure Milestones (`docs/infrastructure/`)

| Document | Focus Area / Stack | Key Technical Achievements |
|---|---|---|
| [Step 1: Multi-Stack Initialization](infrastructure/STEP_1_HOW_AND_WHY.md) | CDK App Architecture | Multi-stack decoupling, TypeScript build pipeline, `Fn::GetStackOutput` pattern. |
| [Step 2: Network Foundation](infrastructure/STEP_2_HOW_AND_WHY.md) | `NetworkStack` | 3-tier VPC (Public, Compute, Isolated), $0 NAT Gateway approach via S3/DynamoDB Gateway endpoints. |
| [Step 3: Cognito & Location](infrastructure/STEP_3_HOW_AND_WHY.md) | `AuthStack` | Cognito User Pool, Identity Pool with scoped IAM roles, Amazon Location Service map/geofence. |
| [Step 4: Cloud Verification](infrastructure/STEP_4_HOW_AND_WHY.md) | Phase 1 Integration | Automated synthetic verification script (`verify-phase1.ts`), `client-config.json` generation. |
| [Step 5: Stateful Data Layer](infrastructure/STEP_5_HOW_AND_WHY.md) | `DataStack` | ElastiCache Redis (`cache.t3.micro`) for live spatial queries, Aurora Serverless v2 PostGIS auto-pause. |
| [Step 6: Telemetry Compute](infrastructure/STEP_6_HOW_AND_WHY.md) | `ComputeStack` | IoT Core MQTT topic rule, private Lambda processor, SQS DLQ, VPC Interface Endpoints. |
| [Step 7: Native CI/CD Pipeline](infrastructure/STEP_7_HOW_AND_WHY.md) | `PipelineStack` | AWS CodePipeline, CodeBuild runner, GitHub CodeStar Connection, S3 artifact storage. |
| [Step 8: CloudWatch Observability](infrastructure/STEP_8_HOW_AND_WHY.md) | `ObservabilityStack` | Operational dashboard, error alarms, IoT Core CloudWatch logging, DLQ monitoring. |

---

## 📱 2. Flutter Mobile Architecture (`docs/mobile/`)

| Document | Feature Area | Key Technical Achievements |
|---|---|---|
| [Step 1: Pack & Auth Decoupling](mobile/STEP_1_PACK_AUTH_DECOUPLING_HOW_AND_WHY.md) | Identity & Session | Decoupled temporary convoy rooms from persistent Cognito credentials; enabled independent solo riding. |
| [Step 2: Real Hardware GPS](mobile/STEP_2_REAL_HARDWARE_GPS_HOW_AND_WHY.md) | Device Sensors | Real GPS stream using `geolocator`, runtime permissions, and synthetic mock fallback mode. |
| [Step 3: AWS IoT Core MQTT](mobile/STEP_3_AWS_IOT_MQTT_HOW_AND_WHY.md) | Telemetry Ingestion | Real-time MQTT telemetry publishing over WSS (port 443) using AWS v4 signed credentials. |
| [Step 4: Pack Room Lifecycle](mobile/STEP_4_PACK_ROOM_LIFECYCLE_HOW_AND_WHY.md) | Convoy Rooms | Room creation, 6-character room codes, pilot join/leave lifecycles, and fleet state management. |
| [Step 5: Trip Recording & Export](mobile/STEP_5_TRIP_RECORDING_EXPORT_HOW_AND_WHY.md) | Spatial Persistence | Local SQLite trip logging, duration/distance calculations, and GPX/GeoJSON file export. |
| [Step 6: Final Integration](mobile/STEP_6_FINAL_FUNCTIONAL_APP_HOW_AND_WHY.md) | E2E Mobile Client | Integration of all 4 main tabs, zero compiler warnings, 46/46 passing unit tests. |

---

## 🎨 3. UI Overhaul & Stitch Design System (`docs/ui/`)

| Document | Screen / Component | Key Technical Achievements |
|---|---|---|
| [UI Refresh Overview](ui/UI_REFRESH_HOW_AND_WHY.md) | Complete Design System | Stitch Web3 Convoy Tracker integration, responsive 360dp mobile layout rules. |
| [Step 1: Theme & Tokens](ui/UI_STEP_1_HOW_AND_WHY.md) | Design Tokens | Neon-cyber dark palette, Space Grotesk typography, glassmorphism cards. |
| [Step 2: Atomic Components](ui/UI_STEP_2_HOW_AND_WHY.md) | Reusable Widgets | Glowing metric badges, responsive stat chips, and custom navigation bars. |
| [Step 3: Auth & Call-sign](ui/UI_STEP_3_HOW_AND_WHY.md) | Onboarding Screen | Tactical pilot callsign generator, vehicle selector, and AWS Cognito login HUD. |
| [Step 4: Map & Telemetry HUD](ui/UI_STEP_4_HOW_AND_WHY.md) | Live Map Screen | Interactive map, live convoy tracking, altitude/speed elevation chart card. |
| [Step 5: Pack Management](ui/UI_STEP_5_HOW_AND_WHY.md) | Convoy Screen | Room creation card, QR/code sharing, rider formation list, and solo/convoy toggles. |
| [Step 6: Trip History & Replay](ui/UI_STEP_6_HOW_AND_WHY.md) | Trip Screen | Historical trip cards, GPX route replay dialog, elevation profiles, and export sheet. |

---

## 🛠️ 4. Operations & Cost Management (`docs/operations/`)

| Document | Topic | Key Technical Achievements |
|---|---|---|
| [Service Suspension & Restore Guide](operations/SERVICE_SUSPENSION_AND_RESTORE_HOW_AND_WHY.md) | Cost Optimization | Teardown and restore procedures for stateful and provisioned services (Redis, Aurora, VPC Endpoints) to eliminate continuous idle spending while preserving serverless foundational layers. |

---

## 📋 Working Agreement & Documentation Standard

Every milestone document in this repository adheres to the following standard:
1. **How It Was Done**: Technical breakdown, configuration choices, commands, and mechanics.
2. **Why It Was Done This Way**: Architectural decisions, security boundaries, cost implications, and alternatives considered.
3. **Verification Evidence**: Test command outputs, CloudFormation proofs, and device test results.
4. **Explain, Do Not Dump Code**: Focus on architecture and engineering rationale rather than copying large source code blocks into docs.
