# Project Rules & Working Agreement

## 1. Primary Rule
> **CREATE A DETAILED DOCUMENTATION OF HOW YOU DID IT AND WHY YOU DID. IF YOU NEED ANYTHING TO BE DONE BY ME, JUST ASK ME TO DO; DON'T MAKE A TEMPORARY WORKAROUND FOR THAT.**

---

## 2. Key Principles
1. **Incremental Progression**: Break down implementations into clearly defined steps. Verify each step thoroughly and halt for user permission before proceeding.
2. **Dedicated Workspace Documentation Files**: For each step/milestone, create a separate `.md` file directly in the repository (under `docs/STEP_X_HOW_AND_WHY.md`) documenting:
   - **1. How It Was Done** (implementation details, files changed, commands run)
   - **2. Why It Was Done This Way** (architectural decisions, tradeoffs, security, cost)
   - **3. Verification Evidence** (test outputs, command logs, proof of correctness)
   Never store this only in IDE walkthrough artifacts; the user must have full, permanent access to every milestone's documentation directly in the repository.
3. **No Compromise / No Temporary Workarounds**: If AWS CLI, credentials, or third-party permissions are required, prompt the user immediately. Do not substitute with mock hacks.
4. **Persistent Problem & Solution Tracking**: Whenever a problem arises, record the exact error, root cause analysis, fix, and preventative rule in [TROUBLESHOOTING_LOG.md](file:///c:/Users/faizan/Downloads/AWS/TROUBLESHOOTING_LOG.md).
5. **Decoupled AWS CDK Architecture**: Strictly adhere to the [GroupNav-Infrastructure-Plan.md](file:///c:/Users/faizan/Downloads/AWS/GroupNav-Infrastructure-Plan.md). Keep stacks isolated, avoid export deadlocks, and adhere to cost-conscious configurations.

