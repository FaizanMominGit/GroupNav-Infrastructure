# Step 11: Pilot Password Reset & Recovery (AWS Cognito Email OTP & Password Update)

## Overview
This milestone delivers the complete, self-service **Password Reset & Recovery** flow for GroupNav pilots. Built directly on native AWS Cognito Identity Provider endpoints (`AWSCognitoIdentityProviderService.ForgotPassword` and `AWSCognitoIdentityProviderService.ConfirmForgotPassword`), this capability enables riders to securely recover forgotten account access via encrypted 6-digit email confirmation codes and update their credentials without third-party proxy dependencies.

---

## 1. How It Was Done

### Technical Breakdown & Mechanics

1. **Direct AWS Cognito Identity Provider API Integration (`CognitoAuthService`)**:
   - Implemented `forgotPassword({required String email})`:
     - Dispatches a signed HTTP POST to `https://cognito-idp.{region}.amazonaws.com/` targeting `AWSCognitoIdentityProviderService.ForgotPassword`.
     - Passes `ClientId` and normalized pilot `Username` (email).
     - Extracts and returns `CodeDeliveryDetails` containing the masked destination email (e.g. `p***@g***.io`) and delivery medium (`EMAIL`).
     - Defensive error parsing handles standard Cognito exception types (`UserNotFoundException`, `InvalidParameterException`, `LimitExceededException`).
   - Implemented `confirmForgotPassword({required String email, required String confirmationCode, required String newPassword})`:
     - Dispatches an HTTP POST targeting `AWSCognitoIdentityProviderService.ConfirmForgotPassword`.
     - Submits `ClientId`, `Username`, `ConfirmationCode` (6-digit OTP), and the updated `Password`.
     - Validates HTTP 200 acknowledgment from Cognito.
     - Maps security exceptions (`CodeMismatchException`, `ExpiredCodeException`, `InvalidPasswordException`) into user-friendly error banners.

2. **State Management & Cooldown Timer (`AuthNotifier` & `AuthState`)**:
   - Extended `AuthState` with recovery tracking fields:
     - `passwordResetDestination`: Masked destination address returned by Cognito for visual confirmation.
     - `isPasswordResetLoading`: Granular progress indicator flag for recovery network calls.
     - `passwordResetError`: Isolated error message channel for modal banner rendering.
     - `passwordResetSuccess`: Completion flag triggering the transition to the success confirmation view.
   - Built `sendPasswordResetCode(email)`:
     - Enforces client-side email format validation before initiating network requests.
     - Starts a 60-second cooldown timer preventing spam requests while displaying live remaining seconds (`Resend in 48s`).
   - Built `confirmPasswordReset({email, code, newPassword})`:
     - Enforces client-side validation: strict 6-digit OTP length and minimum 8-character password length.
     - Automatically synchronizes `_password` in local state upon successful reset so the pilot can sign in immediately.
   - Built `clearPasswordResetState()` using an immutable `AuthState.clearPasswordReset()` helper that cleanly wipes all transient recovery states without modifying pilot identity or tokens.

3. **Tactical Multi-Stage Recovery Modal (`ForgotPasswordDialog`)**:
   - Designed a responsive 3-stage dialog adhering to the Convoy Telemetry Design System:
     - **Stage 0 (Request Code)**:
       - Displays clear tactical instructions.
       - Pre-fills the pilot's email from the sign-in form.
       - Validates input and triggers code dispatch with loading states.
     - **Stage 1 (Verify & Set Password)**:
       - Renders an informative delivery destination chip (`Code sent to: p***@g***.io`).
       - Formats 6-digit confirmation code with wide letter spacing for glanceability.
       - Dual password inputs ("New Account Password" and "Confirm New Password") with independent visibility toggles.
       - Instant client-side match validation ("Passwords do not match").
       - Active resend button displaying real-time cooldown countdown.
     - **Stage 2 (Success)**:
       - High-visibility emerald success beacon.
       - One-tap "Proceed to Sign In" action that closes the modal, populates the login form with the new credentials, and displays a floating confirmation SnackBar.
   - Wrapped the dialog content in `SingleChildScrollView` to prevent keyboard or small-screen overflow on compact mobile displays.

4. **Sign-In Form Integration (`AuthOnboardingScreen`)**:
   - Positioned a clean "Forgot Password?" text button directly below the password input field when in "Sign In" mode.
   - Wired the button to launch `ForgotPasswordDialog` wrapped in a Riverpod `Consumer` for reactive state updates.
   - On password reset completion, automatically updates both `_emailController` and `_passwordController` and clears transient reset state.

---

## 2. Why It Was Done This Way

### Architectural Decisions & Tradeoffs

- **Direct Cognito Endpoints vs. Intermediate Backend Proxy**:
   - Rather than creating an intermediary Lambda/API Gateway route to invoke Cognito admin APIs, the mobile client communicates directly with Cognito's public client endpoints (`AWSCognitoIdentityProviderService`). This preserves Cognito's native rate limiting, leverages client ID scoping, eliminates API Gateway egress costs, and keeps client architecture aligned with GroupNav's decoupled philosophy.
- **Client-Side Validation Before Network Dispatch**:
   - Validating email syntax, 6-digit code length, and matching password confirmation before firing network requests prevents unnecessary AWS API calls and delivers instant UI feedback to the rider.
- **60-Second Resend Cooldown Guard**:
   - Automated resend timers safeguard against accidental multiple code requests, protecting pilots from hitting Cognito's `LimitExceededException` threshold.
- **Multi-Stage Modal vs. Separate Screen Routing**:
   - Maintaining the recovery flow inside a focused modal dialog preserves rider context. Upon reset completion, the rider remains on the onboarding screen with pre-filled credentials ready to authenticate, eliminating navigation disorientation.

---

## 3. Verification Evidence

### 1. Unit & Widget Test Suite Execution
- Ran `flutter test test/auth_test.dart` and `flutter test` across the full test suite.
- **Result**: All 77 tests passed (100% pass rate).
- **Test Coverage Added**:
  - `sendPasswordResetCode validates email format before calling service`
  - `sendPasswordResetCode initiates recovery and sets destination`
  - `sendPasswordResetCode records error when Cognito service throws`
  - `confirmPasswordReset validates code and password constraints`
  - `confirmPasswordReset succeeds and updates password in state`
  - `clearPasswordResetState resets transient password reset fields`
  - `ForgotPasswordDialog Widget Tests: Renders stage 0 and advances to stage 1 on code send`
  - `ForgotPasswordDialog Widget Tests: Renders stage 1 with destination and completes reset to stage 2`

### 2. Static Code Analysis
- Ran `flutter analyze` in `mobile/`.
- **Result**: `No issues found! (ran in 53.8s)`. Zero errors, zero warnings.
