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
      Scope flag to control which part of the stack is implemented.
      - "F" or "f" — Frontend only
      - "B" or "b" — Backend only
      - "S" or "s" — Full stack (Backend + Frontend)
      When set, the enhanced prompt includes detailed scope-specific audit and implementation specifications.
      If omitted, the task_description is used as-is without scope-specific injection.
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

### 0d. Scope Resolution

Parse the `scope` argument (if provided) to determine which stack layers are in scope. The scope flag controls whether scope-specific audit and implementation specifications are injected into the enhanced prompt (Step 1).

| Flag | Resolved Scope | Description |
|------|---------------|-------------|
| `F` or `f` | `frontend` | Frontend only — audit, fix, and build all UI pages, forms, and integrations |
| `B` or `b` | `backend` | Backend only — audit, fix, and fully integrate all backend modules and services |
| `S` or `s` | `fullstack` | Full stack — both backend and frontend scopes combined |
| *(omitted)* | `custom` | No scope injection — use `task_description` as-is |

**Flag extraction from task_description**: If the `scope` argument is not provided as a separate parameter, check if the first non-whitespace character of `task_description` is one of `F`, `f`, `B`, `b`, `S`, `s` followed by a space or end-of-string. If so:
1. Extract the flag character as the scope
2. Strip the flag (and any following whitespace) from `task_description` to get the clean task text
3. If `task_description` is empty after stripping (i.e., only the flag was provided), use the scope-specific default objective as the task description

Examples:
- `/auto-orchestrate S implement all features` → scope=`fullstack`, task=`implement all features`
- `/auto-orchestrate B` → scope=`backend`, task=*(scope default objective)*
- `/auto-orchestrate f fix the dashboard` → scope=`frontend`, task=`fix the dashboard`
- `/auto-orchestrate implement auth module` → scope=`custom`, task=`implement auth module`

Record the resolved scope:
```json
"scope": {
  "flag": "S",
  "resolved": "fullstack",
  "layers": ["backend", "frontend"]
}
```

The `layers` array is derived from the resolved scope:
- `frontend` → `["frontend"]`
- `backend` → `["backend"]`
- `fullstack` → `["backend", "frontend"]`
- `custom` → `[]` (no scope-specific injection)

### 0b. Inline Processing Rule

Step 1 (Enhance User Input) is performed INLINE by this command. Do NOT delegate prompt enhancement to `workflow-plan` or any other skill. Do NOT use `EnterPlanMode`.

**Reason**: `workflow-plan` asks clarifying questions for vague input. Auto-orchestrate makes assumptions instead — this is the key difference stated in Step 1.

## Configuration Defaults

| Parameter | Default | Description |
|-----------|---------|-------------|
| `MAX_ITERATIONS` | 100 | Hard cap on orchestrator spawns |
| `STALL_THRESHOLD` | 2 | Consecutive no-progress iterations before fail |
| `SESSION_DIR` | `~/.claude/sessions` | Checkpoint directory |
| `ORCHESTRATE_DIR` | `.orchestrate` | Per-project session output directory (relative to cwd) |
| `HUMAN_INPUT_MODE` | true | Treat command arguments as human-authored input |
| `SCOPE` | `custom` | Stack scope: `frontend`, `backend`, `fullstack`, or `custom` (no injection) |

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

### Scope-Specific Enhanced Prompt Injection

If the resolved scope (from Step 0d) is NOT `custom`, inject the appropriate scope-specific specification into the enhanced prompt. The scope specification replaces the generic "Deliverables" and "Constraints" sections with detailed, prescriptive audit and implementation instructions.

**Injection rule**: The user's `task_description` (after flag stripping) provides the **Objective** and any additional context. The scope specification provides the **Deliverables**, **Constraints**, **Success Criteria**, and **Steps**. If the user's task_description adds further requirements, merge them — do not discard user intent.

**CRITICAL — Verbatim storage rule**: The scope specification text (Backend and/or Frontend sections below) MUST be stored **verbatim** — word-for-word, with all bullet points, sub-sections, design principles, and constraints preserved exactly as written. Do NOT summarize, paraphrase, condense, or restructure the scope specification into the Enhanced Prompt's generic fields (deliverables, constraints, etc.). The scope specification IS the enhanced prompt's core content when scope is not `custom`. Store the full verbatim text in the checkpoint's `enhanced_prompt.scope_specification` field and pass it to the orchestrator in full. Summarizing the scope specification causes downstream agents to receive incomplete instructions, resulting in limited implementation, shallow audits, and missing integrations.

#### Backend Scope Specification (included when `layers` contains `"backend"`)

```markdown
## BACKEND

### Task
Implement all backend features to production-ready state, then audit and fully integrate. This applies whether the codebase is **greenfield** (building from scratch) or **existing** (completing and fixing what's already there):

- **Greenfield**: Design and build the full backend — models, migrations, services, controllers, routes, authentication, authorization, seed data, and configuration. Every feature described in the task description or discovered during research must be fully implemented with real persistence and real integrations.
- **Existing codebase**: Complete all partially implemented features, replace all simulations/placeholders/in-memory workarounds with real implementations, and fix every gap, error, and integration issue.

In both cases: this is a production system — no in-memory workarounds, no simulations, no fake data, no placeholder logic. Everything must use real implementations with proper persistence.

### Steps

1. **Branch** — Create a feature branch for this implementation, integration, and audit work.

2. **Implement All Features** — Build or complete every backend feature to production-ready state:
   - **Greenfield**: Design and create all models, migrations, services, controllers, routes, authentication, authorization, middleware, seed data, and configuration from scratch based on the task requirements and research findings.
   - **Existing codebase**: Walk through every module and complete partially implemented or stubbed features.
   - Write real business logic — no placeholders, no TODOs, no "coming soon".
   - Create all required API endpoints, services, models, and migrations.
   - Implement proper error handling, input validation, and response formatting.
   - Wire up all dependencies, database connections, and service integrations.
   - Ensure every feature has a complete, working data path from API request through to persistent storage and back.
   - If a feature is defined in models/schemas but has no controller or route — build it.
   - If a feature has a route but returns hardcoded or mock data — implement the real logic.
   - If a feature exists but is missing CRUD operations — complete all operations.

3. **Full Codebase Audit** — After implementation, walk through every module again and assess:
   - Is it fully implemented and functionally usable end-to-end?
   - Are there missing validations, broken logic, or incomplete integrations?
   - Are all required API endpoints exposed, documented, and working correctly?
   - Does it use in-memory storage, simulated data, mock services, or placeholder logic instead of real implementations?
   - Are there remaining TODO, FIXME, HACK, or PLACEHOLDER comments marking incomplete work?
   - Document what works, what doesn't, and what's still missing.

4. **Eliminate All Simulations & In-Memory Workarounds** — Identify and replace every instance of:
   - In-memory data stores → real persistent storage (database, cache, or appropriate backing service)
   - Simulated or mocked service calls → real service integrations
   - Hardcoded, fake, or sample data → real data flows
   - Placeholder or stub logic → fully functional implementations
   - Every data path must read from and write to proper persistent storage. Nothing should be lost on restart.

5. **Fix All Gaps** — For every remaining issue found, fix it. This includes:
   - Missing or broken configurations
   - Missing environment variables
   - Incomplete or broken integrations between internal services and modules
   - Validation gaps on all inputs and API boundaries
   - Bugs and logic errors
   - Database migrations — ensure all are up to date and run cleanly
   - Scripts — seed scripts, setup scripts, and utility scripts must all work
   - Any feature that is still partially implemented — complete it
   - Default users, roles, groups, and permissions — ensure the platform has all required seed data to be functional and secure on first install
   - Startup integrity — ensure there are no errors during application restart or cold boot
   - Service accounts and inter-service credentials — ensure all services authenticate with correct, persisted credentials
   - Nothing should remain deferred or broken.

6. **Clean Build** — Ensure all build processes (Docker images, compilation, bundling) complete cleanly with zero errors and zero warnings.

7. **Verify End-to-End** — Confirm the entire backend infrastructure is running and all features are fully operational and integrated. The system must be stable and production-ready. Verify that all data persists correctly across service restarts.

### Backend Constraints
- This is an implement-then-audit pass — first build or complete all features, then audit and fix everything.
- **Greenfield**: Build every module from scratch — do not skip features because "there's nothing to audit yet." The implementation step IS the primary work.
- **Existing codebase**: Scope covers every module and feature — not a single section.
- Zero tolerance for in-memory storage, simulations, mock data, or placeholder logic.
- Everything must use real implementations with proper persistence.
- All API responses must use consistent formats (status codes, error shapes, pagination).
```

#### Frontend Scope Specification (included when `layers` contains `"frontend"`)

```markdown
## FRONTEND

### Task
Implement all frontend features to production-ready state, then audit and fully integrate. This applies whether the frontend is **greenfield** (building from scratch) or **existing** (completing and fixing what's already there):

- **Greenfield**: Design and build the complete frontend application — application shell, navigation, routing, authentication flows, and every page/form/view needed to consume all backend API endpoints. Set up the project structure, component library, state management, and API client layer from scratch.
- **Existing codebase**: Complete all partially implemented pages and components, replace all mock data/placeholder screens with real API integrations, and fix every gap, error, and integration issue.

In both cases: the frontend must consume all backend API endpoints. No fake data, no mock APIs, no placeholder screens. The **primary design goal** is that a 10-year-old child could use this system without any supervision or training — minimum effort, maximum clarity, zero confusion.

### Core Design Principles

#### 1. Minimum Typing, Maximum Selection
Reduce user labour and eliminate input errors:
- **Dropdowns / Select boxes** for every field that has a known set of values. Load all options from the backend API (roles, statuses, categories, types, priorities, users, groups, permissions, and any other reference data).
- **Checkboxes** for boolean fields, toggles, and multi-select scenarios.
- **Radio buttons** for mutually exclusive choices with a small number of options.
- **Date pickers** for all date and datetime fields. No manual date typing ever.
- **Time pickers** for all time fields.
- **Toggle switches** for enable/disable, active/inactive, yes/no states.
- **Auto-complete / searchable dropdowns** for large lists (e.g., user lists, product lists, long reference tables).
- **Sliders** for numeric ranges where applicable (e.g., priority levels, percentage values).
- **Colour pickers** for any colour-related fields.
- **File upload drag-and-drop zones** for any file attachment fields.
- **Text boxes only when absolutely unavoidable** — free-text descriptions, names, notes, and search queries. Minimise these aggressively. If a value exists in the system, it must be selected, not typed.

#### 2. Bulk Operations
Reduce repetitive work on every list and table:
- **Multiple delete** — Select multiple items via checkboxes and delete all at once with a single confirmation dialog.
- **Multiple create** — Allow batch creation where applicable (e.g., adding multiple items, assigning multiple users/roles/permissions in one action).
- **Select All / Deselect All** checkbox on every list and table header.
- **Bulk status change** — Select multiple items and change their status in one action via a dropdown.
- **Bulk assign** — Select multiple items and assign them to a user or group in one action.
- **Bulk export** — Select multiple items and export them (CSV, PDF, etc.).
- **Bulk actions toolbar** — When items are selected, show a floating or sticky toolbar with all available bulk actions.

#### 3. Tabs for Logical Grouping
Use tabbed layouts on pages when:
- A page has more than one logical section (e.g., a record detail page: Details tab, Related Items tab, History/Activity tab, Settings tab).
- A page manages related but distinct datasets.
- It prevents the user from scrolling through a very long single page.
- Each tab should load its own data independently and show a loading indicator.
- The active tab should be reflected in the URL so the user can bookmark or share a direct link to a specific tab.

#### 4. Pre-load Everything from the Backend
The frontend must eliminate guesswork:
- On page load, fetch all dropdown options, reference data, and lookup values from the backend API.
- Never require the user to remember or manually type values that already exist in the system.
- Show **loading states** (spinners, skeletons, or shimmer effects) while data is being fetched.
- Cache dropdown and reference data where appropriate to avoid redundant API calls within the same session.
- Display **meaningful labels** everywhere — not IDs, codes, or UUIDs. Show human-readable names.
- Dropdown options should show relevant context (e.g., "John Smith — Admin" not just "John Smith").

#### 5. Child-Friendly Usability
Design so a 10-year-old can use it without help:
- **Clear, simple labels** on every field — no jargon, no abbreviations, no technical terms.
- **Tooltips / help icons (?)** on every field explaining what it does in plain, simple language.
- **Inline validation** with friendly error messages as the user interacts (e.g., "Please pick a role from the list" not "ValidationError: role_id cannot be null").
- **Confirmation dialogs** before any destructive or irreversible action (delete, bulk delete, status change, permanent actions).
- **Success and failure toast notifications** for every action the user performs.
- **Undo capability** where feasible (e.g., after a delete, show an "Undo" option for a few seconds).
- **Consistent layout across every page** — same patterns everywhere (list view → detail view → edit view → back to list).
- **Breadcrumbs** on every page so the user always knows where they are and how to go back.
- **Large, clearly labelled buttons** — primary actions visually stand out, secondary actions are subdued, destructive actions are red.
- **Empty states** — when a list has no data, show a friendly message explaining why and a clear "Create Your First [Item]" button.
- **Search and filter bars** on every list and table page, using dropdown filters wherever possible instead of free-text search.
- **Pagination** on all list views with sensible defaults and page size options.
- **Responsive design** — must work properly on desktop, tablet, and mobile.
- **Keyboard navigation** — all interactive elements must be reachable and usable via keyboard.
- **Consistent iconography** — use recognisable icons alongside text labels (e.g., trash icon + "Delete", pencil icon + "Edit").
- **No dead ends** — every page must have a clear next action or a way to navigate away.
- **Wizard/stepper flows** for complex multi-step creation processes — break them into simple, numbered steps with progress indicators.

#### 6. User Context in the Frontend
The frontend must be aware of who is using it:
- Show and hide features, pages, and menu items based on the logged-in user's **roles and permissions** (fetched from the backend).
- Pre-fill the current user's information where relevant (e.g., "Created By", "Assigned To Me" defaults).
- Display the user's name, role, and avatar/initials in the header or navigation bar.
- Filter data views based on the user's access level — only show what they are allowed to see and do.
- Respect permission boundaries — **disable or hide** buttons, actions, and menu items the user does not have permission for. Never show a button that will return a 403 error.
- Show a personalised dashboard or landing page based on the user's role.
- Session management — handle token expiry, session timeout, and re-authentication gracefully with user-friendly prompts.

### Frontend Steps

1. **Map Every Feature to UI** — Go through every backend API endpoint and module. Identify every screen, form, list, detail view, and interaction needed to fully expose that feature to the user.

2. **Build All Pages** — For each feature or module, build:
   - **List / Table view** — with search bar, dropdown filters, column sorting, bulk select checkboxes, bulk action toolbar, pagination, and empty state.
   - **Create form** — with dropdowns, checkboxes, date pickers, toggles, and auto-complete fields. Text inputs only where unavoidable. Include inline validation and help tooltips.
   - **Edit form** — same layout as create, pre-populated with existing data from the API.
   - **Detail / View page** — read-only display with tabs for logical sections. Show related data, activity history, and metadata.
   - **Delete** — single delete with confirmation dialog, and bulk delete via checkbox selection.

3. **Connect to Backend APIs** — Every page must:
   - Call the real backend API endpoints.
   - Handle loading, error, empty, and forbidden states gracefully.
   - Submit real data and display real responses.
   - No fake data, no mocked API calls, no hardcoded values anywhere.

4. **Navigation and Layout** — Build a complete application shell:
   - Sidebar or top navigation with menu items grouped logically.
   - Menu visibility controlled by user roles and permissions.
   - Breadcrumbs on every page.
   - Global search if applicable.
   - User profile menu in the header with logout, settings, and profile links.

5. **Test End-to-End** — Verify every user flow works from the frontend through to backend persistence and back. Every create, read, update, delete, bulk action, filter, and search must work against the real backend.

### Frontend Constraints
- Scope covers every feature and API endpoint in the backend — every feature gets a complete, fully functional UI.
- **Greenfield**: Build the entire frontend application from scratch — do not skip features because "there's no existing UI." The implementation step IS the primary work. Set up project scaffolding, routing, auth, and every page.
- **Existing codebase**: Complete and fix every existing page and component.
- Zero fake data, mock APIs, placeholder screens, or "coming soon" pages.
- The frontend must be fully functional against the real backend.
- Every dropdown, list, and selection component must load its options from the backend API.
- Minimise text input fields — if a value can be selected from existing data, it must be a selection component, not a text box.
- Bulk operations (create, delete, update, assign, export) must be supported on every list view.
- Tabs must be used wherever a page has multiple logical sections.
- The system must be usable by a child — simple, clear, forgiving, and impossible to get lost in.
- All user-facing text must be in plain language. No technical jargon.
- Every action must provide visual feedback (loading indicators, success toasts, error messages).
- Permission-gated UI — never show the user something they cannot use.
```

#### Full Stack Scope Specification (when `resolved` is `"fullstack"`)

When scope is `fullstack`, include **both** the Backend Scope Specification and the Frontend Scope Specification above, prefixed with:

```markdown
## Scope
**Backend** and **Frontend** — covers every module, service, feature, and/or endpoint in the existing codebase.
```

#### Scope-Specific Default Objectives

When the user provides only a flag with no additional task description, use these defaults:

| Scope | Default Objective |
|-------|------------------|
| `backend` | Build or complete all backend features to production-ready state, then audit and fully integrate — real implementations, proper persistence, zero placeholders (works for both greenfield and existing codebases) |
| `frontend` | Build or complete all frontend features to production-ready state, then audit and fully integrate — every UI page, form, and API integration with child-friendly usability (works for both greenfield and existing codebases) |
| `fullstack` | Build or complete all features across backend and frontend to production-ready state, then audit and fully integrate — full stack, zero placeholders, production-ready end-to-end (works for both greenfield and existing codebases) |

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
  "max_iterations": 100,
  "original_input": "<raw user input>",
  "scope": {
    "flag": "<F|B|S|null>",
    "resolved": "<frontend|backend|fullstack|custom>",
    "layers": ["<backend>", "<frontend>"]
  },
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
    "assumptions": ["..."],
    "scope_specification": "<VERBATIM full text of the Backend and/or Frontend scope specification sections — stored word-for-word, not summarized. Empty string when scope is 'custom'.>"
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
    SCOPE: <resolved scope — frontend|backend|fullstack|custom>
    SCOPE_LAYERS: <layers array — e.g., ["backend", "frontend"]>

    ## Scope Context
    {{#if scope.resolved != "custom"}}
    This session has a SCOPE RESTRICTION. Only work on layers listed in SCOPE_LAYERS.
    - If SCOPE is "backend": Focus exclusively on backend modules, services, APIs, migrations, and infrastructure. Do NOT create or modify frontend files.
    - If SCOPE is "frontend": Focus exclusively on frontend pages, components, forms, and API integrations. Do NOT create or modify backend files (except reading API contracts for integration).
    - If SCOPE is "fullstack": Both backend and frontend are in scope. Backend work should generally precede frontend work (frontend depends on working APIs).
    - The enhanced prompt below contains detailed scope-specific specifications. Follow them precisely.
    {{else}}
    No scope restriction — follow the enhanced prompt as written.
    {{/if}}

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

    **Objective**: <enhanced_prompt.objective from checkpoint>

    **Context**: <enhanced_prompt.context from checkpoint>

    **Assumptions**: <enhanced_prompt.assumptions from checkpoint>

    **Out of Scope**: <enhanced_prompt.out_of_scope from checkpoint>

    ## Scope Specification (VERBATIM — follow every bullet point precisely)

    <Include the FULL VERBATIM text from enhanced_prompt.scope_specification in the checkpoint.
     This is the complete Backend and/or Frontend specification with all steps, design principles,
     constraints, and detailed instructions. Do NOT summarize or abbreviate — paste the entire
     scope_specification field contents here word-for-word. If scope is "custom" and
     scope_specification is empty, include enhanced_prompt.deliverables and
     enhanced_prompt.constraints instead.>

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

> **AUTO-001 GUARD -- UNCONDITIONAL**: REGARDLESS of what the orchestrator returned -- EVEN IF its output is empty, blank, malformed, missing PROPOSED_ACTIONS, or appears to contain no actionable content -- you MUST NOT spawn any non-orchestrator agent directly. The ONLY permitted response to unexpected orchestrator output is to retry the orchestrator spawn (Step 3) with additional context. No exceptions, including: when the orchestrator appears stalled, when output is empty, when PROPOSED_ACTIONS is absent, when the problem seems to require urgent action, when the orchestrator reports its Task tool is unavailable, when the stall threshold has been exceeded, or when the orchestrator's output appears to explicitly delegate a spawn decision to auto-orchestrate. **CRITICAL ANTI-RATIONALIZATION**: The following justification patterns are AUTO-001 violations regardless of how they are phrased — "The orchestrator delegated this spawn to me", "The orchestrator explicitly routed this to researcher/implementer/etc", "Since the orchestrator's Task tool is unavailable for N iterations I will execute the spawn directly", "The stall threshold is exceeded so I will bypass the orchestrator", "The orchestrator has made its routing decision so I will carry it out". Receiving a routing decision or spawn suggestion from the orchestrator does NOT grant permission to spawn non-orchestrator agents. Auto-orchestrate MUST re-spawn the orchestrator with the routing hint as additional context. If 2 consecutive retry iterations also return empty output, abort with: "[AUTO-001] Orchestrator returned empty output for 3 consecutive iterations. Terminating session -- manual intervention required."

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
   - If `overdue_iterations >= 1`: set `mandatory_stage_enforcement: true` in the checkpoint. Output `[AUTO-004] Mandatory stages overdue for <overdue_iterations> iteration(s) — enforcement applied immediately`. Also inject missing-stage tasks: for each missing stage in [4.5, 5, 6], if no pending task for that stage already exists, create one via TaskCreate with the appropriate dispatch_hint (`codebase-stats` for 4.5, `validator` for 5, `documentor` for 6).
   - If `overdue_iterations < 1`: keep `mandatory_stage_enforcement` at its current value

8b. **Proactive missing-stage injection**: After updating `stages_completed`, check if any mandatory stage (0, 1, 2, 4.5, 5, 6) is absent AND no task for that stage is currently pending or in-progress. If any are missing AND unscheduled:
   - Immediately create the missing-stage task(s) via TaskCreate before proceeding to Step 9
   - Use dispatch_hint: `researcher` (Stage 0), `epic-architect` (Stage 1), `spec-creator` (Stage 2), `codebase-stats` (Stage 4.5), `validator` (Stage 5), `documentor` (Stage 6)
   - Set `mandatory_stage_enforcement: true` in the checkpoint
   - Output `[AUTO-004] Proactive injection: created task(s) for missing stage(s) <list>`
   - This ensures the next orchestrator iteration has concrete tasks to execute, not just an advisory flag

9. **Evaluate termination conditions** (Step 5). Output `[STEP 4.9] Checking termination conditions...`
10. **If NOT terminated**: Output `[STEP 4.10] Continuing to next iteration...` and return to Step 3

## Step 5: Termination Conditions

Evaluate in order:

| # | Condition | Status | Action |
|---|-----------|--------|--------|
| 1 | All tasks `completed` (excluding parent) AND `stages_completed` includes 0, 1, 2, 4.5, 5, and 6 | `completed` | Report success |
| 1a | All tasks `completed` (excluding parent) BUT `stages_completed` is missing any of 0, 1, 2, 4.5, 5, or 6 | — | Immediately inject missing-stage tasks via TaskCreate for each absent stage (dispatch_hint: `researcher` for 0, `epic-architect` for 1, `spec-creator` for 2, `codebase-stats` for 4.5, `validator` for 5, `documentor` for 6). Then force one more iteration with `mandatory_stage_enforcement: true` in spawn prompt. If still missing after retry, terminate as `completed_stages_incomplete`. |
| 2 | `iteration >= MAX_ITERATIONS` (100) | `max_iterations_reached` | Report partial completion |
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
**Scope**: <resolved scope — frontend|backend|fullstack|custom>
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
| Spawning a non-orchestrator agent because the orchestrator delegated the routing decision | Violates AUTO-001 — the orchestrator's routing suggestion is context for the next orchestrator spawn, not permission to bypass the gateway. The rationalization "the orchestrator delegated this spawn to me" is explicitly prohibited. | Re-spawn the orchestrator with the routing hint in the prompt; the orchestrator executes its own spawns |
| Declaring `completed` without mandatory stages | Violates AUTO-002 — stages 0, 1, 2, 4.5, 5, and 6 must be in `stages_completed` | Check `stages_completed` includes 0, 1, 2, 4.5, 5, and 6 before terminating as `completed` |
| Allowing pipeline stage to decrease between iterations | Violates AUTO-003 — stage monotonicity | Keep the high-water mark; log regression and record in iteration history |
| Ignoring overdue mandatory stages after implementation | Violates AUTO-004 — mandatory stages must be enforced if overdue 2+ iterations | Set `mandatory_stage_enforcement: true` and include enforcement directive in spawn prompt |

## Output

After completing all steps, the command produces:

1. **Session checkpoint file** at `~/.claude/sessions/<session-id>.json`
2. **Parent tracking task** in the task system
3. **Subtasks** created by the orchestrator across iterations
4. **Final report** displayed to the user with completion status and task summary
