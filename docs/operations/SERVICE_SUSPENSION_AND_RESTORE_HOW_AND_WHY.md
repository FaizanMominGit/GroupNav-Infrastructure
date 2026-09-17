# Service Suspension & Restore Guide: Stopping Continuous Hourly AWS Costs
> **Phase**: Cost Optimization & Resource Teardown  
> **Milestone**: Suspension of Stateful & Provisioned Compute Layers  
> **Timestamp**: 2026-09-17  
> **Status**: Verified & Successfully Suspended

---

## 1. How It Was Done

### 1.1 Root Cause of Recurring Charges
An analysis of the AWS billing dashboard revealed the following ongoing costs:
1. **Amazon Virtual Private Cloud (~$1.45)**: Caused by 2 VPC Interface Endpoints (`SecretsManagerVpcEndpoint` and `CloudWatchLogsVpcEndpoint`) deployed across 2 Availability Zones (4 ENIs total at $0.01/ENI/hour).
2. **Amazon ElastiCache (~$1.15)**: Caused by an active `cache.t3.micro` Redis cluster running 24/7 in the isolated data subnet.
3. **AWS RDS Aurora (~$0.10)**: Storage and brief active compute before auto-pausing.
4. **CloudWatch Dashboards (~$3.00/month pro-rated)**: Operational monitoring dashboard.

In contrast, serverless components (**AWS Lambda**, **Cognito**, **IoT Core**, and **Amazon Location Service**) incurred essentially $0 while idle.

### 1.2 Teardown Execution Order
Because stacks reference resources from upstream layers (via `Fn::GetStackOutput`), stacks were destroyed in reverse dependency order to avoid CloudFormation dependency locks:

1. **Step 1: ObservabilityStack Teardown**
   ```bash
   npx cdk destroy ObservabilityStack -f
   ```
   - Removed CloudWatch Dashboards and active alarms.

2. **Step 2: ComputeStack Teardown**
   ```bash
   npx cdk destroy ComputeStack -f
   ```
   - Detached and deleted the 2 VPC Interface Endpoints, stopping ongoing VPC PrivateLink hourly fees.
   - Removed the telemetry ingestion Lambda and SQS Dead-Letter Queue.

3. **Step 3: DataStack Teardown**
   ```bash
   npx cdk destroy DataStack -f
   ```
   - Deleted the `cache.t3.micro` Redis Replication Group and subnet group.
   - Took an automatic safety snapshot and terminated the Aurora Serverless PostgreSQL cluster and subnet groups.

---

## 2. Why It Was Done This Way

### 2.1 Selective Teardown vs. Total Destruction
Instead of destroying the entire AWS environment (`cdk destroy --all`), we preserved:
- **`NetworkStack`**: The VPC, route tables, security groups, and S3/DynamoDB Gateway endpoints have **zero continuous hourly costs** ($0.00/month). Preserving them avoids needing to re-synthesize VPC subnets.
- **`AuthStack`**: Cognito User Pool, Identity Pool, and Amazon Location Service Map/Geofences are **serverless**. They have $0 idle cost. Preserving them ensures that registered test users, callsigns, and map configurations remain intact for future Flutter app runs.
- **`PipelineStack`**: CI/CD pipeline and artifact buckets remain ready for code changes.

### 2.2 Cost Prevention
This targeted suspension halts 100% of the active hourly charges, saving hackathon and development credits during non-working hours.

---

## 3. Verification Evidence

### 3.1 Active CloudFormation Stacks
```
--------------------------------------
|             ListStacks             |
+----------------+-------------------+
|      Name      |      Status       |
+----------------+-------------------+
|  PipelineStack |  UPDATE_COMPLETE  |
|  NetworkStack  |  CREATE_COMPLETE  |
|  AuthStack     |  CREATE_COMPLETE  |
|  CDKToolkit    |  CREATE_COMPLETE  |
+----------------+-------------------+
```

### 3.2 VPC Endpoints Status
All billable interface endpoints are removed. Only free Gateway endpoints remain:
```
-----------------------------------------------------------------------------------------
|                                 DescribeVpcEndpoints                                  |
+-------------------------+-------------------------------------+------------+----------+
|           Id            |               Service               |   State    |  Type    |
+-------------------------+-------------------------------------+------------+----------+
|  vpce-034675ccf3736bc6c |  com.amazonaws.ap-south-1.dynamodb  |  available |  Gateway |
|  vpce-062162c270469f2cd |  com.amazonaws.ap-south-1.s3        |  available |  Gateway |
+-------------------------+-------------------------------------+------------+----------+
```

### 3.3 ElastiCache & Aurora Status
- `aws elasticache describe-replication-groups`: 0 clusters found.
- `aws rds describe-db-clusters`: 0 clusters found.

---

## 4. How to Turn Services Back On When Ready to Test

When you are ready to resume testing, redeploy the three suspended stacks with a single command from `c:\Users\faizan\Downloads\AWS`:

```bash
npx cdk deploy DataStack ComputeStack ObservabilityStack --require-approval never
```

Once deployed, update the database and Redis endpoints in [client-config.json](file:///c:/Users/faizan/Downloads/AWS/client-config.json) using the new CloudFormation outputs.
