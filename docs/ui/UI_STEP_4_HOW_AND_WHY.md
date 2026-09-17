# UI Milestone 4: Pack Management & Formation (`/groups`)

> **Phase:** UI Phase 4 — Convoy Formations, Active Group Code & Geofence Perimeter Coordination  
> **Status:** Verified & Complete  
> **Target Platform:** Flutter (Mobile Android/iOS & Web)  
> **Mockup Reference:** [`pack_management_groups/code.html`](file:///c:/Users/faizan/Downloads/AWS/stitch_groupnav_web3_convoy_tracker/pack_management_groups/code.html)  
> **Workspace Location:** `mobile/lib/features/groups/`  

---

## 1. How It Was Done

### 1.1 Screen Layout & Component Composition (`PackManagementScreen`)
- **App Navigation Bar:**
  - Styled floating navigation header matching the convoy HUD aesthetic.
  - Displays convoy icon, formation title (`Pack Formation #804`), live pulsing emerald status chip (`ACTIVE TELEMETRY SYNC`), and a native share button that provides one-touch clipboard export of the pack invite code.
- **Active Group Code & Rendezvous Card (`ActiveCodeCard`):**
  - High-visibility monospace code container rendering `GN-9482` with primary container styling and subtle borders.
  - Dedicated `Copy` button with instant clipboard feedback.
  - `Pair QR` quick-action button triggering the tactile in-person pairing modal.
- **Collapsed Mini-Map Preview (`CollapsedMiniMap`):**
  - Compact vector cartography canvas (112px fixed height) displaying simulated arterial route grid lines and the glowing cyan route path.
  - Dashed circular/elliptical geofence perimeter ring centered on the convoy formation.
  - Spatial cluster nodes representing all 4 pack vehicles (Apex leader with radar pulse, Viper ahead, Ghost near boundary, Nomad trailing/offline).
  - Floating metadata chip: `Cluster Mesh: 4 Vehicles`.
  - Floating `Expand Map` button triggering seamless tab transition to the Live Group Radar (`/radar`, Tab 1).

### 1.2 Dynamic Convoy Geofence Scaling (`GeofenceSliderWidget`)
- Implemented the interactive radius slider widget allowing the convoy leader to scale the Amazon Location Service geofence boundary:
  - Range: `200m` (Tight Urban Pack) to `5,000m` (Highway Convoy) in discrete `50m` steps.
  - Formatted live readout badge switching dynamically between meters (`850m`) and kilometers (`1.5km`, `2.5km`, `5.0km`).
  - Labeled interval indicators (`200m`, `1.0km`, `2.5km`, `5.0km`).
  - Amber breach warning notification card: *"Riders alerted if radius breached"*.

### 1.3 Real-Time Pack Roster (`PackRosterCard`)
- Modeled 4 distinct rider states adhering strictly to the design system:
  1. **Leader (`Apex` — Flagship / You):**
     - Blue accent indicator bar on the left edge.
     - `LEAD` chip and `(You)` identifier.
     - Connected indicator with emerald wifi icon, `0m offset`, `82 km/h` tabular speed, and verified leader badge.
  2. **In-Bounds Peer (`Viper`):**
     - Emerald connection status dot.
     - `+140m ahead` offset readout and sub-second latency marker (`Latency: 12ms`).
     - `80 km/h` speed readout with `In Bounds` green badge chip.
  3. **Warning Peer (`Ghost`):**
     - Amber container backdrop with warning border.
     - `Warning` badge chip, amber moniker, and `+790m near edge` offset label.
     - `75 km/h` speed readout with warning indicator: `60m to limit`.
  4. **Offline Peer (`Nomad`):**
     - Muted grayscale card opacity with `Offline` badge.
     - `Last seen 3m ago` timestamp.
     - Interactive `Ping Rider` action button transmitting a spatial chime packet.

### 1.4 Emergency Actions & Shell Integration
- **Broadcast Pack SOS Button:**
  - High-emphasis crimson action button (`#FF3B30`) with animated emergency beacon icon.
  - Integrated with two-step safety confirmation dialog before transmitting high-priority alerts to AWS IoT Core topic `groupnav/convoy/804/alerts`.
- **In-Person QR Code Pairing (`QrPairDialog`):**
  - Modal overlay featuring a custom-painted tactical QR matrix pattern and pack code banner.
  - Generates JSON pairing payload `{"action":"join_pack","code":"GN-9482","packId":"804"}` with copy functionality.
- **Global Shell Integration (`MainShellScreen`):**
  - Wired `PackManagementScreen` into index 0 (`Convoy` tab) of `IndexedStack`, replacing the initial placeholder.
  - Connected `onExpandMap` callback directly to switch the active navigation tab to `1` (Radar).

---

## 2. Why It Was Done This Way

### 2.1 State Synchronization Between Convoy and Radar
- **Decision:** Drive both `RadarNotifier` and `PackNotifier` with synchronized geofence radius state.
- **Rationale:** When the leader adjusts the geofence slider in the Convoy tab (`/groups`), the radius is immediately synced to `RadarNotifier.updateGeofenceRadius(radius)`. When the leader switches back to `/radar`, the vector map's `CircleLayer` instantly reflects the updated geofence boundary without redundant network requests or state misalignment.

### 2.2 Collapsed Static/Live Mini-Map vs Heavy MapLibre Instance
- **Decision:** Utilize a lightweight custom-painted vector mini-map canvas in `CollapsedMiniMap` rather than initializing a second full-scale `FlutterMap` controller on the roster screen.
- **Rationale:** Embedding multiple interactive vector map engines inside a single scrolling ListView causes heavy GPU draw-call contention, memory bloat, and gesture-scroll collisions on mobile devices. The custom painter delivers an instant, smooth cluster preview at zero memory overhead, while the "Expand Map" button provides instant access to the full-featured map engine.

### 2.3 Two-Step Confirmation on Destructive & Emergency Actions
- **Decision:** Wrap `Broadcast SOS` and `Disband Convoy` in explicit confirmation dialogs.
- **Rationale:** Convoy rides take place at high speeds with gloved hands and handlebar vibration. High-impact actions (such as sending emergency siren alerts or disbanding the spatial mesh) must prevent accidental single-touch triggers.

---

## 3. Verification Evidence

### 3.1 Unit Test Execution (`mobile/test/pack_test.dart`)
- **Command:** `flutter test`
- **Output:**
  ```
  00:00 +0: loading C:/Users/faizan/Downloads/AWS/mobile/test/auth_test.dart
  00:00 +0: C:/Users/faizan/Downloads/AWS/mobile/test/auth_test.dart: PilotProfile Unit Tests Serializes to JSON and from JSON accurately
  00:00 +1: C:/Users/faizan/Downloads/AWS/mobile/test/auth_test.dart: PilotProfile Unit Tests copyWith updates fields without mutating original
  00:00 +2: C:/Users/faizan/Downloads/AWS/mobile/test/auth_test.dart: AuthState Unit Tests Default AuthState is unauthenticated
  00:00 +3: C:/Users/faizan/Downloads/AWS/mobile/test/auth_test.dart: AuthState Unit Tests Authenticated state flags active pilot
  00:00 +4: C:/Users/faizan/Downloads/AWS/mobile/test/auth_test.dart: AuthNotifier & CognitoAuthService Flow Request OTP transitions state to otpPending
  00:00 +5: C:/Users/faizan/Downloads/AWS/mobile/test/config_test.dart: ClientConfig parses client-config.json accurately
  00:00 +6: C:/Users/faizan/Downloads/AWS/mobile/test/pack_test.dart: PackMember Model Tests Status badge labels and text colors derive correctly
  00:00 +7: C:/Users/faizan/Downloads/AWS/mobile/test/pack_test.dart: PackFormation Model Tests Formats radius correctly for meters (<1km) and kilometers (>=1km)
  00:00 +8: C:/Users/faizan/Downloads/AWS/mobile/test/pack_test.dart: PackFormation Model Tests Computes connected count excluding offline members
  00:00 +9: C:/Users/faizan/Downloads/AWS/mobile/test/pack_test.dart: PackNotifier State Tests Initializes with standard pack formation #804 and GN-9482 code
  00:00 +10: C:/Users/faizan/Downloads/AWS/mobile/test/pack_test.dart: PackNotifier State Tests updateGeofenceRadius updates formation and syncs to RadarNotifier
  00:00 +11: C:/Users/faizan/Downloads/AWS/mobile/test/pack_test.dart: PackNotifier State Tests updateGeofenceRadius clamps within bounds (200m to 5000m)
  00:00 +12: C:/Users/faizan/Downloads/AWS/mobile/test/pack_test.dart: PackNotifier State Tests generateQrPayload produces valid JSON with correct pack rendezvous data
  00:00 +13: C:/Users/faizan/Downloads/AWS/mobile/test/pack_test.dart: PackNotifier State Tests disbandConvoy deactivates sync and retains only leader
  00:00 +14: C:/Users/faizan/Downloads/AWS/mobile/test/radar_test.dart: TelemetryPacket Unit Tests Serializes to and from JSON accurately
  00:00 +15: C:/Users/faizan/Downloads/AWS/mobile/test/radar_test.dart: ConvoyPeer Offset & Moniker Tests Leader returns moniker tag or HQ
  00:00 +16: C:/Users/faizan/Downloads/AWS/mobile/test/radar_test.dart: ConvoyPeer Offset & Moniker Tests Peer formats positive and negative offsets
  00:00 +17: C:/Users/faizan/Downloads/AWS/mobile/test/radar_test.dart: RadarState Heading Cardinal Display Tests Calculates cardinal direction and padded degrees
  00:00 +18: C:/Users/faizan/Downloads/AWS/mobile/test/radar_test.dart: IotTelemetryService Packet Generation createPacket returns valid schema
  00:00 +19: All tests passed!
  ```

### 3.2 Static Code Analysis
- **Command:** `flutter analyze`
- **Output:**
  ```
  Analyzing mobile...
  No issues found! (ran in 10.1s)
  ```

