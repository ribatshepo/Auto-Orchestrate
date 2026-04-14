---
name: auto-orchestrate
description: |
  Autonomous orchestration loop. Enhances user input, spawns orchestrator
  repeatedly, loops until all tasks complete. Crash recovery via session checkpoints.
triggers:
  - auto-orchestrate
  - auto orchestrate
  - autonomous orchestration
  - orchestrate until done
  - run to completion
  - continue orchestration
arguments:
  - name: task_description
    type: string
    required: true
    description: The task or objective to orchestrate. Pass "c" to continue the most recent in-progress session. Not required when resuming an existing session.
  - name: session_id
    type: string
    required: false
    description: Resume a specific session by ID (e.g. "auto-orc-2026-01-29-inventory").
  - name: max_iterations
    type: integer
    required: false
    default: 100
    description: Override the maximum number of orchestrator spawns.
  - name: stall_threshold
    type: integer
    required: false
    default: 2
    description: Override the number of consecutive no-progress iterations before failing.
  - name: max_tasks
    type: integer
    required: false
    default: 50
    description: Override maximum total tasks allowed (LIMIT-001). Cap 100.
  - name: scope
    type: string
    required: false
    description: |
      Scope flag: "F"/"f" (Frontend), "B"/"b" (Backend), "S"/"s" (Full stack).
      When set, injects scope-specific audit/implementation specs into the enhanced prompt.
      If omitted, task_description is used as-is.
  - name: resume
    type: boolean
    required: false
    default: false
    description: Explicitly resume the latest in-progress session, ignoring task_description.
  - name: skip_planning
    type: boolean
    required: false
    default: false
    description: Skip P-series planning stages (P1-P4). Use when planning artifacts already exist or for tasks that do not require formal planning.
  - name: fast_path
    type: boolean
    required: false
    default: false
    description: Enable fast-path mode for trivial single-stage tasks. Bypasses full pipeline when the orchestrator determines only one agent is needed. Requires --skip-planning.
  - name: human_gates
    type: string
    required: false
    description: |
      Comma-separated list of stage numbers where the pipeline pauses for human review before proceeding.
      Example: "2,5" pauses after Stage 2 (specs) and Stage 5 (validation).
      Default: none (fully autonomous). Use "all" for every stage.
---

# Autonomous Orchestration Loop

## Pre-flight Component Verification

Before spawning Stage 0 (researcher), verify ALL 9 pipeline-critical components exist in manifest:

### Component Taxonomy

Throughout the pipeline system, components are classified as follows:

| Classification | Definition | Examples | Invocation |
|---------------|-----------|----------|------------|
| **Agent** | Autonomous role with its own `.md` definition in `agents/`, model assignment, and tool access. Can spawn subagents. | orchestrator, researcher, software-engineer, product-manager | `Agent(subagent_type: "<name>")` |
| **Skill** | Reusable capability with a `SKILL.md` in `skills/`, invoked inline by an agent or via the Skill tool. Cannot spawn subagents. | spec-creator, validator, codebase-stats, test-writer-pytest | Read and follow `SKILL.md` inline |

**Canonical classification** (authoritative across all pipelines):

| Component | Type | Used In |
|-----------|------|---------|
| orchestrator | agent | auto-orchestrate, auto-audit (remediation) |
| researcher | agent | auto-orchestrate (Stage 0), auto-debug (optional) |
| product-manager | agent | auto-orchestrate (P1-P2, Stage 1) |
| technical-program-manager | agent | auto-orchestrate (P3) |
| engineering-manager | agent | auto-orchestrate (P4) |
| software-engineer | agent | auto-orchestrate (Stage 3) |
| technical-writer | agent | auto-orchestrate (Stage 6) |
| auditor | agent | auto-audit (Phase A) |
| debugger | agent | auto-debug |
| spec-creator | **skill** | auto-orchestrate (Stage 2) |
| validator | **skill** | auto-orchestrate (Stage 5) |
| codebase-stats | **skill** | auto-orchestrate (Stage 4.5) |
| test-writer-pytest | **skill** | auto-orchestrate (Stage 4, optional) |
| docs-lookup | **skill** | auto-orchestrate (Stage 6, via technical-writer) |
| docs-write | **skill** | auto-orchestrate (Stage 6, via technical-writer) |
| docs-review | **skill** | auto-orchestrate (Stage 6, via technical-writer) |

> **TAXONOMY-001**: `spec-creator` and `validator` are ALWAYS skills, never agents. They are invoked inline by the orchestrator's subagents. Any document that classifies them as agents is in error — this table is authoritative.

### Pipeline Component Matrix

| Stage | Component Name | Type | Mandatory | Manifest Location |
|-------|---------------|------|-----------|-------------------|
| P1-P2 | product-manager | agent | YES | `agents[]` where `name == "product-manager"` |
| P3 | technical-program-manager | agent | YES | `agents[]` where `name == "technical-program-manager"` |
| P4 | engineering-manager | agent | YES | `agents[]` where `name == "engineering-manager"` |
| 0 | researcher | agent | YES | `agents[]` where `name == "researcher"` |
| 1 | product-manager | agent | YES | `agents[]` where `name == "product-manager"` |
| 2 | spec-creator | skill | YES | `skills[]` where `name == "spec-creator"` |
| 3 | software-engineer | agent | YES (one of) | `agents[]` where `name == "software-engineer"` |
| 3 | library-implementer-python | skill | NO (alternative) | `skills[]` where `name == "library-implementer-python"` |
| 4 | test-writer-pytest | skill | NO (Stage 4 optional) | `skills[]` where `name == "test-writer-pytest"` |
| 4.5 | codebase-stats | skill | YES | `skills[]` where `name == "codebase-stats"` |
| 5 | validator | skill | YES | `skills[]` where `name == "validator"` |
| 6 | technical-writer | agent | YES | `agents[]` where `name == "technical-writer"` |

### Verification Steps

1. Read `~/.claude/manifest.json`
2. Verify orchestrator agent exists at `~/.claude/agents/orchestrator.md`
3. For each component in the matrix:
   a. Check if component exists in the appropriate manifest array (`agents[]` or `skills[]`)
   b. For agents, also verify the `.md` file exists at `~/.claude/agents/<name>.md`
   c. Record result in `manifest_validation` object

4. Classify results:
   - **MANDATORY MISSING**: researcher, product-manager, technical-program-manager, engineering-manager, spec-creator, software-engineer, codebase-stats, validator, technical-writer
     - Abort with: `[MANIFEST-001] Mandatory {type} "{name}" not found in manifest. Stage {N} will fail. Aborting.`
   - **OPTIONAL MISSING**: library-implementer-python, test-writer-pytest
     - Warn: `[MANIFEST-WARN] Optional {type} "{name}" not found. Stage {N} may use alternatives.`
   - **ALL MANDATORY PRESENT**: proceed

5. Display pre-flight verification summary:
```
Pre-flight Manifest Check:
  ✓ product-manager (Stage P1-P2 + Stage 1, agent)
  ✓ technical-program-manager (Stage P3, agent)
  ✓ engineering-manager (Stage P4, agent)
  ✓ researcher (Stage 0, agent)
  ✓ spec-creator (Stage 2, skill)
  ✓ software-engineer (Stage 3, agent)
  ? library-implementer-python (Stage 3, optional skill)
  ? test-writer-pytest (Stage 4, optional skill)
  ✓ codebase-stats (Stage 4.5, skill)
  ✓ validator (Stage 5, skill)
  ✓ technical-writer (Stage 6, agent)
  Result: 10/10 mandatory present, 2 optional (0 missing)
```

6. Log: `[MANIFEST] Verified {checked_count}/{total_count} pipeline components. Missing: {missing_list or "none"}`

### Checkpoint Schema Addition

Record verification result in checkpoint:
```json
{
  "manifest_validation": {
    "checked_at": "<ISO-8601>",
    "total_checked": 12,
    "mandatory_present": 10,
    "mandatory_missing": [],
    "optional_present": ["library-implementer-python", "test-writer-pytest"],
    "optional_missing": [],
    "warnings": [],
    "components": [
      { "name": "product-manager", "type": "agent", "stage": "P1-P2", "mandatory": true, "found": true },
      { "name": "technical-program-manager", "type": "agent", "stage": "P3", "mandatory": true, "found": true },
      { "name": "engineering-manager", "type": "agent", "stage": "P4", "mandatory": true, "found": true },
      { "name": "researcher", "type": "agent", "stage": 0, "mandatory": true, "found": true },
      { "name": "product-manager", "type": "agent", "stage": 1, "mandatory": true, "found": true },
      { "name": "spec-creator", "type": "skill", "stage": 2, "mandatory": true, "found": true },
      { "name": "software-engineer", "type": "agent", "stage": 3, "mandatory": true, "found": true },
      { "name": "library-implementer-python", "type": "skill", "stage": 3, "mandatory": false, "found": true },
      { "name": "test-writer-pytest", "type": "skill", "stage": 4, "mandatory": false, "found": true },
      { "name": "codebase-stats", "type": "skill", "stage": 4.5, "mandatory": true, "found": true },
      { "name": "validator", "type": "skill", "stage": 5, "mandatory": true, "found": true },
      { "name": "technical-writer", "type": "agent", "stage": 6, "mandatory": true, "found": true }
    ]
  }
}
```

## Session Resume from Handoff

When /auto-orchestrate starts, check for an existing handoff receipt from /new-project:

### Fresh Start
If no prior session exists, start normally with the provided task_description.

### Handoff Resume
If starting from a /new-project handoff:
1. Look for `.orchestrate/{session_id}/handoff-receipt.json`
2. If found and `status == "pending"`:
   a. Load all 6 project fields from the receipt
   b. Use `task_description` from the receipt as the orchestration objective
   c. Update `status` to `"active"` in the receipt
   d. Log: `[HANDOFF] Resuming from /new-project handoff (gate: {trigger_gate})`
3. If found but `status != "pending"`: Treat as normal session (may already be in progress)
4. If not found: Treat as fresh start

### Handoff Validation (Enhanced)
If resuming from handoff, perform additional validation after loading:

5. **Validate `source_gate_status`** — If present, check that required gate was passed:
   - If `source_gate_status == "PASSED"`: proceed
   - If `source_gate_status != "PASSED"`: emit `[BRIDGE-BLOCK] Handoff receipt source_gate_status is "{status}", expected "PASSED". Bridge protocol requires gate passage before auto-orchestration.` Abort. Set checkpoint status to `"bridge_blocked"`.
6. **Check `scope_contract_path`** — If present, verify the file exists:
   - If file exists: log `[BRIDGE] Scope contract found at {path}`
   - If file missing: log `[BRIDGE-WARN] Scope contract path "{path}" not found. File may have been moved. Proceeding with task_description from receipt.`
7. **Extract `scope_flag`** — If present, use for scope resolution in Step 0d:
   - Store extracted flag for use in scope resolution
   - If `scope_flag` in receipt conflicts with `--scope` argument: argument takes precedence, log `[HANDOFF-OVERRIDE] --scope argument overrides handoff scope_flag`
8. Log validation result: `[HANDOFF-VALID] Gate: {gate}, Scope: {flag}, Contract: {path}`

### Handoff Receipt Path

`{working_dir}/.orchestrate/{session_id}/handoff-receipt.json`

The session_id follows the format: `auto-orc-{YYYYMMDD}-{project_slug}`

## Core Constraints — IMMUTABLE

| ID | Rule |
|----|------|
| AUTO-001 | **Orchestrator-only gateway** — Spawn ONLY `subagent_type: "orchestrator"`. Never spawn software-engineer, technical-writer, etc. directly. If 2 consecutive retries return empty output, abort with `[AUTO-001]` message. |
| AUTO-002 | **Mandatory stage completion** — Cannot declare `completed` unless `stages_completed` includes 0, 1, 2, 4.5, 5, and 6. Stage 4 (test-writer-pytest) is optional — included only when the product-manager (Stage 1) produces test tasks. If no Stage 4 tasks exist, Stage 4 is considered implicitly complete. |
| AUTO-003 | **Stage monotonicity with validation regression** — `current_pipeline_stage` only increases or holds, EXCEPT: when Stage 5 (Validation) fails AND the validator identifies implementation defects (not spec or architecture issues), the pipeline MAY regress to Stage 3 (Implementation) for targeted fixes. Regression rules: (1) Only Stage 5 → Stage 3 regression is permitted; (2) Maximum 3 regression cycles per session — tracked in `validation_regression_count`; (3) Each regression creates a new Stage 3 task with `blockedBy` referencing the failed Stage 5 task and `regression: true` flag; (4) After 3 regressions, the pipeline must proceed to termination or escalate to auto-debug; (5) Log `[REGRESS] Stage 5 → 3 regression {N}/3 — <reason>`. The high-water mark `stages_completed` is NOT modified on regression — Stage 3 remains "completed" but new fix tasks are injected. |
| AUTO-004 | **Post-implementation stage gate** — If Stage 3 done but 4.5/5/6 missing for 1+ iterations, set `mandatory_stage_enforcement: true` and inject missing-stage tasks. |
| AUTO-005 | **Checkpoint-before-spawn** — Write checkpoint to disk before every orchestrator spawn. |
| AUTO-006 | **No direct agent routing** — Never tell the orchestrator which agent to use; routing is its decision. |
| AUTO-008 | **Orchestrator delegation mandate** — The orchestrator MUST spawn subagents for ALL stage work. It must NEVER do research, analysis, implementation, testing, or documentation itself. Reading project files to "understand" the codebase is researcher work, not orchestrator work. |
| AUTO-009 | **Fast-path bypass** — When `fast_path: true` AND `skip_planning: true`, the orchestrator MAY bypass the full stage sequence if it determines the task requires only a single agent and fits within a single stage. Fast-path tasks still write a stage-receipt and proposed-tasks.json. The orchestrator reports `FAST_PATH: true` in PROPOSED_ACTIONS. Auto-orchestrate logs `[FAST-PATH] Single-stage execution — Stage <N> only`. Fast-path is NEVER available when scope is `frontend`, `backend`, or `fullstack` (scoped work always requires the full pipeline). |
| AUTO-007 | **Iteration history immutability** — Only append to `iteration_history`; never modify existing entries. |
| CEILING-001 | **Stage ceiling enforcement** — Calculate `STAGE_CEILING` from `stages_completed` before every spawn (Step 3a). Orchestrator MUST NOT work above STAGE_CEILING. Auto-fix missing `blockedBy` chains. |
| CHAIN-001 | **Mandatory blockedBy chains with independence exceptions** — Every proposed task for Stage N (N > 0) must include `blockedBy` referencing at least one Stage N-1 task. Auto-orchestrate validates and auto-fixes in Step 4.2. **Independence exception (CHAIN-002)**: When the product-manager (Stage 1) marks tasks as `independent: true` (no shared files, no data dependencies), independent task groups MAY progress through stages concurrently. Task A at Stage 3 and Task B at Stage 0 can execute in parallel if they are in different independence groups. Independence groups are declared in Stage 1 output and validated by the orchestrator. Tasks within the same independence group follow strict sequential staging. The orchestrator MUST NOT run two tasks from the same group at different stages simultaneously. |
| PROGRESS-001 | **Always-visible processing** — Output status lines before/after every tool call, spawn, and processing step. Never leave extended silence. See `commands/CONVENTIONS.md` for format. |
| PROGRESS-002 | **In-progress blocks completion** — Tasks with status `in_progress` mean background agents are still working. NEVER evaluate termination, declare completion, or mark stages done while `in_progress > 0`. Display running task count prominently. |
| DISPLAY-001 | **Task board at every iteration** — Show full task board with individual tasks grouped by stage at iteration start (Step 3) and post-iteration (Step 4.3). |
| SCOPE-001 | **Scope specification passthrough** — When scope is not `custom`, pass FULL scope spec (Appendix A/B) VERBATIM through every layer. Never summarize. |
| SCOPE-002 | **Scope template integrity** — A narrow user objective does not reduce the spec — all design principles, steps, and constraints still apply in full. |
| MANIFEST-001 | **Manifest-driven pipeline** — The orchestrator MUST read `~/.claude/manifest.json` at boot and use it as the authoritative registry for agent routing, skill discovery, and capability validation. Auto-orchestrate passes the manifest path in every orchestrator spawn. Agents MUST verify their mandatory skills exist in the manifest before invoking them. |
| PRE-RESEARCH-GATE | **Planning phase prerequisite** — Stage 0 (researcher) MUST NOT begin unless `planning_stages_completed` contains all four values `["P1", "P2", "P3", "P4"]` AND all four entries in `planning_gate_statuses` have value `"PASSED"`. Skip conditions: (1) `--skip-planning` flag is passed, or (2) checkpoint field `planning_skipped` is `true` (set when resuming a session that already has planning artifacts from a prior session). Error codes: `[PLAN-GATE-001]` through `[PLAN-GATE-004]` for each incomplete stage. |

## Execution Guard — AUTO-ORCHESTRATE IS A LOOP CONTROLLER, NOT A WORKER

╔══════════════════════════════════════════════════════════════════════════╗
║  AUTO-ORCHESTRATE MUST NEVER:                                           ║
║                                                                         ║
║  1. Read project files to understand the codebase or task domain        ║
║     (that is the researcher/orchestrator's job)                         ║
║  2. Create implementation/work tasks directly — ONLY create ONE         ║
║     parent tracking task (Step 2c), then let the orchestrator           ║
║     propose all work tasks via proposed-tasks.json                      ║
║  3. Spawn ANY agent type other than "orchestrator" (AUTO-001)           ║
║  4. Do analysis, planning, or implementation work itself                ║
║  5. "Identify services", "read documentation", "understand the          ║
║     architecture" — these are Stage 0 (researcher) activities           ║
║                                                                         ║
║  AUTO-ORCHESTRATE ONLY:                                                 ║
║  - Enhances the user prompt (Step 1)                                    ║
║  - Creates session infrastructure (Step 2)                              ║
║  - Spawns orchestrators in a loop (Step 3)                              ║
║  - Processes orchestrator results and manages tasks (Step 4)            ║
║  - Evaluates termination (Step 5)                                       ║
║                                                                         ║
║  If you catch yourself reading project docs, identifying services,      ║
║  or creating more than 1 task before the first orchestrator spawn       ║
║  — STOP. You are violating this guard.                                  ║
╚══════════════════════════════════════════════════════════════════════════╝

## Planning Phase Stages (P-Series)

The P-series stages implement the Clarity of Intent methodology (see `clarity_of_intent.md`). They execute sequentially before Stage 0 (Research) and produce planning artifacts that inform the AI execution pipeline. All four stages are MANDATORY for new projects. Each stage has one owner agent, one output artifact, one gate, and one or more triggered processes.

### P1: Intent Frame

| Field | Value |
|-------|-------|
| **Stage ID** | P1 |
| **Name** | Intent Frame |
| **Owner Agent** | `product-manager` |
| **Phase Mode** | `HUMAN_PLANNING` |
| **Input** | User's raw task description + project context |
| **Output Artifact** | Intent Brief (`.orchestrate/<session>/planning/P1-intent-brief.md`) |
| **Gate** | Intent Review |
| **Gate Pass Criteria** | Clear objective stated; stakeholders identified; measurable success criteria defined; explicit boundaries (what this is NOT); strategic context references a real OKR or priority |
| **Processes Triggered** | P-001 (Intent Articulation) |
| **max_turns** | 20 |

**Intent Brief Template** (agent MUST produce all 5 sections):

1. **Outcome** -- measurable end-state, not a feature description
2. **Beneficiaries** -- named user segment with before/after description
3. **Strategic Context** -- OKR or quarterly theme connection
4. **Boundaries** -- explicit exclusions (what this project is NOT)
5. **Cost of Inaction** -- what happens if we do not do this

**Intent Review Gate Logic**:

```
GATE_PASS = (
    artifact_exists(".orchestrate/<session>/planning/P1-intent-brief.md")
    AND section_count >= 5
    AND each_section_has_content(min_chars=50)
    AND outcome_is_measurable(section_1)  # contains a metric, percentage, or timeline
    AND boundaries_stated(section_4)       # at least one "NOT" exclusion
)

IF GATE_PASS:
    planning_gate_statuses.P1 = "PASSED"
    planning_stages_completed.append("P1")
    emit "[GATE] Intent Review: PASSED -- Intent Brief produced"
ELSE:
    planning_gate_statuses.P1 = "FAILED"
    emit "[GATE] Intent Review: FAILED -- <missing_sections>"
    # Retry: re-spawn product-manager with failure feedback
```

**Output format**: `[P1:PLANNING] Intent Frame -- product-manager -- P-001`

### P2: Scope Contract

| Field | Value |
|-------|-------|
| **Stage ID** | P2 |
| **Name** | Scope Contract |
| **Owner Agent** | `product-manager` |
| **Phase Mode** | `HUMAN_PLANNING` |
| **Input** | P1 Intent Brief (`.orchestrate/<session>/planning/P1-intent-brief.md`) |
| **Output Artifact** | Scope Contract (`.orchestrate/<session>/planning/P2-scope-contract.md`) |
| **Gate** | Scope Lock |
| **Gate Pass Criteria** | Every deliverable has named owner + Definition of Done; exclusions explicit; success metrics trace to Intent Brief outcome; assumptions with HIGH severity have validation plan |
| **Processes Triggered** | P-007 (Deliverable Decomposition), P-013 (Scope Lock Gate) |
| **max_turns** | 20 |

**Scope Contract Template** (agent MUST produce all 6 sections):

1. **Outcome Restatement** -- verbatim copy from Intent Brief Section 1
2. **Deliverables** -- table with columns: #, Deliverable, Description, Owner
3. **Definition of Done** -- table with columns: Deliverable, Done When (testable criteria)
4. **Explicit Exclusions** -- table with columns: Exclusion, Reason, Future Home
5. **Success Metrics** -- table with columns: Metric, Baseline, Target, Measurement Method, Timeline
6. **Assumptions and Risks** -- table with columns: Item, Type, Severity, Mitigation, Owner

**Scope Lock Gate Logic**:

```
GATE_PASS = (
    artifact_exists(".orchestrate/<session>/planning/P2-scope-contract.md")
    AND section_count >= 6
    AND deliverables_have_owners(section_2)      # every row has non-empty Owner
    AND deliverables_have_dod(section_3)          # every deliverable in section_2 has a DoD in section_3
    AND exclusions_present(section_4)             # at least one exclusion row
    AND metrics_trace_to_intent(section_5)        # at least one metric references Intent Brief outcome
    AND high_severity_items_have_plan(section_6)  # HIGH items have non-empty Mitigation
)

IF GATE_PASS:
    planning_gate_statuses.P2 = "PASSED"
    planning_stages_completed.append("P2")
    emit "[GATE] Scope Lock: PASSED -- Scope Contract produced"
ELSE:
    planning_gate_statuses.P2 = "FAILED"
    emit "[GATE] Scope Lock: FAILED -- <validation_failures>"
```

**Output format**: `[P2:PLANNING] Scope Contract -- product-manager -- P-007, P-013`

### P3: Dependency Map

| Field | Value |
|-------|-------|
| **Stage ID** | P3 |
| **Name** | Dependency Map |
| **Owner Agent** | `technical-program-manager` |
| **Phase Mode** | `HUMAN_PLANNING` |
| **Input** | P2 Scope Contract (`.orchestrate/<session>/planning/P2-scope-contract.md`) |
| **Output Artifact** | Dependency Charter (`.orchestrate/<session>/planning/P3-dependency-charter.md`) |
| **Gate** | Dependency Acceptance |
| **Gate Pass Criteria** | Every dependency has named owner + "needed by" date; critical path documented; escalation paths defined for all blocked dependencies |
| **Processes Triggered** | P-015 (Cross-Team Dependency Registration), P-016 (Critical Path Analysis) |
| **max_turns** | 20 |

**Dependency Charter Template** (agent MUST produce all 4 sections):

1. **Dependency Register** -- table with columns: ID, Dependent Team, Depends On, What Is Needed, By When, Status, Owner, Escalation Path
2. **Shared Resource Conflicts** -- table with columns: Resource, Competing Demands, Resolution
3. **Critical Path** -- sequential dependency chain showing minimum timeline
4. **Communication Protocol** -- table with columns: Mechanism, Cadence, Participants, Purpose

**Dependency Acceptance Gate Logic**:

```
GATE_PASS = (
    artifact_exists(".orchestrate/<session>/planning/P3-dependency-charter.md")
    AND section_count >= 4
    AND dependencies_have_owners(section_1)        # every row has non-empty Owner
    AND dependencies_have_dates(section_1)          # every row has non-empty By When
    AND critical_path_present(section_3)            # section_3 has at least one dependency chain
    AND escalation_paths_defined(section_1)         # blocked items have Escalation Path
)

IF GATE_PASS:
    planning_gate_statuses.P3 = "PASSED"
    planning_stages_completed.append("P3")
    emit "[GATE] Dependency Acceptance: PASSED -- Dependency Charter produced"
ELSE:
    planning_gate_statuses.P3 = "FAILED"
    emit "[GATE] Dependency Acceptance: FAILED -- <validation_failures>"
```

**Output format**: `[P3:PLANNING] Dependency Map -- technical-program-manager -- P-015, P-016`

### P4: Sprint Bridge

| Field | Value |
|-------|-------|
| **Stage ID** | P4 |
| **Name** | Sprint Bridge |
| **Owner Agent** | `engineering-manager` |
| **Phase Mode** | `HUMAN_PLANNING` |
| **Input** | P3 Dependency Charter + P2 Scope Contract |
| **Output Artifact** | Sprint Kickoff Brief (`.orchestrate/<session>/planning/P4-sprint-kickoff-brief.md`) |
| **Gate** | Sprint Readiness |
| **Gate Pass Criteria** | Sprint goal stated and connects to Scope Contract deliverable; intent trace visible (project intent -> deliverable -> sprint goal); all stories have acceptance criteria; dependencies due this sprint have status + contingency |
| **Processes Triggered** | P-022 (Sprint Goal Authoring), P-023 (Intent Trace Validation) |
| **max_turns** | 20 |

**Sprint Kickoff Brief Template** (agent MUST produce all 5 sections):

1. **Sprint Goal** -- one sentence stating what will be true at sprint end
2. **Intent Trace** -- three-line trace: Project Intent -> Scope Deliverable -> Sprint Goal
3. **Stories and Acceptance Criteria** -- table with columns: Story, Acceptance Criteria, Points, Assignee
4. **Dependencies Due This Sprint** -- table with columns: Dependency, Needed By, Current Status, Contingency if Late
5. **Definition of Done (Sprint Level)** -- bulleted checklist of completion criteria

**Sprint Readiness Gate Logic**:

```
GATE_PASS = (
    artifact_exists(".orchestrate/<session>/planning/P4-sprint-kickoff-brief.md")
    AND section_count >= 5
    AND sprint_goal_present(section_1)               # non-empty, one sentence
    AND intent_trace_complete(section_2)              # all three lines present
    AND stories_have_ac(section_3)                    # every story row has Acceptance Criteria
    AND dependencies_have_contingency(section_4)      # every dependency has Contingency if Late
)

IF GATE_PASS:
    planning_gate_statuses.P4 = "PASSED"
    planning_stages_completed.append("P4")
    emit "[GATE] Sprint Readiness: PASSED -- Sprint Kickoff Brief produced"
ELSE:
    planning_gate_statuses.P4 = "FAILED"
    emit "[GATE] Sprint Readiness: FAILED -- <validation_failures>"
```

**Output format**: `[P4:PLANNING] Sprint Bridge -- engineering-manager -- P-022, P-023`

### Planning Artifact Flow

```
User Input (task_description + project context)
  |
  v
P1-Research (researcher) --> P1 Intent Frame (product-manager) --> Intent Review Gate
  |                                    |
  |    answers "Why?" and "What outcome?"
  |    consumed by: P2 (Scope Contract)
  |                                    |
  v                                    v
P2-Research (researcher) --> P2 Scope Contract (product-manager) --> Scope Lock Gate
                                       |
       answers "What exactly?" and "What does done look like?"
       consumed by: P3 (Dependency Charter), Stage 0 (researcher)
                                       |
                                       v
                            P3 Dependency Map (TPM) --> Dependency Acceptance Gate
                                       |
              answers "Who else?" and "What is the critical path?"
              consumed by: P4 (Sprint Kickoff Brief), Stage 1 (product-manager)
                                       |
                                       v
                            P4 Sprint Bridge (EM) --> Sprint Readiness Gate
                                       |
              answers "What in the first sprint?"
              consumed by: Stage 1 (product-manager task decomposition)
                                       |
                                       v PRE-RESEARCH-GATE
                                       |
                            Stage 0 Research (researcher) --> ...

Stage 0: researcher reads P2 (Scope Contract) for research focus
Stage 1: product-manager reads all P1-P4 artifacts for task decomposition
Stages 2-6: unchanged (consume Stage 0/1 outputs as before)
```

### Planning Revision Protocol (PLAN-REV)

The planning flow supports **conditional backward edges** when a later stage discovers that an earlier stage's assumptions are invalid.

| ID | Rule |
|----|------|
| PLAN-REV-001 | **Revision trigger** — If P3 (Dependency Map) or P4 (Sprint Bridge) discovers that a dependency, resource conflict, or timeline constraint makes the P2 Scope Contract infeasible, the agent MUST emit a `[PLAN-REVISION]` signal in its output. |
| PLAN-REV-002 | **Revision scope** — A revision can target P2 (scope change) or P1 (intent change). It CANNOT skip — revising P1 requires re-running P2, P3, and P4. Revising P2 requires re-running P3 and P4. |
| PLAN-REV-003 | **Revision budget** — Maximum 2 revision cycles per planning phase. After 2 revisions, the pipeline proceeds with the current artifacts and logs `[PLAN-REV-CAP] Revision budget exhausted — proceeding with current planning artifacts`. |
| PLAN-REV-004 | **Revision artifact** — The revising agent writes a `P{N}-revision-rationale.md` explaining what changed and why before the target stage re-executes. |

**Revision signal format**:
```
[PLAN-REVISION] Target: P2 | Reason: <one-line reason>
Invalidating finding: <specific dependency/conflict that makes current scope infeasible>
Recommended change: <what should change in the target artifact>
```

**Revision flow**:
```
P1 → P2 → P3 ──[PLAN-REVISION Target:P2]──→ P2' → P3' → P4
                                                     │
P1 → P2 → P3 → P4 ──[PLAN-REVISION Target:P1]──→ P1' → P2' → P3' → P4'
```

**Gate handling on revision**: When a revision is triggered:
1. The triggering stage's gate status remains `"FAILED"` (it did not complete successfully)
2. The target stage's gate status is reset to `null`
3. All stages between target and trigger (inclusive) are removed from `planning_stages_completed`
4. `planning_revision_count` is incremented in checkpoint
5. Log: `[PLAN-REV] Revision {N}/2 — reverting to P{target} due to: <reason>`

**Checkpoint addition**:
```json
{
  "planning_revision_count": 0,
  "planning_revision_history": []
}
```

## Pipeline Stage Reference

| Stage | Name | Agent (`dispatch_hint`) | Mandatory | Artifact | Gate | Complete when |
|-------|------|------------------------|-----------|----------|------|---------------|
| P1 | Intent Frame | `product-manager` | **YES** | Intent Brief | Intent Review | Intent Brief produced; Intent Review gate PASSED |
| P2 | Scope Contract | `product-manager` | **YES** | Scope Contract | Scope Lock | Scope Contract produced; Scope Lock gate PASSED |
| P3 | Dependency Map | `technical-program-manager` | **YES** | Dependency Charter | Dependency Acceptance | Dependency Charter produced; Dependency Acceptance gate PASSED |
| P4 | Sprint Bridge | `engineering-manager` | **YES** | Sprint Kickoff Brief | Sprint Readiness | Sprint Kickoff Brief produced; Sprint Readiness gate PASSED |
| 0 | Research | `researcher` | **YES** | Research Document | -- | researcher task completed |
| 1 | Task Decomposition | `product-manager` | **YES** | Epic Decomposition | -- | product-manager task completed |
| 2 | Specification | `spec-creator` | **YES** | Technical Spec | -- | spec-creator task completed |
| 3 | Implementation | `software-engineer` / `library-implementer-python` | Per task | Production Code | -- | software-engineer task completed |
| 4 | Tests | `test-writer-pytest` | Per task | Test Suite | -- | test-writer-pytest task completed |
| 4.5 | Code Stats | `codebase-stats` | **YES** (post-impl) | Metrics Report | -- | codebase-stats task completed |
| 5 | Validation | `validator` | **YES** | Validation Report | -- | validator task completed |
| 6 | Documentation | `technical-writer` | **YES** | Documentation | -- | technical-writer task completed |

Unknown/no dispatch_hint → "Uncategorized".

## Configuration Defaults

| Parameter | Default | Description |
|-----------|---------|-------------|
| `MAX_ITERATIONS` | 100 | Hard cap on orchestrator spawns |
| `STALL_THRESHOLD` | 2 | Consecutive no-progress iterations before fail |
| `CHECKPOINT_DIR` | `.orchestrate/<session-id>/` | Primary checkpoint directory (project-local) |
| `SESSION_DIR` | `~/.claude/sessions` | Legacy fallback (read-only) |
| `SCOPE` | `custom` | Stack scope: `frontend`, `backend`, `fullstack`, or `custom` |

## Cross-Platform Output Format

All pipeline output (progress lines, task boards, gate statuses, stage summaries) MUST adhere to these format rules to ensure consistent rendering across Terminal, Claude Desktop, and VS Code extension.

### OUTPUT-001: Primary Format

Plain Markdown tables are the PRIMARY format for task boards, stage progress, and gate status displays. Markdown renders correctly in all three platforms.

### OUTPUT-002: Banner Format

ASCII bracket-prefix format for banners and progress lines. Use these prefixes:
- `[PLANNING]` -- P-series stage progress
- `[GATE]` -- Gate check results
- `[STAGE P1]` through `[STAGE P4]` -- Planning stage identification
- `[STAGE 0]` through `[STAGE 6]` -- Execution stage identification (existing)
- `[PRE-RESEARCH-GATE]` -- Planning-to-execution transition
- `[PLAN-GATE-NNN]` -- Planning gate error codes
- `[PLAN-SKIP]` -- Planning phase skipped
- `[PLAN-REUSE]` -- Planning artifacts reused from prior session

### OUTPUT-003: No ANSI in Artifacts

ANSI escape codes MUST NOT appear in stored artifacts (any file under `.orchestrate/` or `.domain/`). ANSI coloring is permitted ONLY for live TTY output. Always provide a plain-text fallback. Rationale: Claude Desktop and VS Code extension render Markdown but not ANSI escape codes.

### OUTPUT-004: Unicode Policy

Unicode box-drawing characters (e.g., the task board in Step 3c) are acceptable in live terminal output and documentation. They MUST NOT appear in structured output fields (JSON values in checkpoint, stage-receipt, or proposed-tasks files).

### OUTPUT-005: Progress Line Format

P-series progress lines follow this exact format:

**Stage start**:
```
[P1:PLANNING] Intent Frame -- product-manager -- P-001
```
Format: `[<stage>:PLANNING] <name> -- <agent> -- <process_ids>`

**Stage completion**:
```
[P1:PASSED] Intent Review gate passed -- Intent Brief produced
```
Format: `[<stage>:PASSED] <gate_name> gate passed -- <artifact_name> produced`

**Stage failure**:
```
[P1:FAILED] Intent Review gate failed -- missing: Boundaries, Cost of Inaction
```
Format: `[<stage>:FAILED] <gate_name> gate failed -- missing: <sections>`

### Planning Phase Task Board

During the planning phase, the task board (DISPLAY-001) shows planning stages instead of execution stages:

```
 PLANNING PHASE TASK BOARD:
 +----- P1 (Intent Frame) ---------------------------------
 |  [done] Intent Brief produced -- product-manager
 |  [done] Intent Review: PASSED
 +----- P2 (Scope Contract) --------------------------------
 |  >> Scope Contract in progress -- product-manager
 |  .. Scope Lock: PENDING
 +----- P3 (Dependency Map) --------------------------------
 |  [blocked] Dependency Charter -- technical-program-manager  [blocked by P2]
 |  .. Dependency Acceptance: PENDING
 +----- P4 (Sprint Bridge) ---------------------------------
 |  [blocked] Sprint Kickoff Brief -- engineering-manager      [blocked by P3]
 |  .. Sprint Readiness: PENDING
 +----------------------------------------------------------
 Legend: [done] passed  >> in progress  [blocked] blocked  .. pending
```

### Markdown Table Format for Gate Status

At each iteration, the planning phase status is shown as a Markdown table when relevant:

| Stage | Gate | Status | Artifact |
|-------|------|--------|----------|
| P1: Intent Frame | Intent Review | PASSED | P1-intent-brief.md |
| P2: Scope Contract | Scope Lock | PASSED | P2-scope-contract.md |
| P3: Dependency Map | Dependency Acceptance | PASSED | P3-dependency-charter.md |
| P4: Sprint Bridge | Sprint Readiness | PASSED | P4-sprint-kickoff-brief.md |

---

## Step 0: Autonomous Mode Declaration

### 0-pre. Continue Shorthand

If `task_description` is `"c"` (case-insensitive): treat as `resume: true`, skip Steps 0a and 1, jump to Step 2b. If no in-progress session found, abort.

### 0a. Permission Grant

Display once:

> **Autonomous mode requested.** This will:
> - Create/update files in `.orchestrate/<session-id>/` and `~/.claude/plans/`
> - Spawn orchestrator and subagents without further prompts
> - Make reasonable assumptions instead of asking clarifying questions
> - Run up to {{MAX_ITERATIONS}} orchestrator iterations
>
> **Proceed autonomously?** (Y/n)

If declined, abort: `"Auto-orchestration cancelled. Use /workflow-plan for interactive planning."`

Record in checkpoint: `"permissions": { "autonomous_operation": true, "session_folder_access": true, "no_clarifying_questions": true, "granted_at": "<ISO-8601>" }`

### 0b. Inline Processing Rule

Step 1 runs INLINE. Do NOT delegate to `workflow-plan` or use `EnterPlanMode`.

### 0c. Human-Input Treatment

Command arguments are **human-authored input**: preserve context, don't reinterpret meaning, document assumptions when resolving ambiguity.

### 0d. Scope Resolution

| Flag | Resolved | Layers |
|------|----------|--------|
| `F`/`f` | `frontend` | `["frontend"]` |
| `B`/`b` | `backend` | `["backend"]` |
| `S`/`s` | `fullstack` | `["backend", "frontend"]` |
| *(omitted)* | `custom` | `[]` |

**Preprocessing**: Strip surrounding quotes recursively, then trim whitespace.

**Inline flag extraction** (when `scope` not provided separately): If the first non-whitespace token is **exactly one character** matching `F/f/B/b/S/s` followed by space or end-of-string, extract as scope flag. Multi-character tokens (e.g., "fix") are NEVER flags.

**Default objectives** (when only a flag is provided):

| Scope | Default |
|-------|---------|
| `backend` | Build or complete all backend features to production-ready state, then audit and fully integrate — real implementations, proper persistence, zero placeholders |
| `frontend` | Build or complete all frontend features to production-ready state, then audit and fully integrate — every UI page, form, and API integration with child-friendly usability |
| `fullstack` | Build or complete all features across backend and frontend to production-ready state — full stack, zero placeholders, production-ready end-to-end |

Record: `"scope": { "flag": "<letter>", "resolved": "<scope>", "layers": [...] }`

### 0e. Manifest Validation

Verify that `~/.claude/manifest.json` exists and contains the `orchestrator` agent definition:

```bash
test -f ~/.claude/manifest.json && grep -q '"orchestrator"' ~/.claude/manifest.json && echo "PASS" || echo "FAIL"
```

If FAIL: abort with `[AO-GAP-002] Manifest missing or orchestrator agent not found at ~/.claude/manifest.json. Cannot proceed.`

### 0f. Domain Memory and Shared State Initialization

Ensure the `.domain/` and `.pipeline-state/` directories exist at the project root:

```bash
mkdir -p .domain
mkdir -p .pipeline-state
```

**`.domain/`** persists **cross-session, cross-command** domain knowledge (research findings, error→fix mappings, patterns, architecture decisions, codebase analysis, user preferences). All stores are append-only JSONL with file locking for concurrency safety. Pass `DOMAIN_MEMORY_DIR=.domain` in the orchestrator spawn prompt.

**`.pipeline-state/`** enables **cross-pipeline knowledge transfer** between auto-orchestrate, auto-audit, and auto-debug. See `_shared/protocols/cross-pipeline-state.md` for the full protocol.

**On startup**, read shared state:
1. Read `.pipeline-state/escalation-log.jsonl` — consume unconsumed escalations from auto-debug (mark as `consumed: true`)
2. Read `.pipeline-state/codebase-analysis.jsonl` — pass high-severity insights to researcher prompt
3. Read `.pipeline-state/pipeline-context.json` — log if another pipeline was recently active
4. Pass `PIPELINE_STATE_DIR=.pipeline-state` in the orchestrator spawn prompt

**On termination**: Update `.pipeline-state/pipeline-context.json` with final session state.

### 0g. Project Type Detection

Classify the target project as `greenfield`, `existing`, or `continuation` to adapt pipeline behavior. Detection uses metadata operations only (git history, file counts, file existence) — no source file reading (preserves Execution Guard).

**Detection Signals**:

```bash
# SIGNAL 1: Git History Depth
COMMIT_COUNT=$(git rev-list HEAD --count 2>/dev/null || echo "0")

# SIGNAL 2: Source File Count
SOURCE_FILE_COUNT=$(find . -maxdepth 3 -type f \( -name "*.py" -o -name "*.ts" -o -name "*.js" -o -name "*.go" -o -name "*.rs" -o -name "*.java" -o -name "*.rb" \) | wc -l)

# SIGNAL 3: Handoff Receipt Presence
HANDOFF_PRESENT=$(test -f .orchestrate/${SESSION_ID}/handoff-receipt.json && echo "present" || echo "absent")

# SIGNAL 4: Prior Orchestration History
PRIOR_SESSION_COUNT=$(ls -d .orchestrate/auto-orc-*/checkpoint.json 2>/dev/null | wc -l)
```

**Classification Logic**:

```
IF PRIOR_SESSION_COUNT > 0 AND any prior session has status "in_progress" or "superseded":
  project_type = "continuation"
ELSE IF COMMIT_COUNT < 5 AND SOURCE_FILE_COUNT < 10:
  project_type = "greenfield"
ELSE:
  project_type = "existing"
```

**Store in checkpoint**:

```json
{
  "project_type": "greenfield|existing|continuation",
  "project_detection": {
    "commit_count": 0,
    "source_file_count": 0,
    "handoff_present": false,
    "prior_session_count": 0,
    "detected_at": "<ISO-8601>"
  }
}
```

**Pass to orchestrator spawn prompt**: Add `PROJECT_TYPE: <type>` in the spawn prompt context.

**Inject into enhanced prompt**:

| Project Type | Context Injected |
|-------------|------------------|
| `greenfield` | `**Project Type**: Greenfield. This is a new project requiring scaffolding, architecture decisions, dependency selection, and initial project structure. The researcher (Stage 0) should prioritize: technology selection, project scaffolding patterns, dependency evaluation. The product-manager (Stage 1) should include scaffolding tasks.` |
| `existing` | `**Project Type**: Existing codebase. This project has established patterns, existing dependencies, and production code. The researcher (Stage 0) should prioritize: codebase analysis, change impact assessment, existing pattern identification. The product-manager (Stage 1) should include regression risk analysis.` |
| `continuation` | `**Project Type**: Continuation of prior orchestration session. Previous session context is available in .orchestrate/. The researcher (Stage 0) should check prior research output and build incrementally.` |

**Detection MUST NOT read project source files** — only metadata (git log, file counts, file existence). Source file reading is the researcher's job (Stage 0).

Log: `[DETECT] Project type: <classification> (commits: <N>, source files: <N>, prior sessions: <N>)`

### 0h-pre. Complexity Triage Gate (TRIAGE-001)

Before entering the planning phase, classify the task complexity to determine whether full P1-P4 planning is warranted.

**Triage signals** (from user input text only — no file reading):

| Signal | Trivial | Medium | Complex |
|--------|---------|--------|---------|
| Word count of task_description | < 20 words | 20-100 words | > 100 words |
| Explicit scope flag | No flag (custom) | Single flag (F/B) | Fullstack (S) |
| Keywords: "fix", "typo", "config", "bump" | Present | — | — |
| Keywords: "build", "implement", "create", "redesign" | — | — | Present |
| Keywords: "refactor", "update", "add", "improve" | — | Present | — |
| Multiple deliverables mentioned | No | 1-2 | 3+ |
| `project_type` (from Step 0g) | Any | existing | greenfield |

**Classification logic**:
```
trivial_signals = count of Trivial column matches
complex_signals = count of Complex column matches

IF trivial_signals >= 3 AND complex_signals == 0:
    complexity = "trivial"
ELSE IF complex_signals >= 2 OR scope == "fullstack":
    complexity = "complex"
ELSE:
    complexity = "medium"
```

**Triage routing**:

| Complexity | Planning | Pipeline |
|-----------|----------|----------|
| `trivial` | **SKIP** P1-P4 (auto-set `planning_skipped: true`) | Full pipeline (Stage 0-6) unless `fast_path: true` |
| `medium` | **SKIP** P1-P4 (auto-set `planning_skipped: true`) | Full pipeline (Stage 0-6) |
| `complex` | **REQUIRE** P1-P4 (proceed to Step 0h) | Full pipeline (Stage 0-6) |

**Override**: The `--skip-planning` flag always wins. The triage gate only applies when `skip_planning` is not explicitly set.

**Process scope classification (PROCESS-SCOPE-001)**:

After determining complexity, classify the process scope. This determines which injection hooks from the expanded process injection map (`processes/process_injection_map.md`) are active for this session.

**Domain flag detection** (from user input text only — same constraint as triage signals):

| Domain Flag | Detection Keywords |
|-------------|-------------------|
| `infra` | "deploy", "infrastructure", "kubernetes", "k8s", "docker", "CI/CD", "pipeline", "terraform", "cloud" |
| `data_ml` | "data pipeline", "ETL", "ML", "model", "training", "dataset", "schema migration", "dbt", "streaming" |
| `sre` | "SLO", "incident", "monitoring", "on-call", "reliability", "observability", "alerting" |
| `risk` | "risk", "compliance", "regulatory", "audit", "RAID" |

```
domain_flags = []
FOR EACH (flag, keywords) IN DOMAIN_FLAG_TABLE:
    IF any keyword IN lowercase(task_description + scope_specification):
        domain_flags.append(flag)

# Process scope tier follows complexity tier
process_scope_tier = complexity  # trivial, medium, or complex

# Active processes determined by tier
IF process_scope_tier == "trivial":
    active_processes = ["P-001", "P-007", "P-033", "P-034"]
    active_categories = [1, 2, 5]
    domain_guides_enabled = []
ELSE IF process_scope_tier == "medium":
    active_processes = CORE_PROCESSES + MEDIUM_PROCESSES  # ~27 processes
    active_categories = [1, 2, 5, 6, 10]
    domain_guides_enabled = ["/security", "/qa"]
ELSE:  # complex
    active_processes = CORE + MEDIUM + COMPLEX_PROCESSES  # base ~42
    active_categories = [1, 2, 3, 5, 6, 10, 12, 13, 16]
    domain_guides_enabled = ["/security", "/qa", "/risk"]
    # Add domain-conditional categories
    IF "infra" IN domain_flags:
        active_categories += [7]
        domain_guides_enabled += ["/infra"]
        active_processes += INFRA_PROCESSES  # P-044-048
    IF "data_ml" IN domain_flags:
        active_categories += [8]
        domain_guides_enabled += ["/data-ml-ops"]
        active_processes += DATA_ML_PROCESSES  # P-049-053
    IF "sre" IN domain_flags:
        active_categories += [9]
        active_processes += SRE_PROCESSES  # P-054-057
    IF "risk" IN domain_flags:
        active_processes += RISK_PROCESSES  # P-074-077 (already in domain_guides)
```

**Checkpoint addition**:
```json
{
  "triage": {
    "complexity": "trivial|medium|complex",
    "signals": { "trivial": 0, "medium": 0, "complex": 0 },
    "planning_skipped_by_triage": false,
    "classified_at": "<ISO-8601>",
    "process_scope": {
      "tier": "trivial|medium|complex",
      "domain_flags": [],
      "active_categories": [],
      "domain_guides_enabled": [],
      "total_active": 0
    }
  }
}
```

Log: `[TRIAGE] Complexity: <classification> (trivial: <N>, medium: <N>, complex: <N> signals). Planning: <SKIP|REQUIRE>.`
Log: `[PROCESS-SCOPE] Tier: <tier>. Domain flags: <flags>. Active categories: <N>. Domain guides: <guides>. Total processes: <count>.`

### 0h. Planning Phase Gate (PRE-RESEARCH-GATE)

Before proceeding to Step 1 (Enhance User Input) and the execution pipeline, verify that all four planning stages have been completed.

**Skip conditions** (check FIRST):

1. `--skip-planning` flag was passed as a command argument
   - Set `planning_skipped: true` in checkpoint
   - Log: `[PLAN-SKIP] --skip-planning flag set. Bypassing planning phase.`
   - Proceed directly to Step 1

2. Complexity triage (Step 0h-pre) classified task as `trivial` or `medium`:
   - Set `planning_skipped: true` and `planning_skipped_by_triage: true` in checkpoint
   - Log: `[PLAN-SKIP] Triage classified task as <complexity>. Bypassing planning phase.`
   - Proceed directly to Step 1

3. Planning artifacts already exist from a prior session or manual creation:
   - Check for existence of ALL four files:
     - `.orchestrate/<session>/planning/P1-intent-brief.md`
     - `.orchestrate/<session>/planning/P2-scope-contract.md`
     - `.orchestrate/<session>/planning/P3-dependency-charter.md`
     - `.orchestrate/<session>/planning/P4-sprint-kickoff-brief.md`
   - If ALL four exist:
     - Set `planning_skipped: true` and `planning_stages_completed: ["P1","P2","P3","P4"]`
     - Set all `planning_gate_statuses` to `"PASSED"`
     - Log: `[PLAN-REUSE] Planning artifacts found from prior session. Skipping planning phase.`
     - Proceed directly to Step 1

4. Handoff receipt from `/new-project` has `planning_complete: true`:
   - Set checkpoint fields as in condition 3
   - Log: `[PLAN-HANDOFF] Planning completed in /new-project handoff. Skipping planning phase.`
   - Proceed directly to Step 1

**Gate enforcement** (if no skip condition met):

```
planning_complete = (
    "P1" in planning_stages_completed
    AND "P2" in planning_stages_completed
    AND "P3" in planning_stages_completed
    AND "P4" in planning_stages_completed
    AND planning_gate_statuses.P1 == "PASSED"
    AND planning_gate_statuses.P2 == "PASSED"
    AND planning_gate_statuses.P3 == "PASSED"
    AND planning_gate_statuses.P4 == "PASSED"
)

IF planning_complete:
    Log: "[PRE-RESEARCH-GATE] All planning stages complete. Proceeding to execution pipeline."
    Proceed to Step 1.

ELSE:
    # Determine which stages are incomplete and report error codes
    IF "P1" not in planning_stages_completed OR planning_gate_statuses.P1 != "PASSED":
        emit "[PLAN-GATE-001] P1 Intent Frame incomplete. Intent Brief missing or Intent Review gate not passed."
    IF "P2" not in planning_stages_completed OR planning_gate_statuses.P2 != "PASSED":
        emit "[PLAN-GATE-002] P2 Scope Contract incomplete. Scope Contract missing or Scope Lock gate not passed."
    IF "P3" not in planning_stages_completed OR planning_gate_statuses.P3 != "PASSED":
        emit "[PLAN-GATE-003] P3 Dependency Map incomplete. Dependency Charter missing or Dependency Acceptance gate not passed."
    IF "P4" not in planning_stages_completed OR planning_gate_statuses.P4 != "PASSED":
        emit "[PLAN-GATE-004] P4 Sprint Bridge incomplete. Sprint Kickoff Brief missing or Sprint Readiness gate not passed."

    # Determine next planning stage to execute
    next_planning_stage = first stage in [P1, P2, P3, P4] where status != "PASSED"
    Set current_planning_stage = next_planning_stage
    Log: "[PRE-RESEARCH-GATE] Planning incomplete. Next: Stage {next_planning_stage}."

    # Execute planning loop
    FOR each stage in [P1, P2, P3, P4] where gate_status != "PASSED":

        Log: "[P{N}:START] Executing {stage_name} -- Agent: {agent}"

        ## P1 and P2 Research Sub-Step
        IF stage is P1 OR stage is P2:
            Log: "[P{N}:RESEARCH] Spawning researcher for planning research"
            Spawn researcher agent with prompt:
              - P1 research: Investigate the project domain, existing codebase structure,
                stakeholder needs, competitive landscape, and technical constraints.
                Use WebSearch (3+ queries) for domain best practices, market context,
                and similar project approaches. Output findings that will inform
                the Intent Brief.
              - P2 research: Investigate technical feasibility, effort estimation patterns,
                dependency risks, and scope precedents. Use WebSearch (3+ queries)
                for effort estimation baselines, scope management best practices,
                and risk quantification approaches. Output findings that will inform
                the Scope Contract.
            Output: .orchestrate/<session>/planning/P{N}-research.md
            Log: "[P{N}:RESEARCH-DONE] Research complete -- feeding into {stage_name}"

        ## Agent Spawn
        Spawn the stage's designated agent (via orchestrator with PHASE: HUMAN_PLANNING):
          - P1: product-manager -> produces Intent Brief
                 (receives P1-research.md as additional input)
          - P2: product-manager -> produces Scope Contract
                 (receives P1 Intent Brief + P2-research.md as input)
          - P3: technical-program-manager -> produces Dependency Charter
                 (receives P2 Scope Contract as input)
          - P4: engineering-manager -> produces Sprint Kickoff Brief
                 (receives P3 Dependency Charter + P2 Scope Contract as input)

        ## Gate Validation
        Verify the stage artifact was produced at the expected path.
        IF artifact exists AND meets gate criteria:
            Set planning_gate_statuses.{gate} = "PASSED"
            Append stage to planning_stages_completed
            Set planning_artifacts.{artifact_key} = "<path>"
            Log: "[P{N}:PASSED] {gate_name} gate passed -- artifact: {filename}"
        ELSE:
            Log: "[P{N}:FAILED] {gate_name} gate failed -- artifact missing or incomplete"
            Retry once. If still failed, log error and continue to next iteration.

        ## Progress Display
        Display planning progress:
        ```
        [PLANNING] P1 V -> P2 V -> P3 > -> P4 o
        ```

        Write checkpoint after each planning stage completion.

    # All planning stages complete
    Log: "[PRE-RESEARCH-GATE] All planning stages complete. Proceeding to execution pipeline."
    Proceed to Step 1.
```

**Planning loop is SELF-CONTAINED** -- it does NOT reuse Step 3. It runs inline at Step 0h before the main orchestration loop begins. Each planning stage is executed sequentially by spawning the orchestrator with `PHASE: HUMAN_PLANNING` context, which routes to the correct agent per the Planning Phase Routing in orchestrator.md.

**Error Code Reference**:

| Error Code | Stage | Meaning | Recovery Action |
|------------|-------|-------P3--|-----------------|
| `[PLAN-GATE-001]` | P1 | Intent Brief missing or Intent Review gate failed | Spawn product-manager in HUMAN_PLANNING mode for P1 |
| `[PLAN-GATE-002]` | P2 | Scope Contract missing or Scope Lock gate failed | Spawn product-manager in HUMAN_PLANNING mode for P2 (requires P1 PASSED) |
| `[PLAN-GATE-003]` | P3 | Dependency Charter missing or Dependency Acceptance gate failed | Spawn technical-program-manager for P3 (requires P2 PASSED) |
| `[PLAN-GATE-004]` | P4 | Sprint Kickoff Brief missing or Sprint Readiness gate failed | Spawn engineering-manager for P4 (requires P3 PASSED) |

---

## Step 0g: Pre-Session Dispatch Check

Evaluate pre-session dispatch triggers per `_shared/protocols/command-dispatch.md`:

### 0g.1 Check for handoff receipt (TRIG-004)

```
IF NOT exists(".orchestrate/<session-id>/handoff-receipt.json"):
    display "[DISPATCH-SUGGEST] TRIG-004: No handoff receipt found."
    display "  Consider running /new-project first to create planning artifacts."
    display "  Proceeding with standalone session."
    append to checkpoint.dispatch_log:
      { trigger_id: "TRIG-004", command: "/new-project", tier: 1,
        action: "suggested", timestamp: now_iso8601() }
```

Do NOT block the session — this is Tier 1 (suggest only).

### 0g.2 Consume unconsumed dispatch receipts from prior sessions

```
IF exists(".pipeline-state/"):
    scan .pipeline-state/ for cross-session dispatch context
    IF found dispatch receipts with consumed: false:
        FOR EACH unconsumed receipt:
            inject receipt.next_action context into enhanced prompt (Step 1)
            mark receipt consumed: true, consumed_at: now_iso8601()
            log "[DISPATCH-RESUME] Consumed prior dispatch receipt: {dispatch_id}"
```

### 0g.3 Detect release flag

```
IF task_description contains "release", "deploy to production", "ship", "go live"
   OR user passed --release flag:
    checkpoint.release_flag = true
    log "[DISPATCH] Release flag detected — TRIG-005 will evaluate at termination"
```

### 0g.4 Initialize dispatch checkpoint fields

```json
{
  "dispatch_log": [],
  "dispatch_context": { "0": [], "1": [], "2": [], "3": [], "4": [], "4.5": [], "5": [], "6": [] },
  "dispatch_gates": {},
  "dispatch_summary": null,
  "release_flag": false
}
```

These fields have safe defaults for backward compatibility — existing sessions that lack them are treated as having empty dispatch state.

### 0g.5 Initialize domain activation checkpoint fields

```json
{
  "domain_activations": [],
  "domain_reviews": { "0": [], "1": [], "2": [], "3": [], "4": [], "4.5": [], "5": [], "6": [] }
}
```

These fields track conditional domain agent activations per `_shared/protocols/agent-activation.md`. `domain_activations` is an append-only log of all activations; `domain_reviews` maps stages to agent names that produced reviews.

---

## Step 1: Enhance User Input (Inline)

> **GUARD**: Do NOT delegate to `workflow-plan` or call `EnterPlanMode`.
> **GUARD**: Do NOT read project files, docs, or source code. Enhancement uses ONLY the user's input text. Project analysis is the researcher's job (Stage 0). If the task mentions "docs folder" or specific files, reference them in the enhanced prompt for the orchestrator — do NOT read them yourself.

Analyze raw input for clarity, scope, deliverables, constraints, and context. Transform into a structured prompt.

### Custom Scope Template (when scope is `custom`)

```
**Objective**: [Clear statement]
**Context**: [Current state, background]
**Deliverables**: [Specific outputs]
**Constraints**: [Limitations]
**Success Criteria**: [Verifiable criteria]
**Out of Scope**: [Exclusions]
**Assumptions** (autonomous mode): [Documented assumptions]
```

### Scope-Templated Enhanced Prompt (when scope is NOT `custom`)

The scope specification IS the enhanced prompt template. The user's `task_description` provides the **Objective**; the scope spec defines everything else.

**Rules**:
- User input may ADD requirements but MUST NOT cause any scope spec content to be omitted (SCOPE-002)
- Store the full verbatim scope spec in `enhanced_prompt.scope_specification`

Format:
```
**Objective**: [User's task_description]
**Additional User Context**: [Extra requirements beyond scope spec, if any]
**Assumptions** (autonomous mode): [Assumptions]
**Out of Scope**: [Exclusions]

## Full Scope Specification (VERBATIM)
[Entire text from Appendix A and/or B — word-for-word, nothing omitted]
```

---

## Step 2: Initialize Session Checkpoint

### 2a. Ensure directories

```bash
mkdir -p .orchestrate/${SESSION_ID}
mkdir -p ~/.claude/sessions  # legacy fallback
```

### 2b. Supersede existing in-progress sessions

```bash
# CROSS-003: Scope scan to current working directory only
grep -rl '"status": "in_progress"' "$(pwd)"/.orchestrate/*/checkpoint.json 2>/dev/null
grep -rl '"status": "in_progress"' ~/.claude/sessions/auto-orc-*.json 2>/dev/null
```

**CWD filter**: Only consider sessions whose checkpoint file is under the current working directory. Sessions from other projects are ignored. Log: `[CROSS-003] Filtered session scan to CWD: $(pwd)`

For EVERY in-progress session: set `"status": "superseded"`, add `"superseded_at"` and `"superseded_by"`. Non-destructive — never delete. If superseded session's `original_input` matches current: **resume** (skip to Step 3).

**Stale in_progress task cleanup on resume**: When resuming a session, scan for tasks marked `in_progress`. For each, check the `in_progress_iterations` counter in the checkpoint. If a task has been `in_progress` for >= 5 iterations: mark as `failed`, log `[RESUME] Task #<id> "<subject>" stuck in_progress for <N> iterations — marking failed`. This prevents resume from hanging on zombie tasks.

Also update `.sessions/index.json` at the project root: set the superseded session's status to `"superseded"` and add `"superseded_at"`. See `commands/SESSIONS-REGISTRY.md` for the registry format and write protocol.

### 2c. Create new session

**Session ID**: `auto-orc-<DATE>-<8-char-slug>` (slug from user input).

Create parent tracking task via `TaskCreate` (if available; if TaskCreate fails, log `[CROSS-001] TaskCreate unavailable — setting parent_task_id: null` and continue with `parent_task_id: null`), then:

```bash
mkdir -p .orchestrate/<session-id>/{planning,stage-0,stage-1,stage-2,stage-3,stage-4,stage-4.5,stage-5,stage-6,dispatch-receipts}
```

**Output structure** (per `_shared/protocols/output-standard.md`):
- `checkpoint.json` — session state (atomic write)
- `MANIFEST.jsonl` — session-level manifest (one per session, not per-stage)
- `proposed-tasks.json` — task proposals from orchestrator
- `stage-N/` — per-stage outputs with `YYYY-MM-DD_<slug>.md` files + `stage-receipt.json`
- **Stage-3, stage-4, stage-6** write code/tests/docs to the **project directory**; their `stage-receipt.json` + `changes.md` track what was modified
- Every stage completion writes a `stage-receipt.json` — the standard bridge to domain memory

Write checkpoint **atomically** (write to `checkpoint.tmp.json`, then rename to `checkpoint.json`) to `.orchestrate/<session-id>/checkpoint.json` (primary) and `~/.claude/sessions/<session-id>.json` (legacy):

**Checkpoint schema migration**: On resume (Step 2b), check the `schema_version` field of the loaded checkpoint. If the version is older than the current format (e.g., "1.0.0" vs "1.1.0"), attempt graceful migration: add any missing fields with defaults, log `[MIGRATE] Checkpoint migrated from <old> to <new>`. If migration fails, abort with `[MIGRATE-FAIL] Cannot migrate checkpoint from schema_version <version>. Start a new session.`

**Planning fields migration (1.0.0 → 1.1.0)**: When resuming a session with `schema_version: "1.0.0"` (pre-planning), add planning fields with default values:

```json
{
  "planning_stages_completed": [],
  "planning_artifacts": {
    "P1_intent_brief": null,
    "P2_scope_contract": null,
    "P3_dependency_charter": null,
    "P4_sprint_kickoff_brief": null
  },
  "planning_gate_statuses": {
    "P1": null,
    "P2": null,
    "P3": null,
    "P4": null
  },
  "current_planning_stage": null,
  "planning_skipped": false,
  "triage": null,
  "planning_revision_count": 0,
  "planning_revision_history": [],
  "validation_regression_count": 0,
  "thrash_counter": 0,
  "state_hash_window": [],
  "human_gates": []
}
```

Log: `[MIGRATE] Added planning fields to checkpoint (1.0.0 → 1.1.0)`

Update `schema_version` to `"1.1.0"` after migration.

### 2d. Gate State Check

If `.gate-state.json` exists at the project root (written by `/gate-review`):

1. Read and parse the gate state file
2. Extract `current_gate`, `gate_status`, and `gates_passed` array (derive from gates with `status: "passed"`)
3. Map organizational gates to pipeline stages:
   - Gate 1 (Intent Review / `gate_1_intent_review`) → prerequisite for Stage 0
   - Gate 2 (Scope Lock / `gate_2_scope_lock`) → prerequisite for Stage 2
   - Gate 3 (Dependency Acceptance / `gate_3_dependency_acceptance`) → prerequisite for Stage 3
   - Gate 4 (Sprint Readiness / `gate_4_sprint_readiness`) → prerequisite for Stage 5
4. Store in checkpoint:
   ```json
   "gate_state": {
     "source": ".gate-state.json",
     "current_gate": 2,
     "gates_passed": ["gate_1_intent_review", "gate_2_scope_lock"],
     "loaded_at": "<ISO-8601>"
   }
   ```

**Backward compatibility**: If `.gate-state.json` does not exist, log `[GATE-SKIP] No gate state found — organizational gates not enforced` and proceed normally. Set `gate_state: null` in checkpoint.

```json
{
  "schema_version": "1.4.0",
  "session_id": "<session-id>",
  "created_at": "<ISO-8601>",
  "updated_at": "<ISO-8601>",
  "status": "in_progress",
  "iteration": 0,
  "max_iterations": 100,
  "original_input": "<raw user input>",
  "scope": { "flag": null, "resolved": "custom", "layers": [] },
  "permissions": { "autonomous_operation": true, "session_folder_access": true, "no_clarifying_questions": true, "granted_at": "<ISO-8601>" },
  "enhanced_prompt": {
    "objective": "...", "context": "...",
    "deliverables": ["..."], "constraints": ["..."], "success_criteria": ["..."],
    "out_of_scope": ["..."], "assumptions": ["..."],
    "scope_specification": "<VERBATIM scope spec or empty for custom>"
  },
  "task_ids": [],
  "parent_task_id": "<TaskCreate ID>",
  "iteration_history": [],
  "terminal_state": null,
  "current_pipeline_stage": 0,
  "stages_completed": [],
  "mandatory_stage_enforcement": false,
  "stage_3_completed_at_iteration": null,
  "task_limits": { "max_tasks": 50, "max_active_tasks": 30, "max_continuation_depth": 3 },
  "task_snapshot": { "written_at": null, "iteration": null, "tasks": [] },
  "gate_state": null,
  "gate_override": false,
  "project_type": null,
  "planning_stages_completed": [],
  "planning_artifacts": {
    "P1_intent_brief": null,
    "P2_scope_contract": null,
    "P3_dependency_charter": null,
    "P4_sprint_kickoff_brief": null
  },
  "planning_gate_statuses": {
    "P1": null,
    "P2": null,
    "P3": null,
    "P4": null
  },
  "current_planning_stage": null,
  "planning_skipped": false,
  "dispatch_log": [],
  "dispatch_context": { "0": [], "1": [], "2": [], "3": [], "4": [], "4.5": [], "5": [], "6": [] },
  "dispatch_gates": {},
  "dispatch_summary": null,
  "release_flag": false,
  "domain_activations": [],
  "domain_reviews": { "0": [], "1": [], "2": [], "3": [], "4": [], "4.5": [], "5": [], "6": [] }
}
```

**Dispatch fields migration (1.1.0 → 1.2.0)**: When resuming a session without dispatch fields, add them with defaults:
```json
{
  "dispatch_log": [],
  "dispatch_context": { "0": [], "1": [], "2": [], "3": [], "4": [], "4.5": [], "5": [], "6": [] },
  "dispatch_gates": {},
  "dispatch_summary": null,
  "release_flag": false
}
```
Log: `[MIGRATE] Added dispatch fields to checkpoint (1.1.0 → 1.2.0)`

**Domain activation fields migration (1.2.0 → 1.3.0)**: When resuming a session without domain activation fields, add them with defaults:
```json
{
  "domain_activations": [],
  "domain_reviews": { "0": [], "1": [], "2": [], "3": [], "4": [], "4.5": [], "5": [], "6": [] }
}
```
Log: `[MIGRATE] Added domain activation fields to checkpoint (1.2.0 → 1.3.0)`

Update `schema_version` to `"1.3.0"` after migration.

**Process scope fields migration (1.3.0 → 1.4.0)**: When resuming a session where `triage` exists but lacks `process_scope`, add it with a safe default:
```json
{
  "triage": {
    "process_scope": {
      "tier": "complex",
      "domain_flags": [],
      "active_categories": [1, 2, 3, 5, 6, 7, 8, 9, 10, 12, 13, 16],
      "domain_guides_enabled": ["/security", "/qa", "/infra", "/data-ml-ops", "/risk", "/org-ops"],
      "total_active": 56
    }
  }
}
```
Log: `[MIGRATE] Added process_scope to triage (1.3.0 → 1.4.0). Defaulting to complex (all processes active).`

**Note**: Default is `complex` (all processes active) so existing sessions do not lose coverage. New sessions compute the actual scope via Step 0h-pre.

Update `schema_version` to `"1.4.0"` after migration.

---

## Step 3: Spawn Orchestrator (Loop Entry)

> **CRITICAL TRANSITION GUARD**: You should arrive here with EXACTLY ONE task (the parent tracking task from Step 2c) and ZERO knowledge of the project's internals. If you have read project files, identified components/services, or created multiple tasks — you have violated the Execution Guard. STOP and restart from this step. The orchestrator and its subagents will do ALL project analysis and task creation.

**Before spawning** (AUTO-005): Increment `iteration`, update `updated_at`, write checkpoint.

### 3a. Calculate STAGE_CEILING

#### Planning Gate Check (PRE-RESEARCH-GATE)

Before calculating the numeric STAGE_CEILING, check planning completion:

```
IF planning_skipped == false AND planning_stages_completed != ["P1","P2","P3","P4"]:
    STAGE_CEILING = "PLANNING"  # Cannot proceed to numeric stages
    # The orchestrator operates in HUMAN_PLANNING mode
    # See Step 0h for planning loop details
ELSE:
    # Proceed to numeric STAGE_CEILING calculation below
```

When `STAGE_CEILING = "PLANNING"`, the orchestrator receives:
- `PHASE: HUMAN_PLANNING` in spawn prompt
- `CURRENT_PLANNING_STAGE: <P1|P2|P3|P4>` indicating the next incomplete stage

#### Numeric STAGE_CEILING Calculation

STAGE_CEILING = the maximum pipeline stage the orchestrator may work on. Calculated from `stages_completed`:

| Condition | STAGE_CEILING |
|-----------|---------------|
| 0 not completed | 0 (research only) |
| 0 done, 1 not | 1 |
| {0,1} done, 2 not | 2 |
| {0,1,2} done, 3 not | 3 |
| {0,1,2,3} done, 4/4.5 not | 4.5 (Stage 4 optional — see AUTO-002) |
| {0,1,2,4.5} done, 5 not | 5 |
| {0,1,2,4.5,5} done, 6 not | 6 |
| All done | 6 |

**STAGE_CEILING is a HARD LIMIT** — the orchestrator MUST NOT spawn agents or do work above this stage.

#### Gate Enforcement at Stage Transitions

Before allowing work at a pipeline stage, check if the mapped organizational gate has been passed (from Step 2d gate_state):

| Pipeline Stage | Required Gate | Gate Name |
|----------------|---------------|-----------|
| Stage 0 | Gate 1 | `gate_1_intent_review` |
| Stage 2 | Gate 2 | `gate_2_scope_lock` |
| Stage 3 | Gate 3 | `gate_3_dependency_acceptance` |
| Stage 5 | Gate 4 | `gate_4_sprint_readiness` |

**Enforcement logic**:

1. **Gate NOT passed AND `gate_override` NOT set**:
   - Log: `[GATE-BLOCK] Stage <N> requires Gate <G> — run /gate-review first`
   - Reduce STAGE_CEILING to block that stage
   - Example: If Stage 2 requires Gate 2 but Gate 2 not passed → cap STAGE_CEILING at 1

2. **Gate NOT passed BUT `gate_override: true` in checkpoint**:
   - Log: `[GATE-OVERRIDE] Proceeding past Gate <G> with override`
   - Allow progression past the gate
   - Record override usage in iteration_history for audit

3. **`.gate-state.json` does not exist**:
   - Log: `[GATE-SKIP] No gate state found — organizational gates not enforced`
   - Proceed normally (backward compatible)
   - This is the default state for projects not using the organizational workflow

**Gate ceiling calculation** (applied AFTER stages_completed ceiling):
```
gate_ceiling = 6  # Default: no gate restriction

if gate_state is not null:
    if "gate_1_intent_review" not in gates_passed and not gate_override:
        gate_ceiling = min(gate_ceiling, -1)  # Block Stage 0
    if "gate_2_scope_lock" not in gates_passed and not gate_override:
        gate_ceiling = min(gate_ceiling, 1)   # Block Stage 2+
    if "gate_3_dependency_acceptance" not in gates_passed and not gate_override:
        gate_ceiling = min(gate_ceiling, 2)   # Block Stage 3+
    if "gate_4_sprint_readiness" not in gates_passed and not gate_override:
        gate_ceiling = min(gate_ceiling, 4.5) # Block Stage 5+

STAGE_CEILING = min(STAGE_CEILING_from_stages, gate_ceiling)
```

### 3b. Display iteration banner

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 ITERATION <N> of <max> | Session: <session_id>
 PLANNING: P1 <✓/✗> P2 <✓/✗> P3 <✓/✗> P4 <✓/✗> | EXECUTION: Stage 0 <✓/✗> → ... → Stage 6 <✓/✗>
 STAGE_CEILING: <ceiling> | Tasks: <completed> done, <in_progress> running, <pending> pending, <blocked> blocked
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Planning status indicators**:
- `✓` — Planning stage gate PASSED
- `✗` — Planning stage gate not passed or FAILED
- If `planning_skipped: true`, display: `PLANNING: [SKIPPED]`

> **IMPORTANT**: If `in_progress > 0`, append to the banner: `⚠ <N> task(s) still running — pipeline NOT complete`

### 3c. Display task board (DISPLAY-001)

Query `TaskList`, group by `dispatch_hint` using the Pipeline Stage Reference table. Display:

```
 TASK BOARD:
 ┌─ Stage 0 (Research) ─────────────────────────────
 │  ✓ #2  Research pipeline audit best practices
 ├─ Stage 1 (Product Management) ────────────────────
 │  ◷ #3  Decompose audit into epic tasks          [blocked by #2]
 ├─ Stage 2 (Specifications) ───────────────────────
 │  ◷ #4  Create technical specifications          [blocked by #3]
 └──────────────────────────────────────────────────
 Legend: ✓ completed  ▶ in_progress  ○ pending  ◷ blocked
```

Each task shows: status icon, task ID, subject (truncated to 45 chars), `[blocked by #N]` if blocked.

### 3d. Pre-spawn self-check

Before spawning, verify ALL of these conditions. If ANY fails, you are off-track:
- [ ] You are about to spawn exactly ONE agent with `subagent_type: "orchestrator"` — NOT 5 parallel agents, NOT software-engineer/researcher/technical-writer agents
- [ ] You have NOT read any project source files, docs, or configs (beyond what Step 1 needed for prompt enhancement)
- [ ] The only task that exists (besides the parent) was proposed by a previous orchestrator iteration (or this is iteration 1 with no work tasks yet)
- [ ] The iteration banner (Step 3b) includes `STAGE_CEILING` — if it doesn't, you skipped Step 3a
- [ ] You are NOT about to "do the work yourself" because it "seems simple enough"

### 3e. Spawn orchestrator

Spawn EXACTLY ONE agent: `Agent(subagent_type: "orchestrator")` using the **Appendix C** template. Never spawn multiple orchestrators in parallel. Never spawn non-orchestrator agents from this loop.

> **Note (CROSS-006)**: Single-spawn enforcement is prompt-level only. No API-level guard exists. Monitor for violations in iteration history.

---

## Step 4: Process Results and Loop

> **AUTO-001 GUARD**: NEVER spawn a non-orchestrator agent regardless of orchestrator output.

After orchestrator returns, execute these sub-steps with visible progress at each (PROGRESS-001):

**4.1 Display summary**: Stages covered, tasks completed/in_progress/pending, pipeline status. If ANY tasks are `in_progress`, display prominently: `⚠ <N> task(s) still running — waiting for completion before evaluating pipeline`. Tasks with status `in_progress` mean background agents are still working — the pipeline is NOT idle and NOT complete.

**4.2 Process task proposals** `[STEP 4.2]`:
- Read `.orchestrate/<session-id>/proposed-tasks.json` and parse `PROPOSED_ACTIONS` from return text
- **Precedence rule**: If BOTH sources contain tasks, the file (`proposed-tasks.json`) takes precedence. `PROPOSED_ACTIONS` from return text is used ONLY as fallback when the file is missing, empty, or contains `"tasks": []`. Log: `[STEP 4.2] Source: file` or `[STEP 4.2] Source: return-text (file empty/missing)`
- **Deduplication**: If both sources are present, merge by `subject` field — file version wins on conflict. Log duplicates: `[STEP 4.2] Deduplicated <N> tasks (file wins)`
- **blockedBy chain validation (CHAIN-001)**: Every task for Stage N (N > 0) must reference Stage N-1. Auto-fix missing chains: `[CHAIN-FIX] Added blockedBy to "<subject>"`. Validate that referenced blockedBy task IDs actually exist — log orphaned references: `[CHAIN-WARN] Task "<subject>" blockedBy references non-existent task`
- **dispatch_hint validation (DISPATCH-001)**: For each task, check that `dispatch_hint` matches a known agent name from `manifest.json` agents list OR a known skill name. If invalid: log `[DISPATCH-WARN] Invalid dispatch_hint "<hint>" on task "<subject>" — routing may fail`. Do NOT block task creation; just warn.
- Create via `TaskCreate`, set `blockedBy` via `TaskUpdate`
- Write `proposed-tasks-processed-<iteration>.json` with enriched content (skip if empty)
- Output: `Created <N> tasks, updated <M> (chain-fixed: <K>)`

**4.3 Query and display tasks** `[STEP 4.3]`:
- Query `TaskList`, categorize: `completed`, `pending`, `in_progress`, `blocked_or_failed`, `partial`
- Display task board (same format as Step 3c) showing status changes

**4.4 Verify partial tasks**: Ensure `"status": "partial"` tasks have continuation tasks.

**4.5 Task ceiling check**: If total tasks >= `max_tasks`: `task_cap_reached: true`. Output: `[LIMIT-001]`

**4.6 Record iteration history**:
```json
{
  "iteration": N,
  "tasks_completed": [{"id": "1", "subject": "..."}],
  "tasks_pending": [{"id": "3", "subject": "..."}],
  "tasks_in_progress": [],
  "tasks_blocked": [{"id": "4", "subject": "...", "blocked_by": ["3"]}],
  "tasks_partial_continued": [],
  "task_cap_reached": false,
  "stages_completed_snapshot": [0, 1],
  "stage_regression": false,
  "mandatory_stage_enforcement": false,
  "summary": "<first 500 chars of orchestrator output>"
}
```

**4.7 Save checkpoint + task snapshot**: Write `task_snapshot` with ALL tasks (complete replacement each iteration):
```json
"task_snapshot": {
  "written_at": "<ISO-8601>", "iteration": N,
  "tasks": [{ "id": "...", "subject": "...", "status": "...", "blockedBy": [], "dispatch_hint": "..." }]
}
```

**4.8 Evaluate pipeline progress**: Use Pipeline Stage Reference to determine completion. A stage is complete ONLY when ALL tasks for that stage are `completed` AND ZERO tasks for that stage are `in_progress`. Tasks still `in_progress` (background agents running) block stage completion — do NOT mark a stage done while any of its tasks are still running. Apply AUTO-003 (monotonicity). Track `stage_3_completed_at_iteration`.

**4.8a Process Hook Verification** (V2 enforcement):

For each completed stage with enforced process hooks, verify process acknowledgments:

```
ENFORCED_HOOKS = {
  5: ["P-034", "P-037"],  # Code Review + UAT at Stage 5 (Validator) exit
  6: ["P-058"]            # Technical Documentation at Stage 6 exit
}

For each stage in stages_completed:
  If stage in ENFORCED_HOOKS:
    1. Read .orchestrate/<session-id>/stage-<N>/stage-receipt.json
    2. Check for process_acknowledgments array containing required process IDs
    3. If required process acknowledgment is missing:
       - Track iteration count in checkpoint.process_gates.stage_<N>.<P-NNN>_iterations
       - Iteration 1: Log [PROC-WARN] Stage <N> missing P-<NNN> acknowledgment — will enforce next iteration
       - Iteration 2: Log [PROC-ENFORCE] Stage <N> P-<NNN> not acknowledged — creating remediation task
         Create remediation task: "Stage <N> Process Gate: Acknowledge P-<NNN> in stage output"
       - Iteration 3+: Log [PROC-ESCALATE] Stage <N> P-<NNN> still unacknowledged — flagging for review
         Set checkpoint.process_gates.stage_<N>.escalated = true
    4. If acknowledgment found:
       - Set checkpoint.process_gates.stage_<N>.<P-NNN>_acknowledged = true
       - Log [PROC-PASS] Stage <N> P-<NNN> acknowledged

Acknowledgment detection patterns (grep stage output or stage-receipt.json):
  - P-034: "[P-034]" or "code review: PASS" or "review checklist"
  - P-037: "[P-037]" or "test results:" or "tests passed:"
  - P-058: "[P-058]" or "documentation: COMPLETE" or "docs written:"
```

**Checkpoint schema addition** for process gates:
```json
{
  "process_gates": {
    "stage_5": {
      "P-034_acknowledged": false,
      "P-034_iterations": 0,
      "P-037_acknowledged": false,
      "P-037_iterations": 0,
      "escalated": false
    },
    "stage_6": {
      "P-058_acknowledged": false,
      "P-058_iterations": 0,
      "escalated": false
    }
  }
}
```

**4.8b Human Checkpoint Gates (HUMAN-GATE-001)**:

If `human_gates` is configured, check whether a newly completed stage requires human review:

```
IF human_gates is set AND human_gates != "":
    completed_stages_this_iteration = stages_completed - stages_completed_previous_iteration
    
    FOR each newly_completed_stage in completed_stages_this_iteration:
        IF newly_completed_stage in human_gates_list OR human_gates == "all":
            1. Display stage output summary:
               ```
               ╔══════════════════════════════════════════════════════════════╗
               ║  HUMAN REVIEW GATE — Stage <N> (<name>) completed           ║
               ║                                                              ║
               ║  Output: .orchestrate/<session>/stage-<N>/                   ║
               ║  Tasks completed: <list>                                     ║
               ║                                                              ║
               ║  Review the output and respond:                              ║
               ║  - "continue" or "y" to proceed to next stage               ║
               ║  - "revise" to re-run this stage with feedback              ║
               ║  - "stop" to halt the pipeline                              ║
               ╚══════════════════════════════════════════════════════════════╝
               ```
            2. Wait for user input (no timeout — human gates are synchronous)
            3. On "continue"/"y": proceed normally
            4. On "revise": mark stage tasks as `pending`, remove stage from `stages_completed`, log `[HUMAN-GATE] Stage <N> sent back for revision by user`
            5. On "stop": set terminal_state to `user_stopped`, terminate
            6. Log: `[HUMAN-GATE] Stage <N> — user response: <response>`
```

**Checkpoint addition**:
```json
{
  "human_gates": [],
  "human_gate_history": []
}
```

**4.8c Dispatch Trigger Evaluation (DISPATCH-001)**:

After evaluating pipeline progress (4.8), process hooks (4.8a), and human gates (4.8b), evaluate command dispatch triggers per `_shared/protocols/command-dispatch.md`:

1. **Build event context** for each newly completed stage this iteration:
   ```
   completed_stages_this_iteration = stages_completed - stages_completed_previous_iteration

   FOR EACH newly_completed_stage IN completed_stages_this_iteration:
       event_context = {
         event_type: "stage_completed",
         stage: newly_completed_stage,
         stage_receipt: read ".orchestrate/<session>/stage-<N>/stage-receipt.json" (if exists),
         checkpoint: current checkpoint,
         gap_report: null  # auto-orchestrate does not use gap reports
       }
   ```

2. **Evaluate applicable triggers** from the trigger rules table:
   - TRIG-001: Stage 0 completes → check stage-receipt for P-038 security flags → invoke `/security`
   - TRIG-002: Stage 3 completes → invoke `/qa` for test strategy analysis
   - TRIG-003: Stage 5 fails → check failure for deploy/infrastructure keywords → invoke `/infra`
   - TRIG-007: Any stage → check `.pipeline-state/codebase-analysis.jsonl` and planning artifacts for CRITICAL RAID items → invoke `/risk`
   - TRIG-012: Any stage → check process acknowledgments for HIGH/CRITICAL flags in domain guide ranges → invoke corresponding guide

3. **For Tier 2 triggers that fire**:
   ```
   a. Write dispatch context file:
      .orchestrate/<session>/dispatch-receipts/dispatch-context-<trigger_id>.json
   b. Invoke domain guide: Skill(skill: "<skill_name>")
   c. Parse structured output from domain guide
   d. Create dispatch receipt:
      .orchestrate/<session>/dispatch-receipts/dispatch-<YYYYMMDD>-<trigger_id>-<4hex>.json
   e. Process next_action:
      - "inject_into_stage": append to checkpoint.dispatch_context.<target_stage>
      - "create_task": TaskCreate with appropriate dispatch_hint and blockedBy
      - "gate_block": set checkpoint.dispatch_gates.<stage> = dispatch_id
      - "informational": log only
   f. Append to checkpoint.dispatch_log
   ```

4. **For Tier 1 triggers** (unlikely mid-pipeline, mostly at Step 0g and Step 5):
   ```
   display "[DISPATCH-SUGGEST] <trigger_id>: Consider running <command>."
   append to checkpoint.dispatch_log
   ```

5. **Proactive process sweep (TRIG-013 / PROCESS-DELEGATE-001)**:

   After evaluating TRIG-001 through TRIG-012, run the proactive process sweep if `checkpoint.triage.process_scope.tier >= "medium"`. This ensures processes from the expanded injection map that aren't natively handled get domain guide coverage.

   ```
   already_dispatched = set of skill names dispatched by TRIG-001-012 in this evaluation

   IF checkpoint.triage.process_scope.tier != "trivial":
       proactive_results = proactive_process_sweep(
           completed_stage=newly_completed_stage,
           process_scope=checkpoint.triage.process_scope,
           already_dispatched=already_dispatched
       )
       # proactive_results follow the same receipt protocol as TRIG-001-012
       # Process next_action for each proactive dispatch receipt
       FOR EACH receipt IN proactive_results:
           process_next_action(receipt)  # inject_into_stage, create_task, etc.
           append to checkpoint.dispatch_log:
               { trigger_id: "TRIG-013", command: receipt.command,
                 tier: 2, action: "invoked", dispatch_id: receipt.dispatch_id,
                 proactive: true, processes: receipt.processes, timestamp }
   ```

   Log: `[DISPATCH] TRIG-013 proactive sweep: <N> domain guides invoked for <M> processes`

   **Cap**: Maximum 2 proactive dispatches per stage transition. If TRIG-001-012 already dispatched a domain guide, TRIG-013 skips it.

6. **Log summary**: `[DISPATCH] Evaluated <N> triggers for <M> newly completed stages, <K> fired (reactive), <J> proactive, <R> receipts written`

7. **Dispatch gate enforcement**: Before proceeding, check if any `dispatch_gates` block the next stage:
   ```
   IF checkpoint.dispatch_gates contains key for next pending stage:
       display "[DISPATCH-GATE] Stage <N> blocked by dispatch gate {dispatch_id}"
       display "  Findings from {command} must be addressed before proceeding"
       # Stage remains blocked until gate cleared (finding addressed in a subsequent iteration)
   ```

> **DISPATCH-GUARD-001**: Skill invocations are NOT Agent spawns. This step does NOT violate AUTO-001 (orchestrator-only gateway). Domain guide Skills are inline tools, not autonomous agents.

> **DISPATCH-NOCIRCLE-001**: Domain guides invoked here do NOT evaluate dispatch triggers themselves. They produce output and return.

**4.8d Domain Activation Review (AGENT-ACTIVATE-001)**:

After dispatch evaluation, check if the orchestrator reported domain agent activations in this iteration. Domain agent activation is handled BY the orchestrator (not the loop controller) per `_shared/protocols/agent-activation.md`. The loop controller's role here is to log and track activations in the checkpoint.

1. **Scan for new domain review artifacts**:
   ```
   new_reviews = glob(".orchestrate/<session>/domain-reviews/*-stage-*.md")
   known_reviews = flatten(checkpoint.domain_reviews.values())
   new_this_iteration = new_reviews - known_reviews
   ```

2. **Log activations**:
   ```
   IF new_this_iteration is non-empty:
       display "[DOMAIN-REVIEW] {len(new_this_iteration)} domain review(s) produced this iteration:"
       FOR EACH review IN new_this_iteration:
           agent_name = extract_agent_name(review.filename)  # e.g., "security-engineer" from "security-engineer-stage-2.md"
           stage = extract_stage(review.filename)
           display "  - {agent_name} reviewed Stage {stage} artifacts"
   ```

3. **Update checkpoint**:
   ```
   FOR EACH review IN new_this_iteration:
       agent_name = extract_agent_name(review.filename)
       stage = extract_stage(review.filename)
       
       checkpoint.domain_activations.append({
           "agent": agent_name,
           "stage": stage,
           "artifact_path": review.path,
           "timestamp": now_iso8601(),
           "iteration": checkpoint.iteration
       })
       
       IF agent_name NOT IN checkpoint.domain_reviews[stage]:
           checkpoint.domain_reviews[stage].append(agent_name)
   ```

4. **Inject domain review context for next orchestrator spawn**: If domain reviews exist for stages with pending tasks, include review summaries in the next orchestrator spawn prompt via the Domain Review Context section in Appendix C.

> **AGENT-ACTIVATE-001 boundary**: Domain agents are spawned BY the orchestrator during its execution, not by the loop controller. The loop controller only observes and logs the results. This preserves AUTO-001 (loop controller spawns only orchestrators).

**4.9 Mandatory stage gates**:
- **AUTO-004**: If Stage 3 done but 4.5/5/6 missing for 1+ iterations → `mandatory_stage_enforcement: true`, inject missing tasks.
- **Proactive injection**: For any mandatory stage at or below `STAGE_CEILING` absent from `stages_completed` with no pending/in-progress task, create it immediately with proper `blockedBy` chain:
  - Stage 0: `researcher`, no blockedBy
  - Stage 1: `product-manager`, blockedBy Stage 0
  - Stage 2: `spec-creator`, blockedBy Stage 1
  - Stage 4: `test-writer-pytest`, blockedBy Stage 3 (**optional** — inject only if product-manager produced test tasks)
  - Stage 4.5: `codebase-stats`, blockedBy Stage 3
  - Stage 5: `validator`, blockedBy Stage 4.5
  - Stage 6: `technical-writer`, blockedBy Stage 5

**4.10 Evaluate termination** (see Step 5).

**4.11 If NOT terminated** → return to Step 3.

---

## Step 5: Termination Conditions

**Pre-check — in_progress tasks block termination**: If ANY tasks have status `in_progress`, skip ALL termination checks and return to Step 3 (next iteration). Background agents are still working — the pipeline is neither complete, stalled, nor blocked. Display: `⚠ <N> task(s) still in_progress — skipping termination check, continuing loop`.

**Planning completion pre-condition**: Before evaluating execution pipeline termination, verify planning is complete:

```
planning_complete = (
    planning_skipped == true
    OR planning_stages_completed == ["P1", "P2", "P3", "P4"]
)

IF NOT planning_complete:
    # Cannot terminate — planning phase still active
    # Return to Step 3 to continue planning loop
    Display: "[PRE-RESEARCH-GATE] Planning incomplete — cannot evaluate termination"
    Return to Step 3
```

Evaluate in order (ONLY when zero tasks are `in_progress` AND planning is complete):

| # | Condition | Status |
|---|-----------|--------|
| 1 | All tasks completed AND `stages_completed` includes 0,1,2,4.5,5,6 (Stage 4 optional — see AUTO-002) AND (planning_stages_completed includes P1,P2,P3,P4 OR planning_skipped == true) | `completed` |
| 1a | All tasks completed BUT mandatory stages missing | Inject tasks, retry once. If still missing: `completed_stages_incomplete` |
| 2 | `iteration >= MAX_ITERATIONS` | `max_iterations_reached` |
| 3 | No progress for `STALL_THRESHOLD` consecutive iterations | `stalled` |
| 4 | All remaining tasks blocked AND zero `in_progress` | `all_blocked` |

**Stall detection**: Same pending+completed counts for 2 consecutive iterations = stall. However, `in_progress` tasks reset the stall counter (work is actively happening). `tasks_partial_continued` also resets counter.

**Thrashing detection (THRASH-001)**: Track a rolling window of state hashes (last 6 iterations). The state hash is computed from: `SHA-256(sorted task IDs + ":" + sorted task statuses + ":" + sorted stages_completed)`. If the current state hash matches ANY previous hash in the rolling window, the system is **thrashing** — alternating between states without making net progress. Thrashing is detected even when individual iteration counts change (which would evade the stall counter).

When thrashing is detected:
1. Log: `[THRASH-001] State hash collision detected — iteration <N> matches iteration <M>. System is thrashing.`
2. Increment `thrash_counter` in checkpoint
3. If `thrash_counter >= 2`: set terminal_state to `thrashing` and terminate
4. If `thrash_counter == 1`: log `[THRASH-WARN] First thrashing occurrence — attempting recovery` and inject a diagnostic task: "Analyze pipeline thrashing — identify conflicting changes between iterations <M> and <N>"

**Checkpoint additions**:
```json
{
  "thrash_counter": 0,
  "state_hash_window": [],
  "thrash_history": []
}
```

Add `thrashing` to the Terminal State Reference table as:
```
| `thrashing` | System alternating between states without net progress |
```

**In-progress ceiling (AO-INEFF-001)**: Track per-task `in_progress_iterations` count. If any task remains `in_progress` for 5 consecutive iterations without completing, treat it as failed: set status to `failed`, log `[AO-INEFF-001] Task #<id> "<subject>" stuck in_progress for 5 iterations — marking failed`, and do NOT let it reset the stall counter.

### Post-Termination Dispatch (TRIG-005, TRIG-006)

After `terminal_state` is determined but before the termination display:

```
IF terminal_state == "completed":
    # TRIG-005: Release preparation suggestion
    IF checkpoint.release_flag == true:
        display "[DISPATCH-SUGGEST] TRIG-005: Pipeline complete with release flag."
        display "  Run /release-prep to prepare for release."
        append to checkpoint.dispatch_log:
          { trigger_id: "TRIG-005", command: "/release-prep", tier: 1,
            action: "suggested", timestamp: now_iso8601() }

    # TRIG-006: Post-launch suggestion
    IF exists(".orchestrate/<session>/dispatch-receipts/") AND
       any receipt has command == "/release-prep":
        display "[DISPATCH-SUGGEST] TRIG-006: Release preparation was previously suggested."
        display "  After release, run /post-launch for operational readiness."
        append to checkpoint.dispatch_log:
          { trigger_id: "TRIG-006", command: "/post-launch", tier: 1,
            action: "suggested", timestamp: now_iso8601() }

# Write dispatch summary
checkpoint.dispatch_summary = {
    total_dispatches: count(checkpoint.dispatch_log where action == "invoked"),
    receipts_consumed: count(receipts where consumed == true),
    receipts_unconsumed: count(receipts where consumed == false),
    suggestions_made: count(checkpoint.dispatch_log where action == "suggested")
}
```

### On Termination

Set `terminal_state` and `status`, update parent task, display:

```
## Auto-Orchestration Complete
**Session**: <session_id> | **Scope**: <resolved> | **Status**: <terminal_state> | **Iterations**: N/max

### Planning Phase
P1 <✓/✗> → P2 <✓/✗> → P3 <✓/✗> → P4 <✓/✗> (or [SKIPPED] if planning_skipped)

### Execution Pipeline
Stage 0 <✓/✗> → Stage 1 <✓/✗> → ... → Stage 6 <✓/✗>

### Completed Tasks
- ✓ [#id] <subject> (<agent>, Stage N)

### Remaining Tasks (if any)
- ○ [#id] <subject> (<agent>, Stage N) — blocked by #id

### Mandatory Stages
| Stage | Status | Task |
|-------|--------|------|
| 0 (researcher) | ✓/✗ | #<id> <subject> |
| 1 (product-manager) | ✓/✗ | #<id> <subject> |
| 2 (spec-creator) | ✓/✗ | #<id> <subject> |
| 4.5 (codebase-stats) | ✓/✗ | #<id> <subject> |
| 5 (validator) | ✓/✗ | #<id> <subject> |
| 6 (technical-writer) | ✓/✗ | #<id> <subject> |

### Terminal State Reference

| Value | Meaning |
|-------|---------|
| `completed` | All tasks done, all mandatory stages covered |
| `completed_stages_incomplete` | All tasks done but mandatory stages missing after retry |
| `max_iterations_reached` | Hit MAX_ITERATIONS limit |
| `stalled` | No progress for STALL_THRESHOLD consecutive iterations |
| `all_blocked` | All remaining tasks blocked, zero in_progress |
| `user_stopped` | User manually cancelled |
| `thrashing` | System alternating between states without net progress |
| `escalated_to_debug` | Escalated to /auto-debug after validation failures |

### Git Commit Instructions
> Auto-orchestrate NEVER commits automatically. Review and commit manually.
**Files modified**: [from software-engineer DONE blocks]
**Suggested commits**: [Git-Commit-Message values]

### Command Dispatch Summary
| Metric | Count |
|--------|-------|
| Domain guides invoked | <dispatch_summary.total_dispatches> |
| Findings consumed | <dispatch_summary.receipts_consumed> |
| Findings unresolved | <dispatch_summary.receipts_unconsumed> |
| Lifecycle suggestions | <dispatch_summary.suggestions_made> |

### Domain Agent Activation Summary
| Metric | Value |
|--------|-------|
| Total activations | <len(checkpoint.domain_activations)> |
| Agents activated | <unique agents from checkpoint.domain_activations> |
| Stages with reviews | <stages with non-empty checkpoint.domain_reviews> |

{{#if checkpoint.domain_activations is non-empty}}
| Stage | Agent | Rule | Artifact |
|-------|-------|------|----------|
{{#for each activation in checkpoint.domain_activations}}
| {{activation.stage}} | {{activation.agent}} | {{activation.rule_id}} | {{activation.artifact_path}} |
{{/for each}}
{{/if}}

### Iteration Timeline
| # | Completed | Running | Pending | Tasks Worked On |
|---|-----------|---------|---------|-----------------|
| 1 | 0 | 0 | 7 | Proposed all pipeline tasks |
| 2 | 0 | 1 | 6 | ▶ #2 Research (Stage 0) |
| 3 | 1 | 0 | 6 | ✓ #2 Research (Stage 0) |
```

### Pipeline Chain Completion (GAP-PIPE-004)

On successful termination (`completed` status), check for handoff receipt and write pipeline chain entry:

1. Check if `.orchestrate/<session-id>/handoff-receipt.json` exists
2. If found and `return_path.next_command` is defined:
   - Read `.sessions/index.json`
   - Add or update `pipeline_chains` array entry:
     ```json
     {
       "chain_id": "chain-<YYYYMMDD>-<slug>",
       "from_session": "<current-session-id>",
       "from_command": "auto-orchestrate",
       "to_command": "<return_path.next_command>",
       "trigger": "completion",
       "status": "pending",
       "created_at": "<ISO-8601>"
     }
     ```
   - Atomic write to `.sessions/index.tmp.json`, then rename
   - Display: `[CHAIN] Pipeline continuation registered: → <next_command>`
3. If no handoff receipt or no return_path: skip silently
4. **Display only — NEVER auto-invoke the next command** (R-010)

### Return Path Completion (GAP-PIPE-005)

After displaying the termination summary, update the handoff receipt and display the return path:

1. Check if `.orchestrate/<session-id>/handoff-receipt.json` exists
2. If found:
   - Update `auto_orchestrate_status` to `"completed"` (or `"failed"` on non-successful termination)
   - Update `completed_timestamp` to current ISO-8601 timestamp
   - Set `return_path.stage6_artifacts_path` to `".orchestrate/<session-id>/stage-6/"`
   - Set `return_status` to `terminal_state` value (e.g., `"completed"`, `"stalled"`, `"max_iterations_reached"`)
   - Set `return_at` to current ISO-8601 timestamp
   - Set `return_summary` to the termination summary (first 500 characters of the summary text)
   - Atomic write (write to `.tmp` then rename)
   - If `return_path.next_command` exists, display:
     ```
     [COMPLETE] Auto-orchestration finished.
     Return path: → <return_path.next_command>
     To continue the workflow, run: /<next_command>
     ```
3. If no handoff receipt: skip silently (standalone session, no return path)
4. **Display only — NEVER auto-invoke the return path command** (R-010)

**Updated handoff receipt fields on termination**:
```json
{
  "auto_orchestrate_status": "completed",
  "completed_timestamp": "<ISO-8601>",
  "return_path": {
    "stage6_artifacts_path": ".orchestrate/<session-id>/stage-6/"
  },
  "return_status": "<terminal_state>",
  "return_at": "<ISO-8601>",
  "return_summary": "<first 500 chars of termination summary>"
}
```

---

## Crash Recovery Protocol

Runs at the START of every invocation:

1. Ensure `.orchestrate/` and `~/.claude/sessions/` exist
2. Scan for `"status": "in_progress"` checkpoints
3. If found: same/no input → **Resume**; different input → supersede, start fresh
4. If not found → proceed normally
5. Cross-command awareness: read `.sessions/index.json` (if present) to detect active sessions from other commands. Log any `in_progress` cross-command sessions found. See `commands/SESSIONS-REGISTRY.md`.

### Resume

1. Read `task_snapshot` (skip if absent for backward compat)
2. If `TaskList` populated: use live state. If empty AND snapshot non-empty: restore tasks (create completed as completed, pending as pending, set up `blockedBy`; log `[WARN]` on failures)
3. Display recovery summary with restored task board (same format as Step 3c)
4. Resume from `iteration + 1`, skip Step 1

---

## Known Limitations

### GAP-CRIT-001: Task Tool Availability

Subagents lack TaskCreate/TaskList/TaskUpdate/TaskGet. **Workaround**: Auto-orchestrate acts as task management proxy — subagents write to `proposed-tasks.json`, auto-orchestrate creates tasks (Step 4.2), current state passed in spawn prompt, orchestrators return `PROPOSED_ACTIONS`.

### .orchestrate/ Folder Structure

```
.orchestrate/<session-id>/
├── planning/                      # P-series planning artifacts
│   ├── P1-intent-brief.md
│   ├── P2-scope-contract.md
│   ├── P3-dependency-charter.md
│   ├── P4-sprint-kickoff-brief.md
│   └── planning-receipt.json      # Combined receipt for all planning stages
├── stage-{0,1,2,3,4,4.5,5,6}/     # Per-stage output
└── proposed-tasks.json            # Task proposals (written by orchestrator FIRST)
```

---

## Appendix A: Backend Scope Specification

> Included in enhanced prompt when `layers` contains `"backend"`.

### Task
Implement all backend features to production-ready state, then audit and fully integrate. Applies to both **greenfield** (build from scratch) and **existing** (complete and fix) codebases.

- **Greenfield**: Design and build the full backend — models, migrations, services, controllers, routes, authentication, authorization, seed data, and configuration. Every feature must be fully implemented with real persistence and real integrations.
- **Existing**: Complete all partial features, replace all simulations/placeholders/in-memory workarounds, fix every gap and integration issue.

No in-memory workarounds, no simulations, no fake data, no placeholder logic. Everything uses real implementations with proper persistence.

### Implementation Quality Criteria (for Stage 3 — NOT a pipeline sequence)

> **IMPORTANT**: These are quality requirements for the software-engineer (Stage 3) and validator (Stage 5).
> They are NOT pipeline stages. The pipeline sequence is always: Stage 0 (Research) -> 1 (Product Management) -> 2 (Specifications) -> 3 (Implementation) -> 4.5 (Codebase Stats) -> 5 (Validation) -> 6 (Documentation).

- **Branch** — Create a feature branch.

- **Implement All Features** — Build or complete every backend feature:
   - **Greenfield**: Create all models, migrations, services, controllers, routes, auth, middleware, seed data, config from scratch.
   - **Existing**: Walk through every module and complete partial/stubbed features.
   - Write real business logic — no placeholders, no TODOs.
   - Create all API endpoints, services, models, migrations.
   - Implement error handling, input validation, response formatting.
   - Wire all dependencies, database connections, service integrations.
   - Every feature must have a complete data path from API request -> persistent storage -> response.
   - Build missing controllers/routes for defined models. Implement real logic for mock-returning routes. Complete missing CRUD operations.

- **Full Codebase Audit** — After implementation, assess every module:
   - Fully implemented and functional end-to-end?
   - Missing validations, broken logic, incomplete integrations?
   - All API endpoints exposed, documented, working?
   - Any in-memory storage, simulated data, mock services, placeholder logic?
   - Any remaining TODO/FIXME/HACK/PLACEHOLDER comments?

- **Eliminate All Simulations** — Replace every instance of:
   - In-memory stores -> real persistent storage
   - Simulated/mocked service calls -> real integrations
   - Hardcoded/fake/sample data -> real data flows
   - Placeholder/stub logic -> full implementations
   - Every data path must survive restarts.

- **Fix All Gaps** — Address every remaining issue:
   - Broken configs, missing env vars, incomplete integrations
   - Validation gaps, bugs, logic errors
   - Database migrations — up to date and clean
   - Scripts (seed, setup, utility) must all work
   - Complete any still-partial features
   - Default users, roles, groups, permissions — functional seed data
   - Startup integrity — no errors on restart/cold boot
   - Service accounts and inter-service credentials working

- **Clean Build** — All build processes complete with zero errors, zero warnings.

- **Verify End-to-End** — Entire backend running, all features operational, data persists across restarts.

### Backend Constraints
- Implement-then-audit: build/complete all features first, then audit and fix.
- **Greenfield**: Build every module — don't skip because "nothing to audit."
- **Existing**: Scope covers every module and feature.
- Zero tolerance for in-memory storage, simulations, mock data, placeholders.
- All API responses use consistent formats (status codes, error shapes, pagination).

---

## Appendix B: Frontend Scope Specification

> Included in enhanced prompt when `layers` contains `"frontend"`.

### Task
Implement all frontend features to production-ready state, then audit and fully integrate. Applies to both **greenfield** and **existing** frontends.

- **Greenfield**: Build the complete frontend — app shell, navigation, routing, auth flows, every page/form/view to consume all backend APIs. Set up project structure, component library, state management, API client from scratch.
- **Existing**: Complete all partial pages/components, replace mock data/placeholder screens with real API integrations, fix all gaps.

The frontend must consume all backend API endpoints. No fake data, no mock APIs, no placeholder screens. **Primary design goal**: a 10-year-old child could use this system without supervision or training.

### Core Design Principles

#### 1. Minimum Typing, Maximum Selection
- **Dropdowns/Select boxes** for every field with known values — load from backend API.
- **Checkboxes** for booleans, toggles, multi-select.
- **Radio buttons** for small mutually exclusive choices.
- **Date/Time pickers** for all date/datetime/time fields — never manual typing.
- **Toggle switches** for enable/disable, active/inactive states.
- **Auto-complete/searchable dropdowns** for large lists.
- **Sliders** for numeric ranges. **Colour pickers** for colour fields. **File upload drag-and-drop** for attachments.
- **Text boxes only when unavoidable** (descriptions, names, notes, search). If a value exists in the system, it must be selected, not typed.

#### 2. Bulk Operations
Every list and table must support:
- **Multiple delete** with confirmation dialog.
- **Multiple create** / batch creation where applicable.
- **Select All / Deselect All** checkbox on headers.
- **Bulk status change**, **bulk assign**, **bulk export** (CSV, PDF, etc.).
- **Bulk actions toolbar** — floating/sticky when items selected.

#### 3. Tabs for Logical Grouping
- Use tabbed layouts when a page has multiple logical sections (Details, Related Items, History, Settings).
- Each tab loads data independently with loading indicator.
- Active tab reflected in URL for bookmarking/sharing.

#### 4. Pre-load Everything from the Backend
- Fetch all dropdown options, reference data, lookups on page load.
- Show loading states (spinners, skeletons, shimmer).
- Cache reference data within session. Display human-readable labels everywhere — not IDs/UUIDs.
- Dropdown options show relevant context (e.g., "John Smith — Admin").

#### 5. Child-Friendly Usability
- **Clear, simple labels** — no jargon, abbreviations, or technical terms.
- **Tooltips/help icons (?)** on every field with plain-language explanations.
- **Inline validation** with friendly messages (e.g., "Please pick a role" not "ValidationError: role_id null").
- **Confirmation dialogs** before destructive/irreversible actions.
- **Success/failure toast notifications** for every action.
- **Undo** where feasible (brief "Undo" option after delete).
- **Consistent layout** — same patterns everywhere (list -> detail -> edit -> back).
- **Breadcrumbs** on every page.
- **Large, clearly labelled buttons** — primary prominent, secondary subdued, destructive red.
- **Empty states** with friendly message and "Create Your First [Item]" button.
- **Search and filter bars** on every list (prefer dropdown filters over free-text).
- **Pagination** with sensible defaults and page size options.
- **Responsive design** (desktop, tablet, mobile).
- **Keyboard navigation** for all interactive elements.
- **Consistent iconography** alongside text labels (trash + "Delete", pencil + "Edit").
- **No dead ends** — every page has a clear next action or navigation.
- **Wizard/stepper flows** for complex multi-step creation with progress indicators.

#### 6. User Context in the Frontend
- Show/hide features based on logged-in user's **roles and permissions** from backend.
- Pre-fill current user info where relevant.
- Display user name, role, avatar in header.
- Filter data views by access level.
- **Disable or hide** actions the user lacks permission for — never show buttons that return 403.
- Personalised dashboard by role.
- Handle token expiry, session timeout, re-auth gracefully.

### Frontend Implementation Quality Criteria (for Stage 3 — NOT a pipeline sequence)

> **IMPORTANT**: These are quality requirements for the software-engineer (Stage 3) and validator (Stage 5).
> They are NOT pipeline stages. The pipeline sequence is always: Stage 0 (Research) -> 1 (Product Management) -> 2 (Specifications) -> 3 (Implementation) -> 4.5 (Codebase Stats) -> 5 (Validation) -> 6 (Documentation).

- **Map Every Feature to UI** — For every backend endpoint/module, identify every screen, form, list, detail view, and interaction needed.

- **Build All Pages** — For each feature:
   - **List/Table view**: search bar, dropdown filters, column sorting, bulk checkboxes, bulk toolbar, pagination, empty state.
   - **Create form**: dropdowns, checkboxes, date pickers, toggles, auto-complete. Text inputs only where unavoidable. Inline validation, help tooltips.
   - **Edit form**: same as create, pre-populated from API.
   - **Detail/View page**: read-only with tabs for logical sections, related data, activity history, metadata.
   - **Delete**: single with confirmation, bulk via checkbox selection.

- **Connect to Backend APIs** — Every page calls real endpoints, handles loading/error/empty/forbidden states, submits real data. No fake data, no mocked calls, no hardcoded values.

- **Navigation and Layout** — Complete application shell:
   - Sidebar/top nav grouped logically. Menu visibility by roles/permissions. Breadcrumbs everywhere.
   - Global search if applicable. User profile menu with logout, settings, profile.

- **Test End-to-End** — Every user flow works through to backend persistence. Every CRUD, bulk action, filter, and search works against the real backend.

### Frontend Constraints
- Every feature/endpoint gets a complete, fully functional UI.
- **Greenfield**: Build entire frontend from scratch — don't skip features.
- **Existing**: Complete and fix every page and component.
- Zero fake data, mock APIs, placeholder screens.
- Every dropdown/list/selection loads from backend API.
- Minimise text inputs — if a value can be selected, use a selection component.
- Bulk operations on every list view.
- Tabs wherever a page has multiple logical sections.
- Usable by a child. Plain language only. Visual feedback for every action.
- Permission-gated UI — never show what the user cannot use.

---

## Appendix C: Orchestrator Spawn Prompt Template

Use `Agent(subagent_type: "orchestrator", max_turns: 30)` with this prompt:

```
## MANDATORY FIRST ACTION (before boot)
Write `.orchestrate/<SESSION_ID>/proposed-tasks.json` atomically: write to `.orchestrate/<SESSION_ID>/proposed-tasks.tmp.json` first, then rename to `proposed-tasks.json`. This prevents partial reads if auto-orchestrate reads during write. If no new tasks: write `{"session_id": "<SESSION_ID>", "iteration": <N>, "tasks": []}`.

Format:
```json
{
  "session_id": "<SESSION_ID>",
  "iteration": <N>,
  "tasks": [
    {"subject": "...", "description": "...", "activeForm": "...", "stage": 0, "dispatch_hint": "researcher", "blockedBy": []},
    {"subject": "...", "description": "...", "activeForm": "...", "stage": 1, "dispatch_hint": "product-manager", "blockedBy": ["<stage-0-task-subject>"]},
    {"subject": "...", "description": "...", "activeForm": "...", "stage": 2, "dispatch_hint": "spec-creator", "blockedBy": ["<stage-1-task-subject>"]}
  ]
}
```
**CRITICAL**: Every task for Stage N (N > 0) MUST include `blockedBy` referencing Stage N-1 task(s). Tasks without chains will be auto-fixed or rejected.

All output files: `YYYY-MM-DD_<descriptor>.<ext>`.

## Auto-Orchestration Context

PARENT_TASK_ID: <parent_task_id>
SESSION_ID: <session_id>
ITERATION: <N> of <max_iterations>
SCOPE: <resolved scope>
SCOPE_LAYERS: <layers array>
STAGE_CEILING: <calculated ceiling>
MANIFEST_PATH: ~/.claude/manifest.json
GATE_STATE: <current gate state or "not_enforced">
PROJECT_TYPE: <greenfield|existing|continuation>
PROCESS_SCOPE_TIER: <trivial|medium|complex>
PROCESS_DOMAIN_FLAGS: <domain flags array>
PROCESS_ACTIVE_CATEGORIES: <active category numbers>
PROCESS_DOMAIN_GUIDES: <enabled domain guide commands>

**GATE_STATE values**:
- `"not_enforced"` — No `.gate-state.json` found; organizational gates not active
- `"gate_1_passed"` — Gate 1 (Intent Review) passed; Stage 0 unlocked
- `"gate_2_passed"` — Gates 1-2 passed; Stages 0-2 unlocked
- `"gate_3_passed"` — Gates 1-3 passed; Stages 0-3 unlocked
- `"gate_4_passed"` — All gates passed; full pipeline unlocked
- `"gate_N_blocked"` — Stage blocked due to missing gate; see STAGE_CEILING

**PROJECT_TYPE values**:
- `"greenfield"` — New project (< 5 commits AND < 10 source files)
- `"existing"` — Existing project with established codebase
- `"continuation"` — Continuation of a prior orchestration session

## STAGE_CEILING — HARD STRUCTURAL LIMIT
╔══════════════════════════════════════════════════════════════╗
║  STAGE_CEILING = <ceiling>                                   ║
║                                                              ║
║  MUST NOT: Spawn agents above ceiling, do work above         ║
║  ceiling, propose tasks without blockedBy chains,            ║
║  rationalize skipping ahead.                                 ║
║                                                              ║
║  MAY: Propose future-stage tasks WITH blockedBy chains,      ║
║  spawn agents at/below ceiling, advance current stage.       ║
║                                                              ║
║  0=research only, 1=+architect, 2=+specs, 3=+impl,          ║
║  4.5=+stats, 5=+validation, 6=+docs.                        ║
║  Stages above ceiling are STRUCTURALLY BLOCKED.              ║
╚══════════════════════════════════════════════════════════════╝

## Scope Context
{{#if scope != "custom"}}
Only work on layers in SCOPE_LAYERS.
- backend: Backend modules, services, APIs, migrations. Do NOT modify frontend.
- frontend: Frontend pages, components, forms, API integrations. Do NOT modify backend (except reading API contracts).
- fullstack: Both in scope. Backend generally precedes frontend.
Follow scope specifications in Enhanced Prompt precisely.
{{else}}
No scope restriction — follow the enhanced prompt as written.
{{/if}}

## Process Scope (PROCESS-SCOPE-001)

Process scope tier: **{{PROCESS_SCOPE_TIER}}**
Domain flags: {{PROCESS_DOMAIN_FLAGS}}
Active categories: {{PROCESS_ACTIVE_CATEGORIES}}
Domain guides enabled: {{PROCESS_DOMAIN_GUIDES}}

When evaluating process injection hooks from `processes/process_injection_map.md`, only fire hooks whose `scope_condition` is met by the current process scope tier. Hooks with `domain_flag` requirements only fire if that flag is in PROCESS_DOMAIN_FLAGS.

At each stage transition, consult the expanded injection map for applicable processes:
- **Core hooks** (scope_condition: "all"): Always fire
- **MEDIUM hooks**: Fire only if PROCESS_SCOPE_TIER is "medium" or "complex"
- **COMPLEX hooks**: Fire only if PROCESS_SCOPE_TIER is "complex"
- **Domain-conditional hooks**: Fire only if PROCESS_SCOPE_TIER is "complex" AND the required domain_flag is active

Log applicable processes as `[PROCESS-INJECT]` or `[PROCESS-INFO]` per the injection map's action types.

## Dispatch Context (from Command Dispatcher)

{{#if dispatch_context[STAGE_CEILING] is non-empty}}
The Command Dispatcher has produced findings relevant to the current stage. Address these in your work:

{{#for each entry in dispatch_context[STAGE_CEILING]}}
### [DISPATCH-{{entry.trigger_id}}] {{entry.command}} findings
**Severity**: {{entry.severity_max}}
**Summary**: {{entry.result_summary}}
**Action required**: {{entry.next_action_instruction}}
**Artifacts**: {{entry.artifacts}}
{{/for each}}

These findings were produced by domain guide analysis and MUST be incorporated into stage work. For Stage 2 (specification), include as requirements. For Stage 3 (implementation), include as constraints. For Stage 5 (validation), include as acceptance criteria.
{{else}}
No dispatch context for the current stage.
{{/if}}

## Domain Review Context (from Agent Activation Protocol)

Read and follow `~/.claude/_shared/protocols/agent-activation.md`.
At each stage transition, evaluate activation rules from `manifest.agents[*].activation_rules`. If conditions are met, spawn domain agent(s) for single-stage review (max 2 per stage, budget-exempt per AGENT-ACTIVATE-003).
Domain review artifacts: `.orchestrate/<SESSION_ID>/domain-reviews/`
Inject review findings into subsequent stage spawn prompts.

{{#if domain_reviews[STAGE_CEILING] is non-empty}}
Domain expert agents reviewed artifacts for the current stage. Their findings MUST inform your work:

{{#for each review_agent in domain_reviews[STAGE_CEILING]}}
### [DOMAIN-REVIEW] {{review_agent}} findings
Read: `.orchestrate/<SESSION_ID>/domain-reviews/{{review_agent}}-stage-{{STAGE_CEILING}}.md`
Incorporate CRITICAL/HIGH findings as requirements. Acknowledge MEDIUM/LOW findings.
{{/for each}}
{{else}}
No domain reviews for the current stage.
{{/if}}

## Autonomous Mode Permissions (pre-granted)
Operate without confirmations (MAIN-008). Access ~/.claude/ freely. Make assumptions. Do NOT call EnterPlanMode.
Ask user ONLY when: files outside scope (MAIN-009), deletion needed (MAIN-010), or all tasks blocked.

## MANDATORY: Progress Output (PROGRESS-001)
Output visible progress before/after each subagent spawn, at loop start, between spawns, on error/retry, at end. Never leave extended silence.

## Enhanced Prompt
{{#if scope != "custom"}}
### Objective
<enhanced_prompt.objective>

### Additional User Context
<enhanced_prompt.context, assumptions, out_of_scope>

### FULL SCOPE SPECIFICATION (VERBATIM — EVERY LINE MANDATORY)
╔══════════════════════════════════════════════════════════════╗
║  NON-NEGOTIABLE. Every bullet MUST be followed precisely.    ║
║  ALL subagents MUST receive relevant parts in full.          ║
║  "Implementation Quality Criteria" = Stage 3/5 requirements  ║
║  ONLY. Pipeline sequence: Stage 0->1->2->3->4.5->5->6.      ║
╚══════════════════════════════════════════════════════════════╝

<Paste FULL enhanced_prompt.scope_specification verbatim>

{{else}}
**Objective**: <enhanced_prompt.objective>
**Context**: <enhanced_prompt.context>
**Deliverables**: <enhanced_prompt.deliverables>
**Constraints**: <enhanced_prompt.constraints>
**Success Criteria**: <enhanced_prompt.success_criteria>
**Assumptions**: <enhanced_prompt.assumptions>
**Out of Scope**: <enhanced_prompt.out_of_scope>
{{/if}}

## Delegation Guard — YOU ARE A COORDINATOR, NOT A WORKER
╔══════════════════════════════════════════════════════════════╗
║  The orchestrator MUST delegate ALL work to subagents.       ║
║  The orchestrator NEVER does the work itself.                ║
║                                                              ║
║  - Stage 0: Spawn `researcher` agent — do NOT read project  ║
║    files, do NOT use WebSearch yourself, do NOT analyze      ║
║    the codebase. The researcher agent does this.             ║
║  - Stage 1: Spawn `product-manager` agent — do NOT decompose ║
║    tasks yourself.                                           ║
║  - Stage 2: Spawn `spec-creator` agent — do NOT write       ║
║    specs yourself.                                           ║
║  - Stage 3+: Spawn appropriate agents — do NOT implement,   ║
║    test, validate, or document yourself.                     ║
║                                                              ║
║  Your ONLY job: propose tasks, spawn subagents, track        ║
║  progress, report back via PROPOSED_ACTIONS.                 ║
║                                                              ║
║  "Composing task descriptions" means writing a prompt for    ║
║  the subagent. It does NOT mean reading files to understand  ║
║  the codebase, doing research, or analyzing code.            ║
║  Glob/Grep to find file paths for subagent prompts = OK.     ║
║  Reading file contents to understand/analyze them = VIOLATION║
╚══════════════════════════════════════════════════════════════╝

## Tool Availability
TaskCreate, TaskList, TaskUpdate, TaskGet are NOT available.
Agent tool for spawning subagents IS available — use it. You MUST spawn subagents to do work.

**If Agent tool fails**: Return PROPOSED_ACTIONS only. NEVER do work yourself. NEVER fall back to doing research/implementation inline. Glob/Grep ONLY to find file paths for subagent prompts — NEVER to analyze, research, or understand the codebase.

**Violation patterns** (if you catch yourself doing ANY of these — STOP):
- "Let me take a more practical approach"
- "I'll do the research by reading the codebase"
- "This is more efficient"
- "I'll just quickly check/read/analyze..."
- "I'll create tasks and spawn agents directly"
- Reading file contents to understand the project (that's the researcher's job)
- Using WebSearch/WebFetch yourself (that's the researcher's job)
- Doing codebase analysis yourself (that's the researcher/architect's job)
- Writing specs, code, tests, or docs yourself (that's the subagent's job)
- Spawning any agent above STAGE_CEILING
- "Stage 0/1/2 isn't needed for this"
- "I'll skip to implementation since I know what to do"
- "The fix is obvious, no need for research/specs"
- Proposing tasks without blockedBy chains

## Current Task State
<TaskList output: Task #id: "subject" — status, blockedBy: [ids]>

## Pipeline Progress
Current stage: <N> | Completed: <list> | Next: <first incomplete> | STAGE_CEILING: <ceiling>

## Previous Iteration Summary
<Summary from N-1, or "First iteration">

## Session Isolation
SESSION_ID: <session_id>. Pass to ALL subagent spawns and file paths.

## Instructions
1. **FIRST: Check STAGE_CEILING** — You MUST NOT work above this number. Non-negotiable.
2. Skip completed tasks. Focus on pending/failed AT OR BELOW STAGE_CEILING.
3. Do NOT call TaskCreate/TaskList/TaskUpdate/TaskGet.
4. Propose new tasks via .orchestrate/<session_id>/proposed-tasks.json AND PROPOSED_ACTIONS. ALL Stage N proposals must `blockedBy` Stage N-1 tasks.
5. Spawn subagents via Agent tool to do ALL work. You MUST delegate — never do research, analysis, implementation, or any stage work yourself. If Agent tool fails: return PROPOSED_ACTIONS only and let auto-orchestrate retry.
6. Follow the Execution Loop — don't stop after one piece of work.
7. **Sequential stage gate** — Do NOT spawn Stage N+1 while Stage N tasks are pending/in-progress. Stages 0->1->2 before Stage 3. Stages 4.5->5->6 after Stage 3.
8. **STAGE_CEILING gate** — NEVER exceed ceiling. If STAGE_CEILING=0, ONLY Stage 0 work. Period.
9. FLOW INTEGRITY (MAIN-012): Full pipeline, never skip stages.
10. STAGE ENFORCEMENT: {{#if mandatory_stage_enforcement}}OVERDUE — prioritize missing stages.{{else}}Stages 0,1,2,4.5,5,6 ALL mandatory.{{/if}}
11. Return PROPOSED_ACTIONS JSON block at end.
12. NO AUTO-COMMIT (MAIN-014): Never git commit/push. Include in every subagent prompt.
13. SCOPE-001/002: Include FULL scope spec verbatim in EVERY subagent spawn when scope != custom.

## Agent Constraints (include in spawn prompts)

**All agents (when scope != custom)**: Include FULL scope spec verbatim (SCOPE-001).

**researcher** (Stage 0 — mandatory, always first):
- You MUST spawn a `researcher` subagent via `Agent(subagent_type: "researcher")`. Do NOT do research yourself — no reading project files, no WebSearch, no codebase analysis. The researcher AGENT does all of this.
- Include in the researcher's prompt: MUST use WebSearch+WebFetch (RES-008). Codebase-only analysis = VIOLATION. At least 3 WebSearch queries. If unavailable: status "partial".
- Check CVEs (RES-005), latest stable versions.
- MUST research implementation risks and produce Risks & Remedies (RES-009).
- Packages with unpatched HIGH/CRITICAL CVEs = BLOCKED — list alternatives (RES-010).
- MUST recommend LATEST stable versions of all packages/images, not just CVE-free ones (RES-011).
- MUST verify version numbers via WebSearch against official registries — training-data versions are PROHIBITED as sole source (RES-012).
- Output MUST include a "Recommended Versions" table: package name, version, source URL, date checked.
- If software-engineer triggers feedback (IMPL-FEEDBACK), re-spawn researcher with targeted version/API query (RES-013). Max 2 re-research iterations per package.
- Output: .orchestrate/<SESSION_ID>/stage-0/YYYY-MM-DD_<slug>.md

**product-manager** (Stage 1 — mandatory, after researcher):
- You MUST spawn a `product-manager` subagent via `Agent(subagent_type: "product-manager")`. Do NOT decompose tasks or design architecture yourself.
- 4-Phase Pipeline: Scope Analysis -> Task Decomposition -> Dependency Graph -> Quick Reference
- Every task needs dispatch_hint (required) and risk level.
- MUST read Stage 0 research: no CVE-blocked packages; include HIGH-severity remedies as acceptance criteria.
- Output: .orchestrate/<SESSION_ID>/stage-1/

**spec-creator** (Stage 2 — mandatory, after product-manager):
- You MUST spawn a `spec-creator` subagent. Do NOT write specs yourself.
- Technical specs: scope, interface contracts, acceptance criteria.
- MUST read Stage 0 research: no CVE-blocked packages in specs; include remedies as requirements.
- Output: .orchestrate/<SESSION_ID>/stage-2/

**software-engineer** (Stage 3):
- IMPL-001: No placeholders. IMPL-006: Enterprise production-ready. IMPL-008: 0 security issues. IMPL-013/MAIN-014: No auto-commit.
- IMPL-014: MUST read Stage 0 research. Apply all remedies. MUST NOT use CVE-blocked packages. Pin to CVE-free versions.
- IMPL-015: MUST use exact versions from researcher's "Recommended Versions" table. If the recommended version's API differs from expected patterns, emit `[IMPL-FEEDBACK] Package: {name}@{version}, Issue: {description}` and HALT — orchestrator re-spawns researcher (RES-013). Max 2 feedback loops; after 2nd, proceed with best info or escalate to user.

**codebase-stats** (Stage 4.5 — mandatory after implementation):
- TODO/FIXME/HACK counts, large files, complex functions. Compare against previous.

**validator** (Stage 5 — mandatory after implementation):
- Zero-error gate: 0 errors, 0 warnings (MAIN-006).
- MANDATORY: User journey testing (CRUD, auth, navigation, error handling).
- MANDATORY: Feature functionality testing per implemented feature.
- Docker available: invoke docker-validator. Otherwise: API-level/code verification.
- Fix-loop: validate->report->fix->revalidate (max 3 iterations).
- **Auto-Debug Escalation** (GAP-CMD-003): After the validator exhausts 3 fix iterations and errors persist:
  1. Display to user:
     ```
     [ESCALATE] Stage 5 validation failed after 3 fix iterations.
     Remaining errors: <error_count>
     
     Would you like to escalate to /auto-debug for autonomous error resolution? (Y/n)
     ```
  2. If user confirms (Y): Display invocation hint:
     ```
     [ESCALATE] Run: /auto-debug
     Context: Session auto-orc-<session-id>, Stage 5 validation failures
     ```
     Set `terminal_state: "escalated_to_debug"` and exit the auto-orchestrate loop.
  3. If user declines (n): Continue with normal termination as `stalled`.
  4. **NEVER trigger auto-debug automatically** — always require explicit user confirmation.

**technical-writer** (Stage 6 — mandatory after stable implementation):
- Pipeline: docs-lookup -> docs-write -> docs-review.
- Update ARCHITECTURE.md, INTEGRATION.md, relevant docs.
```

---

## Appendix D: Fullstack Scope Prefix

When scope is `fullstack`, prefix both Appendix A and B with:

```markdown
## Scope
**Backend** and **Frontend** — covers every module, service, feature, and/or endpoint in the codebase.
```

---

## Appendix E: Unified Pipeline Flow Integration

This appendix maps the auto-orchestrate pipeline stages to the organizational process framework defined in `Engineering_Team_Structure_Guide.md` and `clarity_of_intent.md`.

### E.1 Clarity of Intent Gate Mapping

The four Clarity of Intent gates (from `clarity_of_intent.md`) map to auto-orchestrate preconditions and stage boundaries:

| Clarity of Intent Stage | Gate | Auto-Orchestrate Mapping | Enforcement |
|------------------------|------|-------------------------|-------------|
| Stage 1: Intent Frame | Intent Review Gate (P-004) | Handoff receipt contains valid `task_description`; P-001 intent captured | Informational — logged if present |
| Stage 2: Scope Contract | Scope Lock Gate (P-013) | `gate_2_scope_lock.status == "passed"` required before pipeline start | **Enforced** — blocks pipeline if not passed |
| Stage 3: Dependency Map | Dependency Acceptance Gate (P-019) | Dependency Charter exists at `scope_contract_path` | Informational — not enforced by auto-orchestrate |
| Stage 4: Sprint Bridge | Sprint Readiness Gate (P-025) | Sprint Kickoff Brief present in handoff | Informational — logged when passed |

### E.2 Engineering Team Role Mapping

Auto-orchestrate pipeline stages map to the Engineering Team Structure Guide roles:

| Pipeline Stage | Agent | Engineering Team Role(s) | Typical Organizational Level |
|---------------|-------|-------------------------|------------------------------|
| Stage 0 | researcher | Staff Engineer, Principal Engineer | L6-L7 (technical research) |
| Stage 1 | product-manager | Product Manager, Tech Lead | L5-L6 (architecture) |
| Stage 2 | spec-creator | Tech Lead, Product Manager | L5 + PM (specification) |
| Stage 3 | software-engineer | Software Engineer, Senior Software Engineer | L4-L5 (implementation) |
| Stage 4 | test-writer-pytest | SDET, QA Engineer | L4-L5 (quality) |
| Stage 4.5 | codebase-stats | Staff Engineer | L6 (codebase analysis) |
| Stage 5 | validator | QA Engineer, Tech Lead | L4-L6 (validation) |
| Stage 6 | technical-writer | Technical Writer, Software Engineer | L3-L5 (documentation) |

### E.3 Process Injection Points

The process injection map (`process_injection_map.md`) links organizational processes to pipeline stages:

| Pipeline Stage | Injected Processes | Enforcement Level |
|---------------|-------------------|-------------------|
| Stage 0 | P-001 (Intent), P-038 (AppSec Scope) | Advisory (notify) |
| Stage 1 | P-007, P-008, P-009, P-010 (Deliverables, DoD, Metrics, RAID) | Advisory (link) |
| Stage 2 | P-033 (Technical Design), P-038 (Security by Design) | **Gate** (P-038 enforced) |
| Stage 3 | P-034 (Code Review), P-036 (Security), P-040 (Dependency) | Advisory (notify) |
| Stage 4 | P-035 (Testing), P-037 (Automated Testing) | Advisory (link) |
| Stage 4.5 | P-062 (Technical Debt Audit) | Advisory (link) |
| Stage 5 | P-034, P-036, P-037 (Review, Security, UAT) | **Gate** (P-034, P-037 enforced V2) |
| Stage 6 | P-058 (Technical Docs), P-059 (API Docs), P-061 (Runbook) | **Gate** (P-058 enforced V2) |

### E.4 Audit Layer Coverage

Per the 7-layer audit system from the Engineering Team Structure Guide:

| Audit Layer | Applicable Pipeline Stages | Automated Coverage |
|-------------|---------------------------|-------------------|
| Layer 7: IC/Squad Engineer | Stages 3, 4 | Stage 3 (software-engineer), Stage 4 (test-writer-pytest) |
| Layer 6: Tech Lead/Staff | Stages 1, 2, 4.5, 5 | Stage 1 (product-manager), Stage 2 (spec-creator), Stage 5 (validator) |
| Layer 5: Engineering Manager | Pre-pipeline (handoff) | Gate enforcement at pipeline start |
| Layers 1-4 | Outside pipeline scope | Organizational processes, not automated |

### E.5 Cross-Reference Documents

For full process details, consult:
- `clarity_of_intent.md` — Four-stage intent-to-execution framework
- `Engineering_Team_Structure_Guide.md` — Team roles, hierarchy, delivery methodology
- `claude-code/processes/process_injection_map.md` — Process-to-stage injection hooks
- `claude-code/processes/UNIFIED_END_TO_END_PROCESS.md` — 93-process lifecycle synthesis
