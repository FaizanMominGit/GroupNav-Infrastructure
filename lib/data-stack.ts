import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as elasticache from 'aws-cdk-lib/aws-elasticache';
import * as rds from 'aws-cdk-lib/aws-rds';
import { Construct } from 'constructs';

export class DataStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // 1. Decoupled Imports via Fn::GetStackOutput
    // Fetching values output by NetworkStack without creating tight CFN Export deadlocks
    const vpcId = cdk.Fn.getStackOutput('NetworkStack', 'VpcId');
    const isolatedDataSubnetsString = cdk.Fn.getStackOutput('NetworkStack', 'IsolatedDataSubnetIds');
    const dataSgId = cdk.Fn.getStackOutput('NetworkStack', 'DataSecurityGroupId');

    const isolatedSubnetIds = cdk.Fn.split(',', isolatedDataSubnetsString, 2);

    // Reconstruct the VPC construct using the imported properties
    const vpc = ec2.Vpc.fromVpcAttributes(this, 'ImportedVpc', {
      vpcId: vpcId,
      availabilityZones: cdk.Fn.getAzs(this.region),
      isolatedSubnetIds: isolatedSubnetIds,
    });

    const dataSg = ec2.SecurityGroup.fromSecurityGroupId(this, 'ImportedDataSg', dataSgId);

    // 2. Redis (ElastiCache)
    // Used for GEOADD / GEOSEARCH live position queries
    const redisSubnetGroup = new elasticache.CfnSubnetGroup(this, 'RedisSubnetGroup', {
      description: 'Subnet group for Redis in isolated subnets',
      subnetIds: isolatedSubnetIds,
    });

    const redis = new elasticache.CfnReplicationGroup(this, 'RedisCluster', {
      replicationGroupDescription: 'GroupNav Redis Cluster for telemetry',
      engine: 'redis',
      cacheNodeType: 'cache.t3.micro', // Appropriate for hackathon
      numCacheClusters: 1, // No replication (cost savings)
      automaticFailoverEnabled: false, // Required when numCacheClusters is 1
      securityGroupIds: [dataSg.securityGroupId],
      cacheSubnetGroupName: redisSubnetGroup.ref,
    });

    // 3. Aurora Serverless v2 (PostgreSQL with PostGIS)
    // Used for historical trip geometry and spatial queries
    const dbCluster = new rds.DatabaseCluster(this, 'AuroraCluster', {
      engine: rds.DatabaseClusterEngine.auroraPostgres({
        version: rds.AuroraPostgresEngineVersion.VER_16_8, // Supported in ap-south-1 & supports auto-pause
      }),
      writer: rds.ClusterInstance.serverlessV2('Writer'),
      serverlessV2MinCapacity: 0,
      serverlessV2MaxCapacity: 2,
      vpc,
      vpcSubnets: {
        subnetType: ec2.SubnetType.PRIVATE_ISOLATED,
      },
      securityGroups: [dataSg],
      // No RDS proxy to allow auto-pause to work correctly
    });
    
    // Explicitly add auto-pause setting using Cfn override
    const cfnDbCluster = dbCluster.node.defaultChild as rds.CfnDBCluster;
    cfnDbCluster.addPropertyOverride('ServerlessV2ScalingConfiguration.SecondsUntilAutoPause', 300);

    // 4. Exports
    new cdk.CfnOutput(this, 'RedisEndpoint', {
      value: redis.attrPrimaryEndPointAddress,
      description: 'Redis Primary Endpoint Address',
    });

    new cdk.CfnOutput(this, 'RedisPort', {
      value: redis.attrPrimaryEndPointPort,
      description: 'Redis Primary Endpoint Port',
    });

    new cdk.CfnOutput(this, 'AuroraSecretArn', {
      value: dbCluster.secret?.secretArn || 'none',
      description: 'Aurora Cluster Credentials Secret ARN',
    });

    new cdk.CfnOutput(this, 'AuroraClusterEndpoint', {
      value: dbCluster.clusterEndpoint.hostname,
      description: 'Aurora Cluster Endpoint',
    });
  }
}
