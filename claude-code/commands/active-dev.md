# Active Development Phase

Guide the user through processes that are continuously active during sprint execution.

## Phase: In Active Development

These categories run concurrently during every sprint:

### Sprint Delivery Execution (Category 4)

**Processes**: P-022 through P-031
**Primary agents**: `software-engineer`, `engineering-manager`, `product-manager`
**Reference**: `processes/04_sprint_delivery_execution.md`

Active processes:
- **Daily Standup** (P-026) — EM facilitates, all ICs report blockers
- **Feature Development** (P-030) — Software engineers implement stories
- **Sprint Review** (P-027) — Demo completed work to stakeholders
- **Sprint Retrospective** (P-028) — Team identifies improvements
- **Backlog Refinement** (P-029) — PM + EM groom upcoming stories
- **Sprint Delivery** (P-031) — Track velocity, burndown, completion

### Quality Assurance & Testing (Category 5)

**Processes**: P-032 through P-037
**Primary agents**: `qa-engineer`, `software-engineer`
**Reference**: `processes/05_quality_assurance_testing.md`

Active processes:
- **DoD Enforcement** (P-034) — Every story checked against Definition of Done before close
- **Acceptance Verification** (P-036) — QA validates acceptance criteria per story
- **Contract Testing** (P-037) — Run on every PR that changes API contracts
- **Test Architecture** (P-032) — QA maintains test strategy and frameworks
- **Automated Testing Framework** (P-033) — CI runs unit/integration/e2e tests

### Security & Compliance (Category 6)

**Processes**: P-038 through P-043
**Primary agents**: `security-engineer`, `software-engineer`
**Reference**: `processes/06_security_compliance.md`

Active processes:
- **SAST/DAST on Every PR** (P-039) — Security scans in CI pipeline
- **CVE Triage on Dependency Updates** (P-040) — Assess new vulnerabilities
- **Threat Modeling** (P-038) — Update threat model as architecture evolves
- **Security Exceptions** (P-041) — Process for accepted risks

### Documentation & Knowledge (Category 10)

**Processes**: P-058 through P-061
**Primary agents**: `technical-writer`, `software-engineer`
**Reference**: `processes/10_documentation_knowledge.md`

Active processes:
- **API Documentation** (P-058) — Update per API-changing story
- **ADR Publication** (P-060) — Write ADR per significant technical decision

## Agent Routing for Active Development

| Task Type | Primary Agent | Supporting Agents |
|-----------|---------------|-------------------|
| Feature implementation | `software-engineer` | `qa-engineer` |
| Bug fix | `software-engineer` | `sre` (if production) |
| API contract change | `software-engineer` | `qa-engineer`, `technical-writer` |
| Security finding | `security-engineer` | `software-engineer` |
| Test gap | `qa-engineer` | `software-engineer` |
| Architecture decision | `staff-principal-engineer` | `software-engineer` |
| Sprint ceremony | `engineering-manager` | `product-manager` |
| Dependency blocked | `technical-program-manager` | `engineering-manager` |

## Usage

What sprint activity do you need help with? I can:
- Guide a feature through implementation with the right quality checks
- Run a DoD enforcement check on completed stories
- Help with sprint ceremony preparation (review, retro, refinement)
- Triage a security finding or CVE
- Update documentation for API changes
