---
name: infra
description: Guide the user through Infrastructure & Platform processes (P-044 to P-048).
---

# /infra — Infrastructure & Platform

Guides execution of Infrastructure and Platform processes using platform-engineer, cloud-engineer, and sre agents.

## Processes Covered

| Process ID | Name | Owner | Description |
|------------|------|-------|-------------|
| P-044 | Golden Path Adoption | platform-engineer | Create and maintain CI/CD templates as the default path for new services. The golden path must be the easiest option -- not the only option. Adoption is measured quarterly via developer NPS. |
| P-045 | Infrastructure Provisioning | cloud-engineer | All cloud resources provisioned via Infrastructure as Code (IaC). Manual provisioning is a policy violation. All IaC changes reviewed by a Cloud Engineer before apply. |
| P-046 | Environment Self-Service | platform-engineer | Developers request and provision environments via the developer portal (Backstage/Port) without raising tickets to cloud or platform teams. Reduces cognitive load and eliminates ticket queue delays. |
| P-047 | Cloud Architecture Review Board (CARB) | cloud-engineer | Weekly review of new cloud service adoptions, architecture pattern changes, and cost commitments above defined thresholds. Prevents ungoverned cloud sprawl, vendor lock-in, security gaps, and cost overruns. |
| P-048 | Production Release Management | sre | Structured release process ensuring all quality, security, and reliability gates pass before production deployment. Release Manager owns the go/no-go decision. No release proceeds without explicit authorization. |

## Agents

- **platform-engineer**: Owns infrastructure provisioning and configuration management
- **cloud-engineer**: Owns cloud resource management and cost optimization
- **sre**: Owns reliability processes and SLA management

## When to Use

Use /infra when:
- Provisioning or modifying infrastructure
- Managing cloud resources
- Setting up monitoring and alerting
- Running infrastructure health checks

## How to Use

1. Select the process you need from the table above
2. The command will route to platform-engineer, cloud-engineer, or sre as appropriate
3. Follow process steps in `claude-code/processes/07_infrastructure_platform.md`

## Related Commands

- `/release-prep` — Infrastructure readiness for release (P-048)
- `/post-launch` — Post-launch infrastructure monitoring

## Process Reference

Full process definitions: `claude-code/processes/07_infrastructure_platform.md`
