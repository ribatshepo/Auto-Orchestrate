# Start a New Project

Guide the user through the core delivery pipeline for starting a new project.

## Phase: Project Initiation

Follow these categories in order, engaging the right agents at each stage:

### Stage 1: Intent & Strategic Alignment (Category 1)

**Processes**: P-001 through P-006
**Primary agents**: `product-manager`, `engineering-manager`, `staff-principal-engineer`
**Reference**: `processes/01_intent_strategic_alignment.md`

Steps:
1. **Articulate Intent** (P-001) — PM drafts the Intent Brief answering: Why are we doing this? What problem does it solve? Who benefits?
2. **Align to OKRs** (P-002) — Map deliverables to team/org OKRs
3. **Define Boundaries** (P-003) — Explicit in-scope / out-of-scope / deferred lists
4. **Intent Review Gate** (P-004) — PM + EM present to stakeholders. Pass criteria: clear problem statement, OKR alignment, boundary agreement
5. **Strategic Prioritization** (P-005) — Stack rank against competing initiatives
6. **Technology Vision Alignment** (P-006) — Staff/Principal validates tech direction fits architecture vision

**Gate**: Intent Review Gate (P-004) must PASS before proceeding.

### Stage 2: Scope Contract Management (Category 2)

**Processes**: P-007 through P-014
**Primary agents**: `product-manager`, `software-engineer`, `qa-engineer`, `security-engineer`
**Reference**: `processes/02_scope_contract_management.md`

Steps:
1. **Decompose Deliverables** (P-007) — Break intent into concrete deliverables with acceptance criteria
2. **Define Definition of Done** (P-008) — Per-story and per-epic DoD
3. **Define Success Metrics** (P-009) — Measurable outcomes tied to OKRs
4. **Register Assumptions & Risks** (P-010) — Initial RAID log entries
5. **Document Exclusions** (P-011) — Explicit "we are NOT building" list
6. **AppSec Scope Review** (P-012) — Security engineer reviews scope for security implications
7. **Scope Lock Gate** (P-013) — PM owns. All deliverables, DoD, metrics, risks documented
8. **Change Control** (P-014) — Process for handling scope changes post-lock

**Gate**: Scope Lock Gate (P-013) must PASS before proceeding.

**Also engage early**:
- **Security** (Category 6, P-038) — Threat modeling should begin during scope definition
- **Risk Management** (Category 13, P-075) — Risk register at Scope Lock

### Stage 3: Dependency Coordination (Category 3)

**Processes**: P-015 through P-021
**Primary agents**: `technical-program-manager`, `engineering-manager`, `staff-principal-engineer`
**Reference**: `processes/03_dependency_coordination.md`

Steps:
1. **Register Cross-Team Dependencies** (P-015) — Map all external team dependencies
2. **Analyze Critical Path** (P-016) — Identify blocking dependencies
3. **Resolve Resource Conflicts** (P-017) — Negotiate shared resource allocation
4. **Communication Plan** (P-018) — Establish sync cadences with dependent teams
5. **Dependency Acceptance Gate** (P-019) — All dependent teams acknowledge and commit
6. **Dependency Standups** (P-020) — Recurring sync for active dependencies
7. **Escalation Protocol** (P-021) — When and how to escalate blocked dependencies

**Gate**: Dependency Acceptance Gate (P-019) must PASS before proceeding.

### Stage 4: Sprint Bridge (Category 4)

**Processes**: P-022 through P-031
**Primary agents**: `engineering-manager`, `software-engineer`, `product-manager`
**Reference**: `processes/04_sprint_delivery_execution.md`

Steps:
1. **Author Sprint Goals** (P-022) — Clear, measurable sprint objectives
2. **Intent Trace** (P-023) — Every story traces back to intent brief
3. **Write Stories** (P-024) — Detailed user stories with acceptance criteria
4. **Sprint Readiness Gate** (P-025) — Stories refined, dependencies cleared, team committed

**Gate**: Sprint Readiness Gate (P-025) must PASS before sprint execution begins.

## Usage

To start a new project, I will:
1. Read the relevant process files for the current stage
2. Identify which agents should be involved
3. Guide you through each gate's pass criteria
4. Track progress through the 4-stage pipeline

What is the project you'd like to start? I'll begin with Stage 1 (Intent & Strategic Alignment).

### Phase 5: Pipeline Handoff (Optional — For Autonomous Implementation)

After Gate 4 (Sprint Readiness) passes, the project may be handed off to the auto-orchestrate
autonomous implementation pipeline.

**Trigger condition**: Sprint Kickoff Brief artifact is complete AND team elects autonomous mode.

**Gate check** (required before proceeding): Verify `gate-state.json` for the session confirms `gate_2_scope_lock.status == "passed"`. If not: `[GATE-BLOCK] Gate 2 (Scope Lock) has not passed. Bridge protocol requires gate_2_scope_lock.status == "passed". Run /gate-review scope-lock to complete gate review.`

**Steps**:
1. Extract `task_description` from Scope Contract per `claude-code/processes/bridge_protocol.md`
2. Determine scope flag: Frontend → "F", Backend → "B", Full Stack → "S"
3. Generate `session_id`: `"auto-orc-YYYYMMDD-{project_slug}"` (first 8 chars of project name, lowercased, hyphens for spaces)
4. Write handoff receipt to `.orchestrate/{session_id}/handoff-receipt.json`
5. Launch: `/auto-orchestrate "{task_description}" --scope {scope} --session_id {session_id}`

**Reference**: `claude-code/processes/bridge_protocol.md`

**Return path**: When /auto-orchestrate completes, implementation artifacts are in
`.orchestrate/{session_id}/stage-6/`. These feed back into Sprint 1 execution via `/sprint-ceremony`.

**Gate state check at each stage transition**:

Before Stage 2 (Scope Contract) begins:
- Check: `gate_1_intent_review.status == "passed"`
- If not: `[GATE-BLOCK] Gate 1 (Intent Review) has not passed. Cannot advance to Scope Contract. Run /gate-review intent-review to complete gate review.`

Before Stage 3 (Dependency Coordination) begins:
- Check: `gate_2_scope_lock.status == "passed"`
- If not: `[GATE-BLOCK] Gate 2 (Scope Lock) has not passed. Cannot advance to Dependency Coordination. Run /gate-review scope-lock to complete gate review.`

Before Stage 4 (Sprint Bridge) begins:
- Check: `gate_3_dependency_acceptance.status == "passed"`
- If not: `[GATE-BLOCK] Gate 3 (Dependency Acceptance) has not passed. Cannot advance to Sprint Bridge. Run /gate-review dependency-acceptance to complete gate review.`

Before /sprint-ceremony (execution):
- Check: `gate_4_sprint_readiness.status == "passed"`
- If not: `[GATE-BLOCK] Gate 4 (Sprint Readiness) has not passed. Cannot begin sprint execution. Run /gate-review sprint-readiness to complete gate review.`

Override: If `gate_N.override` is non-null with a valid `authorized_by` field, enforcement is waived for that gate only.
