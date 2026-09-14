import * as cdk from 'aws-cdk-lib';
import { Template, Match } from 'aws-cdk-lib/assertions';
import { NetworkStack } from '../lib/network-stack';

describe('NetworkStack', () => {
  let app: cdk.App;
  let stack: NetworkStack;
  let template: Template;

  beforeEach(() => {
    app = new cdk.App();
    stack = new NetworkStack(app, 'TestNetworkStack', {
      env: { account: '123456789012', region: 'ap-south-1' },
    });
    template = Template.fromStack(stack);
  });

  test('creates a VPC with CIDR 10.0.0.0/16 and DNS enabled', () => {
    template.hasResourceProperties('AWS::EC2::VPC', {
      CidrBlock: '10.0.0.0/16',
      EnableDnsHostnames: true,
      EnableDnsSupport: true,
    });
  });

  test('enforces zero NAT Gateways to satisfy budget constraints ($0 NAT fee)', () => {
    template.resourceCountIs('AWS::EC2::NatGateway', 0);
  });

  test('creates 6 subnets across 2 AZs (2 Public, 2 PrivateCompute, 2 IsolatedData)', () => {
    // 2 AZs * 3 subnet types = 6 subnets total
    template.resourceCountIs('AWS::EC2::Subnet', 6);

    // Public subnets have MapPublicIpOnLaunch enabled
    template.hasResourceProperties('AWS::EC2::Subnet', {
      MapPublicIpOnLaunch: true,
      Tags: Match.arrayWith([
        Match.objectLike({ Key: 'aws-cdk:subnet-name', Value: 'Public' }),
      ]),
    });

    // Compute subnets are isolated (no NAT route, no public IP)
    template.hasResourceProperties('AWS::EC2::Subnet', {
      MapPublicIpOnLaunch: false,
      Tags: Match.arrayWith([
        Match.objectLike({ Key: 'aws-cdk:subnet-name', Value: 'PrivateCompute' }),
      ]),
    });

    // Data subnets are isolated
    template.hasResourceProperties('AWS::EC2::Subnet', {
      MapPublicIpOnLaunch: false,
      Tags: Match.arrayWith([
        Match.objectLike({ Key: 'aws-cdk:subnet-name', Value: 'IsolatedData' }),
      ]),
    });
  });

  test('creates free S3 and DynamoDB Gateway VPC Endpoints', () => {
    template.resourceCountIs('AWS::EC2::VPCEndpoint', 2);

    template.hasResourceProperties('AWS::EC2::VPCEndpoint', {
      VpcEndpointType: 'Gateway',
      ServiceName: Match.objectLike({
        'Fn::Join': Match.arrayWith([
          Match.arrayWith([Match.stringLikeRegexp('.*s3.*')]),
        ]),
      }),
    });

    template.hasResourceProperties('AWS::EC2::VPCEndpoint', {
      VpcEndpointType: 'Gateway',
      ServiceName: Match.objectLike({
        'Fn::Join': Match.arrayWith([
          Match.arrayWith([Match.stringLikeRegexp('.*dynamodb.*')]),
        ]),
      }),
    });
  });

  test('creates ComputeSG and DataSG with least-privilege ingress', () => {
    template.hasResourceProperties('AWS::EC2::SecurityGroup', {
      GroupDescription: 'GroupNav compute tier security group (Lambda, ECS)',
    });

    template.hasResourceProperties('AWS::EC2::SecurityGroup', {
      GroupDescription: 'GroupNav data tier security group (Redis, Aurora)',
    });

    // Ingress rule for Redis (Port 6379) from ComputeSG
    template.hasResourceProperties('AWS::EC2::SecurityGroupIngress', {
      FromPort: 6379,
      ToPort: 6379,
      IpProtocol: 'tcp',
      Description: 'Allow inbound Redis traffic strictly from ComputeSG',
      SourceSecurityGroupId: Match.objectLike({
        'Fn::GetAtt': Match.arrayWith([Match.stringLikeRegexp('ComputeSecurityGroup.*'), 'GroupId']),
      }),
    });

    // Ingress rule for PostgreSQL (Port 5432) from ComputeSG
    template.hasResourceProperties('AWS::EC2::SecurityGroupIngress', {
      FromPort: 5432,
      ToPort: 5432,
      IpProtocol: 'tcp',
      Description: 'Allow inbound PostgreSQL/Aurora traffic strictly from ComputeSG',
      SourceSecurityGroupId: Match.objectLike({
        'Fn::GetAtt': Match.arrayWith([Match.stringLikeRegexp('ComputeSecurityGroup.*'), 'GroupId']),
      }),
    });
  });

  test('strictly prohibits 0.0.0.0/0 inbound ingress on all security groups', () => {
    // Ensure no SecurityGroupIngress resource has CidrIp 0.0.0.0/0
    const ingressResources = template.findResources('AWS::EC2::SecurityGroupIngress');
    for (const [, resource] of Object.entries(ingressResources)) {
      expect(resource.Properties.CidrIp).not.toBe('0.0.0.0/0');
    }

    // Also check SecurityGroups directly for inline ingress rules
    const sgResources = template.findResources('AWS::EC2::SecurityGroup');
    for (const [, resource] of Object.entries(sgResources)) {
      const inlineIngress = resource.Properties.SecurityGroupIngress || [];
      for (const rule of inlineIngress) {
        expect(rule.CidrIp).not.toBe('0.0.0.0/0');
      }
    }
  });

  test('exports decoupled CfnOutputs for cross-stack consumption', () => {
    template.hasOutput('VpcId', {});
    template.hasOutput('ComputeSecurityGroupId', {});
    template.hasOutput('DataSecurityGroupId', {});
    template.hasOutput('PublicSubnetIds', {});
    template.hasOutput('PrivateComputeSubnetIds', {});
    template.hasOutput('IsolatedDataSubnetIds', {});
  });
});
