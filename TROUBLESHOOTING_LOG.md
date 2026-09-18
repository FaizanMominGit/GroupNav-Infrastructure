# GroupNav Engineering & Troubleshooting Log
> **Purpose**: Record all critical architectural decisions, discovered problems, failure modes, root causes, exact fixes, and preventative rules so we never repeat the same mistakes.

---

## Issue Log Template
When an issue, error, or unexpected behavior is encountered, document it using this format:

```markdown
### [ISSUE-XXX] Short Title Describing the Problem
- **Date & Phase**: YYYY-MM-DD | Phase X (e.g., Phase 1 - NetworkStack)
- **Component / Command**: Component or command that triggered the issue
- **Symptom / Error Message**:
  ```
  Exact error output or unexpected behavior
  ```
- **Root Cause Analysis**:
  Why did this happen? (e.g. AWS CDK behavior, CloudFormation restriction, missing IAM permission, environment discrepancy)
- **Fix / Solution Applied**:
  Exact steps and code changes taken to resolve it. No temporary workarounds.
- **Verification**:
  How was the fix verified?
- **Prevention Rule**:
  Rule or check added to prevent this from reoccurring.
```

---

## Logged Issues & Pre-emptive Findings

### [ISSUE-001] AWS CLI Not Found in System PATH (Resolved: Installed v2.36.44)
- **Date & Phase**: 2026-09-14 | Phase 1 Prerequisites
- **Component / Command**: Environment verification (`aws --version`)
- **Symptom / Error Message**:
  ```
  aws : The term 'aws' is not recognized as the name of a cmdlet, function, script file, or operable program.
  ```
- **Root Cause Analysis**:
  AWS CLI v2 was not installed on the system. Deployment, CDK bootstrap, and manual verification require AWS CLI tools and active credentials.
- **Fix / Solution Applied**:
  Installed official AWS CLI v2 via `winget install --id Amazon.AWSCLI -e --accept-source-agreements --accept-package-agreements`. Binary located at `C:\Program Files\Amazon\AWSCLIV2\aws.exe`.
  *Note on Active Shells*: Existing PowerShell sessions opened prior to installation do not automatically inherit updated environment PATH variables until either the terminal is restarted or `$env:Path` is refreshed from the registry.
- **Verification**:
  `aws --version` verified working (`aws-cli/2.36.44`).
- **Prevention Rule**:
  When installing CLI utilities in active Windows terminal sessions, instruct user to reload the session PATH or open a new terminal tab.

---

### [ISSUE-002] Global AWS CDK Not Installed
- **Date & Phase**: 2026-09-14 | Phase 1 Prerequisites
- **Component / Command**: Environment verification (`cdk --version`)
- **Symptom / Error Message**:
  ```
  cdk : The term 'cdk' is not recognized as the name of a cmdlet...
  ```
- **Root Cause Analysis**:
  `aws-cdk` is not installed globally in the system.
- **Fix / Solution Applied**:
  Use `npx -y aws-cdk@2.1141.0` or project-local `node_modules/.bin/cdk` via `npx cdk` to guarantee version parity across environments without polluting global packages.
- **Verification**:
  `npx -y aws-cdk --version` verified working (v2.1141.0).
- **Prevention Rule**:
  All CDK commands in npm scripts and terminal runs will invoke `npx cdk` or `npm run cdk`.

---

### [ISSUE-003] CDK VPC Private Subnets Without NAT Gateway Synthesis Conflict
- **Date & Phase**: 2026-09-14 | Phase 1 Architectural Design
- **Component / Command**: `NetworkStack` VPC definition
- **Symptom / Error Message**:
  If `SubnetType.PRIVATE_WITH_EGRESS` is specified with `natGateways: 0`, AWS CDK v2 throws an error at synthesis time:
  ```
  Error: If you configure private subnets and no NAT gateways (natGateways: 0), you must specify how egress is provided...
  ```
- **Root Cause Analysis**:
  In CDK, `PRIVATE_WITH_EGRESS` automatically synthesizes default routes pointing to NAT Gateways. GroupNav deliberately avoids NAT Gateways to save hackathon credits (Section 5.4), using VPC Interface Endpoints (PrivateLink) instead.
- **Fix / Solution Applied**:
  In the VPC definition, define the compute subnets as `SubnetType.PRIVATE_ISOLATED` (or configure custom route tables / endpoints), or explicitly decouple egress route creation. For isolated data tiers and private compute with VPC endpoints, isolated subnets with interface endpoints fulfill the security boundary without paying ~$32/month NAT fee.
- **Verification**:
  Validate with `npx cdk synth` during unit testing before any deployment.
- **Prevention Rule**:
  Model cost-aware VPC subnets strictly matching CloudFormation route constraints.

---

### [ISSUE-004] Cross-Stack Reference Deadlocks (`Fn::Export` vs `Fn::GetStackOutput`)
- **Date & Phase**: 2026-09-14 | Phase 1 Cross-Stack Architecture
- **Component / Command**: Passing VPC, Subnets, and Security Groups between `NetworkStack`, `AuthStack`, and downstream stacks
- **Symptom / Potential Failure**:
  CDK default construct passing generates `Export [StackName]:[ExportName] cannot be updated because it is in use by [ConsumerStack]`.
- **Root Cause Analysis**:
  Direct construct references across CDK stacks generate CloudFormation `Fn::Export` and `Fn::ImportValue`, tightly coupling stacks and locking updates.
- **Fix / Solution Applied**:
  Follow Section 3.5 of the infrastructure plan: Export plain outputs via `CfnOutput` and consume them using `Fn.importValue` or `Fn.select`/`Fn.split` with stack outputs or SSM Parameter Store / explicit stack attributes without creating locked CloudFormation export chains.
- **Verification**:
  Check generated CloudFormation templates during `npx cdk synth`.
- **Prevention Rule**:
  Never pass mutable VPC construct references directly to independent stacks without decoupling.

---

### [ISSUE-005] CDK Init Fails in Non-Empty Directory
- **Date & Phase**: 2026-09-14 | Phase 1 Scaffolding
- **Component / Command**: `npx -y aws-cdk@2.1141.0 init app --language typescript`
- **Symptom / Error Message**:
  ```
  Failed to validate directory C:\Users\faizan\Downloads\AWS: `cdk init` cannot be run in a non-empty directory!
  Found 3 visible files in C:\Users\faizan\Downloads\AWS:
    - AGENTS.md
    - GroupNav-Infrastructure-Plan.md
    - TROUBLESHOOTING_LOG.md
  ```
- **Root Cause Analysis**:
  `cdk init` strictly enforces that target project directories contain zero existing files to avoid clobbering user files.
- **Fix / Solution Applied**:
  Run `cdk init` inside an empty temporary directory (`_cdk_init`), migrate the generated scaffold files (`cdk.json`, `package.json`, `tsconfig.json`, `jest.config.js`, etc.) into the project root, remove the temporary directory, and install dependencies cleanly.
- **Verification**:
  Verify successful population of CDK TypeScript project files and run `npm run build`.
- **Prevention Rule**:
  When introducing CDK into existing repositories with documentation or config files, use a temporary initialization directory or directly scaffold official CDK configuration files.

---

### [ISSUE-006] AWS CLI Location Service Output Missing (Requires --outfile)
- **Date & Phase**: 2026-09-14 | Phase 1 Integration
- **Component / Command**: AWS CLI (`aws location ...`)
- **Symptom / Error Message**:
  When calling certain AWS Location Service APIs via the AWS CLI (e.g., getting map tiles), the command fails or hangs because the CLI expects to write binary data to a file but defaults to standard output, which causes formatting errors.
- **Root Cause Analysis**:
  Unlike most AWS APIs that return JSON, Location Service tile data and similar binary payloads require an explicitly designated output stream in the CLI.
- **Fix / Solution Applied**:
  Pass the `--outfile <filename>` parameter to the AWS CLI command when requesting non-JSON payloads.
- **Verification**:
  Successful retrieval of the map tile when saving to a `.png` file.
- **Prevention Rule**:
  Always review the specific payload format of an AWS API; if it is binary/image data, append `--outfile` when testing via CLI.

---

### [ISSUE-007] GitHub Secret Scanner Triggered by Ephemeral STS Access Key in Docs
- **Date & Phase**: 2026-09-14 | Phase 1 Documentation Review
- **Component / Command**: Git commit `be0d430` / `docs/STEP_4_HOW_AND_WHY.md` / `scripts/verify-phase1.ts`
- **Symptom / Error Message**:
  GitHub Secret Scanning alert triggered on public repository:
  `Amazon AWS Temporary Access Key ID #1 detected in docs/STEP_4_HOW_AND_WHY.md (ASIAUXPRTYZAVTLVLWWW)`
- **Root Cause Analysis**:
  During the Step 4 automated verification run, `scripts/verify-phase1.ts` printed the raw `AccessKeyId` returned by Cognito STS (`ASIA...`) to stdout. The verification console output was copied verbatim into `docs/STEP_4_HOW_AND_WHY.md`. Although the token was a short-lived temporary token that was already expired and tied to a deleted test user, GitHub secret scanners match any AWS key signature (including `ASIA...`). Furthermore, including verbatim credentials violates the "Explain, Do Not Dump Code/Raw Secrets" documentation rule.
- **Fix / Solution Applied**:
  1. Masked the output in `scripts/verify-phase1.ts` using `creds.AccessKeyId.substring(0, 4) + '****************'`.
  2. Masked the token in `docs/STEP_4_HOW_AND_WHY.md`.
  3. Amended commit `be0d430` to `56cd867` and force-pushed to completely eliminate the secret string from GitHub commit history.
- **Verification**:
  Grep confirmed zero unmasked `ASIA...` active tokens in the workspace. Commit amended and pushed cleanly.
- **Prevention Rule**:
  Never log unmasked credentials in verification scripts or documentation. All tokens, secrets, ARNs with sensitive IDs, and access keys must be masked prior to console output or inclusion in `.md` reports.

---

### [ISSUE-008] ElastiCache Replication Group Rollback: Automatic Failover with 1 Cache Cluster
- **Date & Phase**: 2026-09-14 | Phase 2 (DataStack Deployment)
- **Component / Command**: `npx cdk deploy DataStack` / `AWS::ElastiCache::ReplicationGroup`
- **Symptom / Error Message**:
  ```
  When using automatic failover, there must be at least 2 cache clusters in the replication group. (Service: ElastiCache, Status Code: 400)
  ```
- **Root Cause Analysis**:
  In AWS CloudFormation, `AWS::ElastiCache::ReplicationGroup` defaults `AutomaticFailoverEnabled` to true or enforces multi-node topology if automatic failover is not explicitly disabled. For a single-node cost-saving dev/hackathon cluster (`numCacheClusters: 1`), automatic failover cannot function and the CloudFormation provider fails creation.
- **Fix / Solution Applied**:
  Explicitly set `automaticFailoverEnabled: false` on the `CfnReplicationGroup` construct in `lib/data-stack.ts`. Deleted the `ROLLBACK_COMPLETE` stack to clear CloudFormation state.
- **Verification**:
  Unit test updated to assert `AutomaticFailoverEnabled: false`. `npx jest test/data-stack.test.ts` passed.
- **Prevention Rule**:
  Whenever specifying `numCacheClusters: 1` or single-node topology on `CfnReplicationGroup`, always explicitly declare `automaticFailoverEnabled: false`.

---

### [ISSUE-009] Aurora PostgreSQL Version 16.3 Not Available in ap-south-1 (Resolved with 16.8)
- **Date & Phase**: 2026-09-14 | Phase 2 (DataStack Deployment)
- **Component / Command**: `npx cdk deploy DataStack` / `AWS::RDS::DBCluster`
- **Symptom / Error Message**:
  ```
  Cannot find version 16.3 for aurora-postgresql (Service: Rds, Status Code: 400)
  ```
- **Root Cause Analysis**:
  In AWS region `ap-south-1` (Mumbai), older point releases of major versions (like 16.3) are superseded and phased out by AWS RDS as newer patch versions are released. Querying `aws rds describe-db-engine-versions` revealed the active 16.x versions start at `16.8` up to `16.14`.
- **Fix / Solution Applied**:
  Updated `rds.AuroraPostgresEngineVersion` in `lib/data-stack.ts` to `VER_16_8` (which meets the plan's requirement of "16.3+ or 15.7+" and fully supports auto-pause `MinCapacity: 0`).
- **Verification**:
  Verified via `aws rds describe-db-engine-versions --engine aurora-postgresql` that `16.8` is available in `ap-south-1`. Unit test updated and passed.
- **Prevention Rule**:
  Before specifying fixed minor/patch engine versions in CloudFormation, query the active engine versions in the target region via `aws rds describe-db-engine-versions`.

---

### [ISSUE-010] AWS Lambda Node.js 20 Deprecation in CDK Construct
- **Date & Phase**: 2026-09-14 | Phase 3 (ComputeStack Implementation)
- **Component / Command**: `NodejsFunction` in `lib/compute-stack.ts`
- **Symptom / Error Message**:
  Deprecation warning / potential synthesis rejection when specifying `Runtime.NODEJS_20_X`:
  `Runtime NODEJS_20_X is deprecated by AWS Lambda / CDK in favor of active LTS versions.`
- **Root Cause Analysis**:
  AWS Lambda and modern CDK v2 releases deprecate older Node.js runtimes as they approach EOL or as newer LTS versions (Node.js 22 LTS) are standardized across the platform.
- **Fix / Solution Applied**:
  Specified `runtime: lambda.Runtime.NODEJS_22_X` on the `processTelemetry` `NodejsFunction` construct.
- **Verification**:
  Synthesized and tested cleanly across all unit tests and successfully executed live in `ap-south-1`.
- **Prevention Rule**:
  Target the latest active LTS runtime supported by AWS Lambda (`NODEJS_22_X`) when initializing new serverless functions.

---

### [ISSUE-011] Flutter SDK Not Found in Windows Environment (Resolved: Installed Flutter 3.47.4)
- **Date & Phase**: 2026-09-14 | UI Phase 1 (Client Scaffolding)
- **Component / Command**: Environment verification (`flutter --version`)
- **Symptom / Error Message**:
  ```
  INFO: Could not find files for the given pattern(s).
  flutter : The term 'flutter' is not recognized as the name of a cmdlet...
  ```
- **Root Cause Analysis**:
  Flutter SDK was not installed on the system. Cross-platform mobile development requires the Flutter CLI framework and Dart runtime.
- **Fix / Solution Applied**:
  Cloned official Flutter stable branch (`--depth 1`) from `https://github.com/flutter/flutter.git` into `D:\flutter`. Initialized Dart SDK artifacts and persisted `D:\flutter\bin` to the Windows User environment `Path` registry.
- **Verification**:
  `flutter --version` verified working (Flutter 3.47.4, Dart 3.13.3, DevTools 2.60.0).
- **Prevention Rule**:
  Install mobile SDKs to dedicated secondary drives with sufficient disk space and register binary paths directly in the User environment registry.

---

### [ISSUE-012] Flutter 3.47 Theme & Deprecation Changes (CardThemeData & withValues)
- **Date & Phase**: 2026-09-14 | UI Phase 1 (Design System Implementation)
- **Component / Command**: `flutter analyze`
- **Symptom / Error Message**:
  ```
  error - The argument type 'CardTheme' can't be assigned to the parameter type 'CardThemeData?' - lib\core\theme\app_theme.dart:83:18
  info - 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss - lib\core\widgets\bottom_nav_bar.dart:24:33
  ```
- **Root Cause Analysis**:
  In modern Flutter (3.47 / Dart 3.13), `ThemeData.cardTheme` strictly requires `CardThemeData` instead of `CardTheme` (which is a widget). Furthermore, `Color.withOpacity()` was deprecated across Flutter framework in favor of `Color.withValues(alpha: ...)`.
- **Fix / Solution Applied**:
  Updated `app_theme.dart` to specify `cardTheme: CardThemeData(...)`. Replaced all occurrences of `withOpacity(...)` with `withValues(alpha: ...)` across the theme and shell widgets.
- **Verification**:
  `flutter analyze` succeeded with `No issues found! (ran in 14.1s)`.
- **Prevention Rule**:
  Strictly use modern Flutter 3.47 API standards (`CardThemeData`, `withValues(alpha: ...)`) for all new UI components.

---

### [ISSUE-013] FlutterSecureStorage Platform Channel Exception in Headless Unit Tests
- **Date & Phase**: 2026-09-15 | UI Phase 2 (Cognito Auth Service Testing)
- **Component / Command**: `flutter test test/auth_test.dart`
- **Symptom / Error Message**:
  ```
  Binding has not yet been initialized.
  The "instance" getter on the ServicesBinding binding mixin is only available once that binding has been initialized.
  MethodChannel.invokeMethod -> MethodChannelFlutterSecureStorage.read
  ```
- **Root Cause Analysis**:
  `FlutterSecureStorage` relies on native platform channels (`MethodChannel`). In pure headless unit tests where no native Android/iOS/Windows engine runner is bootstrapped, invoking platform methods throws a binding initialization error.
- **Fix / Solution Applied**:
  1. Initialized `TestWidgetsFlutterBinding.ensureInitialized()` in test entry points.
  2. Applied the Dependency Inversion Principle: introduced the `AuthStorage` interface in `cognito_auth_service.dart` with `SecureAuthStorage` (wrapping `FlutterSecureStorage` for production) and `MemoryAuthStorage` (an in-memory key-value map for headless unit tests).
- **Verification**:
  `flutter test` passed all 6 unit tests without platform channel exceptions.
- **Prevention Rule**:
  Always abstract platform-specific plugins (storage, sensors, biometric hardware) behind domain interfaces to allow seamless dependency injection during testing.

---

### [ISSUE-014] Flutter Switch activeColor Deprecation in Flutter 3.31+
- **Date & Phase**: 2026-09-15 | UI Phase 3 (Live Radar HUD Sheet Implementation)
- **Component / Command**: `flutter analyze`
- **Symptom / Error Message**:
  ```
  info - 'activeColor' is deprecated and shouldn't be used. Use activeThumbColor instead - lib\features\radar\widgets\radar_hud_sheet.dart:174:19
  ```
- **Root Cause Analysis**:
  In modern Flutter (post v3.31.0), `Switch.activeColor` was deprecated in favor of explicit `Switch.activeThumbColor` and `Switch.activeTrackColor` to clearly differentiate thumb and track styling.
- **Fix / Solution Applied**:
  Replaced `activeColor: AppColors.primary` with `activeThumbColor: AppColors.primary` in `RadarHudSheet`.
- **Verification**:
  `flutter analyze` succeeded with `No issues found! (ran in 10.4s)`.
- **Prevention Rule**:
  Use `activeThumbColor` when styling custom Material 3 toggle switches.

---

### [ISSUE-015] Missing Flutter SDK on Single-Drive (C:) Developer Workstations
- **Date & Phase**: 2026-09-15 | UI Phase 4 (Pack Management & Formation Screen)
- **Component / Command**: `flutter test` / `flutter --version`
- **Symptom / Error Message**:
  ```
  flutter : The term 'flutter' is not recognized as the name of a cmdlet, function, script file, or operable program.
  ```
- **Root Cause Analysis**:
  Earlier milestones (UI 1–3) were executed on a secondary development machine with Flutter hosted at `D:\flutter`. The active workstation has a single primary disk volume (`C:\`) and lacked the Flutter binary directory in `$env:Path`.
- **Fix / Solution Applied**:
  Cloned the official Flutter stable release (`--depth 1 -b stable`) into `C:\flutter`. Initialized the Flutter Dart toolchain and persisted `C:\flutter\bin` to the Windows User Environment `Path` registry.
- **Verification**:
  `flutter --version` verified working and active in terminal sessions.
- **Prevention Rule**:
  Always verify the local volume topology and install developer SDKs to `C:\flutter` if secondary drives are not present.

---

### [ISSUE-016] Android Platform Missing and Corrupted NDK CXX1101 Build Failure
- **Date & Phase**: 2026-09-15 | UI Testing on Physical Device
- **Component / Command**: `flutter install` / `flutter run -d <DEVICE_ID>` / Android Gradle Plugin
- **Symptom / Error Message**:
  1. Initial run failed:
     ```
     AndroidManifest.xml could not be found.
     Please check C:\Users\faizan\Downloads\AWS\mobile\android\AndroidManifest.xml for errors.
     ```
  2. Subsequent Gradle build failed after generating scaffold:
     ```
     > com.android.builder.errors.EvalIssueException: [CXX1101] NDK at C:\Users\faizan\AppData\Local\Android\sdk\ndk\28.2.13676358 did not have a source.properties file
     BUILD FAILED in 13s
     Running Gradle task 'assembleDebug'... 14.2s
     ```
- **Root Cause Analysis**:
  1. The Flutter workspace under `mobile/` originally only contained Dart source files (`lib/`, `test/`) and lacked the native Android platform scaffolding (`android/`).
  2. During the initial background compilation, the background process was interrupted or timed out while AGP was downloading the 28.2.13676358 NDK package, leaving a half-downloaded directory lacking `source.properties`.
- **Fix / Solution Applied**:
  1. Re-generated the clean Android platform harness using `flutter create . --platforms android`.
  2. Cleaned out the corrupted NDK folder with `Remove-Item -Recurse -Force "C:\Users\faizan\AppData\Local\Android\sdk\ndk\28.2.13676358"`.
  3. Re-ran `flutter run -d <DEVICE_ID>` allowing Gradle to cleanly re-fetch the NDK and compile the debug APK.
- **Verification**:
  App launched successfully on physical Android device (`RMX3997`, PID: 9406) with active touch dispatch and viewport metrics streaming.
- **Prevention Rule**:
  If Gradle compilation fails with `CXX1101 source.properties missing`, always remove the corresponding NDK directory in `AppData/Local/Android/sdk/ndk/` before retrying the build.

---

### [ISSUE-017] RenderFlex Overflow on 360dp Viewport Mobile Devices
- **Date & Phase**: 2026-09-15 | UI Polish & Mobile Device Verification
- **Component / Command**: `PackManagementScreen`, `RecordedConvoysCard`, `ActiveCodeCard` on 360dp Android phone (`RMX3997`)
- **Symptom / Error Message**:
  ```
  A RenderFlex overflowed by 9.3 pixels on the right.
  The relevant error-causing widget was: Row
  ```
- **Root Cause Analysis**:
  Certain cards used unconstrained nested `Row` widgets containing fixed-width icons, titles, and trailing status pills/buttons. On 360dp viewports, the total width `(360 - 32 padding - 32 card padding = 296dp)` was insufficient for side-by-side elements without flexible boundaries.
- **Fix / Solution Applied**:
  1. Wrapped primary text content columns in `Expanded` or `Flexible` with `TextOverflow.ellipsis`.
  2. Wrapped secondary action button groups (such as `Export GPX` and `Export GeoJSON`) in `Wrap` with `WrapAlignment.spaceBetween`.
  3. Streamlined horizontal badge chains into 2-column flex layouts matching the updated Stitch mockups (`stitch_groupnav_web3_convoy_tracker`).
- **Verification**:
  All 4 core tabs tested with Flutter test suite (46 passing tests) and verified on 360dp mobile viewport with zero `RenderFlex` overflow errors.
- **Prevention Rule**:
  Never use unconstrained `Row` children inside compact mobile cards. Always wrap variable-width text in `Expanded` or `Flexible`, and wrap multi-button action bars in `Wrap`.

---

### [ISSUE-018] Runtime RenderFlex Overflows Across Auth, Trips, and App Bar on 360dp Device
- **Date & Phase**: 2026-09-15 | UI Polish & Mobile Device Verification
- **Component / Command**: Physical device live run (Process ID 20880, `RMX3997` 360dp width)
- **Symptom / Error Message**:
  ```
  Another exception was thrown: A RenderFlex overflowed by 17 pixels on the right.
  Another exception was thrown: A RenderFlex overflowed by 1.8 pixels on the right.
  Another exception was thrown: A RenderFlex overflowed by 61 pixels on the right.
  Another exception was thrown: A RenderFlex overflowed by 39 pixels on the right.
  Another exception was thrown: A RenderFlex overflowed by 122 pixels on the right.
  Another exception was thrown: A RenderFlex overflowed by 28 pixels on the right.
  Another exception was thrown: A RenderFlex overflowed by 31 pixels on the right.
  ```
- **Root Cause Analysis**:
  1. **122px Overflow (`trip_history_screen.dart`)**: Header `Column` holding long subtitle `"Aurora PostGIS spatial ledger & LiDAR profiles"` was placed in a `Row` alongside a session count container without `Expanded`, exceeding 360dp viewport width by 122px.
  2. **61px Overflow (`elevation_pace_chart_card.dart`)**: Cursor live value strip used `Row(mainAxisAlignment: MainAxisAlignment.spaceBetween)` holding `"Cursor Position:"` (~90px) and 3 formatted telemetry metrics (`"${distance} km • ${elevation} m • ${speed} km/h"`, ~240px) inside a 288dp card body.
  3. **39px & 28px Overflows (`vehicle_class_selector.dart`)**: Each 2-column grid item has ~112dp inner width; `Row` contained fixed icon (18dp), `Spacer()`, and unconstrained label text which pushed beyond the boundary when selected with checkmark (16dp).
  4. **31px Overflow (`otp_verification_dialog.dart`)**: 6 input fields with fixed `width: 44` (`6 * 44 = 264dp` plus gaps) inside a dialog container with 48dp total padding on 360dp width (`360 - 80 - 48 = 232dp` available).
  5. **17px Overflow (`top_app_bar_pill.dart`)**: Left moniker `Row` (Menu icon + `"GroupNav"` + `"DePIN"` pill) and right reward pill (`"+4.2 NAV/hr"`) lacked `Expanded`/`Flexible` constraints.
  6. **1.8px Overflow (`auth_onboarding_screen.dart`)**: Top card badges (`"SECURE ACCESS"` + `"AWS Cognito Connected"`) in a rigid `Row` slightly exceeded 272dp available inner card width.
- **Fix / Solution Applied**:
  1. `trip_history_screen.dart`: Wrapped header column in `Expanded` and gave subtitle `maxLines: 1, overflow: TextOverflow.ellipsis`.
  2. `elevation_pace_chart_card.dart`: Replaced rigid `Row` in cursor value strip with responsive `Wrap(alignment: WrapAlignment.spaceBetween, spacing: 8, runSpacing: 4)`.
  3. `vehicle_class_selector.dart`: Replaced `Text(...) + Spacer()` with `Expanded(child: Text(..., maxLines: 1, overflow: TextOverflow.ellipsis))` and inline checkmark.
  4. `otp_verification_dialog.dart`: Replaced fixed `SizedBox(width: 44)` with `Expanded(child: Container(margin: EdgeInsets.only(right: index < 5 ? 6 : 0), ...))`.
  5. `top_app_bar_pill.dart`: Wrapped left branding `Row` in `Expanded` with `Flexible(child: Text(title, overflow: TextOverflow.ellipsis))`.
  6. `auth_onboarding_screen.dart`: Wrapped badge rows in responsive `Wrap` with `WrapAlignment.spaceBetween`, and protected callsign and banner rows with `Expanded`/`Flexible`.
  7. `trip_replay_map.dart`: Added `right: 12`, `Align(alignment: Alignment.centerLeft)`, and `Flexible` with ellipsis to floating tag.
  8. `navigation_display_card.dart`: Wrapped segment labels in `FittedBox(fit: BoxFit.scaleDown)` to ensure clean rendering under any text scale.
- **Verification**:
  - `flutter analyze`: 0 issues found.
  - `flutter test`: 46/46 unit tests passing.
- **Prevention Rule**:
  Always use `Expanded`, `Flexible`, `FittedBox`, or `Wrap` on horizontal containers that display text or dynamic metrics. Never place rigid unconstrained items inside mobile `Row` layouts.

---

### [ISSUE-019] Pack Room vs. Pilot Identity Conflation ("Leave Pack" vs "Sign Out")
- **Date & Phase**: 2026-09-15 | Functional Overhaul (Step 1)
- **Component / Command**: `pack_provider.dart`, `rider_settings_screen.dart`, `pack_management_screen.dart`
- **Symptom / Unexpected Behavior**:
  The UI conflated exiting a temporary convoy room with logging out of the rider's AWS Cognito user account. When leaving a pack, user credentials were treated as coupled to the room, preventing solo riding and requiring re-authentication.
- **Root Cause Analysis**:
  A pack is an ephemeral rendezvous session (like a Discord channel or WebRTC room), whereas a rider's identity is a permanent AWS Cognito User Pool identity with persistent profile metrics. Coupling them violated the decoupled architecture principle.
- **Fix / Solution Applied**:
  1. Added `isInPack: bool` flag to `PackFormation` model.
  2. Created dedicated `leavePack()` in `PackNotifier` that sets `isInPack = false` and switches to Solo Ride Mode without modifying Cognito tokens or stored AWS credentials.
  3. Added Active Convoy Room management card in `RiderSettingsScreen` with dedicated "Leave Pack" button, while isolating "Log Out of Account" into a separate destructive sign-out dialog.
  4. Added `_buildSoloView` and `_buildInPackView` to `PackManagementScreen` allowing solo riders to independently record trips or create/join convoy rooms.
- **Verification**:
  Unit tests in `mobile/test/pack_test.dart` and `mobile/test/settings_test.dart` verified that `leavePack()` retains pilot identity while switching room states.
- **Prevention Rule**:
  Always keep session/room membership decoupled from user authentication and persistent credentials.

---

### [ISSUE-020] StateNotifier State Getter Access Outside Class Hierarchy in Provider Definition
- **Date & Phase**: 2026-09-15 | Functional Overhaul (Step 5)
- **Component / Command**: `flutter analyze` / `trip_history_provider.dart`
- **Symptom / Error Message**:
  ```
  warning - The member 'state' can only be used within 'package:state_notifier/state_notifier.dart' or a test - lib\features\trips\providers\trip_history_provider.dart:444:18 - invalid_use_of_visible_for_testing_member
  warning - The member 'state' can only be used within instance members of subclasses of 'StateNotifier' - lib\features\trips\providers\trip_history_provider.dart:444:18 - invalid_use_of_protected_member
  ```
- **Root Cause Analysis**:
  `StateNotifier.state` is protected and strictly intended for read/write within subclasses of `StateNotifier`. Referencing `notifier.state` inside the external `Provider` callback violates encapsulation and triggers Riverpod analysis lints.
- **Fix / Solution Applied**:
  Injected `LocationService` into the `TripHistoryNotifier` constructor (`TripHistoryNotifier({this.locationService})`). The notifier manages its own `_locationSub` internally and accesses `state.isRecording` within its own instance methods.
- **Verification**:
  `flutter analyze` succeeded with 0 warnings or issues.
- **Prevention Rule**:
  Never inspect or mutate `notifier.state` outside of the `StateNotifier` class declaration. Pass external dependencies into the constructor and manage reactive subscriptions internally.

---

### [ISSUE-021] AWS CDK NodejsFunction EPERM Rename Failure on Windows
- **Date & Phase**: 2026-09-17 | Service Restore & Deployment Verification
- **Component / Command**: `npx cdk deploy DataStack ComputeStack ObservabilityStack` / `NodejsFunction` in `lib/compute-stack.ts`
- **Symptom / Error Message**:
  ```
  [«FailedToBundleAsset» Failed to bundle asset ComputeStack/ProcessTelemetryFunction/Code/Stage, bundle output is located at D:\chirag\GroupNav-Infrastructure\cdk.out\bundling-temp-8f6cdf209b61ea8b5299404678a39ee8ba58a72ff927b23975544544b4d21f58-building: Error: EPERM: operation not permitted, rename 'D:\chirag\GroupNav-Infrastructure\cdk.out\bundling-temp-8f6cdf209b61ea8b5299404678a39ee8ba58a72ff927b23975544544b4d21f58-building' -> 'D:\chirag\GroupNav-Infrastructure\cdk.out\bundling-temp-8f6cdf209b61ea8b5299404678a39ee8ba58a72ff927b23975544544b4d21f58']
  ```
- **Root Cause Analysis**:
  In `ComputeStack`, `bundling` was configured with `nodeModules: ['pg', 'redis']`. This forced CDK to invoke `npm install` inside a temporary staging folder (`cdk.out/bundling-temp-...-building`) at synthesis time. On Windows, npm background file handles or real-time file scanners retain read locks on freshly extracted files, causing CDK's subsequent synchronous directory rename (`fs.renameSync`) to fail with `EPERM: operation not permitted`.
- **Fix / Solution Applied**:
  Removed `nodeModules: ['pg', 'redis']` and configured direct esbuild bundling with `externalModules: ['@aws-sdk/*', 'pg-native']`. Esbuild compiles pure JavaScript implementations of `pg` and `redis` into `index.js` in ~400ms without triggering an external `npm install` process or generating lock-prone temporary directories.
- **Verification**:
  - `npm test`: All 6 CDK test suites and 35 unit tests passed.
  - `npx cdk synth DataStack ComputeStack ObservabilityStack`: Succeeded with 0 errors.
  - `npx cdk diff DataStack ComputeStack ObservabilityStack`: Succeeded with 0 errors and cleanly generated CloudFormation change sets across all 3 stacks.
- **Prevention Rule**:
  Do not use `nodeModules` in `NodejsFunction` bundling unless native binaries strictly require it. Bundle libraries with pure JS fallbacks (like `pg` and `redis`) directly via esbuild and mark optional native bindings (e.g. `pg-native`) in `externalModules`.

---

### [ISSUE-022] ComputeStack Rollback Due to Pre-existing CloudWatch Log Group Collision
- **Date & Phase**: 2026-09-17 | Operations & Service Restoration
- **Component / Command**: `npx cdk deploy ComputeStack` / `AWS::Logs::LogGroup`
- **Symptom / Error Message**:
  ```
  Resource of type 'AWS::Logs::LogGroup' with identifier '{"/properties/LogGroupName":"/aws/lambda/groupnav-process-telemetry"}' already exists.
  HandlerErrorCode: AlreadyExists
  ComputeStack | ROLLBACK_COMPLETE
  ```
- **Root Cause Analysis**:
  During earlier resource teardowns or lambda invocations, the CloudWatch log group `/aws/lambda/groupnav-process-telemetry` was retained in AWS CloudWatch Logs. When CloudFormation attempted to provision `ComputeStack`, CDK synthesized a managed `AWS::Logs::LogGroup` construct (`ProcessTelemetryFunctionLogGroup330788B4`) which collided with the pre-existing log group, triggering a stack rollback into `ROLLBACK_COMPLETE`.
- **Fix / Solution Applied**:
  1. Deleted the rolled-back stack via `aws cloudformation delete-stack --stack-name ComputeStack`.
  2. Deleted the orphaned CloudWatch log group via `aws logs delete-log-group --log-group-name /aws/lambda/groupnav-process-telemetry`.
  3. Re-deployed `ComputeStack` cleanly via `npx cdk deploy ComputeStack --require-approval never` (all 15 resources provisioned).
  4. Regenerated client configuration with `npm run export-config` and validated end-to-end telemetry ingestion with `npx tsx scripts/verify-phase3.ts`.
- **Verification**:
  All 15 CloudFormation resources in `ComputeStack` deployed in `CREATE_COMPLETE`. End-to-end Phase 3 verification test passed cleanly, and all 35 Jest unit tests passed (6/6 test suites).
### [ISSUE-023] CloudFormation IAM Policy Construct ID Collision During AuthStack Expansion
- **Date & Phase**: 2026-09-18 | Real AWS Integration (Zero Placeholders)
- **Component / Command**: `npx cdk deploy AuthStack` / `lib/auth-stack.ts`
- **Symptom / Error Message**:
  ```
  Resource handler returned message: "Policy GroupNavRiderIotPolicy already exists." (RequestToken: ..., HandlerErrorCode: AlreadyExists)
  AuthStack | UPDATE_FAILED | AWS::IAM::ManagedPolicy
  ```
- **Root Cause Analysis**:
  When expanding IAM permissions for DynamoDB (`groupnav-packs`) and IoT Core MQTT topics, renaming the CDK construct ID from `RiderIotTelemetryPolicy` to `RiderIotAndDynamoPolicy` while specifying the same explicit `managedPolicyName: 'GroupNavRiderIotPolicy'` caused CloudFormation to synthesize a new resource logical ID. CloudFormation attempts to create the new managed policy before deleting the old one, resulting in a name conflict error (`AlreadyExists`).
- **Fix / Solution Applied**:
  Retained the original construct ID `RiderIotTelemetryPolicy` with the updated policy statements (adding `dynamodb:*` on `groupnav-packs` and expanding IoT Core action topics). CloudFormation performed an in-place update on the existing managed policy without naming conflicts.
- **Verification**:
  `npx cdk deploy AuthStack` succeeded in 32.5s with status `UPDATE_COMPLETE`, updating the IAM Managed Policy and creating the DynamoDB table `groupnav-packs`.
- **Prevention Rule**:
  Never alter the CDK construct ID of an IAM role or policy that has an explicit physical name (`roleName` / `managedPolicyName`) in an existing CloudFormation stack, as CloudFormation treats ID changes as resource replacements.

---

### [ISSUE-024] Test Suite Assertion Failures Following Purge of Hardcoded Mock State
- **Date & Phase**: 2026-09-18 | Real AWS Mobile Integration (Phase 4 / Step 7)
- **Component / Command**: `flutter test` in `mobile/`
- **Symptom / Error Message**:
  ```
  Failing tests:
    test/pack_test.dart: PackNotifier State Tests joinPack sets isInPack to true (Expected <4>, Actual <1>)
    test/radar_test.dart: IotTelemetryService createPacket returns valid schema (Expected '804', Actual 'solo')
    test/trips_test.dart: TripHistoryNotifier Playback Tests (Expected availableTrips.isNotEmpty == true, Actual false)
  ```
- **Root Cause Analysis**:
  The mobile test suite was originally constructed to assert the behavior of simulated mock harnesses (e.g., hardcoded 4-bike rosters `Apex`, `Viper`, `Ghost`, `Nomad`, default room `804`, and pre-populated mock trips). When all simulated ticker loops and fake data were completely purged in favor of real AWS Cognito, DynamoDB, and IoT Core connectivity, the baseline state legitimately changed to zero (Solo ride, 0 remote peers, 0 recorded trips).
- **Fix / Solution Applied**:
  1. Updated `mobile/test/pack_test.dart` to assert the true Solo Ride baseline (`members.length == 1`, user only) and verified async join/leave transitions.
  2. Updated `mobile/test/radar_test.dart` to verify that unjoined telemetry streams default to `packId: 'solo'`, and dynamically adopt the joined convoy code via `updateActivePack`.
  3. Updated `mobile/test/trips_test.dart` to verify empty initial trip history (`availableTrips.isEmpty`) and test playback scrubber actions against actively selected trip recordings.
- **Verification**:
  All 57 unit tests passed cleanly (`flutter test`, 100% pass rate) and `flutter analyze` completed with 0 errors, 0 warnings, and 0 lints.
- **Prevention Rule**:
  When transitioning a client from simulation/mock prototypes to genuine cloud-connected architectures, audit test assertions so they validate authentic cloud lifecycle states and empty initialization boundaries rather than synthetic mock fixtures.

---

### [ISSUE-025] Flutter Riverpod CircularDependencyError on LiveRadarScreen Initialization
- **Date & Phase**: 2026-09-18 | Real AWS Mobile Integration (Phase 4 / Step 7)
- **Component / Command**: `LiveRadarScreen` / `radarNotifierProvider` & `packNotifierProvider`
- **Symptom / Error Message**:
  ```
  Instance of 'CircularDependencyError'
  See also: https://docs.flutter.dev/testing/errors
  ```
- **Root Cause Analysis**:
  A two-way circular dependency cycle existed between `radarNotifierProvider` and `packNotifierProvider`:
  1. When navigating to the Radar screen (default tab 1), `LiveRadarScreen` invoked `ref.watch(radarNotifierProvider)`.
  2. During `RadarNotifier` construction, `_syncPackSubscription()` eagerly registered `_ref?.listen(packNotifierProvider)`.
  3. Listening to `packNotifierProvider` forced Riverpod to evaluate the `packNotifierProvider` builder.
  4. The `packNotifierProvider` builder executed `ref.watch(radarNotifierProvider.notifier)` to obtain `RadarNotifier`.
  5. Riverpod detected that `packNotifierProvider` was requesting `radarNotifierProvider.notifier` while `radarNotifierProvider` was still mid-construction on the active instantiation stack, triggering `CircularDependencyError` and crashing the widget tree to the red error screen.
- **Fix / Solution Applied**:
  1. Decoupled `RadarNotifier` entirely from `packNotifierProvider`. Removed `_ref` from `RadarNotifier` and eliminated `_syncPackSubscription()`.
  2. Injected `IotTelemetryService` (`iotTelemetryServiceProvider`) directly into `packNotifierProvider`. `PackNotifier` now directly invokes `_telemetryService.updateActivePack(...)` upon joining, creating, or leaving a pack, and calls `_telemetryService.publishAlert(...)` directly for SOS broadcasts.
  3. Made `RadarNotifier` an optional parameter for `PackNotifier` for geofence updates, establishing a strict unidirectional Directed Acyclic Graph (DAG):
     `IotTelemetryService` $\rightarrow$ `RadarNotifier`
     `IotTelemetryService` + `RadarNotifier` $\rightarrow$ `PackNotifier`
  4. Updated `LiveRadarScreen` to watch `packNotifierProvider` directly for `geofenceRadiusMeters` as the single source of truth for the convoy boundary mesh and HUD indicator chip.
  5. Added a dedicated `ProviderContainer` unit test in `radar_test.dart` to assert that mutual initialization of `radarNotifierProvider` and `packNotifierProvider` succeeds cleanly without circular dependency errors.
- **Verification**:
  All 58 unit tests in `mobile/test/` passed (100% pass rate) with zero failures.
- **Prevention Rule**:
  Never use `ref.listen()` inside a `StateNotifier` constructor to observe a provider that itself depends on or watches that `StateNotifier` (or its `.notifier`). Cross-provider domain synchronization must either flow unidirectionally or through a shared lower-level domain service (such as `IotTelemetryService`).

---

### [ISSUE-026] RenderFlex Overflow on Create Convoy Bottom Sheet Header Row
- **Date & Phase**: 2026-09-18 | Milestone 2 (Create Convoy Feature)
- **Component / Command**: `CreateConvoySheet` (`mobile/lib/features/groups/widgets/create_convoy_sheet.dart`)
- **Symptom / Error Message**:
  ```
  A RenderFlex overflowed by 14 pixels on the right.
  The relevant error-causing widget was: Row
  ```
- **Root Cause Analysis**:
  In `CreateConvoySheet`, the top header row placed an icon container (`36x36`), a `Column` containing the title ("Create Convoy Room") and subtitle ("Launch real-time telemetry rendezvous..."), and a close `IconButton` directly within a `Row`. Because the text column was not wrapped in `Expanded`, on compact mobile display widths (e.g., 720px wide Android viewports), the long subtitle string forced the intrinsic row width beyond the screen boundary, triggering Flutter's yellow-and-black striped pixel overflow indicator.
- **Fix / Solution Applied**:
  Wrapped the title/subtitle `Column` in an `Expanded` widget and set `overflow: TextOverflow.ellipsis` on the subtitle text.
- **Verification**:
  Captured live device screenshot on `Realme RMX3997` confirming zero pixel overflow indicators across all screen densities.
- **Prevention Rule**:
  Always wrap variable-width text columns placed between fixed-width icons inside horizontal `Row` widgets in `Expanded` or `Flexible`, and declare explicit truncation policies (`TextOverflow.ellipsis`) for multi-word descriptive subtitles.

---

### [ISSUE-027] DynamoDbPackService Omitted isInPack: true on PackFormation Instantiation
- **Date & Phase**: 2026-09-18 | Milestone 2 (Create Convoy Feature)
- **Component / Command**: `DynamoDbPackService` (`dynamodb_pack_service.dart`) & `PackNotifier` (`pack_provider.dart`)
- **Symptom / Error Message**:
  After clicking "Launch Convoy Room", the green toast appeared stating room was launched and AWS PutItem succeeded in DynamoDB (`groupnav-packs`), but the screen did not display the active convoy room or QR code card, remaining on "Solo Ride Mode" / "Ride Independently or Join a Convoy".
- **Root Cause Analysis**:
  `PackFormation` model defines `final bool isInPack` with a default of `false`. Inside `DynamoDbPackService.createPack` and `_parsePackItem`, `PackFormation` was constructed without supplying `isInPack: true`. Consequently, `state = formation` received an entity with `isInPack == false`. In `PackManagementScreen`, the body builder evaluated `formation.isInPack ? _buildInPackView(...) : _buildSoloView(...)`, causing Flutter to render the solo placeholder instead of the active convoy room.
- **Fix / Solution Applied**:
  1. Set `isInPack: true` explicitly in `DynamoDbPackService.createPack`.
  2. Set `isInPack: packCode.isNotEmpty` in `DynamoDbPackService._parsePackItem`.
  3. Added defensive `state = formation.copyWith(isInPack: true)` across `createPack`, `joinPack`, and `_startRosterPolling` in `pack_provider.dart`.
  4. Added an offline/guest fallback so pilots without active AWS credentials can also launch convoy rooms without throwing unhandled credential exceptions.
- **Verification**:
  Dealt with live on physical hardware (`Realme RMX3997`). Created room `GN-3554` and verified screen immediately transitions to the active convoy room displaying the `GN-3554` join code, Copy button, interactive Pair QR dialog, geofence radius slider, and connected member roster.
- **Prevention Rule**:
  Whenever constructing domain models from database or network responses that represent active joined states, always explicitly define boolean membership flags rather than relying on default constructor values that default to unjoined states.
