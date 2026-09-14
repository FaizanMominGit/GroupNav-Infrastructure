import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';

export interface NetworkStackProps extends cdk.StackProps {}

export class NetworkStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: NetworkStackProps) {
    super(scope, id, props);

    // Network foundation resources (VPC, Subnets, Security Groups) to be implemented in Step 2
  }
}
