# GroupNav Engineering & Troubleshooting Log
> **Purpose**: Record all critical architectural decisions, discovered problems, failure modes, root causes, exact fixes, and preventative rules so we never repeat the same mistakes.

---

## Issue Log Template
When an issue, error, or unexpected behavior is encountered, document it using this format:

```markdown
### [ISSUE-XXX] Short Title Describing the Problem
- **Date & Phase**: YYYY-MM-DD | Phase X (e.g., Phase 1 - NetworkStack)
- **Component / Command**: Component or command that triggered the issue
- **Symptom / Error Message**:
  ```
  Exact error output or unexpected behavior
  ```
- **Root Cause Analysis**:
  Why did this happen? (e.g. AWS CDK behavior, CloudFormation restriction, missing IAM permission, environment discrepancy)
- **Fix / Solution Applied**:
  Exact steps and code changes taken to resolve it. No temporary workarounds.
- **Verification**:
  How was the fix verified?
- **Prevention Rule**:
  Rule or check added to prevent this from reoccurring.
```

---

## Logged Issues & Pre-emptive Findings

### [ISSUE-001] AWS CLI Not Found in System PATH
- **Date & Phase**: 2026-09-14 | Phase 1 Prerequisites
- **Component / Command**: Environment verification (`aws --version`)
- **Symptom / Error Message**:
  ```
  aws : The term 'aws' is not recognized as the name of a cmdlet, function, script file, or operable program.
  ```
- **Root Cause Analysis**:
  AWS CLI v2 is not installed or not added to the Windows environment `PATH`. Deployment and manual verification (e.g., registering test users, testing IAM auth) require AWS credentials and CLI tools.
- **Fix / Solution Applied**:
  Prompt user to install AWS CLI v2 or configure AWS credentials (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, or AWS profiles). Avoid creating makeshift shell wrappers.
- **Verification**:
  Run `aws --version` and `aws sts get-caller-identity`.
- **Prevention Rule**:
  Always verify prerequisites before attempting deployment. If credentials/CLI are required from the user, request them directly without fake workarounds.

---

### [ISSUE-002] Global AWS CDK Not Installed
- **Date & Phase**: 2026-09-14 | Phase 1 Prerequisites
- **Component / Command**: Environment verification (`cdk --version`)
- **Symptom / Error Message**:
  ```
  cdk : The term 'cdk' is not recognized as the name of a cmdlet...
  ```
- **Root Cause Analysis**:
  `aws-cdk` is not installed globally in the system.
- **Fix / Solution Applied**:
  Use `npx -y aws-cdk@2.1141.0` or project-local `node_modules/.bin/cdk` via `npx cdk` to guarantee version parity across environments without polluting global packages.
- **Verification**:
  `npx -y aws-cdk --version` verified working (v2.1141.0).
- **Prevention Rule**:
  All CDK commands in npm scripts and terminal runs will invoke `npx cdk` or `npm run cdk`.

---

### [ISSUE-003] CDK VPC Private Subnets Without NAT Gateway Synthesis Conflict
- **Date & Phase**: 2026-09-14 | Phase 1 Architectural Design
- **Component / Command**: `NetworkStack` VPC definition
- **Symptom / Error Message**:
  If `SubnetType.PRIVATE_WITH_EGRESS` is specified with `natGateways: 0`, AWS CDK v2 throws an error at synthesis time:
  ```
  Error: If you configure private subnets and no NAT gateways (natGateways: 0), you must specify how egress is provided...
  ```
- **Root Cause Analysis**:
  In CDK, `PRIVATE_WITH_EGRESS` automatically synthesizes default routes pointing to NAT Gateways. GroupNav deliberately avoids NAT Gateways to save hackathon credits (Section 5.4), using VPC Interface Endpoints (PrivateLink) instead.
- **Fix / Solution Applied**:
  In the VPC definition, define the compute subnets as `SubnetType.PRIVATE_ISOLATED` (or configure custom route tables / endpoints), or explicitly decouple egress route creation. For isolated data tiers and private compute with VPC endpoints, isolated subnets with interface endpoints fulfill the security boundary without paying ~$32/month NAT fee.
- **Verification**:
  Validate with `npx cdk synth` during unit testing before any deployment.
- **Prevention Rule**:
  Model cost-aware VPC subnets strictly matching CloudFormation route constraints.

---

### [ISSUE-004] Cross-Stack Reference Deadlocks (`Fn::Export` vs `Fn::GetStackOutput`)
- **Date & Phase**: 2026-09-14 | Phase 1 Cross-Stack Architecture
- **Component / Command**: Passing VPC, Subnets, and Security Groups between `NetworkStack`, `AuthStack`, and downstream stacks
- **Symptom / Potential Failure**:
  CDK default construct passing generates `Export [StackName]:[ExportName] cannot be updated because it is in use by [ConsumerStack]`.
- **Root Cause Analysis**:
  Direct construct references across CDK stacks generate CloudFormation `Fn::Export` and `Fn::ImportValue`, tightly coupling stacks and locking updates.
- **Fix / Solution Applied**:
  Follow Section 3.5 of the infrastructure plan: Export plain outputs via `CfnOutput` and consume them using `Fn.importValue` or `Fn.select`/`Fn.split` with stack outputs or SSM Parameter Store / explicit stack attributes without creating locked CloudFormation export chains.
- **Verification**:
  Check generated CloudFormation templates during `npx cdk synth`.
- **Prevention Rule**:
  Never pass mutable VPC construct references directly to independent stacks without decoupling.

---

### [ISSUE-005] CDK Init Fails in Non-Empty Directory
- **Date & Phase**: 2026-09-14 | Phase 1 Scaffolding
- **Component / Command**: `npx -y aws-cdk@2.1141.0 init app --language typescript`
- **Symptom / Error Message**:
  ```
  Failed to validate directory C:\Users\faizan\Downloads\AWS: `cdk init` cannot be run in a non-empty directory!
  Found 3 visible files in C:\Users\faizan\Downloads\AWS:
    - AGENTS.md
    - GroupNav-Infrastructure-Plan.md
    - TROUBLESHOOTING_LOG.md
  ```
- **Root Cause Analysis**:
  `cdk init` strictly enforces that target project directories contain zero existing files to avoid clobbering user files.
- **Fix / Solution Applied**:
  Run `cdk init` inside an empty temporary directory (`_cdk_init`), migrate the generated scaffold files (`cdk.json`, `package.json`, `tsconfig.json`, `jest.config.js`, etc.) into the project root, remove the temporary directory, and install dependencies cleanly.
- **Verification**:
  Verify successful population of CDK TypeScript project files and run `npm run build`.
- **Prevention Rule**:
  When introducing CDK into existing repositories with documentation or config files, use a temporary initialization directory or directly scaffold official CDK configuration files.

