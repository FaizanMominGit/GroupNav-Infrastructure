# Step 17: Pruning Unimplemented Features and Dead-End UI Controls

## 1. How It Was Done

### 1.1 Technical Breakdown & Pruning Scope
In preparation for final project submission, all mock, placeholder, and non-functional user interface elements were systematically removed so that 100% of visible buttons, dialogs, and features are backed by live AWS cloud services and real hardware sensors.

1. **Web3 / DePIN Telemetry Wallet Elimination**:
   - **Removed**: "Sign In with Web3 Wallet (DePIN)" button with `+4.2 NAV` ticker from `AuthOnboardingScreen`.
   - **Removed**: `Web3WalletModal` bottom sheet trigger from both the auth flow and `RiderSettingsScreen`.
   - **Removed**: "DEPIN TELEMETRY WALLET" row, "+4.2 NAV/hr" badge, and "Connect" / "Disconnect" buttons from `ProfileIdentityCard`.
   - **Updated**: `TopAppBarPill` to replace the mock `+4.2 NAV/hr` reward rate ticker and dead hamburger button with authentic AWS cloud status pills (`Cognito Live`).

2. **Social Auth (Google & Apple) Elimination**:
   - **Removed**: `SocialAuthButtons` (Google and Apple buttons) and "OR CONNECT WITH" divider from `AuthOnboardingScreen`.
   - **Rationale**: Previously returned hardcoded mock identities (`pilot.google@groupnav.io`). Users now exclusively use the 100% verified AWS Cognito Email, Password, and SMS/Email OTP signup/login workflow.

3. **Map Cartography Layer Switcher Elimination**:
   - **Removed**: The `fab_layers` FloatingActionButton on `LiveRadarScreen` that displayed a placeholder toast (`Standard OpenStreetMap Cartography Active`).
   - **Retained**: The primary `fab_recenter` FloatingActionButton which actively centers the vector cartography canvas onto the user's real hardware GPS coordinates.

4. **Simulated Optical QR Code Scanner Elimination**:
   - **Removed**: The "Scan QR Code / Share Link" button on `PackManagementScreen` (Solo view) which opened `CameraQrScannerModal` (simulated laser reticle with no camera hardware backing).
   - **Removed**: The "QR Code" rendezvous button on `ActiveCodeCard` which launched `QrPairDialog` (simulated matrix canvas).
   - **Retained**: Direct room entry via "Join Room" (text entry verified against AWS DynamoDB) and "Copy Code" / "Share Link" (system clipboard integration).

5. **Settings Screen Cleanup**:
   - **`ConvoyAlertsCard`**: Removed the "Voice & Audio Cues" toggle (no TTS or audio library was installed).
   - **`LocationPrivacyCard`**: Removed the "Demo Route Simulation" switch, enforcing pure real-world hardware GPS positioning at all times.
   - **`NavigationDisplayCard`**: Removed "Map Theme" (Day/Night/Auto) and "Keep Screen Awake" switches which had no underlying engine support, keeping clean Speed & Distance measurement unit controls.
   - **`RiderSettingsScreen`**: Replaced the non-clickable top bar hamburger icon with an active settings icon and title header.

6. **Secure Storage Resilience**:
   - **Updated**: `PackNotifier` in `mobile/lib/features/groups/providers/pack_provider.dart` to encapsulate all `FlutterSecureStorage` reads, writes, and deletes inside safe try-catch wrappers (`_safeStorageWrite`, `_safeStorageDelete`, `_restoreSavedPack`), ensuring zero unhandled exceptions when running tests or running on devices with restricted keystore access.

---

## 2. Why It Was Done This Way

### 2.1 Architectural Integrity & Authenticity
- **No Mock Hacks in Production**: Showing buttons that trigger fake mock responses or display non-existent blockchain rewards undermines the credibility of the project during evaluation. Removing them ensures the application is completely truthful about its capabilities.
- **Cognito & DynamoDB Ground Truth**: GroupNav's core strength is its real-time, decentralized group coordination via AWS Cognito, DynamoDB, and AWS IoT Core MQTT. The UI now spotlights these fully operational systems without distracting placeholders.
- **Hardware-First Positioning**: Eliminating simulation toggles guarantees that examiners testing the APK observe real GPS tracking from their physical device sensors.

---

## 3. Verification Evidence

### 3.1 Full Automated Test Suite
All 9 unit and widget test suites passed with zero failures:
```text
00:03 +99: All tests passed!
```
Suites verified:
- `auth_test.dart`: Cognito authentication, OTP verification, password reset, and biometric unlock.
- `pack_test.dart`: DynamoDB room creation, joining, role promotions, and active session persistence.
- `radar_test.dart`: AWS Location Service routes, GPS telemetry packets, and IoT Core MQTT dispatch.
- `settings_test.dart`: Rider settings state management and unit conversions.
- `trips_test.dart`: Live track recording, elevation profiling, and GPX/GeoJSON export.
- `location_test.dart`, `aws_route_test.dart`, `config_test.dart`, `mqtt_test.dart`.

### 3.2 Compilation & Deployment
- Rebuilt Android APK via `flutter build apk --debug`.
- Successfully deployed to connected physical device (`FMONBICQHMLVBAWW`).
