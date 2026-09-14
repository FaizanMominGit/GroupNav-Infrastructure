# Contributing to GroupNav Infrastructure

Thank you for your interest in contributing to GroupNav Infrastructure! We welcome contributions, bug reports, and enhancements to help make real-time group navigation and geospatial telemetry robust, cost-effective, and scalable.

---

## Code of Conduct

We are committed to providing a welcoming, inclusive, and harassment-free environment for all contributors. Please treat everyone with respect, professionalism, and kindness.

---

## Getting Started

1. **Fork and Clone the Repository**:
   ```bash
   git clone https://github.com/<your-username>/GroupNav-Infrastructure.git
   cd GroupNav-Infrastructure
   ```

2. **Install Dependencies**:
   Ensure you are using Node.js 18+ or 22 LTS:
   ```bash
   npm ci
   ```

3. **Verify Existing Tests**:
   Before making changes, verify that all existing unit tests pass:
   ```bash
   npm test
   ```

4. **Verify TypeScript Compilation**:
   ```bash
   npm run build
   ```

---

## Development Workflow

### 1. Branching Strategy
- Create feature or bugfix branches off `master`:
  - `feat/feature-name` for new features or infrastructure additions
  - `fix/bug-name` for bugfixes
  - `docs/doc-update` for documentation changes
  - `refactor/refactor-name` for code refactoring

### 2. Architectural Principles
- **Decoupled Stacks**: Keep CDK stacks isolated. Do not create direct circular dependencies.
- **Avoid Export Deadlocks**: Prefer stack outputs (`Fn::GetStackOutput` / `Fn.importValue` without hard locks) so stacks can be modified and deployed independently.
- **Cost Consciousness**: Maintain the $0 NAT Gateway architecture (VPC Gateway Endpoints and targeted PrivateLink Interface Endpoints). Keep serverless resources scaled to zero when idle.
- **No Temporary Workarounds**: Always address root causes properly. If AWS permissions or CLI utilities are needed, configure them explicitly.

### 3. Commit Message Conventions
Follow [Conventional Commits](https://www.conventionalcommits.org/):
- `feat: add <feature>`
- `fix: resolve <bug>`
- `docs: update <documentation>`
- `test: add tests for <stack>`
- `refactor: optimize <component>`
- `chore: update dependencies or build configuration`

---

## Testing & Verification Guidelines

Every contribution modifying infrastructure stacks or Lambda handlers must include corresponding test coverage:
1. **Unit Tests**:
   - Add CDK assertions in `test/<stack-name>.test.ts` using `@aws-cdk/assertions` (`Template.fromStack`).
   - Run the test suite:
     ```bash
     npm test
     ```
2. **CloudFormation Synthesis**:
   - Verify that your changes synthesize valid CloudFormation templates without warnings:
     ```bash
     npx cdk synth
     ```
3. **Troubleshooting & Defect Tracking**:
   - If a known defect or workaround is discovered during development, document the symptom, root cause, fix, and prevention rule in [TROUBLESHOOTING_LOG.md](TROUBLESHOOTING_LOG.md).

---

## Submitting a Pull Request (PR)

1. Push your branch to your GitHub fork:
   ```bash
   git push origin feat/your-feature-name
   ```
2. Open a Pull Request against the `master` branch of `FaizanMominGit/GroupNav-Infrastructure`.
3. Provide a clear description of:
   - What changed and why.
   - Relevant issue or feature request links.
   - Proof of test execution (`npm test` output) and CDK synthesis.
4. Ensure all CI/CD pipeline checks pass.
5. Address any review comments promptly.

---

## Questions & Support

If you have questions or encounter issues:
- Check existing solutions in [TROUBLESHOOTING_LOG.md](TROUBLESHOOTING_LOG.md).
- Review architectural decisions in [GroupNav-Infrastructure-Plan.md](GroupNav-Infrastructure-Plan.md) and [docs/](docs/).
- Open an issue on [GitHub Issues](https://github.com/FaizanMominGit/GroupNav-Infrastructure/issues).
