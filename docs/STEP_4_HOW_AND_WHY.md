# Step 4: Cloud Deployment & Live AWS Verification
> **Phase**: Phase 1 — Network, Identity & Location Foundation  
> **Milestone**: Step 4 — Cloud Deployment, Live AWS Verification & Client Config Generation  
> **Timestamp**: 2026-09-14  
> **Status**: Verified & Live in AWS (`ap-south-1`)

---

## 1. How It Was Done

### 1.1 Coordinated Multi-Stack Cloud Deployment
Using AWS CDK, we deployed `NetworkStack` and `AuthStack` concurrently to AWS account `325313611329` in region `ap-south-1` (Mumbai):
- **Command Executed**: `npx cdk deploy NetworkStack AuthStack --require-approval never`
- **Deployment Lifecycle**:
  - Synthesized CloudFormation templates for both stacks.
  - Published Lambda asset bundles (for default security group restriction) to the CDK staging S3 bucket.
  - Created and executed CloudFormation change sets across both stacks without circular dependency errors.
  - Deployment completed in **129 seconds** total.

### 1.2 Provisioned AWS Cloud Resources
The deployment instantiated all foundational Phase 1 resources:
- **Networking (`NetworkStack`)**:
  - Virtual Private Cloud: `vpc-00344461b667c775b`
  - Compute Security Group: `sg-0652edc6f66a106c3`
  - Data Security Group: `sg-0919354b60c52b091`
  - Subnets: 2 Public (`subnet-05819044160ff84a6`, `subnet-0a7aaec6dd9c4280b`), 2 Private Compute (`subnet-09da142a33f841e76`, `subnet-0577e6ba5a6d03c15`), and 2 Isolated Data (`subnet-0b40b6140d28643f6`, `subnet-078da58d5e8a48ef9`).
  - Gateway VPC Endpoints: S3 Gateway Endpoint and DynamoDB Gateway Endpoint attached to all route tables.
  - Zero NAT Gateways provisioned.
- **Identity & Location (`AuthStack`)**:
  - Cognito User Pool: `ap-south-1_JoK8Zlj1x` (`GroupNav-Riders`)
  - Cognito User Pool Client: `4ko1153kp0hl7q7oa402cqiqfi` (`GroupNav-MobileClient`)
  - Cognito Identity Pool: `ap-south-1:0efa5668-5ed9-4ee6-9120-86f8cc2ae4cd`
  - Amazon Location Service Map: `GroupNavMap` (`VectorEsriNavigation`)
  - Amazon Location Service Geofence Collection: `GroupNavGeofenceCollection`
  - Authenticated IAM Role: `GroupNav-Cognito-Authenticated-Role`

### 1.3 Client Configuration Export
Per Section 6 of the infrastructure plan, we generated [client-config.json](file:///c:/Users/faizan/Downloads/AWS/client-config.json) containing all deployed resource identifiers and the AWS IoT Core ATS endpoint (`a362o0ub4ypzaj-ats.iot.ap-south-1.amazonaws.com`). This artifact serves as the single source of truth for the Flutter mobile engineering team, preventing configuration drift.

### 1.4 End-to-End Live Verification Pipeline
We created and executed an automated verification script ([scripts/verify-phase1.ts](file:///c:/Users/faizan/Downloads/AWS/scripts/verify-phase1.ts)) to test the entire client authentication and mapping pipeline live against AWS:
1. **User Registration**: Provisioned a dynamic rider user in the deployed Cognito User Pool.
2. **Account Confirmation**: Confirmed the rider's email registration via administrative API.
3. **Password Authentication**: Authenticated the rider using `USER_PASSWORD_AUTH` via the public mobile client and retrieved a valid Cognito `IdToken`.
4. **IAM Token Exchange**: Exchanged the `IdToken` with the Cognito Identity Pool (`GetId` + `GetCredentialsForIdentity`) to issue temporary AWS STS credentials (`ASIA...`).
5. **Signed Geospatial API Call**: Using exclusively the temporary rider credentials, made signed requests to Amazon Location Service:
   - Retrieved the complete Map Style Descriptor (`557,455` bytes).
   - Retrieved a raw Map Vector Tile (`z=0, x=0, y=0`, `422,187` bytes).
6. **Teardown**: Automatically removed the test rider identity to leave the production user pool pristine.

---

## 2. Why It Was Done This Way

### 2.1 Live In-Cloud Validation vs Mock Testing
- Unit tests and template synthesis prove that the CDK code generates valid CloudFormation syntax. However, unit tests cannot prove that Cognito User Pool trust policies, STS federation conditions, and Amazon Location Service IAM actions integrate seamlessly in the real cloud environment.
- By performing an end-to-end user authentication and map tile retrieval using live AWS STS credentials, we definitively proved that the Flutter mobile app can authenticate riders and render map tiles without any backend blocker.

### 2.2 Dynamic Automated Teardown
- Creating manual test accounts through the console leads to leftover test data that pollutes user pools and confuses metrics.
- The verification script dynamically generates a unique identity, tests the full flow, and immediately purges the test entity in a `finally` block, ensuring zero resource pollution.

### 2.3 Automated Client Configuration Delivery
- Copying Cognito Pool IDs and Map names manually into Flutter code leads to human errors, broken builds, and environment confusion.
- Exporting [client-config.json](file:///c:/Users/faizan/Downloads/AWS/client-config.json) automatically from stack outputs provides mobile engineers with immediate, machine-readable access to live infrastructure parameters.

---

## 3. Verification Evidence

### 3.1 Live Cloud Execution Log
Command executed:
```bash
npx tsx scripts/verify-phase1.ts
```

**Live Verification Output:**
```
====================================================
  GroupNav Phase 1: Live Cloud Verification
====================================================
Region: ap-south-1
User Pool: ap-south-1_JoK8Zlj1x
Client ID: 4ko1153kp0hl7q7oa402cqiqfi
Identity Pool: ap-south-1:0efa5668-5ed9-4ee6-9120-86f8cc2ae4cd
Map: GroupNavMap
----------------------------------------------------

[1/5] Registering test rider: verifier-...@groupnav.local...
  ✓ Registered successfully (UserSub: d1e3ddfa-5071-700c-0035-8c5c4df95fc4)

[2/5] Admin confirming rider sign-up...
  ✓ Rider confirmed

[3/5] Authenticating rider via USER_PASSWORD_AUTH...
  ✓ Authentication successful (Retrieved IdToken of length 1109)

[4/5] Exchanging IdToken for temporary AWS IAM credentials...
  ✓ Obtained Cognito Identity ID: ap-south-1:4bbe33c6-4187-c924-bc96-4a921380f381
  ✓ Temporary AWS Access Key ID: ASIA**************** (masked temporary STS credentials)
  ✓ Session Expiration: 2026-09-14T17:12:49+05:30

[5/5] Testing Amazon Location Service access with rider credentials...
  ✓ Successfully fetched Map Style Descriptor (557455 bytes)
  ✓ Successfully fetched Map Vector Tile at z=0, x=0, y=0 (422187 bytes)

====================================================
  VERIFICATION RESULT: ALL 5 PHASES PASSED 100%!
====================================================

[Cleanup] Deleting test rider from Cognito User Pool...
  ✓ Test user cleaned up.
```

### 3.2 CloudFormation Deployed Stack Confirmation
- `NetworkStack`: Status `CREATE_COMPLETE` (Stack ARN: `arn:aws:cloudformation:ap-south-1:325313611329:stack/NetworkStack/afb8a490-b028-11f1-a304-06e0761a62bb`)
- `AuthStack`: Status `CREATE_COMPLETE` (Stack ARN: `arn:aws:cloudformation:ap-south-1:325313611329:stack/AuthStack/8d848a10-b028-11f1-9e1c-0654f9670da7`)
