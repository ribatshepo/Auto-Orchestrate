# Development Workflow

Show the complete development workflow mapping agents to project phases.

## The Clarity of Intent Pipeline

```
 STAGE 1              STAGE 2              STAGE 3              STAGE 4
 Intent Frame    -->  Scope Contract  -->  Dependency Map  -->  Sprint Bridge
 (1-3 days)           (3-5 days)           (3-5 days)           (1-2 days)
     |                    |                    |                    |
 Intent Review       Scope Lock         Dependency           Sprint Readiness
    Gate                Gate            Acceptance Gate           Gate
```

## Agent Engagement by Phase

### Phase 1: Starting a New Project (`/new-project`)

```
Stage 1: Intent Frame
  product-manager ............ Drafts Intent Brief, defines problem
  engineering-manager ........ Validates capacity, co-owns gate
  staff-principal-engineer ... Technology vision alignment

Stage 2: Scope Contract  
  product-manager ............ Decomposes deliverables, defines DoD
  software-engineer .......... Technical estimation, story breakdown
  qa-engineer ................ Test strategy, acceptance criteria
  security-engineer .......... AppSec scope review (P-012)

Stage 3: Dependency Map
  technical-program-manager .. Maps dependencies, critical path
  engineering-manager ........ Resource conflict resolution
  staff-principal-engineer ... Cross-team architecture alignment

Stage 4: Sprint Bridge
  engineering-manager ........ Sprint goal, capacity validation
  product-manager ............ Story prioritization
  software-engineer .......... Story decomposition, estimation
```

### Phase 2: Active Development (`/active-dev`)

```
Continuous:
  software-engineer .......... Feature implementation (P-030)
  qa-engineer ................ DoD enforcement (P-034), testing (P-032-P-037)
  security-engineer .......... SAST/DAST per PR (P-039), CVE triage (P-040)
  technical-writer ........... API docs per API change (P-058)

Sprint Cadence:
  engineering-manager ........ Standups (P-026), review (P-027), retro (P-028)
  product-manager ............ Backlog refinement (P-029)
```

### Phase 3: Release Preparation (`/release-prep`)

```
Pre-Release:
  qa-engineer ................ Performance testing (P-035)
  platform-engineer .......... CI/CD pipeline verification (P-048)
  cloud-engineer ............. Infrastructure provisioning (P-045)
  sre ....................... Monitoring, alerting, SLO dashboards (P-054)
  technical-writer ........... Runbooks (P-059), release notes (P-061)
  technical-program-manager .. CAB review for HIGH-risk (P-076)
```

### Phase 4: Post-Launch (`/post-launch`)

```
Ongoing:
  sre ....................... SLO monitoring (P-054), incidents (P-055), on-call (P-057)
  
Scheduled:
  product-manager ............ Outcome measurement at 30/60/90 days (P-073)
  engineering-manager ........ Project post-mortem (P-070), OKR retro (P-072)
  sre ....................... Post-mortems after incidents (P-056)
```

### Phase 5: Organizational Operations (`/org-ops`)

```
Continuous/Cadenced:
  engineering-manager ........ Audit hierarchy (P-062-P-069), DORA (P-081)
  staff-principal-engineer ... RFCs (P-085), architecture patterns (P-088)
  product-manager ............ OKR cascade (P-078)
  technical-program-manager .. Capacity planning (P-082)
  platform-engineer .......... Tech debt tracking (P-086), DX survey (P-089)
  technical-writer ........... Knowledge transfer (P-092)
```

## Available Commands

| Command | Phase | Description |
|---------|-------|-------------|
| `/new-project` | Starting | Walk through 4-stage delivery pipeline |
| `/active-dev` | Development | Sprint execution guidance |
| `/release-prep` | Release | Release preparation checklist |
| `/post-launch` | Operations | Post-launch processes |
| `/org-ops` | Continuous | Organizational operations |
| `/assign-agent` | Any | Route task to correct agent |
| `/gate-review` | Starting | Run gate review checklist |
| `/process-lookup` | Any | Find process for a situation |
| `/agent-capabilities` | Any | Show agent profiles |
| `/sprint-ceremony` | Development | Facilitate sprint ceremonies |

## Quick Reference

Need to know which agent handles what? Use `/assign-agent <task description>`.
Need a specific process? Use `/process-lookup <situation>`.
Starting fresh? Use `/new-project`.
