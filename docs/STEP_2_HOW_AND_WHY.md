# Step 2: NetworkStack Implementation (VPC, Subnets, Security Groups & Endpoints)
> **Phase**: Phase 1 — Network, Identity & Location Foundation  
> **Milestone**: Step 2 — NetworkStack Implementation & Zero-Trust Boundary  
> **Timestamp**: 2026-09-14  
> **Status**: Verified & Ready for Deployment

---

## 1. How It Was Done

### 1.1 VPC Architecture & Subnet Segmentation
In [lib/network-stack.ts](file:///c:/Users/faizan/Downloads/AWS/lib/network-stack.ts), we established a dedicated Virtual Private Cloud (`GroupNavVpc`) configured with:
- **CIDR & Scope**: A `10.0.0.0/16` CIDR block providing 65,536 private IP addresses, with DNS resolution and DNS hostnames explicitly enabled.
- **Multi-AZ Redundancy**: Distributed evenly across 2 Availability Zones (`ap-south-1a` and `ap-south-1b`) for high availability.
- **Three-Tier Subnet Layout (6 Subnets Total)**:
  1. **Public Subnets** (2 subnets, `/24`): Connected to an Internet Gateway for public ingress or temporary administration (bastion host).
  2. **Private Compute Subnets** (2 subnets, `/24`, isolated): Dedicated to Lambda compute workers running the telemetry pipeline.
  3. **Isolated Data Subnets** (2 subnets, `/24`, isolated): Completely cut off from internet routing, reserved for stateful stores (Redis and Aurora Serverless).
- **Cost Guardrail (`natGateways: 0`)**: We explicitly set NAT Gateway count to zero. This completely avoids synthesizing AWS NAT Gateways and prevents recurring hourly charges.

### 1.2 Private AWS Service Routing via VPC Gateway Endpoints
Because compute subnets are isolated without internet egress, we configured AWS Gateway Endpoints:
- **S3 Gateway Endpoint**: Routes S3 API calls (for assets, deployment packages, and future data dumps) directly over the AWS private network.
- **DynamoDB Gateway Endpoint**: Routes DynamoDB requests over AWS private infrastructure.
- **Route Table Association**: Both endpoints automatically inject route table entries across all 6 subnets, enabling unlimited private bandwidth at **$0 additional cost**.

### 1.3 Least-Privilege Zero-Trust Security Groups
We established strict boundary controls between application compute and persistent data:
- **`ComputeSecurityGroup` (`GroupNav-Compute-SG`)**:
  - Attached to compute workloads (Lambda functions in Phase 3).
  - Outbound traffic enabled to communicate with databases and AWS endpoints.
- **`DataSecurityGroup` (`GroupNav-Data-SG`)**:
  - Attached to stateful stores (ElastiCache Redis and Aurora PostgreSQL in Phase 2).
  - Outbound traffic disabled (`allowAllOutbound: false`) to enforce containment.
- **Restricted Ingress Rules**:
  - Inbound traffic to the data layer is permitted **strictly from resources tagged with `ComputeSecurityGroup`**.
  - Access is restricted exclusively to the designated operational ports: TCP `6379` (Redis live location indexing) and TCP `5432` (PostgreSQL historical trip storage).
  - **Zero Public Access**: Inbound `0.0.0.0/0` ingress is completely forbidden on all security groups.

### 1.4 Decoupled Stack Outputs (Section 3.5)
To comply with the infrastructure plan's decoupling rules:
- We exported plain CloudFormation outputs (`CfnOutput`) for `VpcId`, `ComputeSecurityGroupId`, `DataSecurityGroupId`, and subnet ID lists.
- Downstream stacks (`DataStack`, `ComputeStack`) consume these parameters independently without creating locked CloudFormation export chains.

---

## 2. Why It Was Done This Way

### 2.1 The NAT Gateway Dilemma & Resolution
- **The Problem**: A standard CDK VPC configured with `SubnetType.PRIVATE_WITH_EGRESS` attempts to provision a NAT Gateway for every AZ. Each NAT Gateway costs ~$32.85/month baseline (~$65+/month for 2 AZs) plus data processing fees—unnecessary spending that quickly burns through hackathon credits. Furthermore, setting `natGateways: 0` with `PRIVATE_WITH_EGRESS` causes CDK synthesis to fail.
- **The Architectural Fix**: We defined the compute tier as `SubnetType.PRIVATE_ISOLATED`. Combined with Gateway Endpoints (S3, DynamoDB) and PrivateLink Interface Endpoints (IoT, CloudWatch Logs, Secrets Manager in Phase 3), Lambda compute operates inside a private network without paying NAT Gateway charges.

### 2.2 Defense-in-Depth Beyond Subnet Routing
- Subnet isolation prevents external internet routing, but does not prevent lateral movement between resources inside the same VPC.
- If a future worker or container were compromised, open network routing inside the VPC would expose the database.
- By binding `DataSecurityGroup` ingress strictly to `ComputeSecurityGroup` at the hypervisor firewall level, Redis and Aurora will reject any connection not explicitly originating from authorized compute workers, even if the request originates from within the VPC.

### 2.3 Eliminating CloudFormation Export Deadlocks
- When one CDK stack references a construct from another stack directly, CDK generates `Fn::Export` and `Fn::ImportValue` CloudFormation tokens.
- Once an export is consumed by a downstream stack, CloudFormation locks the producing stack. Any subsequent update (such as adding a subnet, modifying tags, or adjusting route tables) fails with:
  ```
  Export [StackName]:[ExportName] cannot be updated because it is in use by [ConsumerStack]
  ```
- Using plain `CfnOutput`s keeps the stacks loosely coupled, allowing `NetworkStack` to be updated independently without cascading rollback failures.

---

## 3. Verification Evidence

### 3.1 Automated Jest Unit Tests
We implemented 7 granular assertion tests in [test/network-stack.test.ts](file:///c:/Users/faizan/Downloads/AWS/test/network-stack.test.ts) verifying:
1. VPC CIDR is `10.0.0.0/16` with DNS hostnames and support enabled.
2. NAT Gateway count is exactly 0.
3. Subnet count is exactly 6 across 2 AZs (2 Public, 2 PrivateCompute, 2 IsolatedData).
4. Free S3 and DynamoDB Gateway VPC Endpoints are present.
5. `ComputeSecurityGroup` and `DataSecurityGroup` exist with scoped ingress rules.
6. Zero `0.0.0.0/0` ingress rules exist across all security groups.
7. Decoupled `CfnOutput`s are published.

**Result**: 7 passed, 0 failed (100% test pass rate).

### 3.2 CloudFormation Synthesis Validation
Executed `npx cdk synth NetworkStack` to inspect the generated CloudFormation template:
- Verified single VPC construct with 2 availability zones.
- Verified absence of NAT Gateways and Elastic IPs.
- Verified Gateway Endpoints attached to route tables.
- Verified ingress security group rules matching exact security specifications.
