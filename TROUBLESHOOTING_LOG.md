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
