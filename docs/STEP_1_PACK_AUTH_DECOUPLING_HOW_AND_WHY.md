# Step 1: Decouple Pack Session from Auth Identity — How & Why

## 1. Overview

In this step, we resolved a fundamental architectural and user experience problem: the conflation of **Pack (Convoy Room Session)** with **Pilot Identity (Cognito Auth)**.

Previously, leaving a pack was coupled to signing out of the mobile app (`"Leave Pack / Log Out"`), forcing the pilot to re-authenticate via OTP every time they left or completed a ride.

We have cleanly decoupled these two concepts:
- **Pilot Identity (`PilotProfile`, Cognito Auth)**: Persistent account state that stays authenticated across sessions, rides, and days.
- **Pack Room (`PackFormation`, Ephemeral Convoy Session)**: A temporary room where riders assemble for a specific route (`GN-9482`, `GN-XXXX`), which a pilot can enter, create, or leave at will.

---

## 2. Technical Breakdown: How It Was Done

### 2.1 Model & Provider Refactoring
- **`PackFormation` (`mobile/lib/features/groups/models/pack_formation.dart`)**:
  - Added `isInPack: bool` flag (defaults to `true` when joined, `false` in Solo Mode).
  - Updated `copyWith` to support toggling pack presence.
- **`PackNotifier` (`mobile/lib/features/groups/providers/pack_provider.dart`)**:
  - Implemented `leavePack()`:
    - Clears room code (`packCode = ''`) and room ID.
    - Sets `isInPack = false` and `title = 'Solo Ride Mode'`.
    - Deactivates pack telemetry sync (`isTelemetrySyncActive = false`).
    - Retains only the active pilot (`Apex (You)`) in the roster.
  - Implemented `joinPack(String code)`:
    - Sets `isInPack = true`, formats code to uppercase.
    - Connects to room and initializes pack peers.
  - Implemented `createPack()`:
    - Generates a unique room code e.g. `GN-XXXX` based on timestamp.
    - Assigns current pilot as Convoy Lead.

### 2.2 Screen & UI Decoupling
- **`PackManagementScreen` (`mobile/lib/features/groups/screens/pack_management_screen.dart`)**:
  - **In-Pack Mode**:
    - Displays active room code card (`GN-9482`), geofence slider, roster, and SOS button.
    - Added an explicit **"Leave"** button in the AppBar and at the bottom of the roster.
    - Tapping "Leave" triggers a confirmation dialog: *"Leave Convoy Room? You will exit room GN-XXXX and switch to Solo Ride Mode. Your pilot account remains active."*
  - **Solo Mode**:
    - Renders a clean **Solo Pilot Mode** hero card indicating GPS is active.
    - Provides two clear call-to-actions: **"Create Convoy"** (becomes lead with new code) and **"Join Room"** (prompts 6-character room code input dialog).
- **`RiderSettingsScreen` (`mobile/lib/features/settings/screens/rider_settings_screen.dart`)**:
  - Added an **Active Convoy Room** status card with `packCode` and a dedicated **"Leave Pack"** action button.
  - Renamed the bottom account action to **"Log Out of Account"** with subtitle *"Signing out removes your credentials and pilot profile from this device"*.
  - Clicking "Log Out" opens `SignOutDialog` and only triggers `authNotifier.signOut()`.

---

## 3. Why It Was Done This Way

1. **Clean Separation of Concerns**: A user account should never be destroyed or reset just because a group ride has concluded. Riders frequently ride solo before or after joining a pack.
2. **Reduced Cognitive Friction**: Riders do not need to re-enter their phone number or wait for SMS OTP codes every time they exit a group convoy.
3. **Multi-Ride Flexibility**: A rider can now seamlessly leave one convoy and create or join another within seconds directly from the UI.
4. **Adherence to AWS Decoupled Architecture**: MQTT topic subscriptions (`groupnav/packs/{packId}/#`) are ephemeral and tie to the session room, whereas IAM credentials from Cognito Identity Pool tie to the rider's identity.

---

## 4. Verification Evidence

### 4.1 Unit Test Suite
Ran full test suite in `mobile/test`:
```powershell
C:\flutter\bin\flutter.bat test
```
**Result**:
- **49/49 passed (100% pass rate)**.
- New dedicated tests verified:
  - `leavePack sets isInPack to false and clears packCode` (Verified)
  - `joinPack sets isInPack to true and updates packCode` (Verified)
  - `createPack generates a new room and assigns user as Convoy Lead` (Verified)
  - `disbandConvoy deactivates sync and retains only leader` (Verified)

### 4.2 Static Code Analysis
Ran Flutter analyzer:
```powershell
C:\flutter\bin\flutter.bat analyze
```
**Result**:
```
Analyzing mobile...
No issues found! (ran in 4.5s)
```
