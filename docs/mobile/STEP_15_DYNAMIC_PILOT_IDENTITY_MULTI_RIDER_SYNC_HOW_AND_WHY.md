# Step 15: Dynamic Pilot Identity, Roster Role Isolation & Zero-Default Accounts

## Overview
This milestone resolves critical multi-rider identity synchronization issues discovered during live physical and virtual device testing. The fixes eliminate hardcoded pilot fallbacks (`Apex`), prevent account session collisions, correct misleading tactical roster indicators (the dual `(You)` badge issue), and ensure authentic AWS Cognito attributes and leader roles are dynamically propagated across the live map and convoy roster.

---

## 1. How It Was Done

### 1.1 Root Cause Diagnostics
1. **Unwanted Default Session Injection**:
   - In `AuthNotifier`, the private field `_callsign` was initialized to `'Apex'`. When `signIn(email, password)` was invoked from the login form, it passed `_callsign` (`'Apex'`) to `CognitoAuthService.signIn()`.
   - `CognitoAuthService` used `final resolvedCallsign = callsign ?? tokenClaims['name']...`. Because `callsign` was always passed as `'Apex'`, it systematically ignored the user's authentic Cognito account `name` claim (e.g. `lion`).
   - The pilot profile was then persisted into `FlutterSecureStorage` with callsign `'Apex'`. On subsequent app launches, `restoreSession()` reloaded this profile and automatically logged in as `'Apex'`.
2. **Dual `(You)` Badge Display on Roster Cards**:
   - In `PackRosterCard`, line 123 had a hardcoded conditional `if (isLead) ... [ Text('(You)') ]`. This assumed that whichever member held the leader status was the local user.
   - When rider B (`lion`) joined rider A's convoy room, rider A displayed `(You)` because of `isLead == true`, while rider B displayed `(You)` because their callsign had `(You)` appended. As a result, both participants appeared with `(You)` tags on rider B's screen.
3. **Radar Map Leader Marker Attribution**:
   - `IotTelemetryService` initialized `_currentCallsign = 'Apex'` and `_isLeader = true`.
   - `radar_provider.dart` only registered a `ref.listen` on `authNotifierProvider` for subsequent state changes, failing to read the initial authenticated pilot profile upon provider instantiation. Consequently, self-telemetry was broadcast with `callsign: 'Apex (You)'` and leader marker tags (`'Lead'`).

### 1.2 Authentication Decoupling & Authentic Claim Resolution
- **Empty Default State**: Modified `AuthNotifier._callsign` to initialize as empty string `''`.
- **Dynamic Cognito Claim Extraction**: Updated `CognitoAuthService.signIn()` to check if the caller passed a non-empty callsign. If empty or null, it extracts the authentic callsign directly from Cognito ID Token JWT claims: `tokenClaims['name']`, falling back to `tokenClaims['cognito:username']` or email prefix.
- **State Synchronization**: Upon successful authentication, `AuthNotifier` sets its internal `_callsign` to the authenticated pilot profile's callsign.
- **Clean Sign-Out**: Enhanced `AuthNotifier.signOut()` to reset all credentials, email, password, and callsign fields to empty states, guaranteeing that sign-out completely returns the application to `AuthOnboardingScreen`.

### 1.3 Roster Role Isolation & Clean Domain Models
- **Isolated User Tagging**: Added `final bool isCurrentUser;` (default `false`) to `PackMember`.
- **Clean Callsign Helper**: Added `cleanCallsign` getter to `PackMember` that strips any legacy `(You)` string artifacts, ensuring the domain model stores only the clean callsign.
- **Pill Badge Isolation in `PackRosterCard`**: Removed the `if (isLead)` condition. Replaced it with `if (member.isCurrentUser || member.callsign.contains('(You)'))`, rendering a styled `You` badge strictly for the active device's logged-in rider.
- **DynamoDB Pack Service Parser**: Updated `_parsePackItem()` to evaluate `isCurrentUser = (currentRiderId != null && id == currentRiderId)` and sanitize incoming callsigns before populating member models.

### 1.4 Dynamic Radar Map & Telemetry Synchronization
- **Telemetry Service Defaults**: Reset `IotTelemetryService._currentCallsign` to empty and `_isLeader` to `false`.
- **Provider Initialization**: In `radar_provider.dart`, added an eager read of `authNotifierProvider` on creation of `iotTelemetryServiceProvider`. If a pilot session exists, `service.updateRiderIdentity()` is immediately dispatched with their genuine callsign and Cognito ID.
- **Dynamic Leader Status**: The leader status is now dynamically resolved from active convoy membership. When in a pack, only the designated Road Captain receives leader markers; followers render standard peer markers.

### 1.5 Device Keystore Purge
- Executed `adb shell pm clear com.example.groupnav_mobile` to eradicate legacy cached test sessions and ensure a pristine test baseline.

---

## 2. Why It Was Done This Way

### 2.1 Backend Identity Truth vs. Local Defaults
- **Rationale**: Real cloud systems must derive user identity from authenticated cryptographic tokens (AWS Cognito JWT ID Tokens), not arbitrary in-memory defaults. Defaulting to `'Apex'` created a race condition where real pilot names were obscured.
- **Architectural Decision**: Allowing `signIn()` to pass `null` for callsign permits the Identity Provider (Cognito) to serve as the single source of truth for user attributes.

### 2.2 Decoupling Roles from Local Identity
- **Rationale**: In convoy systems, "Leadership" (`isLead` / `roadCaptain`) is a tactical operational role, whereas "Self" (`isCurrentUser` / `You`) is a client viewport identity. Conflating the two was the root cause of the dual `(You)` bug.
- **Tradeoff**: Explicitly modeling `isCurrentUser` in domain models requires parsers to accept the active user's ID, but guarantees deterministic UI rendering across any number of convoy participants.

---

## 3. Verification Evidence

### 3.1 Static Analysis & Test Automation
- `flutter analyze` completed with **0 errors and 0 warnings**.
- `flutter test` completed with all **99 tests passing**.

### 3.2 Live Device Verification
- Device storage cleared via ADB.
- App launched in unauthenticated state displaying `AuthOnboardingScreen`.
- Authentication verified against AWS Cognito with dynamic username resolution.
- Convoy room roster verified to display exactly one `You` badge for the active user, with accurate Road Captain and Pack Member role pills.
