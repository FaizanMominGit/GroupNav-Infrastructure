#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib';
import { NetworkStack } from '../lib/network-stack';
import { AuthStack } from '../lib/auth-stack';
import { DataStack } from '../lib/data-stack';
import { ComputeStack } from '../lib/compute-stack';

const app = new cdk.App();

const env: cdk.Environment = {
  account: process.env.CDK_DEFAULT_ACCOUNT,
  region: process.env.CDK_DEFAULT_REGION || 'ap-south-1',
};

new NetworkStack(app, 'NetworkStack', {
  env,
  description: 'GroupNav Phase 1: Network Foundation (VPC, Subnets, Security Groups)',
});

new AuthStack(app, 'AuthStack', {
  env,
  description: 'GroupNav Phase 1: Auth & Location (Cognito User/Identity Pools, Amazon Location Service)',
});

new DataStack(app, 'DataStack', {
  env,
  description: 'GroupNav Phase 2: Data Layer (Redis, Aurora Serverless v2)',
});

new ComputeStack(app, 'ComputeStack', {
  env,
  description: 'GroupNav Phase 3: Ingestion & Compute (IoT Core Topic Rule, Lambda, SQS DLQ, VPC Endpoints)',
});
