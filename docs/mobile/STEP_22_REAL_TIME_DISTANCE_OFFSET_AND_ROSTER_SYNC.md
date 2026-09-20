# Step 22: Real-Time Dynamic Distance Offset & Live Convoy Roster Sync

## 1. How It Was Done

### Background & Observed Issue
From device screenshots taken during multi-rider testing:
1. Both the Convoy Leader (`Aliya`) and Follower (`faizan (You)`) had their radar marker badges permanently display `+0m` (or 0 offset) even when located at distinct geographic coordinates on the map.
2. In the Convoy Roster screen, all member tiles showed static speeds (`0 km/h`) and static descriptions (`Road Captain`, `Pack Rider`), without reflecting real-time movement or distance separation.

### Technical Breakdown & Root Causes Identified
1. **Hardcoded Zero Offset**: In `IotTelemetryService` (`mobile/lib/features/radar/services/iot_telemetry_service.dart`), both incoming remote peer packets and local self position updates instantiated `ConvoyPeer` with `relativeOffsetMeters: 0`. No geodesic distance was ever calculated between coordinates.
2. **Missing `isLeader` in Telemetry Packets**: `TelemetryPacket.toJson()` omitted the `isLeader` boolean, preventing remote riders from knowing whether an incoming peer was the Road Captain or a general member.
3. **Disconnected Pack Roster**: `PackNotifier` only read member data once from DynamoDB on pack join. The live incoming MQTT telemetry (`convoyStream`) was never piped into `PackFormation.members`, leaving speeds and offset descriptions frozen at 0.

### Solution Applied

#### A. Telemetry Packet Schema Update (`TelemetryPacket`)
- Added `final bool isLeader;` to `TelemetryPacket` (`mobile/lib/features/radar/models/telemetry_packet.dart`).
- Serialized `'isLeader': isLeader` in `toJson()` and deserialized it in `fromJson()`.
- Included `isLeader: _isLeader` when publishing location telemetry from `IotTelemetryService`.

#### B. Geodesic Distance & Bearing Direction Calculation (`IotTelemetryService`)
- Updated `_emitPeers()` in `IotTelemetryService` to dynamically calculate real-time distance for every connected convoy peer:
  - Uses `const Distance().as(LengthUnit.Meter, ...)` from `package:latlong2/latlong.dart` to compute true geodesic distance in meters from the user (`selfPeer`) to each peer.
  - When the rider has movement/heading (`speedKmh > 3` or `headingDeg > 0`), computes the bearing angle:
    $$\Delta\theta = (\text{bearing} - \text{heading} + 540) \pmod{360} - 180$$
    If $|\Delta\theta| \le 90^\circ$, the peer is ahead ($+\text{distance}$). If $|\Delta\theta| > 90^\circ$, the peer is behind ($-\text{distance}$).
  - If stationary, the designated Road Captain is oriented ahead, while followers are positioned behind.

#### C. Human-Readable Formatting & Clean Badging (`ConvoyPeer` & `ConvoyMarkerWidget`)
- In `ConvoyPeer.offsetFormatted`:
  - For Self (`faizan (You)`): Displays `You` (or `Lead` if Road Captain) instead of redundant `+0m`.
  - For Peers:
    - Within 15m: Displays `With Pack` (or `Lead` if Road Captain).
    - Under 1,000m: Displays signed meters (e.g. `+350m`, `-120m`).
    - At/Above 1,000m: Displays signed kilometers (e.g. `+1.8km`, `-2.4km`).
- In `ConvoyMarkerWidget` (`mobile/lib/features/radar/widgets/convoy_marker_widget.dart`):
  - Self marker badge cleanly shows the user's callsign and an optional gold `LEAD` chip (if captain).
  - Remote peer marker features a high-contrast pill badge with the formatted offset distance.

#### D. Live Telemetry Subscription for Convoy Roster (`PackNotifier`)
- Subscribed `PackNotifier` to `_telemetryService.convoyStream` via `_listenToTelemetryForRoster()`.
- Maps incoming telemetry to each `PackMember` by callsign, dynamically updating:
  - `member.speedKmh`: Live GPS speed (e.g. `28 km/h`).
  - `member.offsetMeters`: Live relative distance.
  - `member.offsetDescription`: `Leading`, `+350m ahead`, `120m behind`, or `With Pack`.

---

## 2. Why It Was Done This Way

1. **Client-Side Geodesic Math vs Server Calculations**:
   - Calculating distance and bearing on-device avoids expensive round-trips to cloud APIs (like AWS Location Routes) for every 1-second telemetry heartbeat.
   - The Haversine/spherical distance formula runs in sub-millisecond time directly in Dart, guaranteeing instantaneous 60fps HUD updates.

2. **Self Marker vs Peer Marker Distinction**:
   - Displaying `+0m` on the user's own avatar confuses riders into thinking tracking is broken. Differentiating self (`You`/`Lead`) from peers (`+350m`/`-120m`) matches industry standard avionics and rally navigation systems.

---

## 3. Verification Evidence
- `flutter analyze` &rarr; Zero issues found (`No issues found!`).
- Clean debug APK assembly via `flutter build apk --debug`.
