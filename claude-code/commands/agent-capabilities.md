# Agent Capabilities

Show the capabilities, scope, and process ownership for a specific agent or all agents.

## Instructions

If a specific agent is named in: $ARGUMENTS
Then read that agent's definition from `agents/<agent-name>.md` and show its full profile.

If no agent specified, show the summary matrix.

### Agent Summary Matrix

| Agent | Model | Scope | Key Processes |
|-------|-------|-------|---------------|
| `software-engineer` | opus | Production code, debugging, tests (L3-L5) | P-030, P-024, P-034 |
| `staff-principal-engineer` | sonnet | Architecture, RFCs, ADRs (L6-L9) | P-006, P-085, P-088 |
| `engineering-manager` | sonnet | Sprints, DORA, capacity, OKRs (EM-VP) | P-022, P-025, P-026, P-027, P-028, P-066, P-081, P-082 |
| `product-manager` | sonnet | Stories, backlog, acceptance, roadmaps | P-001, P-007, P-009, P-013, P-029 |
| `technical-program-manager` | sonnet | Dependencies, RAID, milestones | P-015, P-016, P-019, P-074, P-076 |
| `platform-engineer` | opus | CI/CD, golden paths, IDP (BUILDS) | P-044, P-047, P-048 |
| `cloud-engineer` | sonnet | Terraform, multi-cloud, IAM (PROVISIONS) | P-045, P-046 |
| `sre` | sonnet | SLOs, incidents, post-mortems (OPERATES) | P-054, P-055, P-056, P-057 |
| `security-engineer` | opus | Security reviews, threat modeling (read-only) | P-012, P-038, P-039, P-040 |
| `qa-engineer` | sonnet | Test architecture, DoD, performance | P-032, P-033, P-034, P-035, P-036, P-037 |
| `data-engineer` | opus | ETL/ELT, warehousing, dbt, streaming | P-049, P-050 |
| `ml-engineer` | opus | ML pipelines, model serving, experiments | P-051, P-052, P-053 |
| `technical-writer` | sonnet | API docs, runbooks, release notes | P-058, P-059, P-060, P-061 |

### Infrastructure Triad (Non-Overlapping)

```
platform-engineer  ──  BUILDS the Internal Developer Platform
                       CI/CD, golden paths, IaC modules, DX
                       
cloud-engineer     ──  PROVISIONS cloud infrastructure
                       Terraform/CDK, IAM, networking, FinOps
                       
sre                ──  OPERATES production systems
                       SLOs, incidents, monitoring, on-call
```

## Output

For the requested agent(s):
1. Read the agent definition from `agents/<name>.md`
2. Show: name, model, tools, description, scope boundaries
3. List owned processes with brief descriptions
4. Show which project phases the agent is most active in
5. Note any explicit scope exclusions or boundaries
