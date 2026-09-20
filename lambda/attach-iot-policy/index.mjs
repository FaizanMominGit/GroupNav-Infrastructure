import { IoTClient, AttachPolicyCommand } from "@aws-sdk/client-iot";

const iotClient = new IoTClient({});
const POLICY_NAME = process.env.IOT_POLICY_NAME || "GroupNav-Rider-IoT-Core-Access";

export const handler = async (event) => {
  console.log("Event:", JSON.stringify(event, null, 2));

  // Extract the Cognito Identity ID from the API Gateway request context
  const identityId = event.requestContext?.identity?.cognitoIdentityId;

  if (!identityId) {
    console.error("Missing cognitoIdentityId in requestContext");
    return {
      statusCode: 401,
      body: JSON.stringify({ message: "Unauthorized: Missing identity ID" }),
      headers: {
        "Access-Control-Allow-Origin": "*",
      }
    };
  }

  try {
    const command = new AttachPolicyCommand({
      policyName: POLICY_NAME,
      target: identityId,
    });
    
    await iotClient.send(command);
    console.log(`Successfully attached policy ${POLICY_NAME} to identity ${identityId}`);
    
    return {
      statusCode: 200,
      body: JSON.stringify({ message: "Success", identityId }),
      headers: {
        "Access-Control-Allow-Origin": "*",
      }
    };
  } catch (error) {
    console.error(`Error attaching policy to ${identityId}:`, error);
    return {
      statusCode: 500,
      body: JSON.stringify({ message: "Internal server error" }),
      headers: {
        "Access-Control-Allow-Origin": "*",
      }
    };
  }
};
