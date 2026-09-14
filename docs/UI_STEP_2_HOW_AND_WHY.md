# UI Milestone 2: Pilot Authentication & Onboarding Screen (`/auth`)

> **Phase:** UI Phase 2 — Authentication, Vehicle Staging & AWS Cognito Identity Integration  
> **Status:** Verified & Complete  
> **Target Platform:** Flutter (Mobile Android/iOS & Web)  
> **Mockup Reference:** [`auth_onboarding_auth/code.html`](file:///d:/chirag/GroupNav-Infrastructure/scratch/stitch_groupnav_web3_convoy_tracker/auth_onboarding_auth/code.html)  
> **Workspace Location:** `mobile/lib/features/auth/`  

---

## 1. How It Was Done

### 1.1 Pilot Authentication & Onboarding Screen (`AuthOnboardingScreen`)
- Built the full visual composition matching `auth_onboarding_auth/code.html`:
  - **Vector Map Backdrop (Layer Z-0):** Ambient dark canvas (`#0D1117`) rendered with a custom painter displaying vector grid street lines and glowing route curves.
  - **Spatial Top App Bar (Layer Z-20):** Floating 52px header showing the "GroupNav DePIN" moniker, live node status indicator (`NODE 01`, `99.8%`), and token reward pool ticker (`+4.2 NAV/hr`).
  - **Pilot Authentication Card (Layer Z-30):** High-elevation floating card featuring an "AWS Cognito Connected" status badge, phone/email input, tactical callsign tag (e.g. `0xApex`), and a tactile "Continue with OTP" action button.
  - **Identity Setup Staging Card:** Integrated 2x2 grid for vehicle classification and a 4-swatch circular picker for HUD beacon colors.
  - **DePIN Reward Pool Banner:** Docked footer card with animated pulse indicator.

### 1.2 Interactive Vehicle Class & Beacon Color Selectors
- **`VehicleClassSelector` (`mobile/lib/features/auth/widgets/vehicle_class_selector.dart`)**:
  - Modular 2x2 grid widget supporting **Sportbike** (active default), **Adventure**, **Touring**, and **Cruiser**.
  - Displays vehicle category iconography, active electric blue container fills, and selection checkmarks.
- **`BeaconColorPicker` (`mobile/lib/features/auth/widgets/beacon_color_picker.dart`)**:
  - Color swatches for **Cyan** (`#00D4FF`), **Electric Blue** (`#0066FF`), **Amber** (`#FF9500`), and **Emerald** (`#00C48C`).
  - Active swatch elevates with an offset glow ring and checkmark.

### 1.3 6-Digit OTP Verification Modal (`OtpVerificationDialog`)
- Elevated dialog (Layer Z-50) appearing over a semi-transparent backdrop (`Colors.black54`) when `AuthState.isOtpPending` is true:
  - 6 individual split numeric cells with auto-advancing and backspacing focus node management.
  - Active cell highlighting with primary border and tabular telemetry typography.
  - Masked destination indicator displaying the pilot's phone/email.
  - Resend countdown timer (45 seconds ticker) with auto-disabling resend action.
  - "Verify & Connect Fleet" submission CTA with progress indicator state.
  - Footer displaying the active Cognito Session ID.

### 1.4 AWS Cognito & STS Credentials Integration
- **`CognitoAuthService` (`mobile/lib/features/auth/services/cognito_auth_service.dart`)**:
  - Implemented direct REST communication with AWS Cognito Identity Provider (`https://cognito-idp.ap-south-1.amazonaws.com`) and Cognito Identity Pool (`https://cognito-identity.ap-south-1.amazonaws.com`).
  - Dispatches `InitiateAuth` (`CUSTOM_AUTH`) to trigger SMS OTP delivery.
  - Dispatches `RespondToAuthChallenge` with the 6-digit OTP code to validate the challenge and obtain Cognito JWT tokens (`IdToken`, `AccessToken`).
  - Calls `GetId` and `GetCredentialsForIdentity` on the Identity Pool (`ap-south-1:0efa5668-5ed9-4ee6-9120-86f8cc2ae4cd`) to exchange the JWT for short-lived **AWS STS IAM Credentials** (`AccessKeyId`, `SecretKey`, `SessionToken`).
  - Abstracted storage access behind an `AuthStorage` interface (`SecureAuthStorage` using `FlutterSecureStorage` for production hardware keystore, and `MemoryAuthStorage` for headless unit tests).
- **`AuthNotifier` (`mobile/lib/features/auth/providers/auth_provider.dart`)**:
  - Riverpod `StateNotifier` managing reactive login state, vehicle class updates, beacon color updates, countdown intervals, and session restoration on app boot.

### 1.5 Main Shell Auth Gating
- Updated `MainShellScreen` (`mobile/lib/features/shell/main_shell_screen.dart`):
  - Injected auth state guard: unauthenticated users are presented with `AuthOnboardingScreen`.
  - Once authenticated, transitions directly into the 4-destination convoy radar dashboard, displaying the pilot's callsign and vehicle class on the header and radar canvas.
  - Integrated "Sign Out of Cognito Session" button on the Settings tab to purge stored credentials and return to onboarding.

---

## 2. Why It Was Done This Way

### 2.1 Direct REST Integration vs Heavyweight Native SDKs
- **Decision:** Communicate directly with AWS Cognito endpoints over HTTP REST rather than pulling in monolithic native plugins.
- **Rationale:** Avoids native Android Gradle dependency deadlocks and CocoaPods compilation issues. Provides clean, deterministic behavior across mobile and web targets, while still storing resulting AWS STS credentials securely in device hardware keystores.

### 2.2 AuthStorage Abstraction
- **Decision:** Introduce the `AuthStorage` contract decoupling `CognitoAuthService` from direct `FlutterSecureStorage` platform channels.
- **Rationale:** Platform channels require a running native host or mock binary messenger. Decoupling storage allows unit and integration tests to run headlessly in CI without mocking platform channels, while production builds continue using the device Keychain / EncryptedSharedPreferences.

### 2.3 Auto-Advancing OTP Focus Architecture
- **Decision:** Manage individual `TextEditingController` and `FocusNode` instances for each of the 6 digits.
- **Rationale:** Riders wearing motorcycling gloves or operating in high-vibration vehicle mounts need unambiguous, tactile visual feedback for each entered digit without navigating soft keyboard cursors.

---

## 3. Verification Evidence

### 3.1 Unit Test Execution (`test/auth_test.dart` and `test/config_test.dart`)
- **Command:** `flutter test`
- **Output:**
  ```
  00:00 +0: loading test/auth_test.dart
  00:00 +0: PilotProfile Unit Tests Serializes to JSON and from JSON accurately
  00:00 +1: PilotProfile Unit Tests copyWith updates fields without mutating original
  00:00 +2: AuthState Unit Tests Default AuthState is unauthenticated
  00:00 +3: AuthState Unit Tests Authenticated state flags active pilot
  00:00 +4: AuthNotifier & CognitoAuthService Flow Request OTP transitions state to otpPending
  00:00 +5: ClientConfig parses client-config.json accurately
  00:00 +6: All tests passed!
  ```

### 3.2 Static Code Analysis
- **Command:** `flutter analyze`
- **Output:** `No issues found! (ran in 14.1s)`
