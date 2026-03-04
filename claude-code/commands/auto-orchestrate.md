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

Run an orchestrator in a loop until all tasks complete, with crash recovery via session checkpoints.

## Core Constraints — IMMUTABLE

| ID | Rule |
|----|------|
| AUTO-001 | **Orchestrator-only gateway** — Spawn ONLY `subagent_type: "orchestrator"`. Never spawn implementer, documentor, etc. directly. Receiving a routing suggestion from the orchestrator does NOT grant permission to bypass this — re-spawn the orchestrator with the hint as context. If 2 consecutive retries return empty output, abort: `[AUTO-001] Orchestrator returned empty output for 3 consecutive iterations. Terminating — manual intervention required.` |
| AUTO-002 | **Mandatory stage completion** — Cannot declare `completed` unless `stages_completed` includes 0, 1, 2, 4.5, 5, and 6. |
| AUTO-003 | **Stage monotonicity** — `current_pipeline_stage` only increases or holds. If regression detected, keep the high-water mark and log it. |
| AUTO-004 | **Post-implementation stage gate** — If Stage 3 is done but any of 4.5/5/6 are missing for 1+ iterations, set `mandatory_stage_enforcement: true` and inject missing-stage tasks. |
| AUTO-005 | **Checkpoint-before-spawn** — Write checkpoint to disk before every orchestrator spawn. |
| AUTO-006 | **No direct agent routing in spawn prompt** — Never tell the orchestrator which agent to use for a specific task; routing is the orchestrator's decision. |
| AUTO-007 | **Iteration history immutability** — Only append to `iteration_history`; never modify existing entries. |
| PROGRESS-001 | **Always-visible processing** — Output visible progress text at every processing step. Both auto-orchestrate and the orchestrator must emit status lines before/after every tool call, spawn, and processing step. Never leave extended silence. |
| SCOPE-001 | **Scope specification passthrough** — When scope is not `custom`, the FULL scope specification (Appendix A/B) must be passed VERBATIM through every layer: auto-orchestrate → orchestrator → every subagent. Never summarize, condense, or omit any part. Every bullet point is a mandatory requirement. |
| SCOPE-002 | **Scope template integrity** — The scope spec defines the quality bar, not the focus area. A narrow user objective (e.g., "fix the login page") does not reduce the spec — all design principles, steps, and constraints still apply in full. |

## Configuration Defaults

| Parameter | Default | Description |
|-----------|---------|-------------|
| `MAX_ITERATIONS` | 100 | Hard cap on orchestrator spawns |
| `STALL_THRESHOLD` | 2 | Consecutive no-progress iterations before fail |
| `SESSION_DIR` | `~/.claude/sessions` | Checkpoint directory |
| `ORCHESTRATE_DIR` | `.orchestrate` | Per-project session output directory (relative to cwd) |
| `SCOPE` | `custom` | Stack scope: `frontend`, `backend`, `fullstack`, or `custom` |

---

## Step 0: Autonomous Mode Declaration

### 0-pre. Continue Shorthand

If `task_description` is `"c"` (case-insensitive): treat as `resume: true`, skip Steps 0a and 1, jump to Step 2b. If no in-progress session found, abort: `"No in-progress session to continue. Start a new session with /auto-orchestrate <task>."`

### 0a. Permission Grant

Display once:

> **Autonomous mode requested.** This will:
> - Create/update files in `~/.claude/sessions/` and `~/.claude/plans/`
> - Spawn orchestrator and subagents without further prompts
> - Make reasonable assumptions instead of asking clarifying questions
> - Run up to {{MAX_ITERATIONS}} orchestrator iterations
>
> **Proceed autonomously?** (Y/n)

If declined, abort: `"Auto-orchestration cancelled. Use /workflow-plan for interactive planning."`

Record permissions in checkpoint:
```json
"permissions": {
  "autonomous_operation": true,
  "session_folder_access": true,
  "no_clarifying_questions": true,
  "granted_at": "<ISO-8601>"
}
```

### 0b. Inline Processing Rule

Step 1 runs INLINE. Do NOT delegate to `workflow-plan` or use `EnterPlanMode`. Reason: `workflow-plan` asks clarifying questions; auto-orchestrate makes assumptions instead.

### 0c. Human-Input Treatment

Command arguments are **human-authored input**: preserve context, don't reinterpret meaning, document assumptions when resolving ambiguity.

### 0d. Scope Resolution

| Flag | Resolved | Description |
|------|----------|-------------|
| `F`/`f` | `frontend` | Frontend only |
| `B`/`b` | `backend` | Backend only |
| `S`/`s` | `fullstack` | Backend + Frontend |
| *(omitted)* | `custom` | No scope injection |

**Preprocessing**: Strip surrounding quotes (single, double, backtick) recursively, then trim whitespace.

**Inline flag extraction** (when `scope` argument not provided separately): If the first non-whitespace token of the cleaned `task_description` is **exactly one character** matching `F/f/B/b/S/s` followed by space or end-of-string, extract it as the scope flag and strip it from the task text. Multi-character tokens (e.g., "fix", "build", "setup") are NEVER flags.

**Examples**:
- `S implement all features` → scope=`fullstack`, task=`implement all features`
- `s implement all features` → scope=`fullstack`, task=`implement all features`
- `B` → scope=`backend`, task=*(scope default)*
- `fix the dashboard` → scope=`custom`, task=`fix the dashboard` ("fix" is multi-char)
- `"S implement all features"` → scope=`fullstack`, task=`implement all features` (quotes stripped)

**Default objectives** (when only a flag is provided):

| Scope | Default |
|-------|---------|
| `backend` | Build or complete all backend features to production-ready state, then audit and fully integrate — real implementations, proper persistence, zero placeholders |
| `frontend` | Build or complete all frontend features to production-ready state, then audit and fully integrate — every UI page, form, and API integration with child-friendly usability |
| `fullstack` | Build or complete all features across backend and frontend to production-ready state — full stack, zero placeholders, production-ready end-to-end |

Record: `"scope": { "flag": "<letter>", "resolved": "<scope>", "layers": [<"backend">, <"frontend">] }`

Layers: `frontend` → `["frontend"]`, `backend` → `["backend"]`, `fullstack` → `["backend", "frontend"]`, `custom` → `[]`.

---

## Step 1: Enhance User Input (Inline)

> **GUARD**: Do NOT delegate to `workflow-plan` or call `EnterPlanMode`.

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

The scope specification IS the enhanced prompt template. The user's `task_description` provides the **Objective**; the scope spec defines deliverables, steps, design principles, constraints, and success criteria.

**Rules**:
- The user's input may ADD requirements but MUST NOT cause any part of the scope spec to be omitted, summarized, or deprioritized
- A short/narrow user input does not reduce the scope — the full template always applies (SCOPE-002)
- Store the full verbatim scope spec text in `enhanced_prompt.scope_specification`

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
mkdir -p ~/.claude/sessions
```

### 2b. Supersede existing in-progress sessions

```bash
grep -rl '"status": "in_progress"' ~/.claude/sessions/auto-orc-*.json 2>/dev/null
```

For EVERY in-progress session found:
1. Read checkpoint (skip malformed with `[WARN]`)
2. Set `"status": "superseded"`, add `"superseded_at"` and `"superseded_by": "<new_session_id>"`
3. Write back. If `.orchestrate/<session-id>/` exists, create `.stale` marker (log warning on failure, don't abort)
4. Non-destructive — never delete checkpoint files or directories

After supersession, if any superseded session's `original_input` matches current input: **resume** (skip to Step 3 with loaded state). Otherwise proceed to 2c.

### 2c. Create new session

**Session ID**: `auto-orc-<DATE>-<8-char-slug>` (slug derived from user input).

Create parent tracking task via `TaskCreate`, then:

```bash
mkdir -p .orchestrate/<session-id>/{research,architecture,logs}
```

Write initial checkpoint to `~/.claude/sessions/<session-id>.json`:

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
    "objective": "...",
    "context": "...",
    "deliverables": ["..."],
    "constraints": ["..."],
    "success_criteria": ["..."],
    "out_of_scope": ["..."],
    "assumptions": ["..."],
    "scope_specification": "<VERBATIM scope spec text or empty string for custom>"
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

**Before spawning** (AUTO-005): Increment `iteration`, update `updated_at`, write checkpoint.

Display:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 ITERATION <N> of <max> — Starting...
 Session: <session_id> | Stage: <current_pipeline_stage>
 Tasks: <completed> done, <pending> pending, <blocked> blocked
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Spawning orchestrator — progress will appear below.
```

Spawn with `Task(subagent_type: "orchestrator", max_turns: 30)` using the prompt template in **Appendix C**.

---

## Step 4: Check Completion and Loop

> **AUTO-001 GUARD**: Regardless of orchestrator output (empty, malformed, missing PROPOSED_ACTIONS), NEVER spawn a non-orchestrator agent. The ONLY response to unexpected output is to retry the orchestrator with additional context.

After orchestrator returns, output progress at EVERY sub-step (PROGRESS-001):

1. **Display output**: `[ITERATION <N>] Orchestrator returned. Processing results...`

2. **Process task proposals**: `[STEP 4.2] Processing task proposals...`
   - Read `.orchestrate/<session-id>/proposed-tasks.json` if it exists
   - Create tasks via `TaskCreate`, set up `blockedBy` via `TaskUpdate`
   - Rename processed file to `proposed-tasks-processed-<iteration>.json`
   - Parse orchestrator return text for `PROPOSED_ACTIONS` JSON blocks
   - Output: `Created <N> tasks from proposals`

3. **Query task statuses**: `[STEP 4.2a] Querying task statuses...` via `TaskList`

4. **Categorize tasks**: `[STEP 4.3] Categorizing tasks...`
   - Categories: `completed`, `pending`, `in_progress`, `blocked_or_failed`, `partial`
   - Output: `Tasks: <completed> completed, <pending> pending, <in_progress> in progress, <blocked> blocked`

5. **Verify partial tasks**: `[STEP 4.4] Checking for partial tasks...` — Verify manifests with `"status": "partial"` have corresponding continuation tasks.

6. **Task ceiling check**: If total tasks >= `max_tasks`: set `task_cap_reached: true`, block new creation. Output: `[LIMIT-001] Task ceiling reached`

7. **Record iteration history**: `[STEP 4.6] Recording iteration history...`
   ```json
   {
     "iteration": N,
     "tasks_completed": ["id1"],
     "tasks_pending": ["id3"],
     "tasks_in_progress": [],
     "tasks_blocked": [],
     "tasks_partial_continued": [],
     "task_cap_reached": false,
     "stages_completed_snapshot": [0, 1, 3],
     "stage_regression": false,
     "mandatory_stage_enforcement": false,
     "summary": "<first 500 chars of orchestrator output>"
   }
   ```

8. **Save checkpoint + task snapshot**: `[STEP 4.7] Saving checkpoint...`
   Write `task_snapshot` with ALL tasks (complete replacement each iteration):
   ```json
   "task_snapshot": {
     "written_at": "<ISO-8601>",
     "iteration": N,
     "tasks": [{ "id": "...", "subject": "...", "status": "...", "blockedBy": [], "dispatch_hint": "..." }]
   }
   ```

9. **Pipeline progress**: `[STEP 4.8] Evaluating pipeline progress...`

   Stage completion criteria:
   | Stage | Complete when |
   |-------|--------------|
   | 0 | `researcher` task completed |
   | 1 | `epic-architect` task completed |
   | 2 | `spec-creator` task completed |
   | 3 | `implementer` or `library-implementer-python` task completed |
   | 4 | `test-writer-pytest` task completed |
   | 4.5 | `codebase-stats` task completed |
   | 5 | `validator` task completed |
   | 6 | `documentor` task completed |

   - **AUTO-003 check**: If new stage < current, keep high-water mark, log regression
   - **Track Stage 3**: Set `stage_3_completed_at_iteration` when Stage 3 first completes
   - Output: `Pipeline: Stage 0 ✓ → Stage 1 ✓ → Stage 2 ✗ → ...`

10. **Mandatory stage gate (AUTO-004)**: If Stage 3 done but 4.5/5/6 missing for 1+ iterations: set `mandatory_stage_enforcement: true`, inject missing-stage tasks via TaskCreate.

11. **Proactive injection**: For any mandatory stage (0, 1, 2, 4.5, 5, 6) absent from `stages_completed` with no pending/in-progress task, create the task immediately.

12. **Evaluate termination** (Step 5): `[STEP 4.9] Checking termination conditions...`

13. **If NOT terminated**: `[STEP 4.10] Continuing...` → return to Step 3.

---

## Step 5: Termination Conditions

Evaluate in order:

| # | Condition | Status |
|---|-----------|--------|
| 1 | All tasks completed AND `stages_completed` includes 0,1,2,4.5,5,6 | `completed` |
| 1a | All tasks completed BUT mandatory stages missing | Inject missing-stage tasks, force one more iteration. If still missing after retry: `completed_stages_incomplete` |
| 2 | `iteration >= MAX_ITERATIONS` | `max_iterations_reached` |
| 3 | No progress for `STALL_THRESHOLD` consecutive iterations | `stalled` |
| 4 | All remaining tasks blocked | `all_blocked` |

**Stall detection**: Same `tasks_pending` AND `tasks_completed` counts for 2 consecutive iterations = stall. Exception: non-empty `tasks_partial_continued` resets the counter.

### On Termination

1. Set `terminal_state` and `status` (`completed` or `failed`)
2. Update parent task accordingly
3. Display final report:

```
## Auto-Orchestration Complete
**Session**: <session_id> | **Scope**: <resolved> | **Status**: <terminal_state> | **Iterations**: N/max

### Task Summary
Completed: N | Pending: N | Blocked: N

### Mandatory Stages
| Stage | Status |
|-------|--------|
| 0 (researcher) | ✓/✗ |
| 1 (epic-architect) | ✓/✗ |
| 2 (spec-creator) | ✓/✗ |
| 4.5 (codebase-stats) | ✓/✗ |
| 5 (validator) | ✓/✗ |
| 6 (documentor) | ✓/✗ |

### Git Commit Instructions
> Auto-orchestrate NEVER commits automatically. Review and commit manually.
**Files modified**: [from implementer DONE blocks]
**Suggested commits**: [Git-Commit-Message values]

### Iteration Timeline
| # | Completed | Pending | Summary |
|---|-----------|---------|---------|
```

---

## Crash Recovery Protocol

Runs at the START of every invocation:

1. Ensure `~/.claude/sessions/` exists
2. Scan for `auto-orc-*.json` with `"status": "in_progress"`
3. If found: compare `original_input` with current input
   - Same or no new input → **Resume** (see below)
   - Different → supersede existing session, start fresh from Step 1
4. If not found → proceed normally

### Resume with Task Snapshot Restoration

1. Read `task_snapshot` (if absent/empty: skip restoration for backward compat)
2. If `TaskList` is populated: use live state as-is
3. If `TaskList` is empty AND snapshot non-empty: restore tasks
   - Create completed tasks and immediately mark completed
   - Create pending/in-progress/blocked tasks as pending
   - Set up `blockedBy` dependencies
   - If a task can't be recreated, log `[WARN]` and continue
   - Task IDs may differ — use subject-matching as fallback
4. Resume from `iteration + 1`, skip Step 1

---

## Known Limitations

### GAP-CRIT-001: Task Tool Availability

Subagents do NOT have TaskCreate/TaskList/TaskUpdate/TaskGet. Task (spawn) is unreliable for subagents.

**Workaround**: Auto-orchestrate acts as task management proxy:
1. Subagents write proposals to `.orchestrate/<session-id>/proposed-tasks.json`
2. Auto-orchestrate reads and creates tasks via TaskCreate (Step 4.2)
3. Current task state is passed in the orchestrator spawn prompt
4. Orchestrators return `PROPOSED_ACTIONS` JSON for task updates

### .orchestrate/ Folder Structure

```
.orchestrate/<session-id>/
├── research/            # Researcher output
├── architecture/        # Epic-architect plans
├── logs/                # Session logs (incl. docker-checkpoint.json)
└── proposed-tasks.json  # Task proposals
```

---

## Appendix A: Backend Scope Specification

> Included in enhanced prompt when `layers` contains `"backend"`.

### Task
Implement all backend features to production-ready state, then audit and fully integrate. Applies to both **greenfield** (build from scratch) and **existing** (complete and fix) codebases.

- **Greenfield**: Design and build the full backend — models, migrations, services, controllers, routes, authentication, authorization, seed data, and configuration. Every feature must be fully implemented with real persistence and real integrations.
- **Existing**: Complete all partial features, replace all simulations/placeholders/in-memory workarounds, fix every gap and integration issue.

No in-memory workarounds, no simulations, no fake data, no placeholder logic. Everything uses real implementations with proper persistence.

### Steps

1. **Branch** — Create a feature branch.

2. **Implement All Features** — Build or complete every backend feature:
   - **Greenfield**: Create all models, migrations, services, controllers, routes, auth, middleware, seed data, config from scratch.
   - **Existing**: Walk through every module and complete partial/stubbed features.
   - Write real business logic — no placeholders, no TODOs.
   - Create all API endpoints, services, models, migrations.
   - Implement error handling, input validation, response formatting.
   - Wire all dependencies, database connections, service integrations.
   - Every feature must have a complete data path from API request → persistent storage → response.
   - Build missing controllers/routes for defined models. Implement real logic for mock-returning routes. Complete missing CRUD operations.

3. **Full Codebase Audit** — After implementation, assess every module:
   - Fully implemented and functional end-to-end?
   - Missing validations, broken logic, incomplete integrations?
   - All API endpoints exposed, documented, working?
   - Any in-memory storage, simulated data, mock services, placeholder logic?
   - Any remaining TODO/FIXME/HACK/PLACEHOLDER comments?

4. **Eliminate All Simulations** — Replace every instance of:
   - In-memory stores → real persistent storage
   - Simulated/mocked service calls → real integrations
   - Hardcoded/fake/sample data → real data flows
   - Placeholder/stub logic → full implementations
   - Every data path must survive restarts.

5. **Fix All Gaps** — Address every remaining issue:
   - Broken configs, missing env vars, incomplete integrations
   - Validation gaps, bugs, logic errors
   - Database migrations — up to date and clean
   - Scripts (seed, setup, utility) must all work
   - Complete any still-partial features
   - Default users, roles, groups, permissions — functional seed data
   - Startup integrity — no errors on restart/cold boot
   - Service accounts and inter-service credentials working

6. **Clean Build** — All build processes complete with zero errors, zero warnings.

7. **Verify End-to-End** — Entire backend running, all features operational, data persists across restarts.

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
- **Dropdowns/Select boxes** for every field with known values (roles, statuses, categories, etc.) — load from backend API.
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
- **Consistent layout** — same patterns everywhere (list → detail → edit → back).
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

### Frontend Steps

1. **Map Every Feature to UI** — For every backend endpoint/module, identify every screen, form, list, detail view, and interaction needed.

2. **Build All Pages** — For each feature:
   - **List/Table view**: search bar, dropdown filters, column sorting, bulk checkboxes, bulk toolbar, pagination, empty state.
   - **Create form**: dropdowns, checkboxes, date pickers, toggles, auto-complete. Text inputs only where unavoidable. Inline validation, help tooltips.
   - **Edit form**: same as create, pre-populated from API.
   - **Detail/View page**: read-only with tabs for logical sections, related data, activity history, metadata.
   - **Delete**: single with confirmation, bulk via checkbox selection.

3. **Connect to Backend APIs** — Every page calls real endpoints, handles loading/error/empty/forbidden states, submits real data. No fake data, no mocked calls, no hardcoded values.

4. **Navigation and Layout** — Complete application shell:
   - Sidebar/top nav grouped logically. Menu visibility by roles/permissions. Breadcrumbs everywhere.
   - Global search if applicable. User profile menu with logout, settings, profile.

5. **Test End-to-End** — Every user flow works through to backend persistence. Every CRUD, bulk action, filter, and search works against the real backend.

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

Use `Task(subagent_type: "orchestrator", max_turns: 30)` with this prompt:

```
## Auto-Orchestration Context

PARENT_TASK_ID: <parent_task_id>
SESSION_ID: <session_id>
ITERATION: <N> of <max_iterations>
SCOPE: <resolved scope>
SCOPE_LAYERS: <layers array>

## Scope Context
{{#if scope != "custom"}}
Only work on layers in SCOPE_LAYERS.
- backend: Focus on backend modules, services, APIs, migrations, infrastructure. Do NOT modify frontend files.
- frontend: Focus on frontend pages, components, forms, API integrations. Do NOT modify backend files (except reading API contracts).
- fullstack: Both in scope. Backend generally precedes frontend.
The enhanced prompt below contains detailed scope-specific specifications. Follow them precisely.
{{else}}
No scope restriction — follow the enhanced prompt as written.
{{/if}}

## Autonomous Mode Permissions (pre-granted)
Operate without routine confirmations (MAIN-008). Access ~/.claude/ freely (MAIN-007). Make assumptions, don't ask clarifying questions. Do NOT call EnterPlanMode.
Only ask user when: files outside scope need modification (MAIN-009), deletion needed (MAIN-010), or all tasks blocked with no recovery.

## MANDATORY: Progress Output (PROGRESS-001)
Output visible progress at every stage. Your text output is visible in real-time.
Required output points: before/after each subagent spawn, before/after boot, at loop start, between spawns, on error/retry, at end (Execution Tracker summary).
Never leave more than one tool call without a progress line.

## Enhanced Prompt
{{#if scope != "custom"}}
### Objective
<enhanced_prompt.objective>

### Additional User Context
<enhanced_prompt.context, assumptions, out_of_scope>

### FULL SCOPE SPECIFICATION (VERBATIM — EVERY LINE MANDATORY)
╔══════════════════════════════════════════════════════════════╗
║  NON-NEGOTIABLE TEMPLATE. Every section, bullet, principle, ║
║  step, and constraint MUST be followed precisely. Nothing   ║
║  may be omitted, summarized, or deprioritized.              ║
║  ALL subagents MUST receive relevant parts in full.         ║
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

## Tool Availability
TaskCreate, TaskList, TaskUpdate, TaskGet are NOT available.
Task tool for spawning may or may not work — attempt it.

**If Task tool is unavailable**: Return PROPOSED_ACTIONS only. NEVER fall back to doing work yourself. MAIN-001 (stay high-level) and MAIN-002 (delegate ALL work) apply regardless of tool availability. Use Read/Glob/Grep ONLY to compose task descriptions. NEVER write files. NEVER use Bash to write/edit/create code.

**Violation patterns to catch yourself doing**:
- "Let me take a more practical approach" → VIOLATION
- "I'll do the research by reading the codebase" → VIOLATION
- "This is more efficient" → VIOLATION — efficiency doesn't override pipeline
- "I'll create tasks and spawn agents directly" → VIOLATION
- Any codebase reading beyond composing PROPOSED_ACTIONS task descriptions → VIOLATION

## Current Task State
<TaskList output formatted as: Task #id: "subject" — status, blockedBy: [ids]>

## Pipeline Progress
Current stage: <N> | Completed: <list> | Next: <first incomplete>

## Previous Iteration Summary
<Summary from N-1, or "First iteration">

## Session Isolation
SESSION_ID: <session_id>. Pass to ALL subagent spawns, session-manager boot, and workflow-* invocations.

## Instructions
1. Skip completed tasks
2. Focus on pending and failed tasks
3. Do NOT call TaskCreate/TaskList/TaskUpdate/TaskGet
4. Propose new tasks: write to .orchestrate/<session_id>/proposed-tasks.json AND include in PROPOSED_ACTIONS
5. Propose updates: include in PROPOSED_ACTIONS
6. If Task tool works: spawn up to 5 subagents; if not: Read/Glob/Grep for analysis ONLY, propose via PROPOSED_ACTIONS
7. Follow the Execution Loop — don't stop after one piece of work
8. Progress through pipeline stages in order from current stage
9. Report which stages were covered this iteration
10. Include SESSION_ID in every file path and subagent spawn
11. FLOW INTEGRITY (MAIN-012): Follow full pipeline, never skip stages
12. CODEBASE-STATS (Stage 4.5): Mandatory after implementation
13. STAGE ENFORCEMENT: {{#if mandatory_stage_enforcement}}OVERDUE — prioritize missing stages BEFORE other work.{{else}}Stages 0,1,2,4.5,5,6 are ALL mandatory. 0,1,2 before implementation; 4.5,5,6 after.{{/if}}
14. Return PROPOSED_ACTIONS JSON block at end
15. NO AUTO-COMMIT (MAIN-014): Never git commit/push. Collect Git-Commit-Message from subagents. Include MAIN-014 in every subagent prompt.
16. SCOPE-001: When scope != custom, include FULL scope spec verbatim in EVERY subagent spawn. Never summarize for subagents.
17. SCOPE-002: Full spec applies regardless of how narrow the user's objective is.

## Agent Constraints (include in spawn prompts)

**All agents (when scope != custom)**: Include FULL scope spec verbatim in every spawn prompt (SCOPE-001).

**researcher** (Stage 0 — mandatory, always first):
- Use WebSearch and WebFetch for internet research (RES-008)
- Check CVEs for packages/docker images (RES-005), check latest stable versions
- Output to: .orchestrate/<SESSION_ID>/research/

**epic-architect** (Stage 1 — mandatory, after researcher):
- 4-Phase Planning Pipeline: Scope Analysis → Task Decomposition → Dependency Graph → Quick Reference
- Every task needs dispatch_hint (required) and risk level
- Must decompose according to full scope spec

**spec-creator** (Stage 2 — mandatory, after epic-architect):
- Technical specs with scope, interface contracts, acceptance criteria
- Output to: .orchestrate/<SESSION_ID>/specs/

**implementer** (Stage 3):
- IMPL-001: No placeholders. IMPL-006: Enterprise production-ready. IMPL-007: Scope-conditional quality pipeline. IMPL-008: 0 security issues. IMPL-013/MAIN-014: No auto-commit — output Git-Commit-Message in DONE block.

**codebase-stats** (Stage 4.5 — mandatory after implementation):
- Measure technical debt: TODO/FIXME/HACK counts, large files, complex functions
- Compare against previous reports. Report key_findings.

**validator** (Stage 5 — mandatory after implementation):
- Zero-error gate: 0 errors, 0 warnings (MAIN-006)
- When Docker available: invoke docker-validator (8-phase validation)

**documentor** (Stage 6 — mandatory after stable implementation):
- Full docs pipeline: docs-lookup → docs-write → docs-review
- Update ARCHITECTURE.md, COOKBOOK.md, relevant docs
```

---

## Appendix D: Fullstack Scope Prefix

When scope is `fullstack`, prefix both Appendix A and B with:

```markdown
## Scope
**Backend** and **Frontend** — covers every module, service, feature, and/or endpoint in the codebase.
```