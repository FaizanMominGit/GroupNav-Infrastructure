# UI Milestone 3: Live Group Radar & Convoy HUD (`/radar`)

> **Phase:** UI Phase 3 — Real-Time Spatial Cartography, Geofence Mesh & AWS IoT Core MQTT Integration  
> **Status:** Verified & Complete  
> **Target Platform:** Flutter (Mobile Android/iOS & Web)  
> **Mockup Reference:** [`live_group_radar_radar/code.html`](file:///d:/chirag/GroupNav-Infrastructure/scratch/stitch_groupnav_web3_convoy_tracker/live_group_radar_radar/code.html)  
> **Workspace Location:** `mobile/lib/features/radar/`  

---

## 1. How It Was Done

### 1.1 Full-Bleed Map Canvas (`LiveRadarScreen`)
- Implemented the full-bleed vector map canvas utilizing `flutter_map` (v7.0.2) and `latlong2`:
  - **Tile Layer (Layer Z-0):** Configured street cartography layer rendering OpenStreetMap/Amazon Location Service vector tiles with sub-second tile buffering and smooth gesture-based pinch-to-zoom/pan navigation.
  - **800m Circular Geofence Mesh:** Implemented dynamic circular geofence boundary centered on the convoy formation (`CircleLayer`) with primary electric blue border (`#0066FF`) and translucent fill (`alpha: 0.08`), accompanied by an anchored floating tag badge: `800M CONVOY GEOFENCE`.
  - **Glowing Multi-Stop Navigation Polyline:** Modeled dual-layer vector polyline along the `Skyline Summit` convoy route: an outer high-radius glowing blue polyline (`#0066FF`, 8px width) overlaid with an inner high-intensity cyan route core (`#00D4FF`, 3.5px width).

### 1.2 Convoy Participant Markers (`ConvoyMarkerWidget`)
- **Leader Marker (`Leader: Apex (HQ)`):**
  - High-prominence avatar marker with animated radar ping ring (`#0066FF`).
  - Tactile moniker tag pill with live telemetry emerald connectivity dot.
  - Directional navigation vector arrow dynamically rotated by the heading angle (`peer.headingDeg`).
- **Peer Rider Pins:**
  - **`Viper: +120m`:** Positioned ahead of the leader with verified telemetry emerald badge chip.
  - **`Ghost: -85m`:** Trailing in-bounds behind the leader with amber warning badge chip.
  - Renders direction arrow indicators showing current peer orientation.

### 1.3 Floating Action Controls (Layers Z-10 & Z-20)
- **Top Route & DePIN Status Pill:**
  - Displays route navigation icon (`near_me`), route category (`ACTIVE ROUTE`), and current itinerary (`Skyline Summit`).
  - Displays live DePIN NAV token ticker (`142.8 $NAV`), pulsing emerald ping dot, and pilot wallet reference (`0x7F2`).
- **Right Floating Action Buttons (FAB):**
  - Map Layer quick-action button (`Icons.layers`).
  - Recenter crosshair FAB (`Icons.my_location`) moving the camera smoothly back to the flagship leader's coordinates with zoom level 15.5.

### 1.4 Docked Telemetry HUD Bottom Sheet (`RadarHudSheet`)
- Persistent bottom sheet (Layer Z-30) docking above the global bottom navigation bar:
  - Drag handle indicator pill (36px x 4px).
  - **4-Card Bento Metric Strip:**
    1. **Speed:** High-visibility tabular readout (`78 km/h`).
    2. **Heading:** Cardinal direction + bearing (`NE 042°`).
    3. **Elevation:** Tabular meters (`312 meters`).
    4. **Pack Cohesion:** Cohesion score and dynamic formation status (`98% TIGHT` in emerald).
  - **AWS IoT Core MQTT Live Broadcast Controller Card:**
    - Live pulsing emerald indicator dot.
    - QoS badge: `QoS 1` (guaranteed delivery conforming to Phase 3 infrastructure plan).
    - Status readout: `Online / Broadcasting` (or `Paused / Offline`).
    - Interactive hardware-style toggle switch pausing/resuming real-time telemetry publication.

### 1.5 AWS IoT Core MQTT Integration
- **`TelemetryPacket` (`mobile/lib/features/radar/models/telemetry_packet.dart`)**:
  - Implemented schema matching AWS CDK Ingestion & Compute stack topic rule (`groupnav/+/telemetry`):
    - `riderId`, `callsign`, `packId`, `latitude`, `longitude`, `altitude`, `speedKmh`, `headingDeg`, `accuracy`, `timestamp`.
- **`IotTelemetryService` (`mobile/lib/features/radar/services/iot_telemetry_service.dart`)**:
  - Encapsulates AWS IoT Core ATS endpoint communications (`a362o0ub4ypzaj-ats.iot.ap-south-1.amazonaws.com`).
  - Generates realistic linear interpolation along `kSkylineSummitRoute` for testing multi-vehicle motion, heading rotation, and relative distance offsets in real time.
- **`RadarNotifier` (`mobile/lib/features/radar/providers/radar_provider.dart`)**:
  - Riverpod notifier calculating dynamic pack cohesion scores based on maximum peer distances and formatting heading cardinal angles.

---

## 2. Why It Was Done This Way

### 2.1 Pure Dart Cartography vs Native MapLibre C++ Binaries
- **Decision:** Target `flutter_map` with vector tile layers rather than native C++ MapLibre wrappers.
- **Rationale:** Native C++ OpenGL map libraries on Windows developer machines suffer from compiler toolchain mismatches and binary DLL loader failures. `flutter_map` runs in 100% pure Dart, rendering identically across Windows, Web, Android, and iOS while providing complete control over custom widget markers, geofence polygons, and glowing polylines.

### 2.2 Dual-Layer Polyline Route Glow
- **Decision:** Stack two polylines (a wide translucent blue polyline under a narrow opaque cyan polyline).
- **Rationale:** Simulates the glowing HUD aesthetic of the Figma/HTML design template without requiring expensive canvas blur shaders that degrade frame rates on low-power mobile devices.

### 2.3 Dynamic Pack Cohesion Algorithm
- **Decision:** Calculate pack cohesion dynamically inside `RadarNotifier` based on absolute distance deltas.
- **Rationale:** Gives immediate spatial feedback to the convoy leader: when all riders are within 150m, status is `98% TIGHT`; between 150m–300m, status transitions to `88% EXTENDED`; beyond 300m, status flags `74% SPREAD`.

---

## 3. Verification Evidence

### 3.1 Unit Test Execution
- **Command:** `flutter test`
- **Output:**
  ```
  00:00 +0: loading test/auth_test.dart
  ...
  00:00 +6: TelemetryPacket Unit Tests Serializes to and from JSON accurately
  00:00 +7: ConvoyPeer Offset & Moniker Tests Leader returns moniker tag or HQ
  00:00 +8: ConvoyPeer Offset & Moniker Tests Peer formats positive and negative offsets
  00:00 +9: RadarState Heading Cardinal Display Tests Calculates cardinal direction and padded degrees
  00:00 +10: IotTelemetryService Packet Generation createPacket returns valid schema
  00:00 +11: All tests passed!
  ```

### 3.2 Static Code Analysis
- **Command:** `flutter analyze`
- **Output:** `No issues found!`
