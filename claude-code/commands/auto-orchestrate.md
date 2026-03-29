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
---

# Autonomous Orchestration Loop

## Core Constraints — IMMUTABLE

| ID | Rule |
|----|------|
| AUTO-001 | **Orchestrator-only gateway** — Spawn ONLY `subagent_type: "orchestrator"`. Never spawn implementer, documentor, etc. directly. If 2 consecutive retries return empty output, abort with `[AUTO-001]` message. |
| AUTO-002 | **Mandatory stage completion** — Cannot declare `completed` unless `stages_completed` includes 0, 1, 2, 4.5, 5, and 6. Stage 4 (test-writer-pytest) is optional — included only when the epic-architect (Stage 1) produces test tasks. If no Stage 4 tasks exist, Stage 4 is considered implicitly complete. |
| AUTO-003 | **Stage monotonicity** — `current_pipeline_stage` only increases or holds. Keep high-water mark on regression. |
| AUTO-004 | **Post-implementation stage gate** — If Stage 3 done but 4.5/5/6 missing for 1+ iterations, set `mandatory_stage_enforcement: true` and inject missing-stage tasks. |
| AUTO-005 | **Checkpoint-before-spawn** — Write checkpoint to disk before every orchestrator spawn. |
| AUTO-006 | **No direct agent routing** — Never tell the orchestrator which agent to use; routing is its decision. |
| AUTO-008 | **Orchestrator delegation mandate** — The orchestrator MUST spawn subagents for ALL stage work. It must NEVER do research, analysis, implementation, testing, or documentation itself. Reading project files to "understand" the codebase is researcher work, not orchestrator work. |
| AUTO-007 | **Iteration history immutability** — Only append to `iteration_history`; never modify existing entries. |
| CEILING-001 | **Stage ceiling enforcement** — Calculate `STAGE_CEILING` from `stages_completed` before every spawn (Step 3a). Orchestrator MUST NOT work above STAGE_CEILING. Auto-fix missing `blockedBy` chains. |
| CHAIN-001 | **Mandatory blockedBy chains** — Every proposed task for Stage N (N > 0) must include `blockedBy` referencing at least one Stage N-1 task. Auto-orchestrate validates and auto-fixes in Step 4.2. |
| PROGRESS-001 | **Always-visible processing** — Output status lines before/after every tool call, spawn, and processing step. Never leave extended silence. See `commands/CONVENTIONS.md` for format. |
| PROGRESS-002 | **In-progress blocks completion** — Tasks with status `in_progress` mean background agents are still working. NEVER evaluate termination, declare completion, or mark stages done while `in_progress > 0`. Display running task count prominently. |
| DISPLAY-001 | **Task board at every iteration** — Show full task board with individual tasks grouped by stage at iteration start (Step 3) and post-iteration (Step 4.3). |
| SCOPE-001 | **Scope specification passthrough** — When scope is not `custom`, pass FULL scope spec (Appendix A/B) VERBATIM through every layer. Never summarize. |
| SCOPE-002 | **Scope template integrity** — A narrow user objective does not reduce the spec — all design principles, steps, and constraints still apply in full. |
| MANIFEST-001 | **Manifest-driven pipeline** — The orchestrator MUST read `~/.claude/manifest.json` at boot and use it as the authoritative registry for agent routing, skill discovery, and capability validation. Auto-orchestrate passes the manifest path in every orchestrator spawn. Agents MUST verify their mandatory skills exist in the manifest before invoking them. |

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

## Pipeline Stage Reference

| Stage | Agent (`dispatch_hint`) | Mandatory | Complete when |
|-------|------------------------|-----------|---------------|
| 0 | `researcher` | **YES** | researcher task completed |
| 1 | `epic-architect` | **YES** | epic-architect task completed |
| 2 | `spec-creator` | **YES** | spec-creator task completed |
| 3 | `implementer` / `library-implementer-python` | Per task | implementer task completed |
| 4 | `test-writer-pytest` | Per task | test-writer-pytest task completed |
| 4.5 | `codebase-stats` | **YES** (post-impl) | codebase-stats task completed |
| 5 | `validator` | **YES** | validator task completed |
| 6 | `documentor` | **YES** | documentor task completed |

Unknown/no dispatch_hint → "Uncategorized".

## Configuration Defaults

| Parameter | Default | Description |
|-----------|---------|-------------|
| `MAX_ITERATIONS` | 100 | Hard cap on orchestrator spawns |
| `STALL_THRESHOLD` | 2 | Consecutive no-progress iterations before fail |
| `CHECKPOINT_DIR` | `.orchestrate/<session-id>/` | Primary checkpoint directory (project-local) |
| `SESSION_DIR` | `~/.claude/sessions` | Legacy fallback (read-only) |
| `SCOPE` | `custom` | Stack scope: `frontend`, `backend`, `fullstack`, or `custom` |

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

Also update `.sessions/index.json` at the project root: set the superseded session's status to `"superseded"` and add `"superseded_at"`. See `commands/SESSIONS-REGISTRY.md` for the registry format and write protocol.

### 2c. Create new session

**Session ID**: `auto-orc-<DATE>-<8-char-slug>` (slug from user input).

Create parent tracking task via `TaskCreate` (if available; if TaskCreate fails, log `[CROSS-001] TaskCreate unavailable — setting parent_task_id: null` and continue with `parent_task_id: null`), then:

```bash
mkdir -p .orchestrate/<session-id>/{stage-0,stage-1,stage-2,stage-3,stage-4,stage-4.5,stage-5,stage-6}
```

Write checkpoint to `.orchestrate/<session-id>/checkpoint.json` (primary) and `~/.claude/sessions/<session-id>.json` (legacy):

```json
{
  "schema_version": "1.0.0",
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
  "task_snapshot": { "written_at": null, "iteration": null, "tasks": [] }
}
```

---

## Step 3: Spawn Orchestrator (Loop Entry)

> **CRITICAL TRANSITION GUARD**: You should arrive here with EXACTLY ONE task (the parent tracking task from Step 2c) and ZERO knowledge of the project's internals. If you have read project files, identified components/services, or created multiple tasks — you have violated the Execution Guard. STOP and restart from this step. The orchestrator and its subagents will do ALL project analysis and task creation.

**Before spawning** (AUTO-005): Increment `iteration`, update `updated_at`, write checkpoint.

### 3a. Calculate STAGE_CEILING

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

### 3b. Display iteration banner

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 ITERATION <N> of <max> | Session: <session_id>
 STAGE_CEILING: <ceiling> | Pipeline: Stage 0 <✓/✗> → ... → Stage 6 <✓/✗>
 Tasks: <completed> done, <in_progress> running, <pending> pending, <blocked> blocked
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

> **IMPORTANT**: If `in_progress > 0`, append to the banner: `⚠ <N> task(s) still running — pipeline NOT complete`

### 3c. Display task board (DISPLAY-001)

Query `TaskList`, group by `dispatch_hint` using the Pipeline Stage Reference table. Display:

```
 TASK BOARD:
 ┌─ Stage 0 (Research) ─────────────────────────────
 │  ✓ #2  Research pipeline audit best practices
 ├─ Stage 1 (Epic Architecture) ────────────────────
 │  ◷ #3  Decompose audit into epic tasks          [blocked by #2]
 ├─ Stage 2 (Specifications) ───────────────────────
 │  ◷ #4  Create technical specifications          [blocked by #3]
 └──────────────────────────────────────────────────
 Legend: ✓ completed  ▶ in_progress  ○ pending  ◷ blocked
```

Each task shows: status icon, task ID, subject (truncated to 45 chars), `[blocked by #N]` if blocked.

### 3d. Pre-spawn self-check

Before spawning, verify ALL of these conditions. If ANY fails, you are off-track:
- [ ] You are about to spawn exactly ONE agent with `subagent_type: "orchestrator"` — NOT 5 parallel agents, NOT implementer/researcher/documentor agents
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
- **blockedBy chain validation (CHAIN-001)**: Every task for Stage N (N > 0) must reference Stage N-1. Auto-fix missing chains: `[CHAIN-FIX] Added blockedBy to "<subject>"`
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

**4.9 Mandatory stage gates**:
- **AUTO-004**: If Stage 3 done but 4.5/5/6 missing for 1+ iterations → `mandatory_stage_enforcement: true`, inject missing tasks.
- **Proactive injection**: For any mandatory stage at or below `STAGE_CEILING` absent from `stages_completed` with no pending/in-progress task, create it immediately with proper `blockedBy` chain:
  - Stage 0: `researcher`, no blockedBy
  - Stage 1: `epic-architect`, blockedBy Stage 0
  - Stage 2: `spec-creator`, blockedBy Stage 1
  - Stage 4: `test-writer-pytest`, blockedBy Stage 3 (**optional** — inject only if epic-architect produced test tasks)
  - Stage 4.5: `codebase-stats`, blockedBy Stage 3
  - Stage 5: `validator`, blockedBy Stage 4.5
  - Stage 6: `documentor`, blockedBy Stage 5

**4.10 Evaluate termination** (see Step 5).

**4.11 If NOT terminated** → return to Step 3.

---

## Step 5: Termination Conditions

**Pre-check — in_progress tasks block termination**: If ANY tasks have status `in_progress`, skip ALL termination checks and return to Step 3 (next iteration). Background agents are still working — the pipeline is neither complete, stalled, nor blocked. Display: `⚠ <N> task(s) still in_progress — skipping termination check, continuing loop`.

Evaluate in order (ONLY when zero tasks are `in_progress`):

| # | Condition | Status |
|---|-----------|--------|
| 1 | All tasks completed AND `stages_completed` includes 0,1,2,4.5,5,6 (Stage 4 optional — see AUTO-002) | `completed` |
| 1a | All tasks completed BUT mandatory stages missing | Inject tasks, retry once. If still missing: `completed_stages_incomplete` |
| 2 | `iteration >= MAX_ITERATIONS` | `max_iterations_reached` |
| 3 | No progress for `STALL_THRESHOLD` consecutive iterations | `stalled` |
| 4 | All remaining tasks blocked AND zero `in_progress` | `all_blocked` |

**Stall detection**: Same pending+completed counts for 2 consecutive iterations = stall. However, `in_progress` tasks reset the stall counter (work is actively happening). `tasks_partial_continued` also resets counter.

**In-progress ceiling (AO-INEFF-001)**: Track per-task `in_progress_iterations` count. If any task remains `in_progress` for 5 consecutive iterations without completing, treat it as failed: set status to `failed`, log `[AO-INEFF-001] Task #<id> "<subject>" stuck in_progress for 5 iterations — marking failed`, and do NOT let it reset the stall counter.

### On Termination

Set `terminal_state` and `status`, update parent task, display:

```
## Auto-Orchestration Complete
**Session**: <session_id> | **Scope**: <resolved> | **Status**: <terminal_state> | **Iterations**: N/max

### Pipeline
Stage 0 <✓/✗> → Stage 1 <✓/✗> → ... → Stage 6 <✓/✗>

### Completed Tasks
- ✓ [#id] <subject> (<agent>, Stage N)

### Remaining Tasks (if any)
- ○ [#id] <subject> (<agent>, Stage N) — blocked by #id

### Mandatory Stages
| Stage | Status | Task |
|-------|--------|------|
| 0 (researcher) | ✓/✗ | #<id> <subject> |
| 1 (epic-architect) | ✓/✗ | #<id> <subject> |
| 2 (spec-creator) | ✓/✗ | #<id> <subject> |
| 4.5 (codebase-stats) | ✓/✗ | #<id> <subject> |
| 5 (validator) | ✓/✗ | #<id> <subject> |
| 6 (documentor) | ✓/✗ | #<id> <subject> |

### Git Commit Instructions
> Auto-orchestrate NEVER commits automatically. Review and commit manually.
**Files modified**: [from implementer DONE blocks]
**Suggested commits**: [Git-Commit-Message values]

### Iteration Timeline
| # | Completed | Running | Pending | Tasks Worked On |
|---|-----------|---------|---------|-----------------|
| 1 | 0 | 0 | 7 | Proposed all pipeline tasks |
| 2 | 0 | 1 | 6 | ▶ #2 Research (Stage 0) |
| 3 | 1 | 0 | 6 | ✓ #2 Research (Stage 0) |
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
├── stage-{0,1,2,3,4,4.5,5,6}/   # Per-stage output
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

> **IMPORTANT**: These are quality requirements for the implementer (Stage 3) and validator (Stage 5).
> They are NOT pipeline stages. The pipeline sequence is always: Stage 0 (Research) -> 1 (Epic Architecture) -> 2 (Specifications) -> 3 (Implementation) -> 4.5 (Codebase Stats) -> 5 (Validation) -> 6 (Documentation).

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

> **IMPORTANT**: These are quality requirements for the implementer (Stage 3) and validator (Stage 5).
> They are NOT pipeline stages. The pipeline sequence is always: Stage 0 (Research) -> 1 (Epic Architecture) -> 2 (Specifications) -> 3 (Implementation) -> 4.5 (Codebase Stats) -> 5 (Validation) -> 6 (Documentation).

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
    {"subject": "...", "description": "...", "activeForm": "...", "stage": 1, "dispatch_hint": "epic-architect", "blockedBy": ["<stage-0-task-subject>"]},
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
║  - Stage 1: Spawn `epic-architect` agent — do NOT decompose ║
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
- If implementer triggers feedback (IMPL-FEEDBACK), re-spawn researcher with targeted version/API query (RES-013). Max 2 re-research iterations per package.
- Output: .orchestrate/<SESSION_ID>/stage-0/YYYY-MM-DD_<slug>.md

**epic-architect** (Stage 1 — mandatory, after researcher):
- You MUST spawn an `epic-architect` subagent via `Agent(subagent_type: "epic-architect")`. Do NOT decompose tasks or design architecture yourself.
- 4-Phase Pipeline: Scope Analysis -> Task Decomposition -> Dependency Graph -> Quick Reference
- Every task needs dispatch_hint (required) and risk level.
- MUST read Stage 0 research: no CVE-blocked packages; include HIGH-severity remedies as acceptance criteria.
- Output: .orchestrate/<SESSION_ID>/stage-1/

**spec-creator** (Stage 2 — mandatory, after epic-architect):
- You MUST spawn a `spec-creator` subagent. Do NOT write specs yourself.
- Technical specs: scope, interface contracts, acceptance criteria.
- MUST read Stage 0 research: no CVE-blocked packages in specs; include remedies as requirements.
- Output: .orchestrate/<SESSION_ID>/stage-2/

**implementer** (Stage 3):
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

**documentor** (Stage 6 — mandatory after stable implementation):
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
