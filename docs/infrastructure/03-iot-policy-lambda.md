# AWS IoT Core Policy Dynamic Attachment

## 1. How It Was Done
- Created a standard AWS Lambda function (`lambda/attach-iot-policy/index.mjs`) using Node.js 20 runtime. It utilizes `@aws-sdk/client-iot` to invoke the `AttachPrincipalPolicyCommand`.
- The Lambda extracts the `cognitoIdentityId` from the incoming API Gateway request context (`event.requestContext.identity.cognitoIdentityId`).
- A REST API Gateway (`GroupNav IoT Policy API`) was set up in `AuthStack` to expose a `/attach-policy` POST endpoint.
- The endpoint is secured with IAM Authorization (`authorizationType: apigateway.AuthorizationType.IAM`), meaning only authenticated AWS requests containing a valid Signature V4 header can invoke it.
- The CDK was updated to deploy these resources and output the resulting endpoint URL, which was subsequently configured in the mobile app's `client-config.json`.
- The existing IoT policy was renamed to `GroupNav-Rider-IoT-Access` in the CDK to resolve an `AlreadyExists` cloudformation conflict with a manually-created debug policy.

## 2. Why It Was Done This Way
- **Requirement for Connection**: AWS IoT Core enforces that Cognito Identities (even when mapped to an IAM Role) must explicitly have an IoT Policy attached to their specific Principal ID before they can connect via MQTT over WebSockets. Failure to do so results in silent TCP disconnects and HTTP 403 Forbidden errors.
- **Why API Gateway + Lambda**: Cognito does not automatically attach IoT policies to new users when they sign up. The most secure architectural pattern for dynamic attachment is routing the client through an IAM-secured API Gateway proxying to a Lambda function which has the `iot:AttachPrincipalPolicy` permission.
- **Why IAM Auth**: Since the client has temporary AWS credentials obtained from the Cognito Identity Pool, SigV4 signing the request allows API Gateway to inherently validate the caller and inject the user's secure Cognito Identity ID into the proxy event, preventing spoofing and removing the need for a custom authorizer or JWT validation.

## 3. Verification Evidence
- Successfully deployed `AuthStack` containing the API Gateway and Lambda (Deployment Time: ~61s).
- Obtained the API Gateway Endpoint: `https://j9tlu1hzc7.execute-api.ap-south-1.amazonaws.com/prod/`.
- Confirmed the Lambda code was bundled natively without needing a `package.json` since `@aws-sdk/client-iot` is included in the AWS Lambda runtime for Node 20.x.
- Mobile client configuration successfully updated.

