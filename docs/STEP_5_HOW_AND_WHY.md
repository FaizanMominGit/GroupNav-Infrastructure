# Step 5: Phase 2 Data Layer Implementation

## 1. How It Was Done
In this step, we built the `DataStack` (`lib/data-stack.ts`) to provide the stateful data storage layer (Phase 2).
- **VPC and Security Group Imports**: We utilized the native `cdk.Fn.getStackOutput` intrinsic helper provided by CDK to fetch the `VpcId`, `IsolatedDataSubnetIds`, and `DataSecurityGroupId` from the previously deployed `NetworkStack`. This avoids direct construct passing and tight `Fn::Export` coupling, ensuring the stacks remain independently deployable.
- **ElastiCache Redis**: Provisioned a `cache.t3.micro` Redis cluster (`AWS::ElastiCache::ReplicationGroup`) inside the isolated subnets with `NumCacheClusters: 1` and `automaticFailoverEnabled: false` to disable replication for cost savings.
- **Aurora Serverless v2 PostgreSQL**: Provisioned an Aurora PostgreSQL 16.8 cluster (`AWS::RDS::DBCluster` & `AWS::RDS::DBInstance`) configured as `serverlessV2` with `MinCapacity: 0` and `MaxCapacity: 2`. We bypassed the L2 construct's default type constraints using `cfnDbCluster.addPropertyOverride` to natively inject `SecondsUntilAutoPause: 300` directly into the `ServerlessV2ScalingConfiguration` property, effectively enforcing the 5-minute scale-to-zero window. Version 16.8 was selected as it is actively supported in `ap-south-1` and supports auto-pause.
- **Secrets Management**: Deployed Aurora credentials directly into AWS Secrets Manager without hardcoding them or outputting them in plaintext.

## 2. Why It Was Done This Way
- **Complete Decoupling**: By explicitly using CloudFormation output reading (`getStackOutput`) rather than sharing CDK constructs between stacks, `NetworkStack` and `DataStack` operate autonomously without generating blocking `Fn::Export`/`Fn::ImportValue` pairs that often deadlock during subsequent infrastructure iterations.
- **Cost Minimization & Scale-to-Zero**: Aurora Serverless v2 auto-pause (introduced for PostgreSQL 16.3+ / 16.8) is configured aggressively (`300` seconds). This ensures hackathon credits are preserved overnight. RDS Proxy was deliberately excluded as it holds persistent connection pools that prevent the database from pausing.
- **Strict Network Segmentation**: Placing ElastiCache and Aurora inside the `PRIVATE_ISOLATED` subnets and binding them strictly to `DataSecurityGroup` guarantees that the databases have zero ingress paths from the open internet, conforming to the least-privilege mandate.

## 3. Verification Evidence

### 3.1 Automated Synthesis & Unit Testing
- **CDK Synth Integrity**: Synthesized cleanly without cyclic dependencies or invalid export schemas.
- **Unit Tests**: All 4 tests in `test/data-stack.test.ts` passed:
  - Verified singleton Redis node with `AutomaticFailoverEnabled: false`.
  - Verified Aurora Serverless v2 PostgreSQL `16.8` with `MinCapacity: 0`, `MaxCapacity: 2`, and `SecondsUntilAutoPause: 300`.
  - Verified Serverless writer instance and decoupled CloudFormation outputs.

### 3.2 Live Cloud Deployment
- Deployed stack `DataStack` to `ap-south-1` via `npx cdk deploy DataStack`:
  - **Redis Endpoint**: `darxx9kygkawaf7.gtzybr.ng.0001.aps1.cache.amazonaws.com:6379`
  - **Aurora Cluster Endpoint**: `datastack-auroracluster23d869c0-bojcqvtjqceq.cluster-clisq44gok7m.ap-south-1.rds.amazonaws.com:5432`
  - **Aurora Secret ARN**: `arn:aws:secretsmanager:ap-south-1:325313611329:secret:AuroraClusterSecret8E4F2BC8-J5bTACaVEp6s-koz1tK`

### 3.3 Interactive Verification via Throwaway Bastion (Option A)
To verify private connectivity into the `PRIVATE_ISOLATED` subnets strictly through `ComputeSG`, a temporary `t4g.nano` EC2 bastion (`i-0c9474bf4d72b7f6d`) was launched in the Public subnet attached to `ComputeSG` with an IAM SSM role (no open SSH port 22).

Via AWS Systems Manager (SSM Run Command), the following tests were executed inside the VPC:

1. **Redis Connectivity & Geospatial Test**:
   - `PING` → Received `PONG`
   - `GEOADD riders 72.8777 19.0760 rider-mumbai-1` → Successfully indexed rider location (Return: `1`).
   - `GEOSEARCH riders FROMLONLAT 72.8777 19.0760 BYRADIUS 10 km WITHDIST WITHCOORD` → Successfully returned rider with coordinates `[72.877697, 19.076000]` and distance `0.0003 km`.

2. **Aurora PostgreSQL 16.8 & PostGIS Spatial Extension Test**:
   - `CREATE EXTENSION IF NOT EXISTS postgis;` → Successfully executed (`CREATE EXTENSION`).
   - `SELECT PostGIS_Full_Version();` → Verified PostGIS version `3.5.6 0` active on PostgreSQL `160` with `GEOS 3.13.0` and `PROJ 9.5.0`.
   - Tested geometry insertion: Created spatial table with `geography(Point, 4326)`, inserted rider point, and verified `SELECT ST_AsText(loc)` returned `POINT(72.8777 19.076)`. Table cleaned up.

### 3.4 Complete Cleanup
- The throwaway bastion instance (`i-0c9474bf4d72b7f6d`) was terminated immediately (`aws ec2 wait instance-terminated` confirmed `shutting-down` → `terminated`).
- Temporary IAM role (`GroupNavBastionRole`) and instance profile (`GroupNavBastionProfile`) were cleanly deleted.
- All temporary local setup scripts were removed. Zero compute remnants left running.

