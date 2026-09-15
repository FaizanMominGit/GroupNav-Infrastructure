# UI Milestone 7: Live Pipeline Health & Observability (`/telemetry`)

> **Phase:** UI Phase 7 — CloudWatch Telemetry Grid, Dark Technical Terminal & MQTT Stream  
> **Status:** Verified & Complete  
> **Target Platform:** Flutter (Mobile Android/iOS & Web)  
> **Mockup Reference:** [`pipeline_health_telemetry/code.html`](file:///c:/Users/faizan/Downloads/AWS/stitch_groupnav_web3_convoy_tracker/pipeline_health_telemetry/code.html)  
> **Workspace Location:** `mobile/lib/features/observability/`  

---

## 1. How It Was Done

### 1.1 State Management & Telemetry Domain Models (`mobile/lib/features/observability/models/pipeline_metrics.dart`)
- **MQTT Log Packet Representation (`MqttLogPacket`):**
  - Encapsulates high-frequency MQTT packet metadata: timestamp with millisecond resolution (`HH:MM:SS.mmm`), AWS IoT Core topic path (`groupnav/convoy/804/telemetry`), packet direction/type (`TELEMETRY`, `ACK`, `ALERT`), and QoS level (`QoS 1`).
- **CloudWatch Operational Metric Summaries (`MetricSummary`):**
  - Modeled key operational health indicators: Lambda executions per minute, Redis cluster memory consumption, SQS Dead Letter Queue (DLQ) depth, and MQTT ingestion rate.
- **Pipeline Health Notifier (`ObservabilityNotifier`):**
  - Riverpod `StateNotifier<PipelineHealthState>` orchestrating real-time MQTT packet arrival simulations and dynamic metric updates.
  - Features memory-safe log buffer capping (clamped at 100 recent packets).
  - Provides atomic actions: stream pause/resume toggle, buffer flushing (`clearLogs`), and log transcript clipboard export (`copyAllLogs`).

### 1.2 Modular Widget Architecture (`mobile/lib/features/observability/widgets/`)
- **Operational Status Header Card (`OperationalStatusCard`):**
  - High-visibility status badge with pulsing emerald beacon (`Telemetry Core: Healthy`).
  - Active AWS Region pill (`ap-south-1`).
  - Live round-trip latency readout (`14ms RTT`).
  - Direct clipboard copy action for the AWS CloudWatch Console Dashboard.
- **2x2 CloudWatch Operational Metrics Grid (`MetricsGrid2x2`):**
  1. **Lambda Ingest:** Real-time throughput (`4,820/min`) with trend indicator (`+4.2% normal load`).
  2. **Redis Memory:** In-memory consensus cache (`412 MB / 1,536 MB`) with dynamic percentage calculation (`27%`) and linear load progress bar.
  3. **DLQ Buffer:** Dead Letter Queue message depth (`0 msgs`) with zero-drop optimal indicator.
  4. **MQTT Ingest:** Message broker throughput (`1,240 pkts/s`) with QoS 1 guaranteed delivery badge.
- **Dark Technical Developer Terminal (`LiveTerminalConsole`):**
  - High-contrast macOS window chrome: Red, Yellow, Green control buttons.
  - Stream header title (`mqtt-broker::stream-in`) and live pulsing status pill (`LIVE` / `PAUSED`).
  - Monospace scrolling log with color-coded syntax formatting for timestamps, topic names, and raw JSON telemetry payloads.
  - Bottom action bar displaying buffer count (`buffer: 12 pkts • QoS 1`) with tactile Pause/Resume, Clear, and Copy actions.
- **CloudWatch Launch Card:**
  - Dedicated card with one-touch deep-link action to open `GroupNav-Observability-Dashboard`.

### 1.3 Shell Navigation & 5-Tab Architecture
- Updated `ConvoyBottomNavBar` to a 5-tab docked layout:
  - Tab 0: Convoy (`/groups`)
  - Tab 1: Radar (`/radar`)
  - Tab 2: Trips (`/trips`)
  - Tab 3: Ops (`/telemetry`)
  - Tab 4: Settings (`/settings`)
- Wired `PipelineHealthScreen` cleanly into Tab 3 of `MainShellScreen`.

---

## 2. Why It Was Done This Way

### 2.1 Glanceable Mission-Control Observability for Convoy Leaders
- In decentralized vehicular networks (DePIN), convoy leaders need instant visibility into cloud pipeline status to verify whether packet drops are caused by poor local cellular reception or backend service degradation.
- A 2x2 high-contrast grid provides sub-second glanceability without requiring developers to open external AWS console windows on laptops during rides.

### 2.2 Memory-Safe In-App Terminal Ingestion
- Live MQTT feeds can easily flood mobile app memory if unbounded log buffers are preserved.
- The terminal console caps active retained logs at 100 entries, evicting the oldest records as new telemetry packets stream in from the AWS IoT Core WebSocket.

### 2.3 Decoupled CloudWatch Metric Polling
- CloudWatch metrics update on 1-minute aggregations, while MQTT packets stream at millisecond intervals.
- Decoupling the metric summary polling from high-frequency packet log rendering ensures 60 FPS UI rendering without blocking user interactions.

---

## 3. Verification Evidence

### 3.1 Automated Unit Tests (`flutter test`)
Executed the comprehensive unit test suite covering all 7 UI phases:
- **Auth & Config Suite:** 5 passing tests (`auth_test.dart`, `config_test.dart`).
- **Pack Management Suite:** 8 passing tests (`pack_test.dart`).
- **Live Radar & Telemetry Suite:** 6 passing tests (`radar_test.dart`).
- **Rider Settings Suite:** 14 passing tests (`settings_test.dart`).
- **Trip History Suite:** 10 passing tests (`trips_test.dart`).
- **Observability Suite:** 9 passing tests (`observability_test.dart`).
  - `PacketType` label mapping.
  - `MqttLogPacket` timestamp formatting (`HH:MM:SS.mmm`).
  - Redis memory load percentage derivation (`412 / 1536 = 26.8%`).
  - `PipelineHealthState` copyWith and state transitions.
  - `ObservabilityNotifier` buffer limits (100 cap), clear, and stream toggles.

**Result:** `00:00 +52: All tests passed!`

### 3.2 Static Analysis (`flutter analyze`)
Ran Flutter static analyzer across all 7 UI feature modules:
```
Analyzing mobile...
No issues found! (ran in 7.1s)
```
