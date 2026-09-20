# Step 20: AWS IoT Core Authorization Fix — Two-Layer Auth for Cognito + IoT Core

## 1. How It Was Done

### Root Cause Discovery

AWS IoT Core MQTT over WebSocket (SigV4) with Cognito Identity Pool enforces **two independent authorization gates**:

| Gate | What it checks | Where configured |
|---|---|---|
| **Gate 1: IAM** | Does the Cognito assumed role IAM policy allow iot:Connect, iot:Publish, etc.? | IAM inline policy on the authenticated role |
| **Gate 2: IoT Core Resource Policy** | Is there an IoT Core policy attached to this Cognito principal? | aws iot attach-policy — attached to Cognito Identity ID |

The project had Gate 1 deployed correctly (`GroupNav-Rider-IoT-Telemetry` inline IAM policy) but Gate 2 was completely missing. This caused AWS IoT Core to accept the WebSocket upgrade (HTTP 101), receive the MQTT CONNECT packet, but then **silently close the connection** with no CONNACK.

### How We Discovered This

**CloudWatch IoT Logs** (log group: `AWSIotLogsV2`) revealed:

```json
{
  "timestamp": "2026-09-19 19:19:13.620",
  "logLevel": "ERROR",
  "status": "Failure",
  "eventType": "Connect",
  "clientId": "groupnav_pilot_1789845552388",
  "principalId": "AROAUXPRTYZAUZGM2OSF6:CognitoIdentityCredentials",
  "reason": "AUTHORIZATION_FAILURE",
  "details": "Authorization Failure"
}
```

The Role ID `AROAUXPRTYZAUZGM2OSF6` matches `GroupNav-Cognito-Authenticated-Role` (confirmed via `aws iam get-role`).

### Fix Applied

**1. Enabled IoT Core DEBUG CloudWatch logging:**
```bash
aws iot set-v2-logging-options \
  --role-arn "arn:aws:iam::325313611329:role/GroupNav-IoT-CloudWatch-Logging-Role" \
  --default-log-level DEBUG
```

**2. Created IoT Core resource policy via CLI:**
```bash
aws iot create-policy \
  --policy-name "GroupNav-Rider-IoT-Core-Access" \
  --policy-document '{ "Version":"2012-10-17","Statement":[
    {"Effect":"Allow","Action":"iot:Connect","Resource":"arn:aws:iot:ap-south-1:325313611329:client/*"},
    {"Effect":"Allow","Action":["iot:Publish","iot:Receive"],"Resource":"arn:aws:iot:ap-south-1:325313611329:topic/groupnav/*"},
    {"Effect":"Allow","Action":"iot:Subscribe","Resource":"arn:aws:iot:ap-south-1:325313611329:topicfilter/groupnav/*"}
  ]}'
```

**3. Attached policy to Identity Pool (pool-level):**
```bash
aws iot attach-policy \
  --policy-name "GroupNav-Rider-IoT-Core-Access" \
  --target "ap-south-1:0efa5668-5ed9-4ee6-9120-86f8cc2ae4cd"
```

**4. Attached policy to all 9 individual Cognito identities** (required for Enhanced Auth Flow authenticated users):
```powershell
@("ap-south-1:4bbe33c6-4137-...", ...) | ForEach-Object {
  aws iot attach-policy --policy-name "GroupNav-Rider-IoT-Core-Access" --target $_
}
```

**5. Added `iot.CfnPolicy` to CDK `auth-stack.ts`** for IaC consistency (lines 290-312).

---

## 2. Why It Was Done This Way

### The Two-Gate Architecture

AWS IoT Core maintains its own authorization system separate from IAM. The IAM check determines whether the *role* can call IoT API endpoints. The IoT Core policy check determines whether the *device* can perform MQTT operations. Both must pass independently.

### Why CONNACK Was Silent

AWS IoT Core completes the WebSocket handshake before MQTT authorization. On failure, it closes the connection without CONNACK — by design, to avoid leaking auth failure details to unauthorized clients.

### Pool-Level vs. Per-Identity Attachment

- **Pool-level target**: Covers unauthenticated identities from the pool
- **Per-identity target**: Required for authenticated identities in Enhanced Auth Flow

New users need the policy attached at registration time — this should be handled by a **Cognito Post-Authentication Lambda trigger** (future work — see Pending).

### CDK Limitation

CDK can declare the `CfnPolicy` resource, but cannot call `attach-policy` to runtime Cognito identity IDs. A Lambda trigger is the correct automation path.

---

## 3. Verification Evidence

### Pre-Fix: CloudWatch confirmed AUTHORIZATION_FAILURE (2026-09-19)

```
principalId: AROAUXPRTYZAUZGM2OSF6:CognitoIdentityCredentials
reason:      AUTHORIZATION_FAILURE
```

### Policy deployment confirmed:
```
aws iot list-attached-policies --target "ap-south-1:0efa5668-5ed9-4ee6-9120-86f8cc2ae4cd"
? GroupNav-Rider-IoT-Core-Access listed ?
```

### Post-Fix Test: PENDING (device offline during fix window)

---

## 4. Pending Work

### Immediate
- [ ] Reconnect device, run app, verify CONNACK received in Flutter debug logs
- [ ] Check CloudWatch AWSIotLogsV2 — expect Connect: Success (not AUTHORIZATION_FAILURE)

### Short-Term
- [ ] Implement Cognito Post-Authentication Lambda: auto-call `aws iot attach-policy` for every new user at sign-up

### CDK Deployment
- [ ] Run `cdk deploy AuthStack` to reconcile the iot.CfnPolicy resource into the deployed stack
