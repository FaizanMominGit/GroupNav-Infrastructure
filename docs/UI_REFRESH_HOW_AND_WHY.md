# UI Refresh & Telemetry Tab Retirement — How & Why

## 1. Overview & Context

This milestone executed two primary directives:
1. **Retirement of Pipeline Health (`/telemetry`)**: Removed the developer-oriented AWS CloudWatch / MQTT terminal screen from the consumer-facing mobile application. System observability continues to be managed natively through AWS CloudWatch dashboards and IoT Core metrics in the cloud infrastructure.
2. **Alignment with Updated Stitch Design System Mockups (`stitch_groupnav_web3_convoy_tracker`)**: Refactored the core mobile screens (**Convoy**, **Radar**, **Trips**, and **Settings**) to strictly match the updated visual hierarchy, micro-interactions, typography tokens, and responsive layout guidelines.
3. **Guaranteed Fit on 360dp Mobile Screens**: Compact Android devices (specifically the connected physical device `RMX3997` / 360dp width) experienced horizontal constraints. Every card, header, and button row was audited and rebuilt with flexible layout wrappers (`Wrap`, `Expanded`, `Flexible`, `TextOverflow.ellipsis`) to eliminate all `RenderFlex` overflow errors.

---

## 2. Technical Breakdown: How It Was Done

### 2.1 Navigation & Global Shell
- **Bottom Navigation Bar (`mobile/lib/core/widgets/bottom_nav_bar.dart`)**:
  - Reverted destination count to strictly 4 items:
    - Index 0: `Convoy` (`Icons.navigation`)
    - Index 1: `Radar` (`Icons.group`)
    - Index 2: `Trips` (`Icons.history`)
    - Index 3: `Settings` (`Icons.settings`)
  - Updated icons, labels, active tab indicators, and touch feedback.
- **Main Shell Screen (`mobile/lib/features/shell/main_shell_screen.dart`)**:
  - Removed `PipelineHealthScreen` from the `IndexedStack`.
  - Removed all imports of `observability/`.
  - Deleted superseded `mobile/lib/features/observability/` package and its test suite.

### 2.2 Rider Settings Screen Refactoring (`rider_settings_settings/code.html`)
- **Model & State Updates (`mobile/lib/features/settings/models/rider_settings.dart`, `providers/settings_provider.dart`)**:
  - Added fields: `callsign`, `vehicle`, `emergencyContact`, `geofenceDepartureWarning`, `speedAlert`, `voiceAudioCues`, `keepScreenAwake`, and `shareRealTimeLocation`.
  - Added mutation handlers in `SettingsNotifier` for live editing and toggle switching.
- **Component Decomposition**:
  - **Floating Top Bar**: Menu icon, `GroupNav` brand title, Callsign pill (`0xApex`), and pilot avatar with `telemetryEmerald` ring.
  - **Section 1: Profile & Identity (`ProfileIdentityCard`)**:
    - Callsign with interactive `Edit` dialog.
    - Vehicle setup with interactive `Change` dialog.
    - Emergency contact with interactive `Update` dialog.
    - `Active Rider` status badge with emerald indicator.
  - **Section 2: Ride & Convoy Alerts (`ConvoyAlertsCard`)**:
    - `Geofence Departure Warning` toggle.
    - `Speed Alert` toggle.
    - `Voice & Audio Cues` toggle.
  - **Section 3: Navigation & Display (`NavigationDisplayCard`)**:
    - `Speed & Distance Units` segmented buttons (`Metric (km/h)` vs `Imperial (mph)`).
    - `Map Theme` segmented buttons (`Day`, `Night`, `Auto (Sensor)`).
    - `Keep Screen Awake While Riding` toggle.
  - **Section 4: Location & Privacy (`LocationPrivacyCard`)**:
    - `Share Real-Time Location with Group` toggle.
    - `GPS Refresh Rate` segmented buttons (`Battery Saver (1s)`, `Standard (500ms)`, `High Precision (100ms)`).
    - Privacy notice stating location is strictly shared with accepted pack members during an active ride.
  - **Section 5: Destructive Action**:
    - Full-width `Leave Pack / Log Out` button styled with `alertCritical` border and text.
    - Prompts `SignOutDialog` to gracefully disconnect active MQTT sessions and purge credentials.

### 2.3 Live Group Radar Screen Updates (`live_group_radar_radar/code.html`)
- **Floating Route Header**:
  - Rebuilt top bar with hamburger menu, active route label (`Skyline Summit Run`), and pulsing `4 Live` emerald badge.
- **Radar HUD Bottom Sheet (`RadarHudSheet`)**:
  - Streamlined from 4 narrow metrics to 3 spacious bento metric cards:
    1. **Speed**: `78 km/h`
    2. **Heading**: `NE 042°`
    3. **Pack Status**: `Tight • 4 Riders`
  - Replaced technical AWS MQTT toggle with **Quick Convoy Status** alert card:
    - Header: `QUICK CONVOY STATUS` • `Tap to Alert Group`
    - 4 responsive action buttons: `Regroup` (`pause_circle`), `Refuel` (`local_gas_station`), `Issue` (`build`), and `Custom` (`chat_bubble`).
    - Tapping triggers an animated SnackBar confirmation and simulates dispatch of a QoS 1 MQTT alert packet to fellow riders.

### 2.4 Pack Management Screen Optimizations (`pack_management_groups/code.html`)
- **Responsive Header**: Wrapped title and subtitle column in `Expanded` to ensure long convoy names never overflow against the action button.
- **Invite Code Card (`ActiveCodeCard`)**: Wrapped code column in `Expanded` and adjusted button heights so `GN-9482`, `Copy`, and `QR Code` button coexist cleanly within 360dp.
- **Pack Roster Card (`PackRosterCard`)**:
  - Restructured to a 2-element horizontal row:
    - Left: Avatar circle + `Expanded` Column containing Callsign (`Apex (You)`) and speed/offline subtitle.
    - Right: Status badge (`Leader`, `With Pack`, `Lagging +790m`) or `Ping` action button.
  - Eliminated nested unconstrained horizontal badge chains that caused RenderFlex overflows.

### 2.5 Comprehensive 360dp Viewport RenderFlex Overflows Resolution
- **Trip History Screen (`trip_history_screen.dart`)**:
  - Wrapped header `Column` in `Expanded` and added `TextOverflow.ellipsis` to `"Aurora PostGIS spatial ledger & LiDAR profiles"`, fixing a 122px overflow.
- **Elevation & Pace Chart Card (`elevation_pace_chart_card.dart`)**:
  - Replaced rigid `Row` in the live cursor value readout with responsive `Wrap(alignment: WrapAlignment.spaceBetween, spacing: 8, runSpacing: 4)`, fixing a 61px overflow.
  - Wrapped header title in `Expanded` with `TextOverflow.ellipsis`.
- **Auth Screen & Widgets (`auth_onboarding_screen.dart`, `vehicle_class_selector.dart`, `otp_verification_dialog.dart`)**:
  - `auth_onboarding_screen.dart`: Converted status badges, callsign headers, and telemetry reward pool rows to responsive `Wrap` and `Expanded` layouts, eliminating a 1.8px badge overflow and preventing font-scaling clipping.
  - `vehicle_class_selector.dart`: Replaced unconstrained label and `Spacer()` in 2-column GridView with `Expanded(child: Text(..., maxLines: 1, overflow: TextOverflow.ellipsis))` and inline checkmark, resolving 39px and 28px overflows.
  - `otp_verification_dialog.dart`: Replaced rigid `SizedBox(width: 44)` with `Expanded(child: Container(margin: EdgeInsets.only(right: 6), ...))` so the 6 OTP input digits scale responsively to fit any dialog width, resolving a 31px overflow.
- **Top App Bar (`top_app_bar_pill.dart`)**:
  - Wrapped left branding container in `Expanded` and brand title in `Flexible(child: Text(..., overflow: TextOverflow.ellipsis))`, eliminating a 17px overflow.
- **Recorded Convoys & Navigation Settings (`recorded_convoys_card.dart`, `navigation_display_card.dart`)**:
  - Wrapped card headers in `Expanded(child: Text(..., overflow: TextOverflow.ellipsis))`.
  - Wrapped segmented buttons in `FittedBox(fit: BoxFit.scaleDown)` to guarantee label scaling without line wrapping.

---

## 3. Why It Was Done This Way

1. **User Experience & Separation of Concerns**: End-users (motorcycle pilots, convoy leads) require glanceable, safety-critical navigation and communication during group rides. Raw CloudWatch throughput and JSON terminal logs clutter the driver UI; removing `/telemetry` keeps the interface clean while Amazon CloudWatch dashboards handle devops monitoring independently.
2. **Safety & Glanceability**: The 3-metric bento strip (`Speed`, `Heading`, `Pack Status`) and Quick Status buttons (`Regroup`, `Refuel`, `Issue`) are instantly legible at highway speeds with minimal cognitive load.
3. **Viewport Constraints (360dp / Android API 36)**: Real-world devices like the user's `RMX3997` operate at 360dp logical width. Fixed-width horizontal rows break easily; using `Expanded` on primary content, `Wrap` on secondary actions, and `FittedBox` on fixed-width segment buttons guarantees zero RenderFlex overflows regardless of font scaling.

---

## 4. Verification Evidence

### 4.1 Unit Test Suite
- Executed full test suite across all feature domains:
  ```powershell
  C:\flutter\bin\flutter.bat test
  ```
- Result: **46/46 tests passed (100% pass rate)** covering auth, pack management, radar telemetry, rider settings, and trip history.

### 4.2 Static Code Analysis
- Executed Flutter static analysis:
  ```powershell
  C:\flutter\bin\flutter.bat analyze
  ```
- Result: **`No issues found!`**.

