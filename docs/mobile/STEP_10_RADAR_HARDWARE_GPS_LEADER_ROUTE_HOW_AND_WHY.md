# Step 10: Radar Tab Hardware GPS, Leader Route Authority & Broadcasting

## Overview
This milestone delivers the core tactical command interface on the mobile application: the **Live Radar** screen. It connects real-time smartphone hardware GPS sensors (`Geolocator`), enforces strict **Road Captain Route Authority** (only the convoy leader can designate or alter the navigation course, automatically synchronizing waypoints to all pack followers), and provides reliable **Telemetry & Quick Alert Broadcasting** (`Regroup`, `Refuel`, `Hazard/Issue`, `Custom`) over AWS IoT Core MQTT.

---

## 1. How It Was Done

### Technical Breakdown & Mechanics

1. **Direct Hardware GPS Sensor Streaming (`LocationService`)**:
   - Switched the default location mode from demo simulation to `LocationMode.hardware`.
   - Enhanced `HardwareLocationEngine` to immediately emit the device's last known coordinates upon initialization (`Geolocator.getLastKnownPosition()`) for instantaneous map centering, followed by high-frequency hardware streaming (`Geolocator.getPositionStream`).
   - Integrated automatic fallback to simulated tactical waypoints if location services or permissions are unavailable, ensuring zero crashes while maximizing hardware utilization.
   - Added runtime location permission request handling (`Geolocator.requestPermission()`).

2. **Tactical Convoy Route Catalog (`ConvoyRoute`)**:
   - Created a curated route library featuring 4 tactical courses:
     - **Skyline Summit Run** (18.4 km, +420m elevation, Staggered formation)
     - **Coastal Marine Highway** (32.1 km, +110m elevation, Free Cruise formation)
     - **Khandala Ghat Pass** (24.8 km, +680m elevation, Single File formation)
     - **Western Express Corridor** (45.2 km, +95m elevation, Staggered formation)
   - Encapsulated waypoint coordinates, difficulty ratings, distance, elevation gain, and recommended riding disciplines.
   - Built serialization and deserialization methods (`toJson` and `fromJson`) for cloud transmission.

3. **Road Captain Route Authority (`RouteSelectionSheet` & `LiveRadarScreen`)**:
   - Implemented role-based route authority logic:
     - **Solo Ride Mode**: The rider possesses full autonomy to designate their course.
     - **Convoy Mode (Leader / Road Captain)**: The top navigation bar displays `ACTIVE ROUTE • ROAD CAPTAIN` with an interactive badge. Tapping opens `RouteSelectionSheet`—a tactical modal allowing the leader to select a new course. Selecting a course immediately updates local waypoints and publishes a route dispatch packet (`{ action: 'route_change', packId: ..., route: ... }`) to AWS IoT Core (`groupnav/packs/{packCode}/telemetry`).
     - **Convoy Mode (Followers / Non-Leaders)**: The top bar is locked with `ACTIVE ROUTE • LOCKED` and a lock icon (`Icons.lock_outline`). Tapping displays a tactical modal explaining that only the Road Captain holds course designation authority. When the leader selects a route, followers automatically receive the MQTT broadcast via `IotTelemetryService.routeUpdateStream` and update their map without polling.

4. **Telemetry Status & Quick Alert Broadcasting (`RadarHudSheet`)**:
   - Integrated live broadcast telemetry tracking on the HUD sheet:
     - Broadcaster status pill showing `BROADCASTING LIVE` with emerald beacon or `BROADCAST PAUSED`.
     - Packet counter tracking the number of telemetry packets dispatched to AWS IoT Core MQTT.
     - One-tap quick alert dispatch buttons: `Regroup`, `Refuel`, `Issue`, and `Custom`.
     - Interactive modal dialog for `Custom` alerts allowing riders to type bespoke tactical warnings (e.g., "Road debris ahead in left lane") and immediately broadcast them to the convoy.
     - Incoming alert listener displaying floating real-time notification snackbars on connected devices.

5. **Map Auto-Centering & Navigation Visuals**:
   - Automatically centers the map canvas on the rider's true hardware coordinates upon acquiring the first valid GPS lock.
   - Preserves manual pan/zoom freedom while providing a floating `My Location` recenter action.
   - Renders glowing neon polylines (`AppColors.primary` outer glow + `AppColors.routeCyan` core) outlining the designated route.
   - Displays a dynamic circular geofence perimeter around the convoy center.

---

## 2. Why It Was Done This Way

### Architectural Decisions & Tradeoffs

- **Hardware Sensors by Default**:
  - Simulating GPS data was vital during initial cloud infrastructure bootstrapping; however, production convoy tracking demands real sensor data. Enabling hardware sensors by default ensures real road testing on physical Android devices.
- **Strict Leader Route Authority vs. Democratic Polling**:
  - In motorcycle pack riding, safety depends entirely on discipline and clear hierarchy. Allowing multiple riders to alter navigation routes simultaneously would fragment the pack and risk collisions. The Road Captain holds sole authority over course selection, while followers' navigation systems follow passively.
- **Push-Based MQTT Synchronization vs. REST Polling**:
  - Route alterations and quick alerts are transmitted via AWS IoT Core MQTT topics (`groupnav/packs/{packCode}/telemetry` and `.../alerts`). MQTT over WebSockets delivers sub-100ms latency with minimal bandwidth consumption, far superior to repeated DynamoDB polling queries.
- **Defensive Sensor Fallback**:
  - In situations where GPS fix is momentarily lost (e.g., tunnels or underground parking), the engine gracefully retains the last known coordinates instead of dropping out or crashing the UI.

---

## 3. Verification Evidence

### 1. Unit Test Suite Execution
- Executed `flutter test` across all mobile tests.
- **Result**: All 64 unit tests passed (100% pass rate).
- **New Tests Added**:
  - `Default routes are loaded with valid waypoints and metadata`
  - `Leader route change updates activeRoute and waypoints in RadarState`
  - `Leader status toggle updates isLeader flag`
  - `Quick alerts are published and recorded in telemetry metrics`

### 2. Static Code Analysis
- Executed `flutter analyze` in `mobile/`.
- **Result**: `No issues found! (ran in 5.9s)`. Zero errors, zero warnings.

### 3. Physical Hardware Verification on Realme Device (`FMONBICQHMLVBAWW`)
- Verified live app execution on Android 16 (Realme RMX3997).
- Verified map centering, route selection sheet display, locked follower protection dialog, and telemetry broadcasting beacon.
