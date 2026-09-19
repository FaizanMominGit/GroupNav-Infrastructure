# Step 16: Complete Data Flush & Authentic Hardware GPS Integration

## 1. How It Was Done

### A. Total Server Data Purge (AWS DynamoDB)
- Scanned the active DynamoDB pack table `groupnav-packs` in region `ap-south-1`.
- Found 16 stale pack records remaining from prior test sessions (including deprecated `Apex` host records, old rooms `GN-3223`, `GN-3554`, `GN-5729`, etc.).
- Created and executed `scripts/purge_packs.js`, issuing individual AWS CLI delete requests for all 16 items.
- Scanned table again to verify `Count: 0`, ensuring zero stale convoy rooms remain on the AWS backend.

### B. Permanent Removal of Demo Simulation Fallback
- **Diagnosed the Root Cause**:
  In `mobile/lib/core/services/location_service.dart`, whenever `HardwareLocationEngine.initialize()` returned `false` (which occurred upon first launch because Android location permissions were still pending or unprompted), the engine silently switched to `SimulationLocationEngine`.
  `SimulationLocationEngine` ran a 1-second periodic timer that emitted synthetic coordinates along `kSimulationRoute` (San Francisco / Skyline route), permanently overriding hardware GPS.
- **Engine Re-Architecture**:
  - Completely removed the silent simulation fallback in `LocationService._startCurrentEngine()`.
  - Added immediate location queries (`Geolocator.getLastKnownPosition()` and `Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)`) so coordinates lock instantaneously without waiting for physical movement.
  - Added continuous real hardware position streaming via `Geolocator.getPositionStream(locationSettings: LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 1))`.
  - Added `retryHardwareGps()` in `LocationService` and called it in `LiveRadarScreen.initState` to guarantee immediate permission checking and hardware lock whenever the radar screen opens.

### C. Removal of Hardcoded Defaults & Mock Nodes
- **Mini-Map Mock Nodes**: In `mobile/lib/features/groups/widgets/collapsed_mini_map.dart`, removed hardcoded fake vehicle dots (`Viper`, `Ghost`, `Nomad`) and replaced them with dynamic rendering of actual `formation.members`.
- **Default Active Route Simulation**: In `mobile/lib/features/radar/providers/radar_provider.dart`, removed `activeRoute: ConvoyRoute.defaultRoutes.first` from `RadarNotifier` initialization so no simulated route waypoints clutter the map by default.
- **Callsign Handling**: In `mobile/lib/features/groups/providers/pack_provider.dart`, removed the artificial filter `callsign != 'Apex'` to allow authentic registered callsigns to be preserved.

### D. Complete Mobile Data Wipe & Reinstallation
- Ran `adb -s FMONBICQHMLVBAWW uninstall com.example.groupnav_mobile` to completely remove all SharedPreferences, Flutter Secure Storage credentials, SQLite databases, and app caches.
- Rebuilt the application from scratch (`flutter build apk --debug`).
- Freshly installed the debug APK onto the connected Realme device (`FMONBICQHMLVBAWW`).
- Verified app launches into clean, unauthenticated onboarding without any pre-cached sessions or dummy accounts.

---

## 2. Why It Was Done This Way

1. **Adherence to Authentic Telemetry (No Mock Hacks)**:
   In a mission-critical motorcycle convoy tracking application, displaying simulated coordinates creates a dangerous false sense of telemetry and prevents genuine field testing between multiple phones. Eliminating simulation fallbacks ensures that only authentic GPS hardware fixes are streamed to AWS IoT Core.
2. **Clean Slate for Multi-Rider Interaction**:
   Lingering DynamoDB records and cached mobile tokens caused stale room collisions and conflicting pilot identities. Wiping both server state (`groupnav-packs`) and device local storage (`com.example.groupnav_mobile`) ensures that Rider 1 and Rider 2 start from a known zero state.
3. **Decoupled Architecture & Real Riverpod State**:
   Allowing the radar notifier to start with a clean state (`RadarState()`) without forcing predefined routes allows pilots to ride solo or choose when to dispatch a route to the pack.

---

## 3. Verification Evidence

1. **DynamoDB Table Scan**:
   ```json
   {
       "Items": [],
       "Count": 0,
       "ScannedCount": 0
   }
   ```
2. **Flutter Test Suite**:
   ```
   00:03 +99: All tests passed!
   ```
3. **Flutter Analyze**:
   ```
   No issues found! (ran in 4.0s)
   ```
4. **Clean Launch Confirmation**:
   App uninstalled and reinstalled; launched into `Pilot Sign In` requiring authentic AWS Cognito credentials.

---

## 4. Convoy Persistence & Identity Synchronization (Follow-up)

### E. Resolving "Convoy Disappears on App Exit"
- **Issue**: Previously, `PackNotifier` did not persist the active `packCode` in `FlutterSecureStorage`. When the app was forcefully closed and reopened, it always initialized to Solo Ride Mode, completely unaware that the user was still actively tracked in a DynamoDB convoy room.
- **Fix**: 
  - In `pack_provider.dart`, implemented `_restoreSavedPack()` that queries `FlutterSecureStorage` for the key `groupnav_active_pack_code` upon initialization.
  - If a key exists, the provider automatically fetches the active session from DynamoDB (`groupnav-packs`) and seamlessly restores `state.isInPack = true`, along with polling and geofence updates.
  - `joinPack` and `createPack` now persist the room code to secure storage, and `leavePack` and `disbandConvoy` securely delete it.

### F. Resolving "Callsign Defaults to Apex"
- **Issue**: `ProfileIdentityCard`'s update callback only updated `settingsNotifier.setCallsign` locally. It completely bypassed the global `AuthNotifier`, the `PackNotifier` roster, and the `IotTelemetryService`. Since UI bindings prioritized Cognito claims, the screen always reverted to 'Apex'.
- **Fix**:
  - Rewrote the `onUpdateCallsign` closure in `rider_settings_screen.dart` to strictly execute cascading updates across all 4 layers sequentially:
    1. `settingsNotifier.setCallsign`
    2. `await authNotifier.updateCallsign` (Syncs to AWS Cognito user pool attributes)
    3. `packNotifier.updateRiderCallsign` (Syncs local roster display)
    4. `iotTelemetryServiceProvider.updateRiderIdentity` (Syncs MQTT telemetry metadata)
- **Verification**: `flutter test` succeeds with 0 failures after applying `FlutterSecureStorage.setMockInitialValues({})` to `pack_test.dart` to isolate the native plugin dependency.
