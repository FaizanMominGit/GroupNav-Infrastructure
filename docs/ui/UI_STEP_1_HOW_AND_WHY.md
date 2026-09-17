# UI Milestone 1: Client Foundation & Infrastructure Configuration

> **Phase:** UI Phase 1 — Scaffolding, Configuration Ingestion & Convoy Telemetry Design System  
> **Status:** Verified & Complete  
> **Target Platform:** Flutter (Mobile Android/iOS & Web)  
> **Workspace Location:** `mobile/`  

---

## 1. How It Was Done

### 1.1 Flutter SDK Provisioning
- Automated a shallow clone (`--depth 1`) of the official Flutter stable channel repository from `https://github.com/flutter/flutter.git` into `D:\flutter`.
- Bootstrapped Dart SDK artifacts and built the Flutter command-line tool (Flutter 3.47.4, Dart 3.13.3).
- Persisted `D:\flutter\bin` to the Windows User environment `Path` registry to ensure availability across all terminal sessions.

### 1.2 Monorepo Scaffolding & Configuration Ingestion
- Scaffolded the mobile application workspace within `mobile/` directly inside the `GroupNav-Infrastructure` repository. This establishes a unified monorepo pattern where client code and infrastructure definitions evolve together without configuration drift.
- Created `mobile/assets/config/client-config.json` by syncing the active outputs from the AWS CDK deployment:
  - **AWS Region:** `ap-south-1`
  - **Cognito User Pool:** `ap-south-1_JoK8Zlj1x`
  - **Cognito Client ID:** `4ko1153kp0hl7q7oa402cqiqfi`
  - **Cognito Identity Pool:** `ap-south-1:0efa5668-5ed9-4ee6-9120-86f8cc2ae4cd`
  - **Amazon Location Service Map:** `GroupNavMap`
  - **AWS IoT Core ATS Data Endpoint:** `a362o0ub4ypzaj-ats.iot.ap-south-1.amazonaws.com`
  - **Telemetry Topic Pattern:** `groupnav/{riderId}/telemetry`
- Implemented `ClientConfig` (`mobile/lib/core/config/client_config.dart`), a strongly typed, immutable Dart data model providing compile-time safety and runtime validation when loading configuration from asset bundles.

### 1.3 Design System Implementation ("Convoy Telemetry")
Translated the complete design token specification from `groupnav_template.md` into Flutter theme structures:
- **`AppColors` (`mobile/lib/core/theme/app_colors.dart`)**:
  - Primary navigation electric blue: `#0066FF`
  - Verified node & telemetry emerald: `#00C48C`
  - Route vector cyan: `#00D4FF`
  - Amber warning `#FF9500` & Red critical alerts `#FF3B30`
  - Pure white card backgrounds (`#FFFFFF`) over neutral surfaces (`#FAF8FF`) with high-contrast slate text (`#1A1D20`).
- **`AppTypography` (`mobile/lib/core/theme/app_typography.dart`)**:
  - Standardized on Google Fonts `Inter` across all text scales (`headlineXl`, `headlineLg`, `headlineMd`, `bodyLg`, `bodyMd`, `bodySm`, `labelLg`, `labelMd`, `labelSm`).
  - Added dedicated `telemetryNum` style with tabular numbers (`FontFeature.tabularFigures()`) for non-jittering speed, coordinates, and token tickers.
- **`AppTheme` (`mobile/lib/core/theme/app_theme.dart`)**:
  - Implemented 3 tiers of ambient drop shadows: Level 1 (chips/badges), Level 2 (floating search/FABs), and Level 3 (bottom sheets/modals).
  - Defined standard border radii: 4px (`sm`), 8px (`md`), 16px (`lg`), 24px (`xl`), and 9999px (`full`).

### 1.4 Spatial Shell & Global Navigation
- Built `TopAppBarPill` (`mobile/lib/core/widgets/top_app_bar_pill.dart`): Layer Z-20 floating 52px header pill displaying the brand moniker, live telemetry node ping (`NODE 01`, `99.8%`), and $NAV reward ticker (`+4.2 NAV/hr`).
- Built `ConvoyBottomNavBar` (`mobile/lib/core/widgets/bottom_nav_bar.dart`): Layer Z-50 persistent 4-tab bottom navigation dock (`Convoy`, `Radar`, `Trips`, `Settings`).
- Built `MainShellScreen` (`mobile/lib/features/shell/main_shell_screen.dart`): Orchestrates tab switching via `IndexedStack` to preserve active screen state and radar map rendering without rebuilding.

---

## 2. Why It Was Done This Way

### 2.1 Monorepo vs Polyrepo
- **Decision:** Place the mobile client inside `mobile/` in the infrastructure repository rather than a disconnected repository.
- **Rationale:** The client is tightly coupled to the AWS infrastructure outputs (`client-config.json`). Co-locating them ensures that whenever infrastructure parameters change (e.g., re-deploying Cognito, updating IoT ATS endpoints, or adding API endpoints), the client's asset bundle is updated atomically in the same commit.

### 2.2 Strongly-Typed Config vs Runtime Environment Injection
- **Decision:** Parse `client-config.json` via a strongly-typed `ClientConfig` model at startup rather than reading raw string maps.
- **Rationale:** Fails fast during app initialization if any infrastructure parameter is missing or malformed, preventing silent downstream authentication or MQTT connection crashes.

### 2.3 IndexedStack State Preservation
- **Decision:** Manage root screens using `IndexedStack` in `MainShellScreen`.
- **Rationale:** Preserves the underlying vector map instance and WebSocket MQTT subscriptions when riders switch between tabs (e.g., viewing trip history or checking settings), preventing expensive map reloads and socket reconnect handshakes.

---

## 3. Verification Evidence

### 3.1 Flutter Installation Verification
```
Flutter 3.47.4 • channel stable • https://github.com/flutter/flutter.git
Framework • revision 9584c6713b
Tools • Dart 3.13.3 • DevTools 2.60.0
```

### 3.2 Configuration Unit Test Execution
- Executed `flutter test test/config_test.dart` to validate:
  - Accurate JSON mapping of AWS Region (`ap-south-1`).
  - Validation of Cognito User Pool ID and Identity Pool ID.
  - Validation of Location Service Map name and IoT ATS endpoint.
