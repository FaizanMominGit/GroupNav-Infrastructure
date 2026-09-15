# Step 3: AWS IoT Core MQTT Client & SigV4 WebSocket Integration

## 1. How It Was Done

### AWS Signature Version 4 WebSocket Presigning Engine
- Created a specialized cryptographic signer (`AwsSigV4Signer`) in `mobile/lib/core/services/aws_sigv4_signer.dart`.
- The signer derives AWS SigV4 signing keys for service `iotdevicegateway` in the active region (e.g. `ap-south-1`) across standard HMAC-SHA256 derivation chains (`kDate`, `kRegion`, `kService`, and `kSigning`).
- Produces presigned WebSocket URLs on standard port 443 with query parameters sorted alphabetically: `X-Amz-Algorithm`, `X-Amz-Credential`, `X-Amz-Date`, `X-Amz-Expires` (86400s), `X-Amz-Security-Token`, `X-Amz-SignedHeaders`, and `X-Amz-Signature`.

### AWS IoT Core MQTT Telemetry & Alert Client
- Refactored `IotTelemetryService` in `mobile/lib/features/radar/services/iot_telemetry_service.dart` to support both simulated and live hardware GPS streaming over an authenticated MQTT WebSocket client.
- Configured client connection with auto-reconnect, 30s keep-alive, client ID `groupnav_pilot_<timestamp>`, and WebSocket transport over HTTPS port 443.
- Subscribed client to pack alert topic pattern `groupnav/packs/+/alerts` using QoS 1 (`atLeastOnce`), streaming parsed JSON alerts through a broadcast stream.
- Implemented `publishTelemetry(TelemetryPacket packet)` publishing to `groupnav/{riderId}/telemetry`.
- Implemented `publishAlert(...)` broadcasting quick convoy alerts (`Regroup`, `Refuel`, `Issue`, `Custom`) to `groupnav/packs/{packId}/alerts` with instantaneous optimistic local UI dispatch.

### UI & Riverpod State Wire-Up
- Integrated `radarNotifierProvider` with `IotTelemetryService.publishAlert(...)` so HUD actions trigger MQTT alerts for the active pack room.
- In `LiveRadarScreen`, wired the 4 quick action buttons in `RadarHudSheet` to dispatch alerts with the active pack room ID and pilot callsign.
- Added an alert stream listener in `LiveRadarScreen` to notify riders with in-app notifications whenever incoming convoy alerts are received from peers.

---

## 2. Why It Was Done This Way

### WebSocket over Port 443 vs. Direct TLS on Port 8883
- Traditional MQTT uses port 8883 with mutual TLS (X.509 client certificates). Distributing and rotating unique X.509 certificates to dynamic consumer mobile devices on public cellular networks is fragile, requires complex provisioning, and is frequently blocked by carrier firewalls or captive portals.
- MQTT over WebSockets (port 443) uses standard HTTPS egress traffic, which passes unhindered through all mobile cellular networks, NATs, and Wi-Fi networks.
- Authenticating via temporary AWS credentials (Cognito Identity Pool) signed using SigV4 ensures short-lived, least-privilege credentials without ever storing static AWS root secrets on device storage.

### Optimistic Local Dispatch for Convoy Alerts
- Quick alerts (e.g. "Regroup", "Refuel") require immediate visual confirmation for the rider while in motion. Emitting locally through the stream immediately prevents perceived UI lag if cellular signal experiences brief latency, while simultaneously transmitting the packet over MQTT QoS 1 to notify all convoy peers.

---

## 3. Verification Evidence

### Automated Unit Test Verification
- Executed `flutter test` across all unit suites, including new tests in `mobile/test/mqtt_test.dart` verifying SigV4 URL query parameter generation, credential hashing, and alert streaming:
```
00:00 +1: C:/Users/faizan/Downloads/AWS/mobile/test/mqtt_test.dart: AwsSigV4Signer Tests Generates valid presigned WebSocket URL with SigV4 parameters
00:00 +2: C:/Users/faizan/Downloads/AWS/mobile/test/mqtt_test.dart: AwsSigV4Signer Tests Omits session token if null or empty
00:00 +3: C:/Users/faizan/Downloads/AWS/mobile/test/mqtt_test.dart: IotTelemetryService Alert Broadcast Tests publishAlert emits to alertStream immediately
...
00:01 +54: All tests passed!
```

### Static Analysis Verification
- Executed `flutter analyze`:
```
Analyzing mobile...
No issues found! (ran in 5.5s)
```
- Zero warnings, zero linter errors, zero deprecated APIs.
