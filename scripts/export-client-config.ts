import {
  CloudFormationClient,
  DescribeStacksCommand,
} from '@aws-sdk/client-cloudformation';
import { IoTClient, DescribeEndpointCommand } from '@aws-sdk/client-iot';
import * as fs from 'fs';
import * as path from 'path';

const REGION = process.env.AWS_REGION || 'ap-south-1';
const cfn = new CloudFormationClient({ region: REGION });
const iot = new IoTClient({ region: REGION });

async function getIotEndpoint(): Promise<string> {
  try {
    const res = await iot.send(new DescribeEndpointCommand({ endpointType: 'iot:Data-ATS' }));
    return res.endpointAddress || '';
  } catch (err: any) {
    console.warn(`[WARN] Could not retrieve IoT ATS endpoint: ${err.message}`);
    return '';
  }
}

async function getStackOutputs(stackName: string): Promise<Record<string, string>> {
  try {
    const res = await cfn.send(new DescribeStacksCommand({ StackName: stackName }));
    const outputs = res.Stacks?.[0]?.Outputs || [];
    const map: Record<string, string> = {};
    for (const o of outputs) {
      if (o.OutputKey && o.OutputValue) {
        map[o.OutputKey] = o.OutputValue;
      }
    }
    return map;
  } catch (err: any) {
    console.warn(`[WARN] Could not retrieve outputs for ${stackName}: ${err.message}`);
    return {};
  }
}

async function main() {
  console.log('====================================================');
  console.log('  GROUPNAV CLIENT CONFIGURATION EXPORTER');
  console.log('====================================================\n');

  console.log(`[1/3] Reading stack outputs and IoT endpoint from AWS (${REGION})...`);
  const [networkOut, authOut, dataOut, computeOut, pipelineOut, iotEndpoint] = await Promise.all([
    getStackOutputs('NetworkStack'),
    getStackOutputs('AuthStack'),
    getStackOutputs('DataStack'),
    getStackOutputs('ComputeStack'),
    getStackOutputs('PipelineStack'),
    getIotEndpoint(),
  ]);

  const clientConfig = {
    region: REGION,
    cognito: {
      userPoolId: authOut.UserPoolId || '',
      userPoolClientId: authOut.UserPoolClientId || '',
      identityPoolId: authOut.IdentityPoolId || '',
    },
    location: {
      mapName: authOut.MapName || 'GroupNavMap',
      mapArn: authOut.MapArn || '',
      geofenceCollectionName: authOut.GeofenceCollectionName || 'GroupNavGeofenceCollection',
      geofenceCollectionArn: authOut.GeofenceCollectionArn || '',
    },
    iot: {
      endpoint: iotEndpoint || authOut.IotEndpoint || '',
    },
    network: {
      vpcId: networkOut.VpcId || '',
      computeSecurityGroupId: networkOut.ComputeSecurityGroupId || '',
      dataSecurityGroupId: networkOut.DataSecurityGroupId || '',
      publicSubnetIds: networkOut.PublicSubnetIds ? networkOut.PublicSubnetIds.split(',') : [],
      privateComputeSubnetIds: networkOut.PrivateComputeSubnetIds ? networkOut.PrivateComputeSubnetIds.split(',') : [],
      isolatedDataSubnetIds: networkOut.IsolatedDataSubnetIds ? networkOut.IsolatedDataSubnetIds.split(',') : [],
    },
    data: {
      redisEndpoint: dataOut.RedisEndpoint ? `${dataOut.RedisEndpoint}:${dataOut.RedisPort || '6379'}` : '',
      auroraClusterEndpoint: dataOut.AuroraClusterEndpoint || '',
    },
    compute: {
      lambdaArn: computeOut.ProcessTelemetryLambdaArn || '',
      dlqUrl: computeOut.TelemetryDlqUrl || '',
      telemetryTopicPattern: 'groupnav/{riderId}/telemetry',
    },
    cicd: {
      pipelineName: pipelineOut.CodePipelineName || '',
      pipelineArn: pipelineOut.CodePipelineArn || '',
      gitHubConnectionArn: pipelineOut.GitHubConnectionArn || '',
      artifactBucketName: pipelineOut.ArtifactBucketName || '',
    },
  };

  const outputPath = path.resolve(__dirname, '../client-config.json');
  console.log(`[2/3] Writing configuration to ${outputPath}...`);
  fs.writeFileSync(outputPath, JSON.stringify(clientConfig, null, 2) + '\n', 'utf8');

  console.log('[3/3] Client config exported successfully!\n');
  console.log(JSON.stringify(clientConfig, null, 2));
}

main().catch((err) => {
  console.error('[ERROR] Failed to export client configuration:', err);
  process.exit(1);
});
