# UI Milestone 5: Rider Settings & Infrastructure (`/settings`)

> **Phase:** UI Phase 5 — Telemetry Controls, DePIN Staked Rewards & AWS Infrastructure Node Identity  
> **Status:** Verified & Complete  
> **Target Platform:** Flutter (Mobile Android/iOS & Web)  
> **Mockup Reference:** [`rider_settings_settings/code.html`](file:///c:/Users/faizan/Downloads/AWS/stitch_groupnav_web3_convoy_tracker/rider_settings_settings/code.html)  
> **Workspace Location:** `mobile/lib/features/settings/`  

---

## 1. How It Was Done

### 1.1 State Management & Domain Models (`RiderSettings`)
- **Configurable Telemetry Sampling (`GpsRate` Enum):**
  - Formulated 3 discrete operational modes tailored for convoy tracking:
    - `1 Hz (Battery Saver)`: 1,000ms GPS intervals with a 5.0m distance displacement filter.
    - `5 Hz (Balanced)`: 200ms GPS intervals with a 2.0m distance displacement filter (default).
    - `10 Hz (Pro Convoy)`: 100ms GPS intervals with a 0.5m ultra-precise distance displacement filter.
- **Unit System & Theming Tokens (`UnitSystem`, `MapThemeMode`):**
  - Built bidirectional conversions supporting Metric (`km/h`, `meters`, `km`) and Imperial (`mph`, `feet`, `mi`).
  - Added theme selection tokens for Day, Night, and Auto/System modes.
- **Settings State Notifier (`SettingsNotifier`):**
  - Created an immutable `RiderSettings` class managed by a Riverpod `StateNotifier`.
  - Exposed atomic state transition mutators for GPS rate switching, background telemetry toggle, lane departure warnings, unit switching, map theme toggles, and spatial audio pings.

### 1.2 Modular Widget Architecture (`mobile/lib/features/settings/widgets/`)
- **Pilot Profile Summary Card (`ProfileSummaryCard`):**
  - Displays authenticated rider callsign (e.g. `Apex`), assigned vehicle class (Sportbike, Touring, Adventure, Cruiser) with dynamic vehicle iconography, and the custom vehicle beacon color ring.
  - Features an active DePIN node indicator chip (`NODE ACTIVE`) with a pulsing emerald status dot.
- **Hardware & Telemetry Controls Card (`TelemetryControlsCard`):**
  - Tactile 3-way animated segmented toggle selecting among 1 Hz, 5 Hz, and 10 Hz rates with subtitle metadata.
  - Background Telemetry Broadcast switch with dedicated primary accenting.
  - Lane Departure Precision Alert switch for haptic/audio warnings when deviating >15m from the convoy line.
- **Map & Display Preferences Card (`DisplayPreferencesCard`):**
  - Unit system toggle container switching between Metric and Imperial formatting.
  - Map theme segmented toggle supporting Day, Night, and Auto.
  - Spatial audio pulse switch controlling proximity audio chimes.
- **Cloud & DePIN Identity Card (`CloudIdentityCard`):**
  - Visual telemetry reward banner rendering current staked balance (`142.8 $NAV`) and accumulation velocity (`+4.2 NAV/hr`).
  - Truncated wallet address pill with one-touch clipboard copy.
  - AWS Cognito Identity ID readout with clipboard copy action and feedback snackbar.
  - IAM Telemetry Role ARN (`arn:aws:iam::325313611329:role/GroupNavTelemetryClientRole`) with copy action.
  - Live backend resource linkage table displaying Cognito User Pool, Identity Pool, IoT MQTT Topic, and Redis Cluster endpoints.
- **Graceful Session Termination (`SignOutDialog`):**
  - Built a modal confirmation dialog warning the rider that signing out cleanly disconnects the active AWS IoT Core MQTT socket and flushes temporary STS credentials from the device keystore.

### 1.3 Shell Navigation & Screen Assembly
- Built `RiderSettingsScreen` bringing together the profile summary, telemetry controls, display preferences, cloud identity, and destructive action buttons inside a scrollable layout.
- Replaced the temporary placeholder in Tab 3 of `MainShellScreen` with the new production `RiderSettingsScreen`.
- Configured top-level shell app bar visibility so settings displays its own dedicated header.

---

## 2. Why It Was Done This Way

### 2.1 Hardware Battery Life vs. Tracking Precision Tradeoff
- Real-time GPS and cellular/MQTT transmissions are extremely power-intensive on mobile devices, especially when motorcycle riders operate on battery without USB charging mounts.
- Offering 1 Hz, 5 Hz, and 10 Hz granular options allows riders to switch between:
  - Long solo endurance rides where battery conservation is paramount (`1 Hz`).
  - Tight pack riding through urban twisties where sub-meter lane accuracy is required (`10 Hz`).

### 2.2 Direct IAM STS Credential Transparency
- GroupNav uses direct client-to-cloud AWS integration (Cognito Identity Pool federated credentials) without intermediate web servers.
- Exposing the assigned Cognito Identity ID and IAM Role ARN in the Settings UI allows riders and developers to verify their scoped AWS credentials and diagnose IoT policy authorization issues on the fly.

### 2.3 Graceful Session Teardown
- Terminating an IoT convoy session must not leave ghost connections in the backend Redis cluster.
- The `Sign Out` flow triggers a graceful MQTT `DISCONNECT` packet and purges temporary STS tokens from the device keystore before resetting application state and returning to `/auth`.

---

## 3. Verification Evidence

### 3.1 Automated Unit Tests (`flutter test`)
Executed the comprehensive unit test suite covering all 5 UI phases:
- **Auth & Config Suite:** 5 passing tests (`auth_test.dart`, `config_test.dart`).
- **Pack Management Suite:** 8 passing tests (`pack_test.dart`).
- **Live Radar & Telemetry Suite:** 6 passing tests (`radar_test.dart`).
- **Rider Settings Suite:** 14 passing tests (`settings_test.dart`).
  - `GpsRate` label mappings, interval calculations, and distance displacement filter validations.
  - `UnitSystem` metric/imperial conversion formatting.
  - `MapThemeMode` token mappings.
  - `RiderSettings` default values and immutable `copyWith` checks.
  - `SettingsNotifier` state mutations (rate changes, toggle switches, theme switches).

**Result:** `00:00 +33: All tests passed!`

### 3.2 Static Analysis (`flutter analyze`)
Ran Flutter static analyzer across the complete codebase:
```
Analyzing mobile...
No issues found! (ran in 9.4s)
```

### 3.3 Physical Device Deployment Verification
- App is running on physical device (`RMX3997`, Android 16, PID: 9406).
- Verified tab switching to Tab 3 (Rider Settings), tactile responsiveness of the segmented controls, and clipboard copy operations.
