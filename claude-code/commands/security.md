---
name: security
description: Guide the user through Security & Compliance processes (P-038 to P-043).
---

# /security — Security & Compliance

Guides execution of Security and Compliance processes using security-engineer and platform-engineer agents.

## Processes Covered

| Process ID | Name | Owner | Description |
|------------|------|-------|-------------|
| P-038 | Threat Modeling | security-engineer | Security Champion runs a STRIDE-based threat model for every new feature before development begins. AppSec reviews the output. No CRITICAL findings can be unresolved before feature development proceeds. |
| P-039 | SAST/DAST CI Integration | security-engineer + platform-engineer | Static Analysis Security Testing (SAST) and Dynamic Analysis Security Testing (DAST) scans integrated into the CI/CD pipeline. CRITICAL and HIGH findings block merge. |
| P-040 | CVE Triage | security-engineer | Security Champion reviews dependency update PRs for CVEs before approving. HIGH and CRITICAL CVEs escalate to AppSec immediately. Dependency update PRs cannot be merged with unreviewed HIGH/CRITICAL CVEs. |
| P-041 | Security Exception | security-engineer | Formal review and approval path for any deviation from security standards. AppSec reviews, CISO approves, Engineering Director is informed. Time-bounded exceptions only. |
| P-042 | Compliance Review | security-engineer | GRC team runs SOC 2 / ISO 27001 / GDPR compliance reviews on defined schedules and against new data-handling features. Findings tracked to closure with named owners and deadlines. |
| P-043 | Security Champions Training | security-engineer | AppSec Lead runs quarterly training for all Security Champions covering the current threat landscape, OWASP Top 10 updates, tool usage, and recent CVE patterns relevant to the codebase. |

## Agents

- **security-engineer**: Owns security reviews, vulnerability assessments, and compliance audits
- **platform-engineer**: Co-owns SAST/DAST pipeline integration (P-039)

## When to Use

Use /security when:
- Running security reviews before release
- Performing vulnerability assessments
- Managing compliance requirements
- Setting up SAST/DAST pipelines

## How to Use

1. Select the process you need from the table above
2. The command will route to security-engineer or platform-engineer as appropriate
3. Follow process steps in `claude-code/processes/06_security_compliance.md`

## Related Commands

- `/release-prep` — Pre-release security gate
- `/gate-review` — Security acceptance criteria

## Process Reference

Full process definitions: `claude-code/processes/06_security_compliance.md`
