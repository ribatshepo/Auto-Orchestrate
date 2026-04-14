# Assign Agent

Route a task to the correct agent based on the work type and organizational scope.

## Instructions

Analyze the user's task description: $ARGUMENTS

Then determine the correct agent using this decision tree:

### Decision Tree

1. **Is it code implementation, debugging, or unit tests?**
   -> `software-engineer` (L3-L5 IC scope)

2. **Is it cross-team architecture, RFCs, or ADRs?**
   -> `staff-principal-engineer` (L6-L9 advisory scope)

3. **Is it sprint planning, team health, capacity, or OKRs?**
   -> `engineering-manager` (EM through VP scope)

4. **Is it user stories, backlog, acceptance criteria, or roadmaps?**
   -> `product-manager` (APM through CPO scope)

5. **Is it cross-team dependencies, RAID logs, or milestone tracking?**
   -> `technical-program-manager`

6. **Is it CI/CD pipelines, golden paths, or developer platform?**
   -> `platform-engineer` (BUILDS the IDP)

7. **Is it Terraform, cloud provisioning, IAM, or FinOps?**
   -> `cloud-engineer` (PROVISIONS infrastructure)

8. **Is it SLOs, incident response, post-mortems, or on-call?**
   -> `sre` (OPERATES production)

9. **Is it security review, threat modeling, SAST/DAST, or CVE triage?**
   -> `security-engineer` (read-only analysis)

10. **Is it test architecture, test frameworks, or DoD enforcement?**
    -> `qa-engineer`

11. **Is it ETL/ELT pipelines, data warehousing, or dbt models?**
    -> `data-engineer`

12. **Is it ML pipelines, model serving, or experiment tracking?**
    -> `ml-engineer`

13. **Is it API docs, runbooks, release notes, or developer guides?**
    -> `technical-writer`

### Multi-Agent Tasks

Some tasks require multiple agents in sequence:

| Scenario | Agent Sequence |
|----------|---------------|
| New API endpoint | `software-engineer` -> `qa-engineer` -> `technical-writer` |
| Infrastructure change | `cloud-engineer` -> `platform-engineer` -> `sre` |
| Security remediation | `security-engineer` (assess) -> `software-engineer` (fix) -> `qa-engineer` (verify) |
| Architecture change | `staff-principal-engineer` (RFC) -> `software-engineer` (implement) |
| Production incident | `sre` (respond) -> `software-engineer` (fix) -> `sre` (post-mortem) |
| Data pipeline | `data-engineer` (build) -> `qa-engineer` (test) -> `sre` (monitor) |
| ML feature | `ml-engineer` (model) -> `software-engineer` (integrate) -> `sre` (serve) |

## Output

For the given task, provide:
1. **Primary agent** and why
2. **Supporting agents** if multi-agent coordination needed
3. **Relevant processes** (P-xxx) that apply
4. **Relevant phase** (new-project / active-dev / release-prep / post-launch / org-ops)
