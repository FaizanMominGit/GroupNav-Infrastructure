import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import { Construct } from 'constructs';

export interface NetworkStackProps extends cdk.StackProps {
  /**
   * VPC CIDR block. Defaults to 10.0.0.0/16.
   */
  cidr?: string;
  /**
   * Maximum availability zones. Defaults to 2.
   */
  maxAzs?: number;
}

export class NetworkStack extends cdk.Stack {
  /** The GroupNav Virtual Private Cloud (VPC) */
  public readonly vpc: ec2.Vpc;

  /** Security group attached to compute workloads (Lambda, ECS) */
  public readonly computeSecurityGroup: ec2.SecurityGroup;

  /** Security group attached to stateful data stores (Redis, Aurora) */
  public readonly dataSecurityGroup: ec2.SecurityGroup;

  constructor(scope: Construct, id: string, props?: NetworkStackProps) {
    super(scope, id, props);

    const maxAzs = props?.maxAzs ?? 2;
    const cidr = props?.cidr ?? '10.0.0.0/16';

    // 1. VPC Definition
    // Configured with 2 AZs and 3 subnet tiers.
    // natGateways is explicitly set to 0 to prevent recurring NAT costs ($~32/month)
    // and strictly conform to hackathon budget constraints (Section 5.4).
    this.vpc = new ec2.Vpc(this, 'GroupNavVpc', {
      ipAddresses: ec2.IpAddresses.cidr(cidr),
      maxAzs,
      natGateways: 0,
      enableDnsHostnames: true,
      enableDnsSupport: true,
      subnetConfiguration: [
        {
          name: 'Public',
          subnetType: ec2.SubnetType.PUBLIC,
          cidrMask: 24,
        },
        {
          name: 'PrivateCompute',
          subnetType: ec2.SubnetType.PRIVATE_ISOLATED,
          cidrMask: 24,
        },
        {
          name: 'IsolatedData',
          subnetType: ec2.SubnetType.PRIVATE_ISOLATED,
          cidrMask: 24,
        },
      ],
    });

    // 2. Gateway Endpoints (Zero ongoing cost)
    // Provides high-throughput, private access to AWS services without NAT Gateways.
    this.vpc.addGatewayEndpoint('S3Endpoint', {
      service: ec2.GatewayVpcEndpointAwsService.S3,
    });

    this.vpc.addGatewayEndpoint('DynamoDbEndpoint', {
      service: ec2.GatewayVpcEndpointAwsService.DYNAMODB,
    });

    // 3. Security Groups
    // Compute Security Group: attached to Lambda compute
    this.computeSecurityGroup = new ec2.SecurityGroup(this, 'ComputeSecurityGroup', {
      vpc: this.vpc,
      securityGroupName: 'GroupNav-Compute-SG',
      description: 'GroupNav compute tier security group (Lambda, ECS)',
      allowAllOutbound: true,
    });

    // Data Security Group: attached to Redis (ElastiCache) & PostgreSQL (Aurora)
    this.dataSecurityGroup = new ec2.SecurityGroup(this, 'DataSecurityGroup', {
      vpc: this.vpc,
      securityGroupName: 'GroupNav-Data-SG',
      description: 'GroupNav data tier security group (Redis, Aurora)',
      allowAllOutbound: false,
    });

    // Least-privilege ingress rules:
    // Inbound traffic to DataSG is strictly permitted ONLY from ComputeSG on ports 6379 (Redis) and 5432 (PostgreSQL).
    // Absolutely NO 0.0.0.0/0 inbound rules anywhere.
    this.dataSecurityGroup.addIngressRule(
      this.computeSecurityGroup,
      ec2.Port.tcp(6379),
      'Allow inbound Redis traffic strictly from ComputeSG'
    );

    this.dataSecurityGroup.addIngressRule(
      this.computeSecurityGroup,
      ec2.Port.tcp(5432),
      'Allow inbound PostgreSQL/Aurora traffic strictly from ComputeSG'
    );

    // 4. Decoupled CloudFormation Outputs (Section 3.5)
    // Plain outputs to prevent Fn::Export cross-stack dependency locks.
    new cdk.CfnOutput(this, 'VpcId', {
      value: this.vpc.vpcId,
      description: 'GroupNav VPC ID',
    });

    new cdk.CfnOutput(this, 'ComputeSecurityGroupId', {
      value: this.computeSecurityGroup.securityGroupId,
      description: 'GroupNav Compute Security Group ID',
    });

    new cdk.CfnOutput(this, 'DataSecurityGroupId', {
      value: this.dataSecurityGroup.securityGroupId,
      description: 'GroupNav Data Security Group ID',
    });

    new cdk.CfnOutput(this, 'PublicSubnetIds', {
      value: this.vpc.publicSubnets.map((s) => s.subnetId).join(','),
      description: 'Comma-separated Public Subnet IDs',
    });

    const computeSubnets = this.vpc.isolatedSubnets.filter((s) =>
      s.node.id.includes('PrivateCompute')
    );
    new cdk.CfnOutput(this, 'PrivateComputeSubnetIds', {
      value: computeSubnets.map((s) => s.subnetId).join(','),
      description: 'Comma-separated Private Compute Subnet IDs',
    });

    const dataSubnets = this.vpc.isolatedSubnets.filter((s) =>
      s.node.id.includes('IsolatedData')
    );
    new cdk.CfnOutput(this, 'IsolatedDataSubnetIds', {
      value: dataSubnets.map((s) => s.subnetId).join(','),
      description: 'Comma-separated Isolated Data Subnet IDs',
    });
  }
}
