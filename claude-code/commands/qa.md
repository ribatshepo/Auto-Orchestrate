---
name: qa
description: Guide the user through Quality Assurance & Testing processes (P-032 to P-037).
---

# /qa — Quality Assurance & Testing

Guides execution of QA and testing processes using qa-engineer and software-engineer agents.

## Processes Covered

| Process ID | Name | Owner | Description |
|------------|------|-------|-------------|
| P-032 | Test Architecture Design | qa-engineer | Design the test coverage strategy for a project — unit, integration, contract, performance — aligned to the deliverable Definition of Done established at Stage 2 (Scope Contract). |
| P-033 | Automated Test Framework | qa-engineer | SDET implements automated test suites integrated into the CI/CD pipeline so that all automated tests run on every pull request. Test failures block merge. |
| P-034 | Definition of Done Enforcement | qa-engineer | Verify all Definition of Done criteria before a story is counted as complete. CI gates enforce all automatable criteria. Human verification is required for criteria that cannot be automated. |
| P-035 | Performance Testing | qa-engineer | Establish performance baselines before optimization and validate P50/P95/P99 latency against SLOs before release. Performance testing is part of the Definition of Done for performance-sensitive deliverables. |
| P-036 | Acceptance Criteria Verification | software-engineer | PM or QA formally verifies each story against its acceptance criteria before story closure. This is the final human gate before a story enters the "done" column. |
| P-037 | Contract Testing | qa-engineer | Validate API contracts between services on every PR that touches API definitions. Prevent consumer services from breaking when provider APIs change. |

## Agents

- **qa-engineer**: Owns test planning, test execution, defect management, and quality metrics
- **software-engineer**: Supports unit testing and code coverage processes

## When to Use

Use /qa when:
- Creating or executing test plans
- Managing defect backlogs
- Running quality gate checks
- Generating test coverage reports

## How to Use

1. Select the process you need from the table above
2. The command will route to qa-engineer or software-engineer as appropriate
3. Follow process steps in `claude-code/processes/05_quality_assurance_testing.md`

## Related Commands

- `/active-dev` — Continuous quality during sprint
- `/release-prep` — Release qualification testing
- `/gate-review` — Gate 2/4 quality criteria review

## Process Reference

Full process definitions: `claude-code/processes/05_quality_assurance_testing.md`
