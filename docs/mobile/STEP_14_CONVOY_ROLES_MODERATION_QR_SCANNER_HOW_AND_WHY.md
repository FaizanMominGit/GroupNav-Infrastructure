# Step 14: Convoy Hierarchy, Moderation, Universal Share Links & Optical QR Scanner

## Overview
This document records the design, engineering mechanics, architectural tradeoffs, and verification evidence for Step 14 of the GroupNav mobile client. This milestone completes Section 2 (Convoy & Pack Management) in `APP_FEATURES.md`, delivering full tactical pack hierarchy (Road Captain, Tail Gunner / Sweeper, Pack Members), host moderation controls (locking convoy rooms, ejecting disruptive riders, and dissolving rooms), universal deep share links (`https://groupnav.app/join/GN-XXXX`), and an optical camera QR scanner with targeting reticle and headless test simulation.

---

## 1. How It Was Done

### 1.1 Tactical Pack Roles & Dynamic Hierarchy
- **Role Model**: Extended `PackMember` with a strongly-typed `PackRole` enum (`roadCaptain`, `tailGunner`, `packMember`).
- **Tactical Visual Design**:
  - **Road Captain**: Gold badge with star icon (`#EAB308`), designating the convoy leader and room host.
  - **Tail Gunner (Sweeper)**: Emerald badge with shield icon (`AppColors.telemetryEmerald`), representing the safety rear-guard rider responsible for keeping track of stragglers.
  - **Pack Member**: Route cyan badge with bike icon (`AppColors.primary`), representing standard convoy riders.
- **Dynamic Hierarchy Evaluation**: Added `isCaptain(riderId)` on `PackFormation`, dynamically verifying whether the active pilot is the original host (`hostRiderId`) or currently holds the Road Captain designation.

### 1.2 Pack Moderation & Room Lifecycle Controls
- **Convoy Room Locking (`isLocked`)**:
  - Added a boolean attribute `isLocked` on the DynamoDB pack item.
  - When active, `joinPack` calls on AWS DynamoDB are intercepted and rejected with an explicit error: `"Convoy room 'GN-XXXX' is locked by the Road Captain. New entries are restricted."`
  - Road Captains can toggle room lock status live via an adaptive tactical toggle switch in the UI.
- **Rider Ejection (Kick Member)**:
  - Enabled Road Captains to remove unruly or lagging riders from the convoy roster via a contextual pop-up menu.
  - Kicking a member invokes an atomic DynamoDB `UpdateItem` with `SET #members = :filteredList, #updatedAt = :now`, causing the removed rider's app to detach upon next polling sync.
- **Convoy Disbandment**:
  - Implemented `disbandConvoy()` allowing Road Captains to terminate the room session for all participants.
  - Sets `#status = :disbanded` and clears active members in DynamoDB, then gracefully transitions the captain's device back to Solo Ride Mode.

### 1.3 Universal Deep Share Links
- **Universal Share Link Format**: Configured `PackFormation.shareLink` generating standard HTTPS URLs formatted as `https://groupnav.app/join/GN-XXXX`.
- **One-Tap Share & Copy**: Added a quick "Share" button to `ActiveCodeCard` alongside "Copy" and "Pair QR", copying the direct link to the clipboard and triggering a confirmation SnackBar toast.

### 1.4 Decoupled Optical Camera QR Scanner
- **Contract Decoupling (`IQrScannerService`)**:
  - Defined an abstract scanner interface with `parseQrPayload(String raw)` and `simulateScan(String code)`.
  - Implemented `ProductionQrScannerService` supporting deep link URLs (`https://groupnav.app/join/GN-XXXX`), JSON pairing manifests (`{"action":"join_pack","code":"GN-XXXX"}`), and direct alphanumeric codes (`GN-XXXX`, `PACK-XXXX`, or bare numbers).
  - Provided `MockQrScannerService` for deterministic mock injection during testing.
- **Tactical Scanner UI Modal (`CameraQrScannerModal`)**:
  - Designed an overlay featuring an animated scanning laser line (oscillating via an `AnimationController`), corner viewfinder reticle brackets, flashlight toggle, and a manual code / clipboard paste fallback for testing and low-light environments.

---

## 2. Why It Was Done This Way

### 2.1 Decoupling Hardware Scanning from Decoding Logic
- **The Problem**: Accessing physical camera hardware in headless automated test runners or desktop simulator environments fails immediately with `MissingPluginException` or channel timeouts.
- **The Architectural Solution**: By isolating the parser logic inside `IQrScannerService` and providing fallback manual input within `CameraQrScannerModal`, 100% of the UI widgets, animation loops, and pairing flows can be tested headlessly while native device cameras work seamlessly when running on mobile.

### 2.2 Atomic DynamoDB Roster Updates
- **The Problem**: Concurrency collisions when multiple riders join, update roles, or leave simultaneously can corrupt pack rosters if handled naively.
- **The Architectural Solution**: AWS DynamoDB `UpdateItem` is called with atomic list append (`list_append(if_not_exists(#members, :empty_list), :new_member)`) for joins, and conditional replacement with updated timestamp `#updatedAt` for moderation actions. This guarantees that role promotions and kicks propagate consistently within the 8-second polling window.

### 2.3 Role Badges for Group Riding Safety
- **The Rationale**: Motorcycle group rides strictly adhere to the Lead / Sweeper discipline for rider safety. If the Sweeper drops off or lags behind, the entire pack must know immediately. Explicit gold and emerald badges provide instant situational awareness at a single glance on handlebar mounts.

---

## 3. Verification Evidence

### 3.1 Automated Test Execution
Executed the complete automated test suite across all mobile unit and widget tests:
```powershell
flutter test
```
**Output**:
```
00:03 +99: All tests passed!
```
- Total test suites passed: **99/99** (including 25 tests in `pack_test.dart`).

### 3.2 Static Analysis
Executed Flutter analyzer across all code in `mobile/`:
```powershell
flutter analyze
```
**Output**:
```
Analyzing mobile...
No issues found! (ran in 3.5s)
```

### 3.3 Tested Scenarios & Coverage
1. **Role Attribution**: Validated Road Captain, Tail Gunner, and Pack Member getters, labels, and badge colors.
2. **Universal Share Links**: Validated deep link construction (`https://groupnav.app/join/GN-4921`) and captain permissions.
3. **Payload Parsing**: Validated `ProductionQrScannerService` across URLs, JSON packets, `PACK-` prefixes, and raw numeric inputs.
4. **Moderation UI**: Tested `PackRosterCard` moderation popup (assigning Tail Gunner, kicking riders) and `ActiveCodeCard` room lock toggle.
5. **Optical Scanner UI**: Tested `CameraQrScannerModal` rendering, reticle drawing, and flashlight toggling.
