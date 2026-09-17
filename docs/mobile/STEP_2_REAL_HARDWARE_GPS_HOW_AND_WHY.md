# Step 2: Real Hardware GPS Location Engine & Simulation Toggle — How & Why

## 1. Overview

In this step, we transitioned the mobile app from relying solely on static hardcoded route arrays to integrating a true **Hardware GPS Location Engine** powered by the physical Android device's GPS chipset, while retaining an on-demand **Demo Simulation Mode** for evaluator demonstrations and indoor testing.

---

## 2. Technical Breakdown: How It Was Done

### 2.1 Dependencies & Android System Permissions
- Added `geolocator: ^12.0.0` to `mobile/pubspec.yaml`.
- Configured Android manifest permissions in `mobile/android/app/src/main/AndroidManifest.xml`:
  - `android.permission.INTERNET`
  - `android.permission.ACCESS_FINE_LOCATION` (satellite GPS accuracy)
  - `android.permission.ACCESS_COARSE_LOCATION` (cell tower / Wi-Fi triangulation)
  - `android.permission.ACCESS_BACKGROUND_LOCATION` (continuous telemetry during rides)

### 2.2 Location Engine Architecture (`mobile/lib/core/services/location_service.dart`)
- Created an extensible `ILocationEngine` contract with two implementations:
  1. **`HardwareLocationEngine`**:
     - Verifies device location service status via `Geolocator.isLocationServiceEnabled()`.
     - Handles runtime permission workflows (`checkPermission()`, `requestPermission()`).
     - Listens to native `Geolocator.getPositionStream` configured with `LocationAccuracy.high` and a 2-meter distance filter.
     - Converts native velocity (`pos.speed`) from meters/sec to kilometers/hour (`speed * 3.6`) and captures compass heading (`pos.heading`).
  2. **`SimulationLocationEngine`**:
     - Interpolates along the Skyline Summit waypoints (`kSimulationRoute`) with realistic 78 km/h telemetry intervals.
- Encapsulated in `LocationService`:
  - Maintains `mode`: `LocationMode.hardware` vs `LocationMode.simulation`.
  - Exposes a unified broadcast stream `Stream<PositionData> get positionStream` and `PositionData? get currentPosition`.
  - Automatically falls back to simulation mode if hardware GPS is disabled or permissions are rejected.

### 2.3 Provider Integration & UI Settings Switch
- In `RiderSettings` (`mobile/lib/features/settings/models/rider_settings.dart`), added `isDemoSimulation: bool` (default `true` for demo and offline safety).
- In `SettingsNotifier` (`mobile/lib/features/settings/providers/settings_provider.dart`), added `toggleDemoSimulation(bool value)`.
- In `LocationPrivacyCard` (`mobile/lib/features/settings/widgets/location_privacy_card.dart`), added an interactive toggle:
  - Label: *"Demo Route Simulation"*
  - Subtitle: *"Replay Skyline Summit track (disable for real GPS hardware)"*
- In `RadarProvider` (`mobile/lib/features/radar/providers/radar_provider.dart`), created `locationServiceProvider` which dynamically reacts to settings changes and feeds `IotTelemetryService`.

---

## 3. Why It Was Done This Way

1. **Dual-Mode Necessity for Hackathons & Real-World Use**:
   - In production on a motorcycle, the rider needs real GPS coordinates, speed, and heading.
   - However, during hackathon evaluations and indoor presentations, judges and engineers are stationary indoors. If the app only used hardware GPS, the map would be frozen at 0 km/h with a single stationary pin. The Demo Simulation toggle allows demonstrating multi-bike pack cohesion dynamically without riding a motorcycle inside the building.
2. **Graceful Fallback**: If permissions are denied by the user on first launch, the app does not crash; it logs a warning and falls back to simulation mode cleanly.
3. **Reactive Riverpod Architecture**: Toggling the simulation switch in settings instantly switches the underlying location engine without requiring an app restart.

---

## 4. Verification Evidence

### 4.1 Unit Test Suite
Ran full test suite in `mobile/test`:
```powershell
C:\flutter\bin\flutter.bat test
```
**Result**:
- **51/51 passed (100% pass rate)**.
- Verified:
  - `LocationService initializes with simulation mode and streams coordinates` (Verified)
  - `PositionData formats readable string correctly` (Verified)

### 4.2 Static Code Analysis
Ran Flutter analyzer:
```powershell
C:\flutter\bin\flutter.bat analyze
```
**Result**:
```
Analyzing mobile...
No issues found! (ran in 4.6s)
```
