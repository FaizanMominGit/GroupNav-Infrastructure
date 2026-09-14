# Project Development & Engineering Rules

## 1. Core Mandate
> **CREATE A DETAILED DOCUMENTATION OF HOW YOU DID IT AND WHY YOU DID. IF YOU NEED ANYTHING TO BE DONE BY ME, JUST ASK ME TO DO; DON'T MAKE A TEMPORARY WORKAROUND FOR THAT.**

---

## 2. Operational Guidelines

### A. Incremental Execution & Explicit Verification
- Execute changes strictly in incremental, bite-sized steps.
- **NEVER** rush ahead or execute multiple phases simultaneously.
- At the end of each step, verify the outcome, present the evidence, and **wait for user review and explicit permission** before proceeding to the next step.

### B. No Temporary Workarounds
- If an external dependency, credential, tool installation (e.g., AWS CLI, AWS credentials, account permissions, Flutter SDK) is needed, **ask the user directly**.
- Do not create mock shims, fake scripts, or temporary hacks to bypass legitimate system requirements.
- Follow production-grade AWS CDK and TypeScript best practices from day one.

### C. Comprehensive Documentation in Workspace (.md) Files
- For **every single step and milestone**, create a dedicated markdown file in the workspace under `docs/` (e.g. `docs/STEP_1_HOW_AND_WHY.md`).
- Document in thorough detail:
  1. **How It Was Done**: Technical mechanics, architecture, file responsibilities, and command invocations.
  2. **Why It Was Done This Way**: Architectural decisions, CDK best practices, cost controls, security rationales.
  3. **Verification Evidence**: Verifiable outputs, test runs, synthesis validations.
- **Rule for Documentation: Explain, Do Not Dump Code**:
  - Focus on clear, structured prose, architectural concepts, component relationships, and trade-offs.
  - **DO NOT paste large blocks of raw source code** into documentation files. The source code already exists in `lib/` and `test/`. Keep documents readable and analytical.
- Do NOT rely on IDE-internal walkthrough artifacts that are inaccessible outside the active session. Everything must live permanently in repository markdown files.
- Maintain and update [TROUBLESHOOTING_LOG.md](../../TROUBLESHOOTING_LOG.md) whenever an error, bug, or architectural challenge is encountered:
  - Document the symptom and exact error.
  - Analyze the root cause.
  - Document the clean, permanent fix.
  - Establish a prevention rule so the problem is not repeated.

### D. Architectural Integrity (Phase-Driven)
- Align strictly with [GroupNav-Infrastructure-Plan.md](../../GroupNav-Infrastructure-Plan.md).
- Keep stacks modular and decoupled (`NetworkStack`, `AuthStack`, `DataStack`, `ComputeStack`, `PipelineStack`, `ObservabilityStack`).
- Avoid direct construct passing that generates tight `Fn::Export` CloudFormation deadlocks.
- Ensure cost awareness (no unneeded NAT gateways; scale-to-zero configurations where planned).

### E. Git Discipline: Commit & Push Strictly Once Per Completed Step
- **No Unnecessary Micro-Commits**: Avoid committing intermediate tweaks, temporary edits, or partial steps.
- **Single Atomic Commit Per Step**: Commit and push strictly once per milestone when implementation, tests, and documentation are all completed and verified.
