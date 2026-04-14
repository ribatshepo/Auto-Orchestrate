# Auto-Orchestrate Architecture

Comprehensive architecture documentation for the Auto-Orchestrate system.

**Last Updated**: 2026-04-14
**Components**: 18 agents | 35 skills | 19 commands | 26 processes | 6 protocols | 2 templates | 9 CI engine modules | 4 domain memory modules

---

## 1. System Overview

Auto-Orchestrate is a multi-layer autonomous pipeline system with built-in continuous improvement. It follows a layered architecture:

- **Commands** provide autonomous loop controllers (`/auto-orchestrate`, `/auto-debug`, `/auto-audit`) and interactive workflow commands
- **Agents** orchestrate complex multi-step workflows via subagent delegation
- **Skills** perform concrete, atomic tasks with Python scripts
- **CI Engine** provides within-run (OODA) and cross-run (PDCA) feedback loops
- **Domain Memory** persists project knowledge across all sessions and commands
- **Protocols** define communication contracts, output standards, and skill chaining rules
- **Shared Library** provides layered Python utilities (layer0-3) used by all scripts

```
┌──────────────────────────────────────────────────────────────────────────┐
│                           COMMANDS LAYER                                │
│  /auto-orchestrate  /auto-debug  /auto-audit                            │
│  /workflow-start  /workflow-dash  /workflow-focus  /workflow-next        │
│  /workflow-end  /workflow-plan  /refactor-analyzer                      │
├──────────────────────────────────────────────────────────────────────────┤
│                            AGENTS LAYER                                 │
│  orchestrator │ researcher     │ session-manager│ debugger                │
│  auditor      │ cloud-engineer │ data-engineer  │ engineering-manager     │
│  ml-engineer  │ platform-engineer│ product-manager│ qa-engineer          │
│  security-engineer│ software-engineer│ sre      │ staff-principal-engineer│
│  technical-program-manager│ technical-writer  │                          │
├──────────────────────────────────────────────────────────────────────────┤
│                            SKILLS LAYER                                 │
│  35 specialized skills (each with SKILL.md + optional Python scripts)   │
├────────────────────────────────┬─────────────────────────────────────────┤
│       CI ENGINE (lib/)         │        DOMAIN MEMORY (lib/)            │
│  OODA loop (within-run)        │  .domain/ (cross-session)              │
│  PDCA loop (cross-run)         │  6 JSONL stores:                       │
│  8 root cause categories       │    research, decisions, patterns,      │
│  Telemetry + baselines         │    fixes, analysis, preferences        │
│  Improvement recommender       │  SQLite index + hooks                  │
├────────────────────────────────┴─────────────────────────────────────────┤
│                          PROTOCOL LAYER                                 │
│  subagent-protocol │ output-standard │ output-schemas                   │
│  skill-chaining    │ chain-contracts │ task-system                      │
├──────────────────────────────────────────────────────────────────────────┤
│                     SHARED PYTHON LIBRARY                               │
│  layer0 (constants) │ layer1 (I/O) │ layer2 (validation) │ layer3 (ops)│
├──────────────────────────────────────────────────────────────────────────┤
│                       PERSISTENT STATE                                  │
│  .orchestrate/  │  .debug/  │  .audit/  │  .domain/  │  .sessions/     │
│  (per-session)  │(per-debug)│(per-audit)│ (project)  │  (registry)     │
└──────────────────────────────────────────────────────────────────────────┘
```

### Data Flow

```
User Input ──→ Command (loop controller) ──→ Orchestrator Agent
                                                    │
                 ┌──────────────────────────────────┤
                 │                                  │
                 v                                  v
          Stage Agents                      CI Engine (optional)
    (researcher, software-engineer,    (OODA: observe→orient→
     validator, technical-writer...)    decide→act per stage)
                 │                                  │
                 v                                  v
          Stage Outputs                    Telemetry + Baselines
    (.orchestrate/stage-N/)            (.orchestrate/knowledge_store/)
                 │                                  │
                 v                                  v
         Stage Receipts ──────────→ Domain Memory (.domain/)
    (stage-receipt.json)           (research, fixes, patterns persist
                                    across ALL future sessions)
```

---

## 2. Directory Structure

```
claude-code/
├── manifest.json                              (2000 lines, 61.2 KB)
├── ARCHITECTURE.md                            (this file)
├── _shared/
│   ├── protocols/
│   │   ├── subagent-protocol-base.md          (336 lines)
│   │   ├── output-standard.md                 (unified output naming/structure)
│   │   ├── output-schemas.md                  (inter-skill JSON schemas)
│   │   ├── skill-chaining-patterns.md         (249 lines)
│   │   ├── skill-chain-contracts.md           (131 lines)
│   │   └── task-system-integration.md         (246 lines)
│   ├── references/
│   │   ├── product-manager/
│   │   │   ├── patterns.md                    (344 lines)
│   │   │   ├── examples.md                    (194 lines)
│   │   │   └── output-format.md               (92 lines)
│   │   └── orchestrator/
│   │       └── SUBAGENT-PROTOCOL-BLOCK.md     (43 lines)
│   ├── templates/
│   │   ├── skill-boilerplate.md               (195 lines)
│   │   └── anti-patterns.md                   (73 lines)
│   ├── style-guides/
│   │   └── style-guide.md                     (83 lines)
│   ├── tokens/
│   │   └── placeholders.json                  (327 lines)
│   └── schemas/                               (canonical: manifest.schema.json — 2020-12, 352 lines)
├── agents/
│   ├── orchestrator.md                        (639 lines, 31.7 KB — orchestration core)
│   ├── session-manager.md                     (149 lines, 7.7 KB — orchestration core)
│   ├── researcher.md                          (190 lines, 11.5 KB — orchestration core)
│   ├── debugger.md
│   ├── auditor.md
│   ├── cloud-engineer.md                      (team agent)
│   ├── data-engineer.md                       (team agent)
│   ├── engineering-manager.md                 (team agent)
│   ├── ml-engineer.md                         (team agent)
│   ├── platform-engineer.md                   (team agent)
│   ├── product-manager.md                     (team agent)
│   ├── qa-engineer.md                         (team agent)
│   ├── security-engineer.md                   (team agent)
│   ├── software-engineer.md                   (team agent)
│   ├── sre.md                                 (team agent)
│   ├── staff-principal-engineer.md            (team agent)
│   ├── technical-program-manager.md           (team agent)
│   └── technical-writer.md                    (team agent)
├── skills/
│   ├── codebase-stats/SKILL.md                (351 lines)
│   ├── dependency-analyzer/SKILL.md           (352 lines)
│   ├── debug-diagnostics/SKILL.md
│   ├── dev-workflow/SKILL.md                  (486 lines)
│   ├── docs-lookup/SKILL.md                   (66 lines)
│   ├── docs-review/SKILL.md                   (172 lines)
│   ├── docs-write/SKILL.md                    (134 lines)
│   ├── error-standardizer/SKILL.md            (399 lines)
│   ├── hierarchy-unifier/SKILL.md             (343 lines)
│   ├── library-implementer-python/SKILL.md    (438 lines)
│   ├── refactor-executor/SKILL.md             (271 lines)
│   ├── researcher/SKILL.md                    (201 lines)
│   ├── schema-migrator/SKILL.md               (365 lines)
│   ├── security-auditor/SKILL.md              (316 lines)
│   ├── skill-creator/SKILL.md                 (361 lines)
│   ├── skill-lookup/SKILL.md                  (81 lines)
│   ├── spec-creator/SKILL.md                  (175 lines)
│   ├── spec-compliance/SKILL.md
│   ├── task-executor/SKILL.md                 (224 lines)
│   ├── test-gap-analyzer/SKILL.md             (462 lines)
│   ├── test-writer-pytest/SKILL.md            (497 lines)
│   ├── validator/SKILL.md                     (260 lines)
│   ├── docker-validator/SKILL.md              (449 lines)
│   ├── production-code-workflow/SKILL.md      (244 lines)
│   ├── python-venv-manager/SKILL.md
│   ├── docker-workflow/SKILL.md               (338 lines)
│   ├── spec-analyzer/SKILL.md                 (388 lines)
│   ├── cicd-workflow/SKILL.md                 (306 lines)
│   ├── refactor-analyzer/SKILL.md             (153 lines)
│   ├── workflow-start/SKILL.md                (123 lines)
│   ├── workflow-end/SKILL.md                  (104 lines)
│   ├── workflow-dash/SKILL.md                 (101 lines)
│   ├── workflow-focus/SKILL.md                (119 lines)
│   ├── workflow-next/SKILL.md                 (136 lines)
│   └── workflow-plan/SKILL.md                 (277 lines)
├── lib/                                       (Python libraries)
│   ├── ci_engine/                             (continuous improvement engine)
│   │   ├── ooda_controller.py                 (OODA within-run loop)
│   │   ├── stage_metrics_collector.py         (telemetry, 12 DMAIC KPIs)
│   │   ├── root_cause_classifier.py           (8-category failure classification)
│   │   ├── retrospective_analyzer.py          (post-run PDCA Check)
│   │   ├── improvement_recommender.py         (cross-run PDCA Act)
│   │   ├── baseline_manager.py                (rolling 10-run baselines)
│   │   ├── knowledge_store_writer.py          (persistent knowledge store)
│   │   ├── run_summary.py, prometheus_exporter.py
│   │   ├── schemas/                           (6 JSON schema files)
│   │   └── tests/                             (unit + integration tests)
│   └── domain_memory/                         (cross-session domain knowledge)
│       ├── store.py                           (JSONL append/query engine)
│       ├── schemas.py                         (6 entry dataclasses)
│       ├── indexer.py                         (SQLite WAL-mode index)
│       ├── hooks.py                           (pipeline integration hooks)
│       └── tests/
└── commands/
    ├── auto-orchestrate.md     (autonomous orchestration loop controller)
    ├── auto-debug.md           (autonomous cyclic error-fix-verify loop)
    ├── auto-audit.md           (autonomous spec compliance audit-remediate loop)
    ├── active-dev.md           (active development phase management)
    ├── agent-capabilities.md   (discover available agent capabilities)
    ├── assign-agent.md         (route task to appropriate team agent)
    ├── data-ml-ops.md          (data and ML operations commands)
    ├── gate-review.md          (run gate checklist, record gate state)
    ├── infra.md                (infrastructure management commands)
    ├── new-project.md          (4-stage org pipeline with Phase 5 handoff)
    ├── org-ops.md              (organizational operations and reporting)
    ├── post-launch.md          (post-launch operations and monitoring)
    ├── process-lookup.md       (look up processes by category or ID)
    ├── qa.md                   (quality assurance commands)
    ├── release-prep.md         (release preparation checklist)
    ├── risk.md                 (risk management commands)
    ├── security.md             (security commands)
    ├── sprint-ceremony.md      (sprint retrospective and close)
    ├── workflow.md             (workflow overview and navigation)
    ├── CONVENTIONS.md          (command conventions, PROGRESS-001 format)
    ├── SESSIONS-REGISTRY.md    (cross-command session registry)
    └── TOOL-AVAILABILITY.md    (tool availability per execution context)
```

---

## 3. Dependency Map

### Hub Files (Most Referenced)

| File | References | Role |
|------|------------|------|
| `skill-boilerplate.md` | 68 | Central template for all skills |
| `subagent-protocol-base.md` | 8 | Output contract for subagents |
| `task-system-integration.md` | 7 | Task tool usage patterns |
| `skill-chain-contracts.md` | — | Producer-consumer contracts |
| `anti-patterns.md` | 6 | Common mistakes to avoid |
| `style-guide.md` | 3 | Documentation writing style |

### Reference Architecture

```
                    ┌───────────────────────────────┐
                    │       manifest.json           │
                    │  (registry of all components) │
                    └───────────────┬───────────────┘
                                    │
        ┌───────────────┬───────────┼───────────┬───────────────┐
        │               │           │           │               │
        v               v           v           v               v
 ┌─────────────┐ ┌─────────────┐ ┌─────────┐ ┌─────────────┐ ┌──────────┐
 │   AGENTS    │ │   SKILLS    │ │COMMANDS │ │  CI ENGINE  │ │  DOMAIN  │
 │  (21 files)  │ │ (35 dirs)   │ │(14 files)│ │  (9 modules)│ │  MEMORY  │
 └──────┬──────┘ └──────┬──────┘ └─────────┘ └──────┬──────┘ │(4 modules│
        │               │                           │        └──────────┘
        │   ┌───────────┼───────────┐               │
        │   │           │           │               │
        v   v           v           v               v
 ┌────────────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐
 │ subagent-      │ │ output-  │ │ skill-   │ │ knowledge    │
 │ protocol-base  │ │ standard │ │ chaining │ │ store writer │
 └────────────────┘ └──────────┘ └──────────┘ └──────────────┘
 ┌────────────────┐ ┌──────────┐ ┌──────────┐
 │ output-schemas │ │ chain-   │ │ task-    │
 │                │ │ contracts│ │ system   │
 └────────────────┘ └──────────┘ └──────────┘
```

### Cross-Reference Frequency

| Source Type | References `protocols` | References `lib/` |
|-------------|------------------------|-------------------|
| Skills (35) | 5 | 0 (use shared Python library) |
| Agents (18) | 7 | 2 (orchestrator, debugger) |
| Commands (3) | 3 | 3 (CI engine + domain memory) |
| Protocols (6) | 3 (internal) | 0 |

---

## 4. Agents Architecture

### 4.1 Orchestrator

**Purpose**: Coordinate complex workflows by delegating to subagents while protecting context.

**Key Constraints (MAIN-001 to MAIN-015)**:
- Stay high-level (no implementation)
- Delegate ALL work via Task tool
- No full file reads (manifest summaries only)
- Respect dependencies (sequential spawning)
- Context budget under 10K tokens
- Zero-error gate (no exit until 0 errors/warnings AND all user journeys pass; explicit FIX_ITER counter, max 3 iterations)
- Session folder autonomy (full read of ~/.claude/)
- Minimal user interruption (autonomous decisions)
- File scope discipline (no out-of-scope file changes)
- No deletion without consent
- max_turns on every Task tool spawn
- Flow integrity (follow full pipeline, never skip stages)
- Decomposition gate (verify dispatch_hint before spawning software-engineer)
- No auto-commit (NEVER run git commit, git push, or any git write operation)
- Always-visible processing (progress output before/after every subagent spawn)

**Additional Rules**:
- **VERBOSE-001**: Every `[STAGE N] completed` line MUST include a `Key findings:` suffix with a one-sentence summary. Never omit this suffix. Progress lines must include quantitative data (task counts, file names, error counts) where available.
- **PRE-BOOT (Step -1)**: The orchestrator's MANDATORY FIRST ACTION each iteration is to write `.orchestrate/<SESSION_ID>/proposed-tasks.json` before any other work. If no new tasks are proposed, write an empty proposals object.
- **SEQUENTIAL-STAGE-GATE**: Do NOT spawn Stage N+1 while any Stage N task is still pending or in-progress. See section 4.3.2.

**Decision Flow**:
```
BOOT
  │
  ├─ Step -0.5: CI Engine probe (granular: HAS_OODA, HAS_METRICS, etc.)
  ├─ Step -0.25: Domain Memory probe (.domain/ init)
  ├─ Step 0: Session-manager (set up .orchestrate/<session>/)
  ├─ Step 1: Read manifest.json (MANIFEST-001 routing registry)
  │
  v
PIPELINE LOOP (respects STAGE_CEILING)
  │
  ├─ Step -1: Write proposed-tasks.json (MANDATORY first action)
  │
  ├─ Stage 0 (researcher) ──→ Domain memory: query research_ledger
  │   └─ If HAS_RECOMMENDER: inject improvement_targets.json
  ├─ Stage 1 (product-manager) ──→ Task decomposition
  ├─ Stage 2 (spec-creator) ──→ Specifications
  ├─ Stage 3 (software-engineer) ──→ Code (to project files)
  ├─ Stage 4 (test-writer) ──→ Tests (conditional)
  ├─ Stage 4.5 (codebase-stats) ──→ Metrics
  ├─ Stage 5 (validator) ──→ Compliance check
  ├─ Stage 6 (technical-writer) ──→ Docs update
  │
  ├─ After EACH stage:
  │   ├─ Write stage-receipt.json (RECEIPT-001)
  │   ├─ If HAS_OODA: OODA loop (continue/retry/fallback/surface)
  │   └─ Domain memory: persist learned knowledge via hooks
  │
  └─ After ALL stages:
      ├─ If HAS_RETRO: RetrospectiveAnalyzer (Check phase)
      ├─ If HAS_RECOMMENDER: ImprovementRecommender (Act phase)
      └─ If HAS_BASELINES: BaselineManager (update rolling averages)
```

**Delegated Skills**:
| Task Type | Skill | When |
|-----------|-------|------|
| Research | `researcher` | Unknowns, exploration |
| Implementation | `task-executor` | Code, config changes |
| Epic decomposition | `product-manager` | Planning large efforts |
| Documentation | `technical-writer` | Docs, READMEs |
| Specifications | `spec-creator` | Technical specs |
| Python libraries | `library-implementer-python` | Python modules |
| Tests | `test-writer-pytest` | Pytest tests |
| Validation | `validator` | Compliance checks |

---

### 4.2 Technical-Writer

**Purpose**: Documentation specialist orchestrating the full docs lifecycle with anti-duplication principle.

**Core Principle**: MAINTAIN, DON'T DUPLICATE

**Decision Flow**:
```
┌──────────────────┐
│ Topic received   │
└────────┬─────────┘
         v
┌──────────────────┐
│ docs-lookup      │ <-- MANDATORY first step
└────────┬─────────┘
         v
    ┌─────────┐
    │ Found?  │
    └────┬────┘
    yes/   \no
       v      v
┌──────────┐  ┌──────────────┐
│ UPDATE   │  │ CREATE       │
│ existing │  │ minimal new  │
└────┬─────┘  └──────┬───────┘
     └────────┬──────┘
              v
     ┌────────────────┐
     │ docs-write     │
     └────────┬───────┘
              v
     ┌────────────────┐
     │ docs-review    │
     └────────┬───────┘
              v
        ┌───────────┐
        │ Passes?   │
        └─────┬─────┘
        yes/   \no
           v      v
      [DONE]   [Fix & re-review]
```

**Skill Chain**:
1. `docs-lookup` -> Find existing docs
2. `docs-write` -> Create/update with style guide
3. `docs-review` -> Style compliance check

---

### 4.3 Epic Architect

**Purpose**: Create comprehensive epics with task decomposition, dependency analysis, and Program planning.

**Decision Flow**:
```
Requirements received
         │
         v
    ┌─────────────────┐
    │ Clear enough?   │
    └────────┬────────┘
        no/   \yes
          v      v
┌──────────────┐  ┌─────────────────┐
│ HITL clarify │  │ Greenfield or   │
└──────────────┘  │ brownfield?     │
                  └────────┬────────┘
                    green/   \brown
                       v        v
              ┌──────────┐  ┌─────────────────┐
              │ Full     │  │ Add impact +    │
              │ decomp   │  │ regression tasks│
              └────┬─────┘  └────────┬────────┘
                   └────────┬────────┘
                            v
                [Create epic + tasks]
                            v
                [Analyze dependencies]
                            v
                [Plan Programs]
```

**Program Planning**:
```
Program 0 (no deps)    -> Can start immediately
Program 1 (deps: W0)   -> Depends only on Program 0
Program 2 (deps: W0,1) -> Depends on Program 0 or 1
...continue until all tasks assigned
```

**Epic Structure**:
```
Epic (type: epic, size: large)
├── Task 1 (no deps)           [Program 0] <- Must have at least one
├── Task 2 (depends: T1)       [Program 1]
├── Task 3 (depends: T1)       [Program 1]  <- Parallel opportunity
├── Task 4 (depends: T2,T3)    [Program 2]
└── Task 5 (depends: T4)       [Program 3]
```


### 4.3.1 Task Management Architecture (File-Based Protocol)

**Updated**: 2026-02-15 (GAP-CRIT-001 reopened — tool availability confirmed)

Task management tools (TaskCreate, TaskList, TaskUpdate, TaskGet) are ONLY available to the **auto-orchestrate loop** (main Claude Code instance). Subagents (orchestrator, product-manager, software-engineer, etc.) communicate task proposals via files.

**How It Works**:

```
1. auto-orchestrate spawns orchestrator with current task state in spawn prompt
   └─> Orchestrator reads task state from ## Current Task State section

2. Orchestrator spawns product-manager for decomposition (or proposes tasks via PROPOSED_ACTIONS if Task tool unavailable)
   └─> Writes task proposals to .orchestrate/<session-id>/proposed-tasks.json

3. Orchestrator returns with PROPOSED_ACTIONS JSON block
   └─> Includes tasks_to_create and tasks_to_update proposals

4. auto-orchestrate reads proposals from file AND return value
   └─> Creates tasks via TaskCreate, updates via TaskUpdate

5. auto-orchestrate spawns orchestrator again with updated task state
   └─> Orchestrator routes work to subagents or performs directly

6. Subagent executes task
   └─> Writes output to manifest, reports status in return value

7. auto-orchestrate updates task status based on results
   └─> Continues iteration loop
```

**Key Fields**:

| Field | Owner | Purpose |
|-------|-------|---------|
| `dispatch_hint` | product-manager | Routing key for auto-orchestrate (REQUIRED field) |
| `blockedBy` | product-manager | Dependency edges for task ordering |
| `PROPOSED_ACTIONS` | orchestrator | Task action proposals in return value |
| `key_findings` | subagent | Summary for orchestrator consumption (manifest entry) |

**dispatch_hint Values**:

| Value | Subagent | Task Type |
|-------|----------|-----------|
| `software-engineer` | Software-engineer agent (opus model) | Production code (default for implementation) |
| `technical-writer` | Technical-writer agent | Documentation creation/updates |
| `validator` | Validator skill | Compliance checks |
| `test-writer-pytest` | Test writer skill | Pytest test creation |
| `task-executor` | Task executor skill | Simple config/non-code tasks |
| `researcher` | Researcher skill | Investigation and discovery |
| `spec-creator` | Spec creator skill | Technical specifications |

**Task Proposal File Format** (`.orchestrate/<session-id>/proposed-tasks.json`):

```json
{
  "tasks": [
    {
      "subject": "Implement user authentication endpoints",
      "description": "Create POST /api/auth/login and POST /api/auth/register endpoints. dispatch_hint: software-engineer",
      "activeForm": "Implementing auth endpoints",
      "blockedBy": [],
      "dispatch_hint": "software-engineer",
      "risk": "medium",
      "acceptance_criteria": ["Endpoint responds correctly", "Validates input"]
    }
  ]
}
```

**GAP-CRIT-001 Status — OPEN**:

Task management tools (TaskCreate, TaskList, TaskUpdate, TaskGet) are **NOT available** to any subagent. The Task tool (for spawning subagents) is also **unreliable** at runtime. The workaround uses a file-based task proposal protocol where:

- Auto-orchestrate loop is the **sole gateway** for task management
- Subagents propose tasks via files (`.orchestrate/<session-id>/proposed-tasks.json`)
- Orchestrator receives task state via spawn prompt, proposes updates via return value
- Auto-orchestrate processes proposals between iterations

### .orchestrate/ Folder Structure

Each auto-orchestrate session creates a per-session output directory in the project root:

```
.orchestrate/
└── <session-id>/
    ├── stage-0/               # Researcher output (Stage 0)
    ├── stage-1/               # Product-manager plans (Stage 1)
    ├── stage-2/               # Spec-creator output (Stage 2)
    ├── stage-3/               # Software-engineer output (Stage 3)
    ├── stage-4/               # Test writer output (Stage 4)
    ├── stage-4.5/             # Codebase stats output (Stage 4.5)
    ├── stage-5/               # Validator output (Stage 5)
    ├── stage-6/               # Technical-writer output (Stage 6)
    └── proposed-tasks.json    # Task proposals (written by orchestrator as MANDATORY FIRST ACTION)
```

This directory is project-local. `~/.claude/sessions/` is retained as a read-only legacy fallback for crash recovery of sessions started before the path migration. Checkpoint data is now stored in `.orchestrate/<session-id>/checkpoint.json`.

**File naming convention**: All output files written to stage directories MUST use date-prefixed filenames: `YYYY-MM-DD_<descriptor>.<ext>` (e.g. `2026-03-04_research-findings.md`).

**References**:
- `claude-code/commands/TOOL-AVAILABILITY.md` — Full tool availability matrix and workarounds (see also: `commands/CONVENTIONS.md`, `commands/SESSIONS-REGISTRY.md`)
- `claude-code/agents/orchestrator.md` — Orchestrator file-based protocol
- `claude-code/agents/product-manager.md` — Task proposal output format
- `claude-code/commands/auto-orchestrate.md` — Task management proxy implementation

---

### 4.3.2 Mandatory Stage Enforcement Guards

**Updated**: 2026-03-03

The orchestrator and auto-orchestrate command enforce mandatory pipeline stages through four interlocking guards that prevent implementation from proceeding when required stages are missing.

#### PRE-IMPL-GATE

Blocks implementation spawns if mandatory pre-implementation stages (0, 1, 2) are not completed. When this gate fires, the orchestrator re-routes to the first missing mandatory stage instead of proceeding to implementation.

```
# Located in: orchestrator.md - Execution Loop
# PRE-IMPL-GATE: Block implementation if mandatory pre-impl stages are incomplete
missing_pre_impl = [s for s in [0, 1, 2] if s not in stages_completed]
if missing_pre_impl and agent in ["software-engineer", "library-implementer-python"]:
    log("[PRE-IMPL-GATE] BLOCKED: Cannot spawn software-engineer -- stages missing.")
    # Re-route to first missing stage
```

#### BUDGET-RESERVATION

Reserves 3 budget slots for mandatory post-implementation stages (4.5, 5, 6). Prevents the orchestrator from exhausting its spawn budget on implementation tasks and then being unable to spawn the validator, codebase-stats, and technical-writer agents.

```
# Located in: orchestrator.md - Execution Loop
POST_IMPL_RESERVED = 3  # Reserved for stages 4.5, 5, 6
IMPL_BUDGET = REMAINING_BUDGET - POST_IMPL_RESERVED
# BUDGET-RESERVATION: Reserve slots for mandatory post-impl stages
if REMAINING_BUDGET <= POST_IMPL_RESERVED:
    log("[BUDGET-RESERVATION] Only {n} slots left -- reserved for stages 4.5/5/6.")
    # Exit implementation loop, force post-impl stages
```

#### POST-IMPL-EXIT-GATE (Budget Exemption)

Budget exhaustion is NEVER a valid reason to skip Stages 5 or 6. Even if REMAINING_BUDGET reaches 0, the validator (Stage 5) and technical-writer (Stage 6) spawns are **exempt from budget limits**. This ensures the quality gate and documentation always run regardless of how many implementation iterations occurred.

**Enhanced Fix-Loop (FIX_ITER)**: After every software-engineer spawn, the orchestrator runs an explicit fix loop with an iteration counter (`FIX_ITER`, max `MAX_FIX_ITER = 3`). Each iteration: spawns validator (including user journey testing) → if errors=0 AND warnings=0 AND all journeys pass → exits loop. Otherwise increments FIX_ITER and re-spawns software-engineer with validator findings. If `FIX_ITER >= MAX_FIX_ITER`, the orchestrator escalates to the user with a blocked task rather than looping indefinitely.

**User Journey Gate**: The validator MUST perform user journey testing (CRUD, authentication, navigation, error handling, edge cases) as part of Stage 5. Advancement is blocked if ANY user journey fails, in addition to the existing errors/warnings=0 requirement.

#### SEQUENTIAL-STAGE-GATE

Enforces strict sequential ordering within the execution loop. The orchestrator MUST NOT spawn a Stage N+1 agent while any Stage N task is still pending or in-progress. When this gate fires, the orchestrator skips the higher-stage task and processes the incomplete prior-stage task first. This prevents out-of-order execution where, for example, product-manager (Stage 1) would be spawned while researcher (Stage 0) is still running.

Output when gate fires: `[GATE] Blocking Stage {N} — Stage {N-1} incomplete.`

#### HARD SELF-AUDIT GATE

Replaces the advisory self-audit checklist with a mandatory gate. Before the orchestrator can return, it must confirm all required stages were spawned. If any mandatory stage (0, 1, 2, 4.5, 5, 6) was skipped, the gate blocks return and forces spawning of the missing agent.

The gate uses structured checklist evaluation with binary pass/fail per item, and requires zero skipped mandatory stages before completing.

#### AUTO-004 Threshold Change (auto-orchestrate.md)

The auto-orchestrate loop enforces that mandatory post-implementation stages cannot be deferred. The enforcement threshold was changed from `overdue_iterations >= 2` to `overdue_iterations >= 1` -- mandatory stages are enforced **immediately** after the first iteration where they are overdue, rather than waiting two iterations.

Three sub-mechanisms support AUTO-004:

1. **Step 8a -- Mandatory stage gate check**: If Stage 3 is complete but 4.5, 5, or 6 are missing, sets `mandatory_stage_enforcement: true` after just 1 overdue iteration. Also injects missing-stage tasks via TaskCreate with the appropriate dispatch_hint.

2. **Step 8b -- Proactive missing-stage injection**: After updating `stages_completed`, proactively checks if any mandatory stage (0, 1, 2, 4.5, 5, 6) is absent AND unscheduled. Creates tasks immediately without waiting for enforcement to trigger. Output: `[AUTO-004] Proactive injection: created task(s) for missing stage(s)`.

3. **Condition 1a**: When all tasks are completed but `stages_completed` is missing mandatory stages, immediately injects the missing-stage tasks via TaskCreate (dispatcher: `researcher` for 0, `product-manager` for 1, `spec-creator` for 2, `codebase-stats` for 4.5, `validator` for 5, `technical-writer` for 6) and forces one more iteration with `mandatory_stage_enforcement: true`.

**Impact**: These guards collectively close the loop on "never-skip" violations where the orchestrator would complete implementation but skip validation, technical debt measurement, or documentation due to budget exhaustion or iteration limits.


### 4.4 Software-Engineer

**Purpose**: Fast implementation agent that implements, reviews, and fixes code in a single pass.

**Core Constraints (IMPL-001 to IMPL-015)**:
- No placeholders -- all code must be production-ready
- Don't ask -- make reasonable decisions and proceed
- Don't explain -- just write code
- Fix immediately -- if something breaks, fix it
- One pass -- implement, review, fix in single pass
- Enterprise production-ready -- no mocks, no hardcoded values
- Scope-conditional quality pipeline
- Security gate -- 0 security issues before completion
- Loop limit -- max 3 fix-audit iterations
- No anti-patterns -- code must not match anti-patterns table
- Context budget discipline (turn count tracking, checkpoints, hard-exit)
- **Single-file scope (IMPL-012)** -- targets exactly ONE file per invocation (SFI-001 enforcement)
- Git-Commit-Message in DONE block (IMPL-013) -- always output a suggested commit message; never auto-commit
- MUST read and apply researcher findings (IMPL-014) -- read Stage 0 output before writing any code; blocked packages are FORBIDDEN; pin exact CVE-free versions confirmed by researcher
- **CVE-free enforcement (IMPL-015)** -- if a required package has an unpatched HIGH/CRITICAL CVE, STOP and invoke FEEDBACK-LOOP-001 before proceeding; document the alternative used

**Single-File Software-Engineer Pattern (SFI-001)** — **UPDATED 2026-02-12**:

The software-engineer enforces a **single-file scope** constraint to eliminate context exhaustion. Each software-engineer invocation targets exactly **one file** — either one file to create OR one file to modify.

**Rationale**: Multi-file software-engineer tasks caused context exhaustion patterns where the agent would read N files, write N files, and run the quality pipeline on N files. This accumulated context (from file reads + writes + pipeline execution) exhausted the 30-turn budget before completion, forcing expensive orchestrator-mediated continuation.

**Architecture change** (2026-02-12):
1. **Product-Manager** (decomposition stage): When `dispatch_hint` is `software-engineer` or `library-implementer-python`, tasks MUST target exactly one file. Multi-file features are decomposed into sequential single-file tasks connected by `blockedBy` dependencies.

2. **Orchestrator** (routing stage): Pre-spawn check verifies software-engineer tasks target exactly 1 file. If multi-file detected (description mentions 2+ files, uses plural scope), route back to product-manager for single-file decomposition.

3. **Software-Engineer** (execution stage): Enforces IMPL-012 — stops if task description mentions multiple files. Simplified Context Window Management (CWM) protocol for single-file scope: write target file to disk immediately after Phase 3, checkpoint by turn count (not file count).

**Impact**: Single-file scope eliminates the multi-file context accumulation that previously caused software-engineer exhaustion. The 30-turn budget is now sufficient for single-file tasks. Context exhaustion becomes rare.

**Example decomposition**:
| Feature scope | Before SFI-001 | After SFI-001 |
|---------------|----------------|---------------|
| 3-file feature (UserService, UserController, UserDto) | 1 task: "Implement UserService, UserController, UserDto" (exhausts context) | 3 tasks: T1: "Implement UserService.ts", T2: "Implement UserController.ts" (blockedBy T1), T3: "Implement UserDto.ts" (blockedBy T1) |
| Interface + implementation | 1 task: "Implement IUserService interface and UserService class" | 2 tasks: T1: "Create IUserService.ts interface", T2: "Create UserService.ts" (blockedBy T1, includes instruction to read interface for patterns) |

**Cross-file consistency**: When multiple files share patterns or interfaces, product-manager includes in each task description:
- Reference to sibling tasks and their target files
- Key patterns/interfaces established by predecessor tasks
- Instruction: "Read [predecessor file] for patterns before implementing"

**Non-software-engineer agents unaffected**: The single-file constraint applies ONLY to `software-engineer` and `library-implementer-python`. Other agents (researcher, technical-writer, validator, etc.) may handle multiple files per the general 3-file limit.

**Decision Flow**:
```
START: Implementation Request
         │
         v
┌─────────────────┐
│ PHASE 1:        │
│ Quick Context   │
└────────┬────────┘
         v
┌─────────────────┐
│ PHASE 2:        │
│ Brief Plan      │
│ + Scope Check   │  <-- NEW: Verify single-file scope (IMPL-012)
└────────┬────────┘
         v
    Multi-file task?
    yes/ \no
      v    v
  [STOP,  [Continue]
   return
   to orch]
         v
┌─────────────────┐
│ PHASE 3:        │
│ Implement file  │  <-- Simplified: exactly 1 file
│ (write to disk  │
│  immediately)   │
└────────┬────────┘
         v
┌─────────────────┐
│ PHASE 4:        │
│ Self-Review     │
└────────┬────────┘
         v  (issues found?)
    yes/   \no
      v     v
┌─────────┐ ┌─────────┐
│ Fix     │ │ PHASE 5:│
│ issues  │ │ Done    │
└────┬────┘ └─────────┘
     │           ^
     └───────────┘
```

**Task Routing**:
| Task Type | Action | Notes |
|-----------|--------|-------|
| Implementation (single file) | Execute directly | This IS the software-engineer |
| Implementation (multi-file) | Return to orchestrator | Violates SFI-001 — route to product-manager for splitting |
| Research needed | Return to orchestrator | Flag as blocked |
| Review needed | Self-review in Phase 4 | No delegation |
| Build failure | Fix immediately | Don't report |
| Test failure | Fix code, re-run | Don't report |

**Skill Delegation**: None - executes directly. References `production-code-workflow` for patterns.

---
### 4.5 Session Manager

**Purpose**: Coordinate work session lifecycle through workflow-* skills.

**Session State Machine**:
```
idle -> /workflow-start -> active
active -> /workflow-focus, /workflow-dash, /workflow-next, /workflow-plan -> active
active -> /workflow-end -> ended
```

**Validation Gates**:
| Transition | Validation | Error |
|------------|------------|-------|
| idle -> /workflow-start | None | Always allowed |
| idle -> /workflow-focus,/workflow-dash,/workflow-next | Require session | "No active session. Use /workflow-start first." |
| active -> /workflow-start | Already running | "Session already active. Use /workflow-end first." |

**Skill Routing**:
| Command | Skill | Purpose |
|---------|-------|---------|
| `/workflow-start` | `workflow-start` | Initialize session |
| `/workflow-dash` | `workflow-dash` | Show dashboard |
| `/workflow-focus` | `workflow-focus` | Set task focus |
| `/workflow-next` | `workflow-next` | Suggest next task |
| `/workflow-end` | `workflow-end` | Wrap up session |
| `/workflow-plan` | `workflow-plan` | Planning mode |

---

### 4.6 Researcher

**Purpose**: Internet-enabled research agent for gathering information on packages, CVEs, best practices, Docker images, and technology evaluation. Mandatory first stage of every orchestration pipeline.

**Spawned At**: Stage 0 (mandatory) — always spawned by the orchestrator before product-manager decomposition begins.

**Tools**: Read, Glob, Grep, Bash, WebSearch, WebFetch

**Constraints (RES-001 to RES-013)**:
- RES-001: Evidence-based — every claim cites a source (URL, file path, or tool output)
- RES-002: Current — prefer sources ≤2 years old; explicitly flag older sources
- RES-003: Relevant — answer only the research questions; no tangential exploration
- RES-004: Actionable — every finding maps to a specific, prioritized, justified recommendation
- RES-005: Security-first — always check CVEs (NVD + GitHub Security Advisories) for packages/images
- RES-006: Structured output — follow the standard output format with all required sections
- RES-007: Manifest entry — always append to `~/.claude/MANIFEST.jsonl` with 3–7 one-sentence key_findings
- RES-008: **Mandatory internet research** — MUST use WebSearch+WebFetch every session. Codebase-only analysis is a VIOLATION. MUST perform at least 3 WebSearch queries per session (e.g. `"<tech> best practices <year>"`, `"<package> CVE site:nvd.nist.gov"`, `"<pattern> production examples"`). If WebSearch is unavailable, return `status: "partial"` with reason. Do NOT silently skip internet research.
- RES-009: **CVE-blocked packages** — packages with unpatched HIGH/CRITICAL CVEs MUST be listed in the research output as BLOCKED, with recommended CVE-free alternatives specified
- RES-010: **Risks & Remedies section** — research output MUST include a structured Risks & Remedies section mapping each risk to a remedy, severity level, and which pipeline stage applies the remedy
- RES-011: **Package version pinning** — for every dependency referenced, specify the exact CVE-free version confirmed via NVD/GitHub Security Advisories; never recommend unpinned or "latest" versions
- RES-012: **Transitive dependency audit** — CVE checks MUST cover direct AND transitive dependencies; flag any transitive chain that includes a HIGH/CRITICAL CVE
- RES-013: **Re-audit trigger** — if the software-engineer or debugger encounters a new package not in the original research, they MUST trigger a FEEDBACK-LOOP-001 cycle before proceeding

**Output**: Research findings file at `.orchestrate/<SESSION_ID>/stage-0/YYYY-MM-DD_<slug>.md` and manifest entry with `key_findings`.

**Skill Delegation**: None — executes directly using WebSearch and WebFetch tools.

---

### 4.7 Debugger

**Purpose**: Autonomous error diagnosis and fixing via cyclic triage-research-root-cause-fix-verify pipeline.

**Key Constraints (DBG-001 to DBG-013)**:
- Evidence-first: every diagnosis cites specific log lines or stack traces
- Minimal blast radius: fix ONLY what is broken (no opportunistic cleanup)
- Verify before declaring fixed: re-run test/check after every fix
- Researcher escalation: spawns researcher for unfamiliar/external-dependency errors
- Docker awareness: collects container logs and health before diagnosing
- No auto-commit: outputs suggested commit message only
- Session output: `.debug/<session-id>/reports/` (project-local)
- **CVE re-audit (DBG-013)** -- when a fix introduces or upgrades a package, invoke FEEDBACK-LOOP-001 to re-audit that package before marking the fix complete

**Mandatory Skill**: debug-diagnostics (Phase 1 — error categorization)

**Cross-Pipeline Escalation Path**:
- **From auto-orchestrate Stage 5**: When validator exhausts 3 fix iterations and errors persist, orchestrator displays escalation prompt. User confirms → session ends with `terminal_state: "escalated_to_debug"` → user manually invokes `/auto-debug`. See GAP-CMD-003 in `auto-orchestrate.md`.
- **From auto-audit**: Advisory only. When gap report contains `implementation_error` or `runtime_failure` gaps, auto-audit displays `[AUD-DEBUG-HINT]` suggesting `/auto-debug`. Does not escalate automatically.

**Decision Flow**:
```
Error input (manual or post-escalation)
    |
    v
debug-diagnostics (Phase 1: categorize error)
    |
    Is error familiar?
    +-- YES --> Fix immediately
    +-- NO  --> Spawn researcher --> Fix
        |
        v
    Verify (re-run test / check endpoint / check docker)
        |
        Pass? --YES--> Write debug report --> DONE
           |
          NO (< 3 retries) --> Loop back
           |
          NO (>= 3 retries) --> Escalate to user
```

### FEEDBACK-LOOP-001: Software-Engineer → Researcher CVE Re-Audit Protocol

**Trigger**: Any of the following events during Stage 3 or Stage 5 (debug/fix) invoke this protocol:
- Software-engineer encounters a package not covered by Stage 0 research (RES-013)
- Software-engineer finds a package with an unpatched HIGH/CRITICAL CVE (IMPL-015)
- Debugger introduces or upgrades a package as part of a fix (DBG-013)

**4-Step Protocol**:
1. **PAUSE** — the software-engineer or debugger immediately halts further code changes
2. **ESCALATE** — spawn a `researcher` sub-task scoped to the specific package(s) flagged, producing a mini Stage-0 findings file at `.orchestrate/<SESSION_ID>/stage-0/YYYY-MM-DD_<slug>-reaudit.md`
3. **EVALUATE** — if the researcher confirms a CVE-free alternative exists, update the implementation plan to use that alternative; if no alternative exists, escalate to the orchestrator as a BLOCKED task
4. **RESUME** — once the researcher confirms a safe version/alternative, the software-engineer or debugger resumes with the CVE-free package pinned to the exact version specified

**Iteration cap**: Maximum 2 FEEDBACK-LOOP-001 cycles per task. If still unresolved after 2 cycles, mark task BLOCKED and surface to human review.



### 4.8 Auditor

**Purpose**: Read-only spec compliance audit. Reads spec document, scans codebase, produces compliance report + machine-readable gap report. Never modifies code.

**Key Constraints (AUD-001 to AUD-008)**:
- Read-only operation: no Write, Edit, or state-changing commands
- Spec-first: reads spec before scanning codebase
- Evidence-based verdicts: every PASS/PARTIAL/MISSING/FAIL cites file + line
- Complete coverage: every requirement in spec gets a verdict
- Dual output: `YYYY-MM-DD_audit-report.md` + `gap-report.json` (per cycle subdirectory)
- Docker conditional: Docker auditing only when DOCKER_MODE is true

**Mandatory Skill**: spec-compliance (structured requirements extraction and compliance mapping)

**Decision Flow**:
```
spec_path input
    |
    v
Read spec document
    |
    v
spec-compliance skill (extract requirements, build compliance matrix)
    |
    v
Scan codebase (Glob/Grep per requirement)
    |
Docker mode?
    +-- YES --> service_discovery.py (read-only Docker audit)
    +-- NO  --> skip Docker
        |
        v
Write YYYY-MM-DD_audit-report.md + gap-report.json to .audit/<session-id>/cycle-<N>/
    |
    v
Return compliance score + gap list to auto-audit
```

### 4.9 Team Agents (13)

The 13 team agents each handle a specialized engineering domain. They are invoked by `/assign-agent`, `/auto-orchestrate`, and domain-specific commands. Each agent has:
- **Dispatch Triggers**: Keywords causing the orchestrator to route tasks to that agent
- **Process Ownership**: The subset of the 93 organizational processes that the agent owns

| Agent | Domain | Key Processes Owned |
|-------|--------|---------------------|
| `cloud-engineer` | Cloud infrastructure, IaaS/PaaS/SaaS | Infrastructure provisioning, cloud architecture |
| `data-engineer` | Data pipelines, ETL, warehousing | Data & ML Operations (P-049 to P-053) |
| `engineering-manager` | Team delivery, sprint management | Sprint Delivery (P-022 to P-031), Org Audit (P-062 to P-069) |
| `ml-engineer` | ML model development, MLOps | Data & ML Operations (P-049 to P-053) |
| `platform-engineer` | Developer platform, tooling | Infrastructure & Platform (P-044 to P-048) |
| `product-manager` | Requirements, roadmap, intent | Intent & Alignment (P-001 to P-006), Scope (P-007 to P-014) |
| `qa-engineer` | Quality assurance, testing strategy | Quality Assurance & Testing (P-032 to P-037) |
| `security-engineer` | Security, compliance, vulnerability | Security & Compliance (P-038 to P-043) |
| `software-engineer` | Feature development, code quality | Technical Excellence (P-085 to P-089) |
| `sre` | Site reliability, incident response | SRE & Operations (P-054 to P-057) |
| `staff-principal-engineer` | Technical vision, cross-team standards | Technical Excellence (P-085 to P-089) |
| `technical-program-manager` | Cross-team coordination, dependencies | Dependency & Coordination (P-015 to P-021) |
| `technical-writer` | Documentation, knowledge management | Documentation & Knowledge (P-058 to P-061) |

All 13 agents are registered in `manifest.json` under `agents[]` with `dispatch_triggers` and `skills_orchestrated`.

---

## 5. Processes

The `processes/` directory contains the formal process handbook used by agents and commands during orchestration.

### Directory Contents

| Type | Count | Location | Purpose |
|------|-------|----------|---------|
| Category files | 18 | `processes/00_*.md` – `processes/18_*.md` | 93 processes across 17 operational categories |
| Supporting docs | 4 | `processes/AGENT_PROCESS_MAP.md`, `QUICK_START.md`, `README.md`, `UNIFIED_END_TO_END_PROCESS.md` | Navigation, role mapping, end-to-end narrative |
| Protocol files | 3 | `processes/bridge_protocol.md`, `gate_enforcement_spec.md`, `process_injection_map.md` | Cross-command integration protocols |
| Schema files | 1 | `processes/gate_state_schema.json` | Gate state persistence schema |
| Stubs | 1 dir | `processes/process_stubs/` | 3 quick-reference companion documents |
| **Total** | **26** | | |

### Process Categories

| Category | Processes | Primary Agent |
|----------|-----------|--------------|
| 1. Intent & Strategic Alignment | P-001 to P-006 | product-manager |
| 2. Scope & Contract Management | P-007 to P-014 | product-manager |
| 3. Dependency & Coordination | P-015 to P-021 | technical-program-manager |
| 4. Sprint & Delivery Execution | P-022 to P-031 | engineering-manager |
| 5. Quality Assurance & Testing | P-032 to P-037 | qa-engineer |
| 6. Security & Compliance | P-038 to P-043 | security-engineer |
| 7. Infrastructure & Platform | P-044 to P-048 | platform-engineer |
| 8. Data & ML Operations | P-049 to P-053 | data-engineer / ml-engineer |
| 9. SRE & Operations | P-054 to P-057 | sre |
| 10. Documentation & Knowledge | P-058 to P-061 | technical-writer |
| 11. Organizational Audit | P-062 to P-069 | engineering-manager |
| 12. Post-Delivery & Retrospective | P-070 to P-073 | product-manager |
| 13. Risk & Change Management | P-074 to P-077 | technical-program-manager |
| 14. Communication & Alignment | P-078 to P-081 | engineering-manager |
| 15. Capacity & Resource Management | P-082 to P-084 | engineering-manager |
| 16. Technical Excellence & Standards | P-085 to P-089 | staff-principal-engineer |
| 17. Onboarding & Knowledge Transfer | P-090 to P-093 | engineering-manager |

### Process-Agent Relationship

Process ownership is defined in `processes/AGENT_PROCESS_MAP.md`. Each of the 13 team agents has Dispatch Triggers and Process Ownership sections defined in their `.md` files. Agents own 2-22 processes and support 0-38 additional processes.

### Install Location

Processes are installed to `~/.claude/processes/` by `install.sh`.

---

## 6. Skills Catalog

### By Category

#### Documentation (3)

| Skill | Purpose | Triggers |
|-------|---------|----------|
| `docs-lookup` | Library docs via Context7 | "how do I configure", "library docs" |
| `docs-write` | Create/edit with style guide | "write docs", "improve doc clarity" |
| `docs-review` | Style guide compliance | "review documentation", "check docs style" |

#### Testing (3)

| Skill | Purpose | Triggers |
|-------|---------|----------|
| `test-writer-pytest` | Pytest unit/integration tests | "write tests", "create pytest tests" |
| `test-gap-analyzer` | Coverage analysis, gap detection | "check test coverage", "find untested code" |
| `validator` | Compliance validation | "validate", "verify", "check compliance" |

#### Research (4)

| Skill | Purpose | Triggers |
|-------|---------|----------|
| `researcher` | Multi-source investigation | "research", "investigate", "gather information" |
| `dependency-analyzer` | Circular deps, layer validation | "check dependencies", "find circular imports" |
| `codebase-stats` | Metrics, technical debt | "codebase stats", "technical debt report" |
| `security-auditor` | Vulnerability scanning | "security audit", "find vulnerabilities" |

#### Implementation (5)

| Skill | Purpose | Triggers |
|-------|---------|----------|
| `task-executor` | Generic task execution | "execute task", "implement", "do the work" |
| `spec-creator` | RFC 2119 specifications | "write a spec", "create specification" |
| `library-implementer-python` | Python library modules | "create library", "python library" |
| `schema-migrator` | JSON schema version upgrades | "migrate schema", "upgrade schema version" |
| `dev-workflow` | Atomic commits, release automation | "commit", "release", "prepare release" |

#### Refactoring (3)

| Skill | Purpose | Triggers |
|-------|---------|----------|
| `refactor-executor` | Execute refactoring plans | "split script", "refactor large file" |
| `hierarchy-unifier` | Consolidate scattered operations | "unify hierarchy", "consolidate operations" |
| `error-standardizer` | Convert to emit_error() pattern | "standardize errors", "fix error handling" |

#### DevOps (4)

| Skill | Purpose | Triggers |
|-------|---------|----------|
| `production-code-workflow` | Production code patterns, placeholder detection | "implement", "production code" |
| `docker-workflow` | Docker containerization patterns | "Docker", "Dockerfile", "container" |
| `spec-analyzer` | Specification analysis and planning | "specification", "validate spec" |
| `cicd-workflow` | CI/CD pipeline configuration | "CI pipeline", "GitHub Actions" |

#### Utility (3)

| Skill | Purpose | Triggers |
|-------|---------|----------|
| `skill-creator` | Create new skills | "create a new skill", "extend Claude capabilities" |
| `skill-lookup` | Search prompts.chat | "find me a skill", "search for skills" |
| `python-venv-manager` | Python virtual environment management | "python venv", "virtual environment", "manage venv" |

---

## 6. Workflow Patterns

### 6.1 Skill Invocation

**Via Frontmatter Triggers**:
Skills auto-activate when user input matches trigger phrases:
```yaml
---
triggers:
  - research
  - investigate
  - gather information
---
```

**Via Skill Tool**:
```python
Skill(skill="researcher")
Skill(skill="docs-write")
```

**Via Slash Commands**:
```
/workflow-start  # Start session
/workflow-focus  # Set/show focus
/workflow-dash   # Project dashboard
```

---

### 6.2 Subagent Protocol

All subagents operating under an orchestrator MUST follow this protocol.

**Output Requirements (RFC 2119)**:

| ID | Rule |
|----|------|
| OUT-001 | MUST write findings to `{{OUTPUT_DIR}}/{{DATE}}_{{SLUG}}.md` |
| OUT-002 | MUST append ONE line to `{{MANIFEST_PATH}}` |
| OUT-003 | MUST return ONLY: "Research complete. See MANIFEST.jsonl for summary." |
| OUT-004 | MUST NOT return research content in response |

**Manifest Entry Format** (single line, no pretty-print):
```json
{"id":"topic-slug-2026-01-25","file":"2026-01-25_topic-slug.md","title":"Title","date":"2026-01-25","status":"complete","topics":["tag1","tag2"],"key_findings":["Finding 1","Finding 2"],"actionable":true,"needs_followup":[],"linked_tasks":["EPIC-1","TASK-1"]}
```

**Task Lifecycle Integration**:
```
1. Get task:     TaskGet with task ID
2. Set focus:    TaskUpdate (status: in_progress)
3. Do work:      [skill-specific execution]
4. Write output: {{OUTPUT_DIR}}/{{DATE}}_{{SLUG}}.md
5. Append manifest: {{MANIFEST_PATH}}
6. Complete:     TaskUpdate (status: completed)
7. Return:       "Research complete. See MANIFEST.jsonl for summary."
```

---

### 6.3 Skill Chaining Patterns

**Pattern 1: Single-Level Spawning**
```
┌─────────────────┐
│   ORCHESTRATOR  │
└────────┬────────┘
         │ Task tool + skill template
         v
┌─────────────────┐
│    SUBAGENT     │
│   (researcher)  │
└─────────────────┘
```

**Pattern 2: Skill Chaining (Within Agent)**
```
┌─────────────────────┐
│  technical-writer   │ <- Loaded by user request
└─────────┬───────────┘
          │
    ┌─────┴─────┬────────────┐
    v           v            v
┌───────┐  ┌────────┐  ┌─────────┐
│lookup │  │ write  │  │ review  │
│(Phase │  │(Phase  │  │(Phase   │
│  1)   │  │   2)   │  │   3)    │
└───────┘  └────────┘  └─────────┘
```

**Pattern 3: Multi-Level Orchestration** (max 3 levels)
```
┌─────────────────────┐
│    ORCHESTRATOR     │  Level 0: Main workflow
└─────────┬───────────┘
          │ Task tool
          v
┌─────────────────────┐
│ SUB-ORCHESTRATOR    │  Level 1: Epic decomposition
│ (product-manager)   │
└─────────┬───────────┘
          │ Task tool
          v
┌─────────────────────┐
│    WORKER AGENT     │  Level 2: Task execution
│  (task-executor)    │
└─────────────────────┘
```

**Guidelines**:
- Depth limit: SHOULD NOT exceed 3 levels
- Context budget: Each level MUST stay under 10K tokens
- Response contract: Each level returns only summary message

---

### 6.4 Orchestrator Decision Flow

```
START
  │
  v
┌───────────────────┐    ┌─────────────────────────┐
│ Check session     │--->│ Active? Resume focus    │
└─────────┬─────────┘    └─────────────────────────┘
          │ no
          v
┌───────────────────┐    ┌─────────────────────────┐
│ Check manifest    │--->│ needs_followup? Create  │
│ for pending work  │    │ continuation session    │
└─────────┬─────────┘    └─────────────────────────┘
          │ no
          v
┌───────────────────┐
│ Route to skill    │
│ based on task type│
└─────────┬─────────┘
          │
          v
┌───────────────────┐
│ Read key_findings │
│ from manifest     │
└─────────┬─────────┘
          │
          v
┌───────────────────┐
│ Next task or      │
│ request direction │
└───────────────────┘
```

---

### 6.5 Epic Architect Program Planning

```
┌────────────────────────────────────────────────────────────┐
│                    Program PLANNING                           │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  Program 0: Foundation (no dependencies)                      │
│  ┌─────────┐  ┌─────────┐                                  │
│  │ Task A  │  │ Task B  │  <- Can start immediately        │
│  └────┬────┘  └────┬────┘                                  │
│       │            │                                       │
│  Program 1: Depends on Program 0                                 │
│       │            │                                       │
│       v            v                                       │
│  ┌─────────┐  ┌─────────┐                                  │
│  │ Task C  │  │ Task D  │  <- Parallel opportunity         │
│  └────┬────┘  └────┬────┘                                  │
│       │            │                                       │
│  Program 2: Depends on Program 0 or 1                            │
│       └─────┬──────┘                                       │
│             v                                              │
│        ┌─────────┐                                         │
│        │ Task E  │  <- Convergence point                   │
│        └─────────┘                                         │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

**Dependency Types**:
| Type | Example | Result |
|------|---------|--------|
| Data | Task B reads Task A's output | Sequential |
| Structural | Task B modifies Task A's code | Sequential |
| Knowledge | Task B needs info from Task A | Sequential or manifest handoff |
| None | Tasks touch different systems | Parallel (same Program) |

---

## 7. Slash Commands Reference

| Command | Purpose | Key Actions |
|---------|---------|-------------|
| `/workflow-start` | Start work session | TaskList -> Display overview -> Set focus |
| `/workflow-end` | End work session | Summarize progress -> Clear focus |
| `/workflow-dash` | Project dashboard | TaskList -> Group by status -> Show blockers |
| `/workflow-focus` | Show/set task focus | TaskGet -> TaskUpdate (in_progress) |
| `/workflow-next` | Get next task suggestion | TaskList -> Find unblocked -> Suggest |
| `/workflow-plan` | Plan mode manager | Optimize prompts -> Track tasks |
| `/refactor-analyzer` | Refactoring assistance | Analyze code -> Suggest improvements |
| `/auto-orchestrate` | Autonomous loop | Enhance prompt -> Loop orchestrator -> Complete all tasks |

---

### 7.1 /workflow-start - Start Work Session

**Purpose**: Initialize a work session by displaying task overview and establishing focus.

```
TaskList -> Display Overview -> Check in_progress
    │                              │
    v                          yes/  \no
Show task counts          ┌────────┐  ┌──────────────┐
by status                 │ Resume │  │ Suggest from │
                          │ focus  │  │ pending      │
                          └────────┘  └──────────────┘
```

**Execution Flow**:
1. Retrieve all tasks via `TaskList`
2. Display summary counts (pending, in_progress, completed, blocked)
3. Check for existing `in_progress` task
4. If found: offer to resume current focus
5. If not: suggest highest-priority unblocked pending task

**Tools Used**: `TaskList`, `TaskCreate`, `TaskUpdate`, `TaskGet`

**Success Criteria**:
- Session overview displayed with accurate counts
- User has clear understanding of project state
- Focus established or ready to be set

**Leads to**: `/workflow-focus`, `/workflow-next`, `/workflow-dash`, `/workflow-end`

---

### 7.2 /workflow-end - End Work Session

**Purpose**: Gracefully conclude a work session with progress summary and task state management.

```
TaskList -> Check in_progress -> Offer completion options
              │                        │
              v                        v
         Display summary        Mark complete or leave
```

**Execution Flow**:
1. Retrieve all tasks via `TaskList`
2. Check for tasks with `in_progress` status
3. For each in_progress task, offer options:
   - Mark as completed (if work finished)
   - Leave as in_progress (if pausing work)
   - Mark as blocked (if waiting on dependencies)
4. Display session summary (tasks completed, time context)

**Tools Used**: `TaskList`, `TaskUpdate`

**Success Criteria**:
- All task states accurately reflect actual progress
- No orphaned in_progress tasks (unless intentional pause)
- Session summary provided

**Pairs with**: `/workflow-start`

---

### 7.3 /workflow-dash - Project Dashboard

**Purpose**: Display comprehensive project status organized by task state.

```
TaskList -> Group by status -> Display dashboard
              │
    ┌─────────┼─────────┬──────────┐
    v         v         v          v
In Progress  Blocked  Pending  Completed
```

**Execution Flow**:
1. Retrieve all tasks via `TaskList`
2. Group tasks by status:
   - **In Progress**: Currently active work
   - **Blocked**: Waiting on dependencies (show blockers)
   - **Pending**: Available to work on
   - **Completed**: Finished tasks
3. Display counts and details for each group
4. Highlight any blockers or dependency chains

**Tools Used**: `TaskList`

**Success Criteria**:
- All tasks visible and correctly categorized
- Blockers clearly identified
- Actionable items apparent

**Provides context for**: All other commands

---

### 7.4 /workflow-focus - Focus Management

**Purpose**: Set or display the current task focus, enforcing the One Active Task Rule.

```
                ┌─────────────────┐
                │ Argument given? │
                └────────┬────────┘
                    yes/   \no
                      v      v
            ┌──────────┐  ┌───────────────┐
            │ TaskGet  │  │ TaskList      │
            │ by ID    │  │ find in_progress│
            └────┬─────┘  └───────┬───────┘
                 │                │
                 v                v
            TaskUpdate      Show current
            in_progress     focus details
```

**Execution Flow**:
1. Check if task ID argument provided
2. **With argument**:
   - Validate task exists via `TaskGet`
   - Check if another task is in_progress
   - If so: prompt to switch focus (update old task status)
   - Set new task to in_progress via `TaskUpdate`
3. **Without argument**:
   - Find current in_progress task via `TaskList`
   - Display focus details (subject, description, dependencies)

**Tools Used**: `TaskList`, `TaskGet`, `TaskUpdate`

**Success Criteria**:
- Only one task in_progress at any time (One Active Task Rule)
- Focus clearly displayed with full context
- Task state accurately updated

**Enforces**: One Active Task Rule

---

### 7.5 /workflow-next - Next Task Suggestion

**Purpose**: Intelligently suggest the next task to work on based on dependencies and impact.

```
TaskList -> Filter unblocked -> Rank by impact -> Suggest
                                    │
                              ┌─────┴─────┐
                              v           v
                        Show reason   --auto-focus
                                      TaskUpdate
```

**Execution Flow**:
1. Retrieve all tasks via `TaskList`
2. Filter to pending tasks with no blockers
3. Rank by:
   - Number of tasks it unblocks (high priority)
   - Program position (earlier Programs first)
   - Explicit priority markers
4. Suggest top candidate with reasoning
5. If `--auto-focus` flag: automatically set focus via `TaskUpdate`

**Tools Used**: `TaskList`, `TaskGet`, `TaskUpdate`

**Success Criteria**:
- Suggested task is actually unblocked
- Reasoning is clear and actionable
- Optional auto-focus works correctly

**Works with**: `/workflow-focus`

---

### 7.6 /refactor-analyzer - Refactoring Assistant

**Purpose**: Analyze code and suggest or execute refactoring improvements.

```
Analyze target -> Identify groups -> Check deps -> Plan extraction -> Execute
      │
      v
  Read file(s)
```

**Execution Flow**:
1. Read target file(s) via `Read`
2. Analyze code structure:
   - Identify function groups
   - Detect code smells (long functions, duplication)
   - Map internal dependencies
3. Check external dependencies via `Grep`
4. Plan refactoring:
   - Suggest extractions
   - Identify safe boundaries
5. Execute refactoring (if approved)

**Tools Used**: `Read`, `Glob`, `Grep`

**Success Criteria**:
- Analysis is accurate and comprehensive
- Suggestions are safe (no breaking changes)
- Dependencies are respected

**May invoke**: `refactor-executor` skill for large files

---

### 7.7 /workflow-plan - Plan Mode Manager

**Purpose**: Manage planning workflows by optimizing prompts and creating tasks from analysis.

```
Analyze input -> Check existing plans -> Check tasks -> Generate prompt
                       │                    │              │
                       v                    v              v
                  Continue?           TaskList        TaskCreate
                  or new?
```

**Execution Flow**:
1. Analyze input requirements
2. Check for existing plans in progress
3. If continuing: load existing context
4. If new: analyze scope and complexity
5. Query current task state via `TaskList`
6. Generate optimized prompt or create tasks via `TaskCreate`
7. Track planning state for resumption

**Tools Used**: `Bash`, `Read`, `Glob`, `Grep`, `TaskCreate`, `TaskList`, `TaskUpdate`

**Success Criteria**:
- Planning context preserved across sessions
- Tasks created match analysis
- Prompt optimization improves efficiency

**Creates**: Tasks for `/workflow-start`, `/workflow-focus`, `/workflow-next` workflows

---

### 7.8 /auto-orchestrate - Autonomous Orchestration Loop

**Purpose**: Autonomously enhance user input, spawn orchestrator repeatedly, and loop until all tasks complete with crash recovery. Supports scope flags for backend/frontend/fullstack quality specifications.

**Arguments**:

| Argument | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `task_description` | string | yes | — | The task or objective to orchestrate. Pass `"c"` to resume most recent session. |
| `session_id` | string | no | — | Resume a specific session by ID |
| `max_iterations` | integer | no | 100 | Maximum number of orchestrator spawns |
| `stall_threshold` | integer | no | 2 | Consecutive no-progress iterations before failing |
| `max_tasks` | integer | no | 50 | Maximum total tasks allowed (LIMIT-001). Cap 100. |
| `scope` | string | no | — | Scope flag: `F`/`f` (frontend), `B`/`b` (backend), `S`/`s` (fullstack) |
| `resume` | boolean | no | false | Resume an existing session |

**Scope Flags**: Scope can be specified as the `scope` argument or as an inline single-character prefix in `task_description`:
- `S implement all features` → scope=`fullstack`, task=`implement all features`
- `B` → scope=`backend`, task=*(default backend objective)*
- `fix the dashboard` → scope=`custom` (multi-char tokens are never flags)

| Flag | Resolved | Layers |
|------|----------|--------|
| `F`/`f` | `frontend` | `["frontend"]` |
| `B`/`b` | `backend` | `["backend"]` |
| `S`/`s` | `fullstack` | `["backend", "frontend"]` |
| *(omitted)* | `custom` | `[]` |

When scope is not `custom`, the full scope specification (Appendix A/B of auto-orchestrate.md) is injected verbatim into every orchestrator spawn and subagent prompt (SCOPE-001). The scope spec defines **Implementation Quality Criteria** — quality requirements for Stage 3 software-engineers and Stage 5 validators. These are explicitly labeled as NOT a pipeline sequence to prevent confusion with the pipeline stages (0→1→2→3→4.5→5→6).

**Execution Flow**:
```
/auto-orchestrate [scope-flag] <description>
         │
         v
┌──────────────────────┐
│ Step 0: Permission   │──> Scope resolution (F/B/S/custom)
│ + manifest validate  │    Pre-flight: 9 components (MANIFEST-001)
│ + domain memory init │    mkdir -p .domain/
│ + greenfield detect  │    Step 0g: project type classification
│ + gate state check   │    Step 2d: read .gate-state.json
└────────┬─────────────┘
         │
         v
┌──────────────────────┐
│ Step 1: Enhance      │──> Inline prompt structuring
│ prompt (structured)  │
└────────┬─────────────┘
         │
         v
┌──────────────────────┐
│ Step 2: Initialize   │──> Supersede old sessions
│ session + checkpoint │    Create .orchestrate/<session-id>/
│ + STAGE_CEILING calc │    Atomic checkpoint write
└────────┬─────────────┘
         │
         v
┌──────────────────────┐
│ Step 3: Spawn        │<─────────────────────────────┐
│ orchestrator         │   (iteration N)              │
│ (task board display) │                              │
│ CI: probe + inject   │   improvement_targets.json   │
│ improvement targets  │   into Stage 0 researcher    │
└────────┬─────────────┘                              │
         │                                            │
         v                                            │
┌──────────────────────┐                              │
│ Step 4: Process      │   Task proposals:            │
│ proposals + validate │   CHAIN-001 (blockedBy)      │
│ + checkpoint         │   DISPATCH-001 (hint check)  │
└────────┬─────────────┘                              │
         │                                            │
         v                                            │
┌──────────────────────┐    not done                  │
│ Step 5: Evaluate     │─────────────────────────────>│
│ termination          │   (checkpoint + continue)    │
└────────┬─────────────┘                              │
         │ done                                       │
         v                                            │
┌──────────────────────┐                              │
│ CI: Check + Act      │   RetrospectiveAnalyzer      │
│ (post-run PDCA)      │   ImprovementRecommender ────┘
│                      │   BaselineManager
│ Termination report   │
└──────────────────────┘

Terminal states: completed | max_iterations_reached | stalled | all_blocked | user_stopped
```

**Storage**: `.orchestrate/<session-id>/checkpoint.json` (atomic write). Each stage directory gets `stage-receipt.json` on completion. Session-level `MANIFEST.jsonl` tracks all outputs.

**Core Constraints (AUTO-001 to AUTO-007, CEILING-001, CHAIN-001, PROGRESS-001, DISPLAY-001, SCOPE-001, SCOPE-002)**:

| ID | Rule |
|----|------|
| AUTO-001 | Orchestrator-only gateway — never spawn non-orchestrator agents directly |
| AUTO-002 | Mandatory stage completion — stages 0, 1, 2, 4.5, 5, 6 required |
| AUTO-003 | Stage monotonicity — pipeline stages only increase |
| AUTO-004 | Post-implementation stage gate — enforce 4.5/5/6 after 1 overdue iteration |
| AUTO-005 | Checkpoint-before-spawn — write checkpoint before every orchestrator spawn |
| AUTO-006 | No direct agent routing — routing is orchestrator's decision |
| AUTO-007 | Iteration history immutability — append-only |
| CEILING-001 | Stage ceiling enforcement — STAGE_CEILING limits orchestrator to next incomplete stage |
| CHAIN-001 | Mandatory blockedBy chains — Stage N tasks must reference Stage N-1 tasks |
| PROGRESS-001 | Always-visible processing — status lines before/after every tool call |
| DISPLAY-001 | Task board at every iteration — full task detail, not just stage counts |
| SCOPE-001 | Scope spec passthrough — full verbatim spec through every layer when scope != custom |
| SCOPE-002 | Scope template integrity — narrow objectives don't reduce the quality bar |

**Tools Used**: `TaskCreate`, `TaskList`, `TaskUpdate`, `TaskGet`, `Task` (orchestrator delegation)

**Success Criteria**:
- All tasks reach `completed` status
- `stages_completed` includes mandatory stages 0, 1, 2, 4.5, 5, 6
- No stall detected (progress made each iteration)
- Session checkpoint written after each iteration

**Termination Conditions** (evaluated in order):

| # | Condition | Status |
|---|-----------|--------|
| 1 | All tasks completed AND all mandatory stages done | `completed` |
| 1a | All tasks completed BUT mandatory stages missing | Inject missing tasks, retry once |
| 2 | `iteration >= MAX_ITERATIONS` | `max_iterations_reached` |
| 3 | No progress for `STALL_THRESHOLD` consecutive iterations | `stalled` |
| 4 | All remaining tasks blocked | `all_blocked` |

**Pairs with**: `orchestrator` agent, all downstream skills

## 8. Token System

### Required Tokens

| Token | Description | Example |
|-------|-------------|---------|
| `{{TASK_ID}}` | Current task identifier | `1` |
| `{{DATE}}` | Current date | `2026-01-25` |
| `{{SLUG}}` | URL-safe topic name | `authentication-research` |

### Optional Tokens (with defaults)

| Token | Default | Description |
|-------|---------|-------------|
| `{{EPIC_ID}}` | `""` | Parent epic ID |
| `{{SESSION_ID}}` | `""` | Session identifier |
| `{{OUTPUT_DIR}}` | `claudedocs/research-outputs` | Output directory |
| `{{MANIFEST_PATH}}` | `{{OUTPUT_DIR}}/MANIFEST.jsonl` | Manifest location |

### Task Tool Mapping

| Token (Legacy) | Claude Code Native |
|----------------|-------------------|
| `{{TASK_SHOW}}` | `TaskGet` |
| `{{TASK_FOCUS}}` | `TaskUpdate` (status: in_progress) |
| `{{TASK_COMPLETE}}` | `TaskUpdate` (status: completed) |
| `{{TASK_LIST}}` | `TaskList` |
| `{{TASK_ADD}}` | `TaskCreate` |

---

## 9. Cross-Reference Matrix

### Agents -> Protocols/Templates

| Agent | References |
|-------|------------|
| `orchestrator` | subagent-protocol-base, skill-chaining-patterns, task-system-integration, SUBAGENT-PROTOCOL-BLOCK |
| `technical-writer` | style-guide, task-system-integration |
| `product-manager` | task-system-integration, subagent-protocol-base, skill-boilerplate, patterns, examples, output-format |
| `software-engineer` | production-code-workflow, task-system-integration |
| `session-manager` | task-system-integration |

### Skills -> Templates

All 35 skills reference `skill-boilerplate.md` sections:
- `#task-integration` (20 skills)
- `#subagent-protocol` (20 skills)
- `#manifest-entry` (20 skills)
- `#completion-checklist` (20 skills)
- `#error-handling` (select skills)

### Skills -> Anti-Patterns

| Anti-Pattern Section | Skills Referencing |
|---------------------|-------------------|
| `#output-anti-patterns` | All skills |
| `#research-anti-patterns` | researcher, dependency-analyzer |
| `#implementation-anti-patterns` | task-executor, library-implementer-python |
| `#testing-anti-patterns` | test-writer-pytest, test-gap-analyzer |
| `#validation-anti-patterns` | validator |
| `#security-anti-patterns` | security-auditor |

### Protocol Internal References

| Protocol | References |
|----------|------------|
| `subagent-protocol-base` | task-system-integration |
| `skill-chaining-patterns` | subagent-protocol-base, task-system-integration, skill-boilerplate, anti-patterns |
| `skill-chain-contracts` | subagent-protocol-base, skill-chaining-patterns |
| `task-system-integration` | (none - leaf node) |

---

## 10. Component Relationship Map

### 10.1 Command Workflow Relationships

This diagram shows how slash commands relate to each other in typical session workflows:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    THREE AUTONOMOUS COMMANDS                            │
│                                                                         │
│  /auto-orchestrate          /auto-debug           /auto-audit           │
│  ┌─────────────────┐       ┌──────────────┐       ┌──────────────┐     │
│  │ Research→Arch→  │       │ Triage→Fix→  │       │ Audit→Remed→ │     │
│  │ Spec→Impl→Test→│       │ Verify loop  │       │ Re-audit loop│     │
│  │ Validate→Docs  │       │ (.debug/)    │       │ (.audit/)    │     │
│  │ (.orchestrate/)│       └──────────────┘       └──────────────┘     │
│  └─────────────────┘                                                    │
│         │                         │                       │             │
│         └─────────────────────────┼───────────────────────┘             │
│                                   v                                     │
│                         ┌─────────────────┐                             │
│                         │  .domain/       │  Cross-session knowledge    │
│                         │  (shared by all │  (research, fixes, patterns,│
│                         │   3 commands)   │   decisions, analysis,      │
│                         └─────────────────┘   preferences)              │
│                                                                         │
│                    INTERACTIVE WORKFLOW COMMANDS                         │
│  /workflow-plan → /workflow-start ←→ /workflow-end                     │
│                       │                    ^                             │
│                       v                    │                             │
│               /workflow-focus ← /workflow-next                          │
│                       │                                                 │
│                       v                                                 │
│                    [WORK] ─────────────────┘                            │
│                                                                         │
│  /workflow-dash (context for all)  │  /refactor-analyzer (independent) │
└─────────────────────────────────────────────────────────────────────────┘
```

**Command Categories**:
| Category | Commands | Session Dir | Gateway Agent |
|----------|----------|-------------|---------------|
| Autonomous | `/auto-orchestrate` | `.orchestrate/` | orchestrator only |
| Autonomous | `/auto-debug` | `.debug/` | debugger only |
| Autonomous | `/auto-audit` | `.audit/` | auditor + orchestrator |
| Interactive | `/workflow-*` (6 commands) | — | session-manager |
| Utility | `/refactor-analyzer` | — | — |
| Shared | `.domain/` | — | All commands read/write |

---

### 10.2 Agent-Skill Delegation Map

This diagram shows which skills each agent can delegate to:

```
┌─────────────────────────────────────────────────────────────────┐
│                     ORCHESTRATOR                                │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Routes to:                                               │   │
│  │   researcher ----------> Research tasks                  │   │
│  │   task-executor -------> Implementation                  │   │
│  │   product-manager -----> Planning (spawns as sub-orch)   │   │
│  │   technical-writer ----> Documentation (chains skills)   │   │
│  │   spec-creator --------> Specifications                  │   │
│  │   library-implementer-python -> Python libraries         │   │
│  │   test-writer-pytest --> Tests                           │   │
│  │   validator -----------> Compliance                      │   │
│  │   codebase-stats ------> Stage 4.5 metrics               │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      DEBUGGER                                    │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Mandatory skills:                                        │   │
│  │   debug-diagnostics -----> Error classification (Ph1)    │   │
│  │ Domain memory integration:                               │   │
│  │   fix_registry query ----> Check known fixes before diag │   │
│  │   fix_registry write ----> Persist fix after verification│   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      AUDITOR                                     │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Mandatory skills:                                        │   │
│  │   spec-compliance -------> Requirement extraction +      │   │
│  │                            compliance matrix (read-only) │   │
│  │ Outputs (per cycle):                                     │   │
│  │   YYYY-MM-DD_audit-report.md + gap-report.json          │   │
│  │   → .audit/<session>/cycle-<N>/                          │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                   TECHNICAL-WRITER                              │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Chains (sequential):                                     │   │
│  │   docs-lookup --> docs-write --> docs-review             │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    PRODUCT-MANAGER                              │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Mandatory skills:                                        │   │
│  │   spec-analyzer ---------> Requirements validation (Ph1) │   │
│  │   dependency-analyzer ---> Dep graph validation (Ph3)    │   │
│  │ Creates tasks for:                                       │   │
│  │   Any skill via Program-planned task decomposition       │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                   SOFTWARE-ENGINEER                              │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Mandatory skills:                                        │   │
│  │   production-code-workflow -> ALL scopes (mandatory)     │   │
│  │   security-auditor -------> MEDIUM + LARGE scopes        │   │
│  │   codebase-stats ---------> LARGE scope                  │   │
│  │   refactor-analyzer ------> LARGE scope                  │   │
│  │   refactor-executor ------> LARGE scope (if findings)    │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      RESEARCHER                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Mandatory skills:                                        │   │
│  │   researcher (skill) ----> Research protocol (Phase 1)   │   │
│  │   docs-lookup -----------> Library/framework docs (Ph2)  │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                   SESSION-MANAGER                                │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Coordinates (state machine):                             │   │
│  │   workflow-start ----> Session initialization            │   │
│  │   workflow-dash -----> Dashboard display                 │   │
│  │   workflow-focus ----> Task focus management             │   │
│  │   workflow-next -----> Next task suggestions             │   │
│  │   workflow-end ------> Session wrap-up                   │   │
│  │   workflow-plan -----> Planning mode                     │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

**Delegation Rules**:
| Agent | Delegation Style | Depth Limit | Spawned By |
|-------|-----------------|-------------|------------|
| Orchestrator | Routes to all stage agents | Level 1 | auto-orchestrate, auto-audit |
| Product-Manager | Creates tasks, spawns workers | Level 2 (sub-orch) | orchestrator |
| Software-Engineer | Executes directly (no delegation) | Level 0 | orchestrator |
| Researcher | Research + docs-lookup | Level 1 | orchestrator |
| Technical-Writer | Chains skills sequentially | Level 1 | orchestrator |
| Debugger | Diagnose + fix + verify loop | Level 0 | auto-debug |
| Auditor | Read-only compliance analysis | Level 0 | auto-audit |
| Session-Manager | Coordinates via state machine | Level 1 | orchestrator |

---

### 10.3 Typical Workflow Sequences

These sequences show how components work together for common scenarios:

**Planning Workflow**:
```
User request -> /workflow-plan -> TaskCreate -> /workflow-start -> /workflow-focus -> work -> /workflow-end
```
1. User describes requirements
2. `/workflow-plan` analyzes and creates task hierarchy
3. `/workflow-start` initializes session with task overview
4. `/workflow-focus` activates first task
5. Implementation work occurs
6. `/workflow-end` concludes session

**Investigation Workflow**:
```
/workflow-start -> /workflow-dash -> /workflow-next -> /workflow-focus -> orchestrator -> researcher -> /workflow-end
```
1. `/workflow-start` initializes session
2. `/workflow-dash` shows project state for orientation
3. `/workflow-next` suggests investigation task
4. `/workflow-focus` activates the task
5. Orchestrator delegates to researcher skill
6. Research findings written to manifest
7. `/workflow-end` concludes with summary

**Documentation Workflow**:
```
/workflow-start -> /workflow-focus -> technical-writer -> docs-lookup -> docs-write -> docs-review -> /workflow-end
```
1. `/workflow-start` initializes session
2. `/workflow-focus` activates documentation task
3. Technical-writer agent takes over
4. `docs-lookup` finds existing docs (prevent duplication)
5. `docs-write` creates/updates content
6. `docs-review` validates style compliance
7. `/workflow-end` concludes session

**Feature Development (Epic)**:
```
/workflow-plan -> product-manager -> [Program 0 tasks] -> [Program 1 tasks] -> ... -> /workflow-end
```
1. `/workflow-plan` invokes product-manager for large feature
2. Product-manager decomposes into tasks with dependencies
3. Program 0 tasks execute (no dependencies)
4. Program 1 tasks execute (depend on Program 0)
5. Continue through all Programs
6. `/workflow-end` concludes epic

---

### 10.4 Task Tool Integration Points

All components integrate via the Task tools:

```
┌─────────────────────────────────────────────────────────────────┐
│                      TASK TOOLS                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  TaskCreate <--- auto-orchestrate loop ONLY                     │
│       │         (product-manager proposes via files)             │
│       v                                                         │
│  TaskList <---- auto-orchestrate loop ONLY                      │
│       │         (passes state to orchestrator in spawn prompt)   │
│       v                                                         │
│  TaskGet <----- auto-orchestrate loop ONLY                      │
│       │                                                         │
│       v                                                         │
│  TaskUpdate <-- auto-orchestrate loop ONLY                      │
│                 (orchestrator proposes via PROPOSED_ACTIONS)     │
│                                                                 │
│  NOTE: Subagents do NOT have access to these tools.             │
│  See commands/TOOL-AVAILABILITY.md (GAP-CRIT-001)                           │
└─────────────────────────────────────────────────────────────────┘
```

**Tool Ownership by Component**:
| Tool | Available To | How Subagents Interact |
|------|-------------|----------------------|
| `TaskCreate` | auto-orchestrate loop only | Subagents write proposals to `.orchestrate/<session-id>/proposed-tasks.json` |
| `TaskList` | auto-orchestrate loop only | Auto-orchestrate passes state in orchestrator spawn prompt |
| `TaskGet` | auto-orchestrate loop only | Task context included in subagent spawn prompts |
| `TaskUpdate` | auto-orchestrate loop only | Orchestrator returns `PROPOSED_ACTIONS` JSON block |

---

### 10.5 Skill Chaining Graph

Skills form producer-consumer networks where output from one skill feeds into the next. The `codebase-stats` skill acts as a hub producer.

**Data Flow**:
```
User → Command/Agent → Task tool → Skill → Output file + Manifest JSONL
                                      ↓
                              Orchestrator reads key_findings from manifest
                                      ↓
                              chains_to → next skill (via manifest metadata)
```

**Producer-Consumer Networks** (codebase-stats as hub):
```
codebase-stats ──┬──> refactor-analyzer ──> refactor-executor ──> validator
                 ├──> test-gap-analyzer ──> test-writer-pytest ──> validator
                 ├──> security-auditor ──> error-standardizer ──> validator
                 └──> dependency-analyzer ──> hierarchy-unifier ──> validator

researcher ──> spec-creator ──> spec-analyzer ──> task-executor ──> validator
```

**Analyzer-Executor Pairs**:

| Analyzer | Executor | Domain |
|----------|----------|--------|
| `refactor-analyzer` | `refactor-executor` | Code restructuring |
| `test-gap-analyzer` | `test-writer-pytest` | Test coverage |
| `spec-analyzer` | `task-executor` | Specification implementation |
| `dependency-analyzer` | `hierarchy-unifier` | Architecture cleanup |

**Sequential Pipeline**:
```
researcher → spec-creator → spec-analyzer → task-executor → validator
```

**Quality Gate** (validator as terminal sink):

The `validator` skill serves as the terminal quality gate. Six upstream skills chain into it:
- `refactor-executor`
- `test-writer-pytest`
- `error-standardizer`
- `hierarchy-unifier`
- `task-executor`
- `docs-review` (for documentation pipelines)

**Chaining Cross-Reference Matrix**:

| Producer Skill | Produces | Consumers |
|----------------|----------|-----------|
| `codebase-stats` | metrics, hotspots, debt-inventory | refactor-analyzer, test-gap-analyzer, security-auditor, dependency-analyzer |
| `researcher` | findings, recommendations | spec-creator, technical-writer |
| `refactor-analyzer` | extraction-plan, function-groups | refactor-executor |
| `test-gap-analyzer` | coverage-gaps, test-stubs | test-writer-pytest |
| `security-auditor` | vulnerabilities, remediation-plan | error-standardizer |
| `dependency-analyzer` | dependency-graph, violations | hierarchy-unifier |
| `spec-creator` | specification, requirements | spec-analyzer |
| `spec-analyzer` | phase-plan, execution-order | task-executor |

---

### 10.6 Meta Files Architecture

The `_shared/` directory contains cross-cutting resources that skills and agents reference via `@` paths.

**Protocols** (4 files):

| File | Purpose | Primary Consumers |
|------|---------|-------------------|
| `subagent-protocol-base.md` | RFC 2119 output contract (OUT-001–004) | All skills operating under orchestrators |
| `task-system-integration.md` | Task tool usage patterns | All skills, all agents |
| `skill-chaining-patterns.md` | Multi-level invocation patterns (CHAIN-001–011) | Orchestrator, chained skills |
| `skill-chain-contracts.md` | Producer-consumer contracts | Skills with `chaining` metadata |

**Templates** (2 files):

| File | Purpose | Reference Count |
|------|---------|-----------------|
| `skill-boilerplate.md` | 7-step execution sequence, manifest entry format | 68 references across 35 skills |
| `anti-patterns.md` | Common mistakes to avoid by category | 6 references |

**References** (2 agent-specific directories):

| Directory | Purpose | Consumer |
|-----------|---------|----------|
| `references/product-manager/` | Patterns, examples, output-format | `product-manager` agent |
| `references/orchestrator/` | Subagent protocol block | `orchestrator` agent |

**How @-references resolve**: Skills and agents reference shared files using `@_shared/` paths (e.g., `@_shared/protocols/subagent-protocol-base.md#output-requirements`). These resolve to the `_shared/` directory within the skills installation path.

---

## 11. Installation

> For step-by-step installation with verification, see [INTEGRATION.md](INTEGRATION.md).

```bash
# Install skills (auto-discovered by Claude Code)
cp -r claude-code/skills/* ~/.claude/skills/

# Install agents (flat .md files)
cp -r claude-code/agents/* ~/.claude/agents/

# Install commands
cp -r claude-code/commands ~/.claude/commands/
```

After copying:
- Skills trigger automatically based on their `triggers:` array in frontmatter
- Agents are available via the Task tool
- Commands are available as slash commands (e.g., `/workflow-start`, `/workflow-end`, `/workflow-dash`)

---

## 12. Validation Checklist

Verify plugin structure integrity:

```bash
# Check for broken references
grep -r "@_shared/" claude-code/

# Validate manifest JSON
jq '.' claude-code/manifest.json > /dev/null && echo "Valid JSON"

# Count entries
jq '._meta.totalAgents, ._meta.totalSkills, ._meta.totalCommands' claude-code/manifest.json
```

**Component Verification**:
- [ ] All 18 agents documented (2 pipeline-core: orchestrator, researcher + 3 pipeline: debugger, auditor, session-manager + 13 team agents)
- [ ] All 35 skills cataloged
- [ ] All 19 commands referenced (auto-orchestrate, auto-debug, auto-audit + 16 workflow/org commands)
- [ ] All 6 protocols described
- [ ] All 2 templates explained
- [ ] Cross-reference counts accurate

---

## 13. Script Reference

This section documents all scripts referenced by components and their expected locations.

### 13.1 Directory Structure (Expected)

The Python library lives under `skills/_shared/python/` with a layered architecture:

```
claude-code/
└── skills/
    └── _shared/
        └── python/
            ├── layer0/
            │   ├── __init__.py
            │   ├── exit_codes.py         # Exit code constants
            │   ├── colors.py             # Color output utilities
            │   └── constants.py          # Application constants
            ├── layer1/
            │   ├── __init__.py
            │   ├── config.py             # Configuration management
            │   ├── error_json.py         # Standardized error JSON output
            │   ├── file_ops.py           # Atomic file operations
            │   ├── heartbeat.py          # Heartbeat monitoring
            │   ├── logging.py            # Audit trail logging
            │   ├── memory.py             # Memory management utilities
            │   └── output_format.py      # JSON/human output formatting
            ├── layer2/
            │   ├── __init__.py
            │   ├── hooks.py              # Lifecycle hook management
            │   ├── messaging.py          # Inter-component messaging
            │   ├── task_ops.py           # Task operations
            │   ├── token_budget.py       # Token budget tracking
            │   ├── validation.py         # Input validation functions
            │   └── webhooks.py           # Webhook dispatch and management
            └── layer3/
                ├── __init__.py
                ├── migrate.py            # Schema migration
                ├── backup.py             # Backup operations
                ├── doctor.py             # Diagnostic utilities
                └── hierarchy_unified.py  # Unified task hierarchy
```

---

### 13.2 Component-to-Script Mapping

#### Development/Build Scripts

| Script | Referenced In | Purpose |
|--------|---------------|---------|
| `./dev/bump-version.sh` | dev-workflow/SKILL.md | Version bumping (patch/minor/major) |
| `./dev/validate-version.sh` | dev-workflow/SKILL.md | Post-release version validation |
| `./dev/run_all_tests.py` | test.md, dev-workflow/SKILL.md, test-writer-pytest/SKILL.md | Pytest test runner |

> **Note**: The `dev/`, `scripts/`, and `tests/` directories referenced above are expected to exist in the consuming project, not within `claude-code/` itself. The Python library resides at `skills/_shared/python/`.

---

### 13.3 Library Dependency Layers

The `skills/_shared/python/` directory follows a strict layered architecture where each layer can only import from layers below it.

```
┌─────────────────────────────────────────────────────────────────┐
│                  LAYER 3 - ORCHESTRATION                        │
│                                                                 │
│   migrate.py │ backup.py │ doctor.py │ hierarchy_unified.py    │
│                                                                 │
│   May import: Layer 0, 1, 2                                     │
├─────────────────────────────────────────────────────────────────┤
│                  LAYER 2 - BUSINESS LOGIC                       │
│                                                                 │
│   hooks.py │ messaging.py │ task_ops.py │ token_budget.py       │
│   validation.py │ webhooks.py                                   │
│                                                                 │
│   May import: Layer 0, 1                                        │
├─────────────────────────────────────────────────────────────────┤
│                  LAYER 1 - BASIC HELPERS                        │
│                                                                 │
│   config.py │ error_json.py │ file_ops.py │ heartbeat.py       │
│   logging.py │ memory.py │ output_format.py                    │
│                                                                 │
│   May import: Layer 0 only                                      │
├─────────────────────────────────────────────────────────────────┤
│                  LAYER 0 - FOUNDATION                           │
│                                                                 │
│   exit_codes.py │ colors.py │ constants.py                      │
│                                                                 │
│   No dependencies (leaf nodes)                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Import Pattern**:
```python
# Skill script example
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "_shared" / "python"))
from layer0.exit_codes import EXIT_SUCCESS, EXIT_ERROR
from layer0.colors import colorize
# Layer 1 modules MUST NOT import from Layer 2 or 3
```

**Layer Rules**:
| Layer | Can Import | Cannot Import |
|-------|------------|---------------|
| Layer 0 | None (foundation) | 1, 2, 3 |
| Layer 1 | Layer 0 | 2, 3 |
| Layer 2 | Layer 0, 1 | 3 |
| Layer 3 | Layer 0, 1, 2 | - |

---

### 13.4 Script Status Table

This table tracks which scripts are referenced in documentation vs actually created.

| Script | Status | Location | Notes |
|--------|--------|----------|-------|
| **Library Layer 0** |
| `exit_codes.py` | Implemented | `skills/_shared/python/layer0/` | Exit code constants |
| `colors.py` | Implemented | `skills/_shared/python/layer0/` | Color output utilities |
| `constants.py` | Implemented | `skills/_shared/python/layer0/` | Application constants |
| **Library Layer 1** |
| `config.py` | Implemented | `skills/_shared/python/layer1/` | Configuration management |
| `error_json.py` | Implemented | `skills/_shared/python/layer1/` | Standardized error JSON |
| `file_ops.py` | Implemented | `skills/_shared/python/layer1/` | Atomic file operations |
| `heartbeat.py` | Implemented | `skills/_shared/python/layer1/` | Heartbeat monitoring |
| `logging.py` | Implemented | `skills/_shared/python/layer1/` | Audit trail logging |
| `memory.py` | Implemented | `skills/_shared/python/layer1/` | Memory management utilities |
| `output_format.py` | Implemented | `skills/_shared/python/layer1/` | JSON/human formatting |
| **Library Layer 2** |
| `hooks.py` | Implemented | `skills/_shared/python/layer2/` | Lifecycle hook management |
| `messaging.py` | Implemented | `skills/_shared/python/layer2/` | Inter-component messaging |
| `task_ops.py` | Implemented | `skills/_shared/python/layer2/` | Task operations |
| `token_budget.py` | Implemented | `skills/_shared/python/layer2/` | Token budget tracking |
| `validation.py` | Implemented | `skills/_shared/python/layer2/` | Input validation |
| `webhooks.py` | Implemented | `skills/_shared/python/layer2/` | Webhook dispatch and management |
| **Library Layer 3** |
| `migrate.py` | Implemented | `skills/_shared/python/layer3/` | Schema migration |
| `backup.py` | Implemented | `skills/_shared/python/layer3/` | Backup operations |
| `doctor.py` | Implemented | `skills/_shared/python/layer3/` | Diagnostic utilities |
| `hierarchy_unified.py` | Implemented | `skills/_shared/python/layer3/` | Unified task hierarchy |

**Status Legend**:
- **Referenced**: Documented in skill/agent files but may not exist yet
- **Implemented**: Script exists and is functional
- **Deprecated**: Script exists but should not be used

---

## 14. CI Engine (Continuous Improvement)

The CI engine (`claude-code/lib/ci_engine/`) provides two feedback loops that enable the pipeline to learn from its own execution:

### 14.1 OODA Loop (Within-Run)

After every stage completion, the OODA controller observes stage results, orients against baselines, decides on corrective action, and acts:

| Decision | Trigger | Action |
|----------|---------|--------|
| `continue` | Stage succeeded, metrics nominal | Proceed to next stage |
| `retry` | Transient/hallucination failure, retries left | Re-spawn same stage (max 2 retries) |
| `fallback_to_spec` | Spec gap classification | Create spec gap task, re-run Stage 2 |
| `surface_to_user` | Dependency failure, retries exhausted, low confidence | Halt pipeline, present failure report |

### 14.2 PDCA Loop (Cross-Run)

After each complete run, the retrospective analyzer compares KPIs against rolling baselines, the improvement recommender generates prioritized targets, and the baseline manager updates averages:

```
Run N completes → RetrospectiveAnalyzer → retro.json + improvement_log.jsonl
                → ImprovementRecommender → improvement_targets.json
                → BaselineManager → stage_baselines.json
Run N+1 Stage 0 → reads improvement_targets.json → targeted research
```

### 14.3 Root Cause Classification (8 Categories)

| Category | Example Signals | Confidence |
|----------|----------------|------------|
| `transient` | HTTP 429/503, timeout, connection reset | 0.5-0.85 |
| `dependency` | ImportError, ModuleNotFoundError | 0.7-0.95 |
| `hallucination` | AttributeError, incorrect output | 0.5-0.85 |
| `spec_gap` | Compliance gap, missing requirement | 0.3-0.85 |
| `resource_exhaustion` | OOM, disk full, quota exceeded | 0.6-0.95 |
| `configuration` | Config error, missing env variable | 0.5-0.85 |
| `permissions` | Permission denied, 403, EACCES | 0.6-0.9 |
| `timeout` | Deadline exceeded, gateway timeout | 0.5-0.85 |

### 14.4 CI Engine Modules

| Module | Purpose |
|--------|---------|
| `ooda_controller.py` | Within-run OODA loop (observe/orient/decide/act) |
| `stage_metrics_collector.py` | Telemetry collection (12 DMAIC KPIs, 3-tier degradation) |
| `root_cause_classifier.py` | 8-category failure classification with 5 Whys chains |
| `retrospective_analyzer.py` | Post-run analysis with log rotation |
| `improvement_recommender.py` | Cross-run improvement targets with pattern decay |
| `baseline_manager.py` | Rolling 10-run baselines with exponential smoothing |
| `knowledge_store_writer.py` | Atomic writes to knowledge store (JSON + JSONL + SQLite) |
| `run_summary.py` | RunSummary dataclass with KPIs |
| `prometheus_exporter.py` | Optional Prometheus metrics export |

### 14.5 Data Files

All data files have JSON schemas at `lib/ci_engine/schemas/`:

| File | Format | Location | Persistence |
|------|--------|----------|-------------|
| `stage_telemetry.jsonl` | JSONL | Per-run | Project lifetime |
| `run_summary.json` | JSON | Per-run | Project lifetime |
| `retro.json` | JSON | Per-run | Project lifetime |
| `stage_baselines.json` | JSON | Knowledge store | Updated each run |
| `improvement_targets.json` | JSON | Knowledge store | Overwritten each run |
| `failure_patterns.json` | JSON | Knowledge store | Decays over time |
| `improvement_log.jsonl` | JSONL | Knowledge store | Rotated at 500 entries |

---

## 15. Domain Memory (Cross-Session Knowledge)

The domain memory system (`claude-code/lib/domain_memory/`) provides project-level knowledge that persists across all sessions and commands. Location: `.domain/` at the project root.

### 15.1 Six Knowledge Stores

| Store | Purpose | Written By | Queried By |
|-------|---------|-----------|-----------|
| `research_ledger.jsonl` | Research findings, CVEs, recommendations | Orchestrator (Stage 0) | Researcher (avoid re-research) |
| `decision_log.jsonl` | Architecture decisions with rationale | Orchestrator (Stage 1) | Product-manager (prior context) |
| `pattern_library.jsonl` | Success patterns and anti-patterns | Software-engineer, Retrospective | Software-engineer (learn from past) |
| `fix_registry.jsonl` | Error fingerprint → verified fix | Debugger, Software-engineer | OODA controller, Debugger |
| `codebase_analysis.jsonl` | Per-file risk, tech debt, findings | Auditor, Validator | All stages (file context) |
| `user_preferences.jsonl` | User corrections and preferences | Any command | All stages (respect choices) |

### 15.2 Concurrency Model

All stores are **append-only JSONL** with `fcntl.flock(LOCK_EX)` on writes. Multiple sessions can safely write concurrently — each append is atomic and serialized via file locking. Reads scan the full file without locking (safe because the file is append-only).

### 15.3 Domain Memory API

```python
from lib.domain_memory import DomainMemoryStore

store = DomainMemoryStore(".domain", session_id="...", command="auto-orchestrate")

# Write
store.append("fix_registry", {"error_fingerprint": "...", "fix_description": "..."})

# Query
fixes = store.lookup_fix("conn_refused_5432")
patterns = store.get_patterns("database")
research = store.search("research_ledger", "JWT")

# Hooks (called by agents after stage completion)
from lib.domain_memory.hooks import on_fix_applied, on_research_complete
on_research_complete(store, topic="auth", findings=["jose is recommended"])
on_fix_applied(store, error_fingerprint="...", fix_description="...", verification_result="pass")
```

### 15.4 Integration with CI Engine

The OODA controller accepts an optional `domain_store` parameter. During the Orient phase, it queries the fix registry for known fixes matching the current error fingerprint. If a verified fix exists, it's included in the retry prompt.

---

## 16. Output Standardization

All commands follow the unified output standard defined in `_shared/protocols/output-standard.md`:

- **Naming**: All output files use `YYYY-MM-DD_<slug>.<ext>`
- **Manifest**: Each session has ONE `MANIFEST.jsonl` at its root
- **Stage Receipt**: Every stage writes `stage-receipt.json` — the bridge to domain memory
- **Subdirectories**: All commands use consistent phase/stage subdirectories
- **Checkpoint Recovery**: Atomic tmp-then-rename with orphaned `.tmp.json` cleanup on startup

---

## 17. Organizational Workflow Integration

**Added**: 2026-04-06 (Session: auto-orc-20260406-gapintg, gap remediation Stage 3)

The auto-orchestrate pipeline connects to a human-facing organizational workflow pipeline through two integration mechanisms: the **bridge protocol** and the **gate state system**. New files in `claude-code/processes/` and a new section in `claude-code/agents/` implement this integration.

### 17.1 New Files Added

| File | Lines | Purpose |
|------|-------|---------|
| `claude-code/processes/bridge_protocol.md` | 218 | Defines how Scope Contract artifacts map to `/auto-orchestrate` invocation arguments. Covers trigger conditions, extraction table, handoff receipt schema, launch template, return path, and error handling. |
| `claude-code/processes/gate_state_schema.json` | 134 | JSON Schema Draft-7 defining the structure of `.orchestrate/{session_id}/gate-state.json`. Validates all 4 organizational gate states with full state machine constraints. |
| `claude-code/processes/gate_enforcement_spec.md` | 208 | Defines the gate state machine (valid/invalid transitions), enforcement points (GATE-BLOCK format), override mechanism, and initialization template. |
| `claude-code/processes/process_injection_map.md` | 166 | Cross-reference table: each auto-orchestrate stage (0-6) mapped to organizational process IDs it engages. Hook format, enforcement philosophy, and orchestrator injection points for future T019. |
| `claude-code/processes/process_stubs/sprint_planning_stub.md` | 73 | Placeholder for P-022/P-023/P-024 (Sprint Goals, Intent Trace, Story Writing) — processes with no AO pipeline home. |
| `claude-code/processes/process_stubs/dependency_coordination_stub.md` | 95 | Placeholder for P-015 through P-021 (Dependency Coordination) — processes that run parallel to AO Stages 0-2 but are never triggered. |
| `claude-code/processes/process_stubs/onboarding_stub.md` | 87 | Placeholder for P-090 through P-093 (Knowledge Handoff, Runbook Handover, Team Onboarding, Lessons Learned) — processes that occur after Stage 6. |
| `claude-code/agents/agent-reconciliation-notes.md` | 263 | Checksum verification record for the three dual-definition agents (researcher, session-manager, orchestrator). Documents install risk and required install.sh guard for orchestrator.md. |

### 17.2 Modified Files

| File | Change |
|------|--------|
| `claude-code/commands/new-project.md` | Added Phase 5 (Pipeline Handoff) section + gate state checks at each stage transition. GATE-BLOCK error format at all 4 gate boundaries. |
| `claude-code/commands/gate-review.md` | Added Gate State Write section: after every gate review, write result to `.orchestrate/{session_id}/gate-state.json`. Full state machine constraints, example JSON, override authorization. |

### 17.3 System Bridge Protocol

```
/new-project (4-stage org pipeline)
    │
    Stage 1: Intent → Gate 1 → Stage 2: Scope → Gate 2 → Stage 3: Dependencies → Gate 3 → Stage 4: Sprint → Gate 4
    │                                                                                                              │
    │  Gate 4 passed (or Gate 2 for early handoff)                                                                │
    ├─────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
    │
    v
Phase 5: Pipeline Handoff
    │
    ├─ Read gate-state.json: confirm gate_2_scope_lock.status == "passed"
    ├─ Extract task_description from Scope Contract (bridge_protocol.md)
    ├─ Generate session_id: "auto-orc-YYYYMMDD-{project_slug}"
    ├─ Write handoff-receipt.json
    └─ Launch: /auto-orchestrate "{task_description}" --scope {F|B|S} --session_id {session_id}
                    │
                    v
        /auto-orchestrate (7-stage technical pipeline)
                    │
                    Stage 0-6 complete
                    │
                    v
        .orchestrate/{session_id}/stage-6/ ──→ feeds back to /sprint-ceremony
```

**Reference**: `claude-code/processes/bridge_protocol.md`

### 17.4 Gate State System

Runtime gate state file: `.orchestrate/{session_id}/gate-state.json`  
Schema: `claude-code/processes/gate_state_schema.json` (JSON Schema Draft-7)  
Enforcement spec: `claude-code/processes/gate_enforcement_spec.md`

**State machine per gate**:
```
pending → in_review → passed
              └──→ failed → in_review (retry)
```

**Invalid transitions** (MUST be blocked):
- `pending → passed/failed`: [GATE-ERROR] Cannot skip in_review
- `passed → failed/pending`: [GATE-ERROR] Use --reopen

**Only `/gate-review` writes gate state. All other commands read only.**

Override: If `gate_N.override` is non-null with required fields (reason ≥10 chars, authorized_by, timestamp), enforcement is waived for that gate only.

### 17.5 Process Injection Map Summary

| AO Stage | Org Processes | Action | Enforced |
|----------|--------------|--------|----------|
| Stage 0 | P-001, P-038 | notify | false |
| Stage 1 | P-007/008/009/010 | link | false |
| Stage 2 | P-033, **P-038** | gate | **true** (P-038 only) |
| Stage 3 | P-034, P-036, P-040 | notify | false |
| Stage 4 | P-035, P-037 | link | false |
| Stage 4.5 | P-062 | link | false |
| Stage 5 | **P-034**, P-036, **P-037** | gate | **true** (P-034, P-037 enforced V2) |
| Stage 6 | **P-058**, P-059, P-061 | gate | **true** (P-058 enforced V2) |

P-038 (Security by Design) is enforced at Stage 2. P-034 (Code Review) and P-037 (Automated Testing) are enforced at Stage 5 exit. P-058 (Technical Documentation) is enforced at Stage 6 exit. All V2 enforced hooks use a 3-iteration escalation pattern (WARN → ENFORCE → ESCALATE). Process stubs cover gaps at Stage 1→3 transition (sprint planning), parallel to Stage 0-2 (dependency coordination), and post-Stage 6 (onboarding).

### 17.6 Agent Reconciliation

Three agents are dual-defined (runtime `~/.claude/agents/` + source `claude-code/agents/`): researcher, session-manager, orchestrator.

As of 2026-04-06: all three are **byte-for-byte identical** (md5 verified).

**CRITICAL**: `orchestrator.md` (32,479 bytes) IS the live orchestrator system prompt. Divergence = broken pipeline. install.sh MUST verify checksums before overwriting. See `claude-code/agents/agent-reconciliation-notes.md` for the guard script.

**Directory addition to Section 2 tree** (`claude-code/` structure):

```
├── processes/
│   ├── gate_state_schema.json               (JSON Schema Draft-7, 134 lines)
│   ├── gate_enforcement_spec.md             (state machine + enforcement, 208 lines)
│   ├── bridge_protocol.md                   (org pipeline ↔ AO bridge, 218 lines)
│   ├── process_injection_map.md             (AO stage → process IDs, 166 lines)
│   ├── [01-17]_*.md                         (organizational process handbooks)
│   └── process_stubs/
│       ├── README.md                        (status legend + stub index, 20 lines)
│       ├── sprint_planning_stub.md          (P-022/023/024, 84 lines)
│       ├── dependency_coordination_stub.md  (P-015 to P-021, 106 lines)
│       └── onboarding_stub.md               (P-090 to P-093, 98 lines)
```

### 17.7 Pipeline Chains Protocol

**Added**: 2026-04-14 (Session: auto-orc-20260414-pipeflow)

Pipeline chains enable explicit cross-pipeline coordination by recording chaining relationships in `.sessions/index.json`. They extend the session index schema (version 1.1.0) with an optional `pipeline_chains` array that tracks multi-command delivery sequences.

**Purpose**:
- Track cross-pipeline coordination (e.g., `/new-project` → `/auto-orchestrate` → `/sprint-ceremony`)
- Enable commands to know their position in a larger workflow
- Allow users to trace unified delivery chains

**Key Constraint (R-007)**: Pipeline chains are **ONLY created on explicit user request**. Commands NEVER create chain entries automatically.

**Schema reference**: `claude-code/processes/pipeline_chains_spec.md`

**Stage status values**: `pending` | `active` | `complete` | `failed` | `skipped` | `ready`

**Commands that interact with pipeline_chains**:
| Command | Operation | Trigger |
|---------|-----------|---------|
| `session-manager` | Read + Write | Session start/end when chain tracking active |
| `auto-orchestrate` | Write (status) | Stage 6 completion when chain entry exists |
| `workflow` | Read | Display chain status in Current Project Status |

### 17.8 Audit Receipt Artifact

**Added**: 2026-04-14 (Session: auto-orc-20260414-pipeflow)

The audit receipt is a completion artifact written by `/auto-audit` Step 7 upon termination. It provides a machine-readable summary of audit session outcome, distinct from cycle-level `stage-receipt.json` files.

**Path**: `.audit/{session_id}/audit-receipt.json`  
**Schema**: `claude-code/processes/schemas/audit-receipt-schema.json` (JSON Schema Draft-7, version 1.0)

**Required fields**:
| Field | Type | Description |
|-------|------|-------------|
| `session_id` | string | Pattern: `auto-aud-YYYYMMDD-{slug}` |
| `verdict` | enum | One of: `fully_compliant`, `acceptable_compliance`, `max_cycles_reached`, `stalled`, `user_stopped` |
| `final_compliance_score` | number | 0-100 compliance percentage |
| `compliance_threshold` | integer | Configured threshold for this session |
| `cycle_count` | integer | Total audit cycles completed (minimum 1) |

**Optional fields**: `gap_count`, `next_steps[]`, `related_orchestrate_session`

**Consumers**: Sprint ceremonies, compliance dashboards, cross-pipeline traceability

### 17.9 Gate 4 Enforcement in Sprint Ceremony

**Added**: 2026-04-14 (Session: auto-orc-20260414-pipeflow)

The `/sprint-ceremony` command enforces Gate 4 (Sprint Readiness) before facilitating any ceremony. This ensures that sprint execution only proceeds after the organizational readiness gate has been formally passed.

**Enforcement flow**:
1. Resolve session ID from environment or user input
2. Read `.orchestrate/{session_id}/gate-state.json`
3. Check `gates.gate_4_sprint_readiness.status`
4. If `"passed"`: `[GATE-PASS]` — proceed to ceremony
5. If not passed AND no valid override: `[GATE-BLOCK]` — halt and prompt for `/gate-review sprint-readiness`
6. If valid override present: `[GATE-OVERRIDE]` — proceed with logged override
7. If file not found: `[GATE-WARN]` — advisory prompt, backward compatible

**Override requirements**: `override.reason` (>=10 chars), `override.authorized_by`, `override.timestamp`

**Reference**: `claude-code/commands/sprint-ceremony.md` — Gate Enforcement Check section

### 17.10 Greenfield Detection (Step 0g)

**Added**: 2026-04-14 (Session: auto-orc-20260414-mainpipe)

The auto-orchestrate pipeline classifies the target project before spawning the first stage agent. Step 0g runs between domain memory initialization (Step 0f) and prompt enhancement (Step 1), using metadata-only operations to preserve the Execution Guard (no source file reading).

**Classification**:

| Type | Condition | Pipeline Adaptation |
|------|-----------|---------------------|
| `continuation` | Prior session exists with status `in_progress` or `superseded` | Researcher checks prior research output; builds incrementally |
| `greenfield` | < 5 git commits AND < 10 source files | Researcher prioritizes technology selection, scaffolding patterns, dependency evaluation; product-manager includes scaffolding tasks |
| `existing` | All other cases | Researcher prioritizes codebase analysis, change impact assessment, existing pattern identification; product-manager includes regression risk analysis |

**Detection signals** (4 metadata probes):
1. Git history depth (`git rev-list HEAD --count`)
2. Source file count (`.py`, `.ts`, `.js`, `.go`, `.rs`, `.java`, `.rb` within 3 levels)
3. Handoff receipt presence (`.orchestrate/{session_id}/handoff-receipt.json`)
4. Prior orchestration history (`.orchestrate/auto-orc-*/checkpoint.json` count)

The detected `project_type` is stored in the checkpoint and passed as `PROJECT_TYPE` in every orchestrator spawn prompt.

**Reference**: `claude-code/commands/auto-orchestrate.md` — Step 0g

### 17.11 Gate Enforcement Integration in Auto-Orchestrate

**Added**: 2026-04-14 (Session: auto-orc-20260414-mainpipe)

Step 2d of auto-orchestrate reads `.gate-state.json` from the project root (written by `/gate-review`) and maps organizational gates to pipeline stage prerequisites. This creates a bidirectional enforcement link between the organizational workflow (`/new-project`) and the technical pipeline (`/auto-orchestrate`).

**Gate-to-stage mapping**:

| Organizational Gate | Pipeline Stage Prerequisite |
|--------------------|-----------------------------|
| Gate 1 — Intent Review | Stage 0 (Research) |
| Gate 2 — Scope Lock | Stage 2 (Specification) |
| Gate 3 — Dependency Acceptance | Stage 3 (Implementation) |
| Gate 4 — Sprint Readiness | Stage 5 (Validation) |

**Enforcement in STAGE_CEILING** (Step 3a): After calculating the stages-based ceiling, a `gate_ceiling` is computed from the gate state. The final `STAGE_CEILING` is `min(stages_ceiling, gate_ceiling)`. Three outcomes are possible:

1. `[GATE-BLOCK]` — gate not passed and no override: ceiling reduced to block the stage
2. `[GATE-OVERRIDE]` — gate not passed but override set: progression allowed with audit trail
3. `[GATE-SKIP]` — no `.gate-state.json` exists: backward compatible, no enforcement

**Checkpoint fields**: `gate_state` (object or null), `gate_override` (boolean)

**Reference**: `claude-code/commands/auto-orchestrate.md` — Steps 2d and 3a

### 17.12 Bridge Protocol Enhancements

**Added**: 2026-04-14 (Session: auto-orc-20260414-mainpipe)

The handoff validation in auto-orchestrate was strengthened with BRIDGE-BLOCK enforcement:

- **Before**: When `source_gate_status != "PASSED"` in the handoff receipt, auto-orchestrate emitted `[HANDOFF-WARN]` and continued. This allowed pipeline execution without proper gate passage.
- **After**: Emits `[BRIDGE-BLOCK]` and aborts with checkpoint status `"bridge_blocked"`. This enforces the bridge protocol contract that gate passage is mandatory before auto-orchestration.

The return path completion on termination now includes:
- `return_path.stage6_artifacts_path` — path to Stage 6 documentation artifacts
- `completed_timestamp` (renamed from `completed_at`) — ISO-8601 completion time

**Reference**: `claude-code/commands/auto-orchestrate.md` — Handoff Resume and Return Path sections

### 17.13 Process Hook Enforcement (V2 Upgrade)

**Added**: 2026-04-14 (Session: auto-orc-20260414-mainpipe)

Three process hooks were upgraded from advisory to enforced with a 3-iteration escalation pattern:

| Process | Stage | Enforcement Change |
|---------|-------|--------------------|
| P-034 (Code Review) | Stage 5 (Validator exit) | Advisory → Enforced |
| P-037 (Automated Testing / UAT) | Stage 5 (Validator exit) | Advisory → Enforced |
| P-058 (Technical Documentation) | Stage 6 (Technical-writer exit) | Advisory → Enforced |

**Enforcement escalation** (3 iterations per process):
1. **Iteration 1 — WARN**: `[PROC-WARN] P-0XX not acknowledged — will enforce next iteration`
2. **Iteration 2 — ENFORCE**: `[PROC-ENFORCE] P-0XX — adding remediation task`
3. **Iteration 3 — ESCALATE**: `[PROC-ESCALATE] P-0XX — blocking pipeline, user intervention required`

**Acknowledgment detection**: The pipeline checks stage output for process-specific markers (e.g., `"[P-034]"`, `"code review: PASS"`, `"test results:"`, `"documentation: COMPLETE"`).

**Checkpoint tracking**: Each enforced process has `P-0XX_acknowledged` (boolean) and `P-0XX_iterations` (counter) fields in the `process_gates` checkpoint object.

**Reference**: `claude-code/commands/auto-orchestrate.md` — Step 4.8a; `claude-code/processes/process_injection_map.md`

### 17.14 Expanded Pre-flight Verification

**Added**: 2026-04-14 (Session: auto-orc-20260414-mainpipe)

Pre-flight verification was expanded from 3 skills to 9 pipeline components. Before spawning Stage 0 (researcher), auto-orchestrate verifies all pipeline-critical components exist in the manifest:

| Stage | Component | Type | Mandatory |
|-------|-----------|------|-----------|
| 0 | researcher | agent | Yes |
| 1 | product-manager | agent | Yes |
| 2 | spec-creator | skill | Yes |
| 3 | software-engineer | agent | Yes |
| 3 | library-implementer-python | skill | No (alternative) |
| 4 | test-writer-pytest | skill | No (Stage 4 optional) |
| 4.5 | codebase-stats | skill | Yes |
| 5 | validator | skill | Yes |
| 6 | technical-writer | agent | Yes |

**Verification output**: A summary table showing each component with pass/warn status and a final count line: `Result: 7/7 mandatory present, 2 optional (N missing)`.

**Failure behavior**: Missing mandatory components abort with `[MANIFEST-001]`. Missing optional components emit `[MANIFEST-WARN]` and continue.

**Reference**: `claude-code/commands/auto-orchestrate.md` — Pre-flight Component Verification section
