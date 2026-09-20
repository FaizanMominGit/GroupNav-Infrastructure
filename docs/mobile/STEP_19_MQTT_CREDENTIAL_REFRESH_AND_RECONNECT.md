# Step 19: MQTT Credential Refresh & Reconnect Fix

## 1. How It Was Done

### Root Cause Identified
The AWS IoT Core MQTT WebSocket connection was silently failing on every app restart after the initial session. The logs showed `MqttConnectionKeepAlive::pingRequired - NOT sending ping - not connected` in a constant loop with no attempt to reconnect.

**Root Cause**: AWS Cognito Identity Pool temporary STS credentials (AccessKeyId, SecretKey, SessionToken) expire after **1 hour**. When the app was relaunched, `checkSavedSession()` restored the cached credentials from FlutterSecureStorage without checking or refreshing them. The expired credentials were used to generate a pre-signed WebSocket URL (SigV4), which AWS IoT Core rejected with a 403 handshake failure — swallowed silently by the MQTT library's connection state machine.

**Secondary Root Cause**: MQTT WebSocket port was set to `0` instead of `443`. AWS IoT Core Data-ATS endpoint requires WSS on port 443. Port 0 is not a valid TCP port and caused the underlying socket to fail before even reaching the SigV4 check.

### Fixes Applied

**A. Refresh Token Persistence** — `cognito_auth_service.dart`
- Added `_keyRefreshToken = 'groupnav_refresh_token'` storage key.
- During sign-in, the Cognito `RefreshToken` is extracted from `AuthenticationResult` and persisted to secure storage.
- Sign-out now also deletes the stored refresh token.

**B. Credential Expiry Check** — `cognito_auth_service.dart`
- Added `areCredentialsExpired(creds)` method: parses the `Expiration` timestamp from stored creds with a 5-minute buffer before actual expiry.

**C. Silent Credential Refresh** — `cognito_auth_service.dart`
- Added `refreshAwsCredentials()` method performing a full silent token exchange:
  1. Reads stored RefreshToken from secure storage.
  2. Calls `InitiateAuth(REFRESH_TOKEN_AUTH)` → Cognito User Pool → new IdToken.
  3. Uses cached `cognitoIdentityId` from stored pilot profile (falls back to `GetId` call).
  4. Calls `GetCredentialsForIdentity` on Identity Pool with the new IdToken.
  5. Persists fresh credentials and updated IdToken to secure storage.

**D. Auto-Refresh on Session Restore** — `auth_provider.dart`
- `checkSavedSession()` now: restores pilot → reads cached creds → calls `areCredentialsExpired()` → if expired, calls `refreshAwsCredentials()` → updates auth state with fresh credentials.
- `flutter/foundation.dart` imported for `debugPrint`.

**E. MQTT Port Fixed to 443** — `iot_telemetry_service.dart`
- `MqttServerClient.withPort(presignedUrl, clientId, 443)` — set to 443 (WSS standard).
- `client.port = 443` — applied to the client instance.

**F. Improved MQTT Connection Logging** — `iot_telemetry_service.dart`
- Logs endpoint and connection intent before attempting connect.
- Logs `status?.state` after connect attempt regardless of outcome.
- Logs full stack trace on exceptions.
- Guards against empty credentials.

## 2. Why It Was Done This Way

**Refresh Token over Re-Login**: Forcing re-login every hour would disrupt multi-hour convoy rides. The Cognito RefreshToken is valid for 30 days by default, making silent refresh a far superior UX.

**Port 443 not 0**: AWS IoT Core Data-ATS WSS endpoint uses port 443. The mqtt_client library does not interpret port 0 as "use URL default" — it requires an explicit port. Port 0 caused the TCP socket to fail before any HTTP upgrade handshake.

**5-Minute Buffer**: Accounts for device clock drift and the time lag between session restore and MQTT connect. Ensures credentials don't expire mid-session.

**Silent Failure Mode**: When `refreshAwsCredentials()` fails (e.g., 30-day refresh token expiry), auth state is still set as authenticated. MQTT simply won't connect. Future work will surface this gracefully.

## 3. Verification Evidence

- `flutter analyze` → **No issues found! (ran in 43.7s)**
- Fresh APK built and deployed to device FMONBICQHMLVBAWW.
- On app restart after >1 hour: `[AuthNotifier] Credentials refreshed successfully` appears in logcat.
- MQTT connection: `[IotTelemetryService] AWS IoT Core MQTT connected successfully.` appears immediately after session restore.
