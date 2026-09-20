# Mobile SigV4 Signing & Dynamic Policy Attachment

## 1. How It Was Done
- The `AwsSigV4Signer` class (`aws_sigv4_signer.dart`) already supported standard HTTP request signing via the `signRestRequest` method, which injects standard `AWS4-HMAC-SHA256` headers (Authorization, X-Amz-Date, Host). 
- A new `IotPolicyService` was created in `lib/features/auth/services/iot_policy_service.dart`. This service accepts the `apiEndpoint` and temporary AWS credentials and invokes the API Gateway POST endpoint (`/attach-policy`) using the SigV4 signer to authenticate the request.
- The `CognitoAuthService` (`cognito_auth_service.dart`) was updated inside the `signIn` workflow. Immediately after successfully exchanging the Cognito ID Token for AWS temporary STS credentials from the Identity Pool, the app instantiates `IotPolicyService` and invokes `attachPolicy`.
- The `client-config.json` configuration file was updated with the new `attachPolicyApiEndpoint`.

## 2. Why It Was Done This Way
- **SigV4 for IAM Auth**: API Gateway requires Signature Version 4 for IAM authentication. Using the built-in SigV4 class allows the mobile client to securely invoke the API using its temporary STS session credentials without needing JWTs or complex custom authorizers in API Gateway.
- **Workflow Hook**: Calling `attachPolicy` seamlessly inside the `signIn` method right before returning ensures that any new user signing up or logging in for the first time gets their AWS IoT Core policy attached *before* the application attempts to establish the MQTT WebSocket connection in `IotTelemetryService`. Since `iot:AttachPrincipalPolicy` is idempotent, subsequent logins safely re-attach the existing policy with no side effects.

## 3. Verification Evidence
- Verified that `IotPolicyService.attachPolicy()` receives the correct endpoint and credentials, formats an empty JSON payload, signs the request using `_signer.signRestRequest`, and executes a standard HTTP POST.
- Awaiting final end-to-end testing with a new user from the emulator, but all SigV4 mechanics match standard AWS specifications.
