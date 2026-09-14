# Step 3: AuthStack Implementation (Cognito User & Identity Pools, Location Service & Scoped IAM)
> **Phase**: Phase 1 — Network, Identity & Location Foundation  
> **Milestone**: Step 3 — AuthStack Implementation & Secure Client Unblocking  
> **Timestamp**: 2026-09-14  
> **Status**: Verified & Ready for Deployment

---

## 1. How It Was Done

### 1.1 Cognito User Pool for Rider Authentication
In [lib/auth-stack.ts](file:///c:/Users/faizan/Downloads/AWS/lib/auth-stack.ts), we implemented a dedicated rider authentication store:
- **Identity & Sign-in**: Configured for email-based login (`UsernameAttributes: ['email']`) with self-registration enabled so mobile users can create accounts freely.
- **Verification & Security**: Email auto-verification is enforced (`autoVerify: { email: true }`). Password complexity requires at least 8 characters, with lowercase, uppercase, and digits.
- **Account Recovery**: Restricted to email delivery only (`EMAIL_ONLY`) to prevent SMS fee traps.
- **Lifecycle Management**: Configured with `DESTROY` removal policy for rapid iterative development.

### 1.2 User Pool Client Tailored for Mobile (Flutter)
We provisioned a dedicated application client for the Flutter mobile application:
- **Zero Client Secret (`generateSecret: false`)**: Mobile applications run on client devices where embedded secrets can be decompiled and compromised. Disabling the secret allows native mobile authentication via AWS Amplify / Cognito SDKs.
- **Authentication Flows**: Enabled `USER_PASSWORD_AUTH` and `USER_SRP_AUTH` (Secure Remote Password protocol) alongside refresh token rotation.
- **User Enumeration Defense**: Enabled `PreventUserExistenceErrors` so authentication errors do not reveal whether a given email exists in the system.

### 1.3 Cognito Identity Pool (Federated AWS Authorization)
To allow mobile clients to interact directly with AWS services without routing heavy map traffic through backend API proxies, we created an Identity Pool:
- **Federation Link**: Coupled directly to the User Pool and App Client as an authentication provider.
- **Strict Access Boundary (`allowUnauthenticatedIdentities: false`)**: Guest/anonymous identities are completely blocked. Callers must possess a valid, signed Cognito ID token.

### 1.4 Amazon Location Service (Map & Geofence Collection)
We established the real-time mapping infrastructure:
- **Vector Map (`GroupNavMap`)**: Configured with `VectorEsriNavigation` style, optimized for mobile navigation rendering.
- **Geofence Collection (`GroupNavGeofenceCollection`)**: Dedicated geofence boundary storage for tracking rider cluster proximity and boundary entry/exit events.

### 1.5 Scoped Zero-Trust IAM Policies for Riders
We created the `GroupNav-Cognito-Authenticated-Role` assumed via Web Identity Federation (`cognito-identity.amazonaws.com` STS assume-role). Attached policies enforce the principle of least privilege:
- **Location Service Policy**:
  - Granted: `geo:GetMapTile`, `geo:GetMapSprites`, `geo:GetMapGlyphs`, `geo:GetMapStyleDescriptor` on the Map ARN.
  - Granted: `geo:BatchEvaluateGeofences` on the Geofence Collection ARN.
  - Denied / Excluded: All administrative actions (no `geo:Create*`, `geo:Delete*`, `geo:Update*`).
- **IoT Core Telemetry Policy**:
  - Implemented dynamic policy variables so riders can **only connect with their own client ID** (`${cognito-identity.amazonaws.com:sub}`).
  - Scoped publish permissions strictly to the rider's private topic (`groupnav/${cognito-identity.amazonaws.com:sub}/telemetry`). Riders cannot eavesdrop or publish on behalf of other riders.

### 1.6 Client Configuration Outputs
Published comprehensive `CfnOutput` parameters (`UserPoolId`, `UserPoolClientId`, `IdentityPoolId`, `CognitoRegion`, `MapName`, `MapArn`, `GeofenceCollectionName`, `GeofenceCollectionArn`, `AuthenticatedRoleArn`) ready for consumption by client configuration generators.

---

## 2. Why It Was Done This Way

### 2.1 Unblocking Mobile Clients Without Backend Dependency
- Traditional backend architectures route all client traffic (map tiles, live location telemetry) through custom reverse proxies or API Gateway endpoints.
- This creates two bottlenecks: (1) heavy data processing costs on API Gateway/Lambda for static map tiles, and (2) mobile developers remain blocked until the backend team finishes building compute and ingestion layers.
- By issuing temporary AWS credentials via Cognito Identity Pool with scoped IAM policies, mobile clients talk directly to Amazon Location Service and AWS IoT Core. The mobile team can begin map rendering and rider UI integration immediately.

### 2.2 Why Mobile App Clients Must Not Have a Secret
- In web server-side applications (Node.js/Next.js/Django), client secrets remain securely stored in server environment variables.
- In mobile native apps (Flutter APK / iOS IPA), any client secret compiled into the binary can be extracted via reverse engineering tools. AWS Cognito strictly enforces public clients for native mobile apps by disabling secrets and requiring SRP-based authentication.

### 2.3 Identity-Scoped IoT Isolation
- Section 5.1 of the infrastructure plan mandates identity-scoped MQTT topics:
  `groupnav/${cognito-identity.amazonaws.com:sub}/telemetry`
- By binding IoT Core publish permissions to the STS-injected `${cognito-identity.amazonaws.com:sub}` variable, authorization is enforced at the AWS hypervisor/broker level. Even if a malicious user alters the client code, AWS IoT Core drops any packet directed outside the rider's personal topic.

---

## 3. Verification Evidence

### 3.1 Automated Jest Unit Tests
We implemented 8 granular assertion tests in [test/auth-stack.test.ts](file:///c:/Users/faizan/Downloads/AWS/test/auth-stack.test.ts):
1. Cognito User Pool exists with email auto-verification and password policy.
2. User Pool Client exists with secret generation disabled and SRP auth flows.
3. Identity Pool rejects unauthenticated guests and links to User Pool.
4. Amazon Location Service Map and Geofence Collection exist.
5. Authenticated IAM Role is assumed via Web Identity Federation with proper audience condition.
6. Location Service policy is scoped exclusively to map tile retrieval and geofence evaluation.
7. IoT Core policy is scoped per-rider using identity variables.
8. Decoupled outputs are published.

**Test Run Output:**
```bash
npm test
```
```
PASS test/auth-stack.test.ts (9.465 s)
PASS test/network-stack.test.ts (9.745 s)

Test Suites: 2 passed, 2 total
Tests:       15 passed, 15 total
Snapshots:   0 total
Time:        10.037 s
```

### 3.2 CloudFormation Synthesis Validation
Executed `npx cdk synth AuthStack` and `npx cdk synth`:
- Validated clean synthesis of Cognito User Pool, Client, Identity Pool, Map, Geofence Collection, Roles, Policies, and Outputs with zero warnings and zero circular dependencies.
