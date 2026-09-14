import * as cdk from 'aws-cdk-lib';
import { Template, Match } from 'aws-cdk-lib/assertions';
import { DataStack } from '../lib/data-stack';

describe('DataStack', () => {
  let app: cdk.App;
  let stack: DataStack;
  let template: Template;

  beforeEach(() => {
    app = new cdk.App();
    stack = new DataStack(app, 'TestDataStack', {
      env: { account: '123456789012', region: 'ap-south-1' },
    });
    template = Template.fromStack(stack);
  });

  test('creates a Redis ElastiCache cluster with numCacheClusters: 1 and automaticFailover disabled', () => {
    template.hasResourceProperties('AWS::ElastiCache::ReplicationGroup', {
      Engine: 'redis',
      CacheNodeType: 'cache.t3.micro',
      NumCacheClusters: 1,
      AutomaticFailoverEnabled: false,
    });
  });

  test('creates an Aurora Serverless v2 PostgreSQL 16.8 cluster', () => {
    template.hasResourceProperties('AWS::RDS::DBCluster', {
      Engine: 'aurora-postgresql',
      EngineVersion: '16.8',
      ServerlessV2ScalingConfiguration: Match.objectLike({
        MinCapacity: 0,
        MaxCapacity: 2,
        SecondsUntilAutoPause: 300,
      }),
    });
  });

  test('creates a writer DB instance of type serverless', () => {
    template.hasResourceProperties('AWS::RDS::DBInstance', {
      DBInstanceClass: 'db.serverless',
      Engine: 'aurora-postgresql',
    });
  });

  test('exports essential connection details', () => {
    template.hasOutput('RedisEndpoint', {});
    template.hasOutput('RedisPort', {});
    template.hasOutput('AuroraSecretArn', {});
    template.hasOutput('AuroraClusterEndpoint', {});
  });
});
