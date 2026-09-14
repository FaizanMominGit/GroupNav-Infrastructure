import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';

export interface AuthStackProps extends cdk.StackProps {}

export class AuthStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: AuthStackProps) {
    super(scope, id, props);

    // Auth & Location foundation resources (Cognito, Location Service) to be implemented in Step 3
  }
}
