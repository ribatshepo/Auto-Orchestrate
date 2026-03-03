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
    default: 15
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
  - name: resume
    type: boolean
    required: false
    default: false
    description: Explicitly resume the latest in-progress session, ignoring task_description.
---

# Autonomous Orchestration Loop

Run an orchestrator in a loop until all tasks are completed, with crash recovery via session checkpoints.

## Core Constraints (AUTO) — IMMUTABLE

| ID | Rule | Violation Example |
|----|------|-------------------|
| AUTO-001 | **Orchestrator-only gateway** — MUST spawn ONLY `subagent_type: "orchestrator"`. No direct agent spawning (implementer, documentor, etc.) from this command | Spawning `implementer` directly from auto-orchestrate instead of through the orchestrator |
| AUTO-002 | **Mandatory stage completion before termination** — MUST NOT declare `completed` unless `stages_completed` includes 0, 1, 2, 4.5, 5, and 6 | Terminating as `completed` when all tasks are done but researcher (Stage 0), epic-architect (Stage 1), or spec-creator (Stage 2) was never spawned |
| AUTO-003 | **Stage monotonicity** — `current_pipeline_stage` must only increase or stay the same across iterations. If a lower stage is detected, keep the high-water mark | Pipeline regressing from Stage 5 back to Stage 3 between iterations |
| AUTO-004 | **Post-iteration mandatory stage gate** — if Stage 3 is done but any of 4.5/5/6 are missing for 2+ consecutive iterations, enforce priority in the next orchestrator spawn | Implementation done 3 iterations ago but validator and documentor never spawned |
| AUTO-005 | **Checkpoint-before-spawn invariant** — MUST write checkpoint to disk before every orchestrator spawn | Spawning orchestrator before persisting iteration state |
| AUTO-006 | **No direct agent routing in spawn prompt** — the spawn prompt MUST NOT instruct the orchestrator to use a specific agent for a specific task; routing is the orchestrator's decision | Telling the orchestrator "use implementer for task X" in the spawn prompt |
| AUTO-007 | **Iteration history immutability** — entries in `iteration_history` MUST NOT be modified after being written; only append new entries | Retroactively changing a previous iteration's `tasks_completed` count |
| AUTO-008 | **Always-visible processing (PROGRESS-001)** — MUST output visible progress text at every processing step. The user MUST never see extended silence. Both auto-orchestrate and the orchestrator MUST emit status lines before/after every tool call, spawn, and processing step | Spawning orchestrator and showing nothing for 5+ minutes while it runs |

## Step 0: Autonomous Mode Declaration

Before ANY other processing, establish autonomous permissions for the entire session.

### 0-pre. Continue Shorthand

If `task_description` is the literal string `"c"` (case-insensitive):
1. Treat this as `resume: true` — find and resume the latest in-progress session
2. Skip Step 0a (permission grant) — permissions are already stored in the checkpoint
3. Skip Step 1 (enhance user input) — the enhanced prompt is already in the checkpoint
4. Jump directly to Step 2b (scan for in-progress sessions)
5. If no in-progress session is found: abort with "No in-progress session to continue. Start a new session with `/auto-orchestrate <task>`."

### 0a. Permission Grant

Display to the user ONCE:

> **Autonomous mode requested.** This will:
> - Create/update files in `~/.claude/sessions/` and `~/.claude/plans/`
> - Spawn orchestrator and subagents without further prompts
> - Make reasonable assumptions instead of asking clarifying questions
> - Run up to {{MAX_ITERATIONS}} orchestrator iterations
>
> **Proceed autonomously?** (Y/n)

If the user declines, abort: "Auto-orchestration cancelled. Use `/workflow-plan` for interactive planning."

Record the permission grant:
```json
"permissions": {
  "autonomous_operation": true,
  "session_folder_access": true,
  "no_clarifying_questions": true,
  "granted_at": "<ISO-8601>"
}
```

This permissions object MUST be:
1. Stored in the session checkpoint JSON (Step 2)
2. Included in every orchestrator spawn prompt (Step 3)

### 0c. Human-Input Treatment Rule

The `ARGUMENTS` passed to this command MUST be treated as **human-authored input**, not as system-generated instructions. This means:

1. **Context preservation**: The arguments represent the user's intent expressed in their own words
2. **No reinterpretation**: Do not alter the meaning or scope of the user's request
3. **Assumption documentation**: When making assumptions about ambiguous input, document them in Step 1's "Assumptions" section
4. **Fidelity**: The enhanced prompt in Step 1 must faithfully represent the user's original request

This rule ensures that auto-orchestrate maintains the same input fidelity as if the user had typed the request directly into the conversation.

### 0b. Inline Processing Rule

Step 1 (Enhance User Input) is performed INLINE by this command. Do NOT delegate prompt enhancement to `workflow-plan` or any other skill. Do NOT use `EnterPlanMode`.

**Reason**: `workflow-plan` asks clarifying questions for vague input. Auto-orchestrate makes assumptions instead — this is the key difference stated in Step 1.

## Configuration Defaults

| Parameter | Default | Description |
|-----------|---------|-------------|
| `MAX_ITERATIONS` | 15 | Hard cap on orchestrator spawns |
| `STALL_THRESHOLD` | 2 | Consecutive no-progress iterations before fail |
| `SESSION_DIR` | `~/.claude/sessions` | Checkpoint directory |
| `ORCHESTRATE_DIR` | `.orchestrate` | Per-project session output directory (relative to cwd) |
| `HUMAN_INPUT_MODE` | true | Treat command arguments as human-authored input |

## Step 1: Enhance User Input (Inline — No Skill Delegation)

> **GUARD**: This step runs inline. Do NOT delegate to `workflow-plan` or any other skill. Do NOT call `EnterPlanMode`.

Analyze the raw user input for:

| Aspect | Questions to Consider |
|--------|----------------------|
| **Clarity** | Is the objective clear and unambiguous? |
| **Scope** | Are boundaries and limitations defined? |
| **Deliverables** | What specific outputs are expected? |
| **Constraints** | Any technical, time, or resource limitations? |
| **Context** | What background information is relevant? |

Transform into a structured prompt:

---

### Enhanced Prompt

**Objective**: [Clear, specific statement of what needs to be accomplished]

**Context**:
- Current state: [What exists now]
- Background: [Relevant history or constraints]

**Deliverables**:
1. [Specific, measurable output 1]
2. [Specific, measurable output 2]

**Constraints**:
- [Technical constraint]
- [Scope limitation]

**Success Criteria**:
- [ ] [Verifiable criterion 1]
- [ ] [Verifiable criterion 2]

**Out of Scope**:
- [What this plan explicitly does NOT include]

**Assumptions** (autonomous mode — no clarifying questions asked):
- [Assumption 1]
- [Assumption 2]

---

**Key difference from workflow-plan**: This command does NOT ask clarifying questions. It makes reasonable assumptions and documents them in the "Assumptions" section. This enables fully autonomous operation.

## Step 2: Initialize Session Checkpoint

### 2a. Ensure session directory exists

```bash
mkdir -p ~/.claude/sessions
```

### 2b. Scan and supersede ALL existing in-progress sessions

```bash
grep -rl '"status": "in_progress"' ~/.claude/sessions/auto-orc-*.json 2>/dev/null
```

**Supersession loop** — For EVERY in-progress session found (not just the first match):

1. Read the checkpoint JSON (skip if malformed — log warning and continue)
2. Set `"status"` to `"superseded"`
3. Add `"superseded_at": "<ISO-8601 timestamp>"`
4. Add `"superseded_by": "<new_session_id>"` (use the session ID that will be generated in Step 2c)
5. Write the updated checkpoint back to disk
6. If `.orchestrate/<session-id>/` directory exists, create a stale marker file at `.orchestrate/<session-id>/.stale`:
   ```json
   {
     "marked_stale_at": "<ISO-8601>",
     "superseded_by": "<new_session_id>"
   }
   ```
   (If `.stale` write fails, log warning but do NOT abort supersession)
7. Do NOT delete any checkpoint files or `.orchestrate/` directories — supersession is non-destructive

Output after loop: `Superseded <N> existing in-progress sessions.` (or skip message if N=0)

**After ALL sessions are superseded**, check if any superseded session's `original_input` matches the current user input:
- If match found: **resume** — skip to Step 3 with loaded state (use saved `iteration`, `task_ids`, `enhanced_prompt`, `task_snapshot`)
- If no match: proceed to Step 2c (create new session)

**Error handling**:
- Malformed JSON in a session file: log `[WARN] Skipping malformed session: <filename>` and skip
- `.stale` file write failure: log `[WARN] Could not create .stale marker for <session-id>` and continue
- Missing `.orchestrate/<session-id>/` directory: skip stale marker creation (no error)

### 2c. Create new session (if no resumable session found)

Generate session ID: `auto-orc-<DATE>-<8-char-slug>`

Derive `<8-char-slug>` from the user input (lowercase, hyphens, first 8 chars of a meaningful slug).

Create a parent tracking task via `TaskCreate`:
- **Subject**: `Auto-orchestrate: <brief objective>`
- **Description**: Include the enhanced prompt from Step 1
- **ActiveForm**: `Auto-orchestrating <brief objective>`

Create the `.orchestrate/` session directory in the project root:

```bash
mkdir -p .orchestrate/<session-id>/{research,architecture,logs}
```

This directory stores per-session output:
- `research/` — Researcher agent output files
- `architecture/` — Epic-architect decomposition plans
- `logs/` — Session execution logs
- `proposed-tasks.json` — Task proposals from subagents (read by auto-orchestrate)

Write the initial checkpoint file to `~/.claude/sessions/<session-id>.json`:

```json
{
  "schema_version": "1.0.0",
  "session_id": "<session-id>",
  "created_at": "<ISO-8601>",
  "updated_at": "<ISO-8601>",
  "status": "in_progress",
  "iteration": 0,
  "max_iterations": 15,
  "original_input": "<raw user input>",
  "permissions": {
    "autonomous_operation": true,
    "session_folder_access": true,
    "no_clarifying_questions": true,
    "granted_at": "<ISO-8601>"
  },
  "enhanced_prompt": {
    "objective": "...",
    "context": "...",
    "deliverables": ["..."],
    "constraints": ["..."],
    "success_criteria": ["..."],
    "out_of_scope": ["..."],
    "assumptions": ["..."]
  },
  "task_ids": [],
  "parent_task_id": "<TaskCreate ID>",
  "iteration_history": [],
  "terminal_state": null,
  "current_pipeline_stage": 0,
  "stages_completed": [],
  "mandatory_stage_enforcement": false,
  "stage_3_completed_at_iteration": null,
  "task_limits": {
    "max_tasks": 50,
    "max_active_tasks": 30,
    "max_continuation_depth": 3
  },
  "task_snapshot": {
    "written_at": null,
    "iteration": null,
    "tasks": []
  }
}
```

## Step 3: Spawn Orchestrator (Loop Entry)

**Before spawning**: Display iteration progress, update the checkpoint file — increment `iteration`, record current timestamp in `updated_at`. This ensures crash during orchestrator execution loses only iteration metadata, not task progress.

Output to user:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 ITERATION <N> of <max_iterations> — Starting...
 Session: <session_id>
 Pipeline stage: <current_pipeline_stage>
 Tasks: <completed> completed, <pending> pending, <blocked> blocked
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Updating checkpoint... done.
Spawning orchestrator — this may take several minutes while subagents work...
[PROCESSING] Orchestrator is coordinating subagents. Progress will appear below.
```

### Mandatory Progress Output Rule (PROGRESS-001)

**CRITICAL**: The user MUST always see visible activity. After displaying the spawn banner above, the auto-orchestrate loop is blocked waiting for the orchestrator to return. During this time, the **orchestrator itself** is responsible for outputting progress (see orchestrator.md Progress Output Requirements). The orchestrator's text output is visible to the user in real-time.

After the orchestrator returns, auto-orchestrate MUST output progress at every sub-step of Step 4 (see below). Never leave more than one processing step without visible output.

Use the `Task` tool with `subagent_type: "orchestrator"` and `max_turns: 30`:

```
Task(
  description: "Orchestrate iteration N of auto-orchestrate session",
  max_turns: 30,
  prompt: "
    ## Auto-Orchestration Context

    PARENT_TASK_ID: <parent_task_id>
    SESSION_ID: <session_id>
    ITERATION: <N> of <max_iterations>
    ## Autonomous Mode Permissions (pre-granted by user)
    The user granted autonomous operation at session start. You MUST:
    - Operate without asking for routine confirmations (MAIN-008 enforced)
    - Access ~/.claude/ freely without prompting (MAIN-007 enforced)
    - Make reasonable assumptions rather than asking clarifying questions
    - NOT call `EnterPlanMode` or enter plan mode

    Only ask the user when: files outside task scope need modification (MAIN-009),
    file deletion is needed (MAIN-010), or all tasks are blocked with no recovery path.

    ## MANDATORY: Progress Output (PROGRESS-001)
    The user MUST always see that work is happening. You MUST output visible progress
    text at every stage of your execution. Your text output is visible to the user in
    real-time. Silence makes users think the pipeline has crashed.

    **Required output points:**
    - BEFORE each subagent spawn: `[STAGE N] Spawning <agent> for: "<task subject>"...`
    - AFTER each subagent returns: `[STAGE N] <agent> completed. Key findings: <1-line summary>`
    - BEFORE boot sequence: `[BOOT] Setting up session infrastructure...`
    - AFTER boot: `[BOOT] Ready. Starting execution loop...`
    - At loop start: `[LOOP] Processing <N> pending tasks. Budget: <remaining>/5 spawns.`
    - Between spawns: `[PROGRESS] <completed>/<total> tasks done. Next: <next task subject>`
    - On error/retry: `[RETRY] <agent> needs retry: <reason>`
    - At end: Full Execution Tracker summary (already required)

    **NEVER** leave more than one tool call without outputting a progress line.
    **NEVER** call a tool and return without outputting what happened.

    ## Enhanced Prompt
    <Include full enhanced prompt from Step 1>

    ## CRITICAL: Tool Availability
    TaskCreate, TaskList, TaskUpdate, and TaskGet are NOT available to you.
    The Task tool for spawning subagents is also NOT reliably available.
    You have: Read, Glob, Grep, Bash for reading ONLY, and possibly Task. Attempt Task. If Task is unavailable, your ONLY permitted action is to return PROPOSED_ACTIONS — there is no fallback behavior and no alternative action.

    **ABSOLUTE RULE**: If the Task tool is unavailable, you MUST NOT "fall back" to doing
    implementation work yourself. MAIN-001 (stay high-level) and MAIN-002 (delegate ALL work)
    apply REGARDLESS of tool availability. You are a conductor, not a musician — even when
    the musicians don't show up, you don't pick up an instrument. Instead:
    - Use Read/Glob/Grep ONLY to read existing files for composing task descriptions in PROPOSED_ACTIONS. NEVER write any output to disk — EVEN IF the output is a plan, analysis, markdown file, or specification.
    - Propose tasks via PROPOSED_ACTIONS so auto-orchestrate can create and delegate them
    - Report that Task tool was unavailable so auto-orchestrate can retry
    - NEVER use Bash to write, edit, or create code files

    **KNOWN VIOLATION PATTERNS** (from production — if you recognize yourself doing any of these, STOP IMMEDIATELY):
    - "Let me take a more practical approach" → VIOLATION. "Practical" is a rationalization for bypassing delegation.
    - "I'll do the research phase directly by reading the codebase" → VIOLATION. You are not the researcher agent.
    - "This is more efficient for an audit task anyway" → VIOLATION. Efficiency is irrelevant to pipeline compliance.
    - "I'll create the tasks myself and spawn implementer agents" → VIOLATION. Only epic-architect decomposes tasks.
    - "The subagent tools can't write files reliably" → VIOLATION. Tool reliability is not your concern; report and return.
    - "I'll read the key files across all services systematically" → VIOLATION. Systematic codebase reading is the researcher's job.
    Tool limitations are NEVER a valid justification for doing work yourself. Return PROPOSED_ACTIONS and let auto-orchestrate handle dispatch.

    Task state is provided below. To propose new tasks or updates, include a
    PROPOSED_ACTIONS JSON block in your return value (see format below).
    To propose tasks for creation, also write to .orchestrate/<session_id>/proposed-tasks.json.

    ## Current Task State
    <Include full TaskList output formatted as:>
    - Task #<id>: "<subject>" — status: <status>, blockedBy: [<ids>]
    - ...

    (Auto-orchestrate calls TaskList and formats this for you each iteration)

    ## Pipeline Progress
    - Current stage: <current_pipeline_stage>
    - Completed stages: <stages_completed list>
    - Next stage: <first incomplete stage>

    ## Previous Iteration Summary
    <Summary from iteration N-1, or 'First iteration' if N=1>

    ## Session Isolation
    SESSION_ID is <session_id>. Pass this SESSION_ID to:
    - session-manager boot spawn (Step 0)
    - ALL subagent spawns (include `SESSION_ID: <session_id>` in every Task prompt)
    - ALL workflow-* skill invocations
    This ensures checkpoint files are scoped to `~/.claude/sessions/<session_id>-tasks.json`,
    preventing concurrent sessions in separate terminals from overwriting each other's state.

    ## Instructions
    1. Do NOT re-do completed tasks
    2. Focus on pending and failed tasks
    3. Do NOT call TaskCreate/TaskList/TaskUpdate/TaskGet — these tools are NOT available
    4. To propose new tasks: write to .orchestrate/<session_id>/proposed-tasks.json AND include in PROPOSED_ACTIONS return block
    5. To propose task updates: include in PROPOSED_ACTIONS return block
    6. If Task tool works, spawn up to 5 subagents per invocation; if not, use Read/Glob/Grep for analysis ONLY and propose tasks via PROPOSED_ACTIONS — NEVER perform implementation work directly (MAIN-001, MAIN-002 are non-negotiable)
    7. Follow the Execution Loop — do NOT stop after one piece of work
    8. Start from the current pipeline stage and progress through stages in order
    9. Report which pipeline stages were covered this iteration
    10. Include SESSION_ID in every file path and subagent spawn prompt
    11. FLOW INTEGRITY (MAIN-012): ALWAYS follow the full pipeline. NEVER skip stages.
    12. CODEBASE-STATS (Stage 4.5 — MANDATORY): After implementation tasks complete, measure technical debt impact.
    13. MANDATORY STAGE ENFORCEMENT: {{#if mandatory_stage_enforcement}}MANDATORY: Required stages are OVERDUE. Prioritize them BEFORE any other work.{{else}}Stages 0, 1, 2, 4.5, 5, and 6 are ALL mandatory. Ensure all are executed before reporting done. Stages 0, 1, 2 MUST run before implementation. Stages 4.5, 5, 6 MUST run after implementation.{{/if}}
    14. Return a PROPOSED_ACTIONS JSON block at the end of your response (see format in orchestrator.md Tool Availability section)
    15. NO AUTO-COMMIT (MAIN-014): NEVER run git commit, git push, or any git write operation. Collect suggested commit messages from subagents (Git-Commit-Message fields) and include them in the session report. Include MAIN-014 in EVERY subagent spawn prompt.

    ## Agent Constraint Enforcement (MANDATORY)
    When spawning each agent, you MUST include the relevant constraint block in the spawn prompt:

    ### researcher (Stage 0 — MANDATORY, NEVER skip):
    - MUST be spawned FIRST, before any other agent
    - MUST use WebSearch and WebFetch for internet-enabled research (RES-008)
    - MUST check CVEs for any packages or docker images involved (RES-005)
    - MUST check for latest stable versions of packages and docker images
    - Codebase-only analysis (Grep/Read without WebSearch) is a RES-008 violation
    - Output to: .orchestrate/<SESSION_ID>/research/

    ### epic-architect (Stage 1 — MANDATORY, NEVER skip):
    - MUST be spawned AFTER researcher (Stage 0) completes — do NOT skip Stage 1
    - MUST produce output through the Mandatory 4-Phase Planning Pipeline: Phase 1 (Scope Analysis), Phase 2 (Categorized Task Decomposition), Phase 3 (Dependency Graph with Programs), Phase 4 (Quick Reference for Execution)
    - Every task MUST have dispatch_hint set (required field)
    - Every task MUST have risk level (high/medium/low)
    - Default dispatch_hint for implementation = `implementer`, for documentation = `documentor`

    ### spec-creator (Stage 2 — MANDATORY, NEVER skip):
    - MUST be spawned AFTER epic-architect (Stage 1) completes — do NOT skip Stage 2
    - MUST produce technical specifications with scope, interface contracts, acceptance criteria
    - Specs guide implementation — implementer reads these before writing code
    - OUTPUT_DIR: .orchestrate/<SESSION_ID>/specs/ (overrides default docs/specs/ path)

    ### implementer (Stage 3):
    - MUST follow IMPL-001 through IMPL-013 constraints
    - IMPL-001: No placeholders — all code production-ready
    - IMPL-006: Enterprise production-ready — no mocks, no hardcoded values
    - IMPL-007: Scope-conditional quality pipeline (SMALL/MEDIUM/LARGE)
    - IMPL-008: Security gate — 0 security issues before completion
    - IMPL-013: No auto-commit — NEVER run git commit/push. Output Git-Commit-Message in DONE block
    - MAIN-014: Do NOT run git commit, git push, or any git write operation
    - For production code tasks, use `implementer` agent (opus model), NOT `task-executor` skill

    ### documentor (Stage 6 — MANDATORY):
    - MUST be spawned after implementation is stable — do NOT skip Stage 6
    - MUST follow maintain-don't-duplicate principle
    - MUST run full docs pipeline: docs-lookup → docs-write → docs-review
    - Update ARCHITECTURE.md, COOKBOOK.md, or relevant docs to reflect changes made

    ### validator (Stage 5 — MANDATORY):
    - MUST be spawned after implementation — do NOT skip Stage 5
    - Zero-error gate: implementation tasks MUST have 0 errors and 0 warnings (MAIN-006)

    ### docker-validator (Stage 5 sub-step — MANDATORY when Docker available):
    - MUST be invoked by the validator when `docker version` exits 0
    - Executes 8 phases: Environment Check, State Audit, Checkpoint, Build & Deploy, UX Testing (Unauth), UX Testing (Auth), HTTP Summary, State Restoration
    - Non-zero error count from docker-validator blocks Stage 5 completion
    - Required parameters: SESSION_ID, TASK_ID, DATE, SLUG, COMPOSE_PATH
    - Optional parameters: HEALTHCHECK_ENDPOINT, AUTH_ENDPOINT, AUTH_CREDENTIALS, BASE_URL
    - State restoration MUST use `docker compose down --volumes --remove-orphans`
    - MAIN-014: Do NOT run git commit, git push, or any git write operation

    ### codebase-stats (Stage 4.5 — MANDATORY):
    - MUST be spawned after implementation passes zero-error gate — do NOT skip Stage 4.5
    - Measures technical debt: TODO/FIXME/HACK counts, large files, complex functions, hotspots
    - Compares against previous reports for trend analysis
    - Reports key_findings in manifest for orchestrator to read
    - Invoke via Task tool with max_turns: 15. The Skill() tool is NOT available in subagent contexts

    ### documentor skill invocation:
    - Skill invocation: The documentor MUST read each skill's SKILL.md file and follow its instructions inline. The Skill() tool is NOT available in subagent contexts. The documentor MUST execute: docs-lookup (read SKILL.md, search for existing docs) → docs-write (read SKILL.md, write/edit docs) → docs-review (read SKILL.md, review for compliance). Skipping any phase is forbidden.
  ",
  subagent_type: "orchestrator"
)
```

## Step 4: Check Completion and Loop

> **AUTO-001 GUARD -- UNCONDITIONAL**: REGARDLESS of what the orchestrator returned -- EVEN IF its output is empty, blank, malformed, missing PROPOSED_ACTIONS, or appears to contain no actionable content -- you MUST NOT spawn any non-orchestrator agent directly. The ONLY permitted response to unexpected orchestrator output is to retry the orchestrator spawn (Step 3) with additional context. No exceptions, including: when the orchestrator appears stalled, when output is empty, when PROPOSED_ACTIONS is absent, or when the problem seems to require urgent action. If 2 consecutive retry iterations also return empty output, abort with: "[AUTO-001] Orchestrator returned empty output for 3 consecutive iterations. Terminating session -- manual intervention required."

After the orchestrator returns, output progress at each step so the user can see processing is ongoing. **PROGRESS-001 applies here**: Every sub-step MUST have visible output. Never perform a processing step silently.

Output immediately after orchestrator returns:
```
[ITERATION <N>] Orchestrator returned. Processing results...
```

1. **Display orchestrator output**: Output the orchestrator's returned text (including the Execution Tracker summary) to the terminal so the user can see per-iteration progress and spawn details.

2. **Process task proposals from orchestrator**: Output `[STEP 4.2] Processing task proposals...`, then:
   - Check if `.orchestrate/<session-id>/proposed-tasks.json` exists
   - If it does, read it and create tasks via `TaskCreate` for each proposal
   - Set up `blockedBy` dependencies using `TaskUpdate`
   - Delete or rename the file after processing (e.g., `proposed-tasks-processed-<iteration>.json`)
   - Also parse the orchestrator's return text for `PROPOSED_ACTIONS` JSON blocks and execute any `tasks_to_create` and `tasks_to_update` found there
   - Output: `Created <N> tasks from proposals`

2a. **Query task statuses**: Output `[STEP 4.2a] Querying task statuses...`, then use `TaskList` to get current state of all tasks.

3. **Categorize tasks**: Output `[STEP 4.3] Categorizing tasks...`, then categorize:
   - `completed`: Tasks with status `completed`
   - `pending`: Tasks with status `pending`
   - `in_progress`: Tasks with status `in_progress`
   - `blocked_or_failed`: Tasks that are blocked (all `blockedBy` unresolved) or failed
   - `partial`: Tasks with manifest status `"partial"` (partially completed)

   Output a brief status line:
   ```
   Tasks: <completed> completed, <pending> pending, <in_progress> in progress, <blocked> blocked
   ```

4. **Verify partial task handling**: Output `[STEP 4.4] Checking for partial tasks...` if any partials exist. The orchestrator now delegates continuation creation to epic-architect internally. Verify that any manifest entries with `"status": "partial"` have corresponding continuation tasks. If unaddressed partials remain, output: `[WARN] Unaddressed partial tasks — orchestrator may have failed to delegate continuations`

5. **Task count ceiling check**: After handling partial tasks, query `TaskList` total. If total >= `max_tasks`:
   - Set `task_cap_reached: true` in the current iteration history entry
   - Orchestrator continues processing existing tasks but MUST NOT create new tasks
   - Output: `[LIMIT-001] Task ceiling reached (<total> tasks) — no new task creation this iteration`

6. **Record iteration history**: Output `[STEP 4.6] Recording iteration history...`, then append to `iteration_history` in the checkpoint:
   ```json
   {
     "iteration": N,
     "tasks_completed": ["id1", "id2"],
     "tasks_pending": ["id3"],
     "tasks_in_progress": [],
     "tasks_blocked": [],
     "tasks_partial_continued": ["id4 → id5"],
     "task_cap_reached": false,
     "stages_completed_snapshot": [0, 1, 3],
     "stage_regression": false,
     "mandatory_stage_enforcement": false,
     "summary": "<first 500 chars of orchestrator return text>"
   }
   ```

7. **Update checkpoint file**: Output `[STEP 4.7] Saving checkpoint...`, then write updated JSON with new `updated_at`, incremented data.

7a. **Write task snapshot**: Output `[STEP 4.7] Writing task snapshot...`. Using the TaskList output from Step 4.2a, write a full task state snapshot to the checkpoint's `task_snapshot` field:
   ```json
   "task_snapshot": {
     "written_at": "<ISO-8601>",
     "iteration": <current_iteration_number>,
     "tasks": [
       {
         "id": "<task_id>",
         "subject": "<task_subject>",
         "status": "<completed|pending|in_progress|blocked>",
         "blockedBy": ["<task_id>", ...],
         "dispatch_hint": "<agent_name or null>"
       }
     ]
   }
   ```
   - MUST include ALL tasks (completed, pending, in_progress, blocked) — not only pending ones
   - MUST overwrite the entire `task_snapshot` field (not append) — each iteration's snapshot is a complete replacement
   - If the snapshot write fails, log `[WARN] Task snapshot write failed` but do NOT abort the checkpoint update
   - Output `[STEP 4.7] Task snapshot saved (<N> tasks).`

   Output `[STEP 4.7] Checkpoint saved.`

8. **Determine pipeline progress**: Output `[STEP 4.8] Evaluating pipeline progress...`, then inspect completed tasks to determine which pipeline stages are done:
   - Stage 0 complete if a `researcher` task is completed
   - Stage 1 complete if an `epic-architect` task is completed
   - Stage 2 complete if a `spec-creator` task is completed
   - Stage 3 complete if an `implementer` or `library-implementer-python` task is completed
   - Stage 4 complete if a `test-writer-pytest` task is completed
   - Stage 4.5 complete if a `codebase-stats` task is completed
   - Stage 5 complete if a `validator` task is completed
   - Stage 6 complete if a `documentor` task is completed
   - Update `stages_completed` with completed stage numbers
   - **Stage regression check (AUTO-003):** Calculate `new_stage` as the first incomplete stage. If `new_stage < current_pipeline_stage`, this is a regression — log `[AUTO-003] Stage regression detected: current_pipeline_stage remains <high-water mark> (new_stage was <new_stage>)`, keep the existing `current_pipeline_stage` (high-water mark), and set `stage_regression: true` in the current iteration history entry. Otherwise, set `current_pipeline_stage` to `new_stage`
   - **Track Stage 3 completion:** If Stage 3 newly appears in `stages_completed` and `stage_3_completed_at_iteration` is null, set `stage_3_completed_at_iteration` to the current iteration number

   Output pipeline status:
   ```
   Pipeline: Stage 0 ✓ → Stage 1 ✓ → Stage 2 ✗ → Stage 3 ✗ → Stage 4 ✗ → Stage 4.5 ✗ → Stage 5 ✗ → Stage 6 ✗
   ```

8a. **Mandatory stage gate check (AUTO-004)**: If `stages_completed` includes Stage 3 but is missing any of 4.5, 5, or 6:
   - Calculate `overdue_iterations = current_iteration - stage_3_completed_at_iteration`
   - If `overdue_iterations >= 2`: set `mandatory_stage_enforcement: true` in the checkpoint. Output `[AUTO-004] Mandatory stages overdue for <overdue_iterations> iterations — enforcement will be applied on next spawn`
   - If `overdue_iterations < 2`: keep `mandatory_stage_enforcement` at its current value

9. **Evaluate termination conditions** (Step 5). Output `[STEP 4.9] Checking termination conditions...`
10. **If NOT terminated**: Output `[STEP 4.10] Continuing to next iteration...` and return to Step 3

## Step 5: Termination Conditions

Evaluate in order:

| # | Condition | Status | Action |
|---|-----------|--------|--------|
| 1 | All tasks `completed` (excluding parent) AND `stages_completed` includes 0, 1, 2, 4.5, 5, and 6 | `completed` | Report success |
| 1a | All tasks `completed` (excluding parent) BUT `stages_completed` is missing any of 0, 1, 2, 4.5, 5, or 6 | — | Force one more iteration with `mandatory_stage_enforcement: true` in spawn prompt. If still missing after retry, terminate as `completed_stages_incomplete` |
| 2 | `iteration >= MAX_ITERATIONS` (15) | `max_iterations_reached` | Report partial completion |
| 3 | No progress for `STALL_THRESHOLD` (2) consecutive iterations | `stalled` | Report stall with diagnostics |
| 4 | All remaining tasks are `blocked` | `all_blocked` | Report blockers |

### Stall Detection

Compare the last `STALL_THRESHOLD` entries in `iteration_history`:
- Same `tasks_pending` count AND same `tasks_completed` count for 2 consecutive iterations = **stall detected**
- **Exception**: Partial tasks that were split into continuations count as progress. If `tasks_partial_continued` is non-empty in either iteration, reset the stall counter

### On Termination

1. Update checkpoint: set `terminal_state` to the matching condition status
2. Update checkpoint: set `status` to `"completed"` (or `"failed"` for stall/blocked)
3. Update parent task:
   - `completed` -> mark parent task as `completed`
   - `completed_stages_incomplete` -> mark parent task as `completed` with note: "Tasks done but mandatory stages missing: <list missing from 4.5, 5, 6>"
   - `max_iterations_reached` -> keep parent as `in_progress`, add note
   - `stalled` or `all_blocked` -> keep parent as `in_progress`, add note
4. Display final report (see below)

### Final Report Format

```
## Auto-Orchestration Complete

**Session**: <session_id>
**Status**: <terminal_state>
**Iterations**: <N> of <max_iterations>
### Task Summary
- Completed: <count> tasks
- Pending: <count> tasks
- Blocked: <count> tasks

### Completed Tasks
- [task_id] <subject>
- ...

### Remaining Tasks (if any)
- [task_id] <subject> — <reason>
- ...

### Mandatory Stages
| Stage | Status |
|-------|--------|
| 0 (researcher) | ✓ Completed / ✗ Not run |
| 1 (epic-architect) | ✓ Completed / ✗ Not run |
| 2 (spec-creator) | ✓ Completed / ✗ Not run |
| 4.5 (codebase-stats) | ✓ Completed / ✗ Not run |
| 5 (validator) | ✓ Completed / ✗ Not run |
| 6 (documentor) | ✓ Completed / ✗ Not run |

### Git Commit Instructions

The following changes were made during this session. Review and commit manually:

**Files modified:**
- [list of files from completed implementer tasks, collected from Git-Commit-Message fields in DONE blocks]

**Suggested commit messages:**
- [Git-Commit-Message values from each implementer DONE block]

**To commit, run:**
```bash
git diff                    # Review all changes first
git add <files>             # Stage specific files
git commit -m "<message>"   # Commit with suggested message
```

> **Note**: Auto-orchestrate NEVER commits automatically. All git operations are the user's responsibility.

### Iteration Timeline
| # | Completed | Pending | Summary |
|---|-----------|---------|---------|
| 1 | 0         | 5       | Initial decomposition |
| 2 | 2         | 3       | Implemented auth module |
| ...| ...      | ...     | ... |
```

## Crash Recovery Protocol

This protocol runs at the **start of every invocation**, before any other step:

1. Ensure `~/.claude/sessions/` exists
2. Scan for files matching `auto-orc-*.json` with `"status": "in_progress"`
3. If found:
   - Read the checkpoint JSON
   - Compare `original_input` with current user input (if any new input provided)
   - **Same input or no new input**: Resume (see step 3a below)
   - **Different input**: Mark existing session as `"status": "superseded"` (with `superseded_at` and `superseded_by`), proceed to Step 1 with new input. Also mark `.orchestrate/<session-id>/` as stale if directory exists.
4. If not found: Proceed normally from Step 1

### 3a. Resume with Task Snapshot Restoration

When resuming an in-progress session, restore task state from the checkpoint's `task_snapshot`:

1. Read `task_snapshot` from the checkpoint JSON
   - If `task_snapshot` is absent or `task_snapshot.tasks` is empty: skip restoration (backward compatibility with older checkpoints that lack this field)
2. Check if TaskList returns any tasks (the task system may be empty after a crash)
3. **If TaskList IS populated**: TaskList is authoritative — use it as-is. Display: `Tasks already in system. Using live state.`
4. **If TaskList IS empty AND task_snapshot.tasks is non-empty**: Restore from snapshot:
   a. Display: `Restoring <N> tasks from checkpoint snapshot (iteration <M>).`
   b. For each task in `task_snapshot.tasks`, ordered by ID:
      - If `status` is `"completed"`: Create via `TaskCreate` and immediately mark as `completed` via `TaskUpdate`
      - If `status` is `"pending"` or `"in_progress"`: Create via `TaskCreate` (starts as `pending`)
      - If `status` is `"blocked"`: Create via `TaskCreate` (starts as `pending`)
   c. After all tasks are created, set up `blockedBy` dependencies via `TaskUpdate` using the original `blockedBy` arrays from the snapshot
   d. Display: `Restored <N> tasks (<completed> completed, <pending> pending, <blocked> blocked).`
5. Resume from `iteration + 1`, skip Step 1 (use saved `enhanced_prompt`)

**Error handling**:
- If `task_snapshot` field is missing from checkpoint: treat as empty snapshot (CON-CR-001 backward compatibility)
- If a task cannot be recreated: log `[WARN] Could not restore task <id>: <subject>` and continue
- Task IDs after restoration may differ from snapshot IDs — use `blockedBy` subject-matching as fallback if ID-based matching fails

Checkpoints are written **before** each orchestrator spawn so that:
- If crash occurs during orchestrator execution: checkpoint shows last completed iteration, task_snapshot preserves full task state
- If crash occurs during checkpoint write: previous checkpoint is still valid, at worst one iteration is repeated
- Task snapshot ensures task states survive even when the in-memory task system is lost


## Known Limitations

### GAP-CRIT-001: Task Tool Availability — OPEN (Workaround Implemented)

Subagents spawned via `Task(subagent_type: "...")` do NOT have access to task management tools:

| Tool | Available to auto-orchestrate | Available to subagents |
|------|------------------------------|----------------------|
| TaskCreate | Yes | **No** |
| TaskList | Yes | **No** |
| TaskUpdate | Yes | **No** |
| TaskGet | Yes | **No** |
| Task (spawn subagents) | Yes | **Unreliable** |

**Workaround**: The auto-orchestrate loop acts as a **task management proxy**:
1. Subagents write task proposals to `.orchestrate/<session-id>/proposed-tasks.json`
2. Auto-orchestrate reads proposals and creates tasks via TaskCreate (Step 4, sub-step 2)
3. Auto-orchestrate passes current task state in the orchestrator's spawn prompt (Step 3)
4. Orchestrators return `PROPOSED_ACTIONS` JSON in their response for task updates

**Status**: OPEN — Workaround via file-based task proposal protocol. See `claude-code/_shared/references/TOOL-AVAILABILITY.md` for details.

### .orchestrate/ Folder

Each auto-orchestrate session creates a per-session directory in the project root:

```
.orchestrate/
└── <session-id>/
    ├── research/            # Researcher output
    ├── architecture/        # Epic-architect decomposition plans
    ├── logs/                # Session logs
    │   └── docker-checkpoint.json  # Docker state checkpoint (pre-test, written by docker-validator)
    └── proposed-tasks.json  # Task proposals (auto-orchestrate reads and creates)
```

This keeps session artifacts organized per-project and per-session, separate from the checkpoint files in `~/.claude/sessions/`.

## Anti-Patterns

| Anti-Pattern | Why It's Wrong | Do This Instead |
|-------------|----------------|-----------------|
| Asking clarifying questions | Breaks autonomous mode | Make assumptions, document them |
| Spawning orchestrator without checkpoint update | Loses crash recovery | Always write checkpoint before spawn |
| Re-doing completed tasks | Wastes iterations | Pass completed IDs, instruct skip |
| Ignoring stall detection | Infinite loops | Check progress every iteration |
| Ignoring proposed-tasks.json after orchestrator returns | Subagent task proposals are lost | Always check .orchestrate/<session-id>/proposed-tasks.json after each iteration |
| Hardcoding task IDs | Brittle | Query TaskList dynamically |
| Expecting subagents to call TaskCreate/TaskList | These tools are NOT available to subagents | Auto-orchestrate is the sole task management gateway |
| Delegating Step 1 to `workflow-plan` | workflow-plan asks clarifying questions, breaks autonomous mode | Enhance prompt inline in Step 1 |
| Using `EnterPlanMode` tool | Switches to interactive plan mode, halts autonomous execution | Skip plan mode; spawn orchestrator directly |
| Using `c` shorthand when no session exists | No checkpoint to resume from | Check for in-progress session first; abort with guidance if none found |
| Spawning a non-orchestrator agent directly | Violates AUTO-001 — only the orchestrator may be spawned from this command | Always use `subagent_type: "orchestrator"`; the orchestrator handles all sub-delegation |
| Declaring `completed` without mandatory stages | Violates AUTO-002 — stages 0, 1, 2, 4.5, 5, and 6 must be in `stages_completed` | Check `stages_completed` includes 0, 1, 2, 4.5, 5, and 6 before terminating as `completed` |
| Allowing pipeline stage to decrease between iterations | Violates AUTO-003 — stage monotonicity | Keep the high-water mark; log regression and record in iteration history |
| Ignoring overdue mandatory stages after implementation | Violates AUTO-004 — mandatory stages must be enforced if overdue 2+ iterations | Set `mandatory_stage_enforcement: true` and include enforcement directive in spawn prompt |

## Output

After completing all steps, the command produces:

1. **Session checkpoint file** at `~/.claude/sessions/<session-id>.json`
2. **Parent tracking task** in the task system
3. **Subtasks** created by the orchestrator across iterations
4. **Final report** displayed to the user with completion status and task summary
