# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- **Session checkpoint path isolation** — Session checkpoints now written to project-local `.orchestrate/<session-id>/checkpoint.json` instead of `~/.claude/sessions/<id>.json`; prevents cross-project interference and keeps all session artifacts co-located with the project
- **Cross-terminal supersession interference** — Supersession scan now scoped to `.orchestrate/*/checkpoint.json` (current project only) instead of `~/.claude/sessions/auto-orc-*.json` (global); eliminates false-positive supersessions when multiple projects run auto-orchestrate concurrently
- **Crash recovery legacy support** — Crash recovery protocol reads `.orchestrate/` (primary) then falls back to `~/.claude/sessions/` (read-only legacy) so sessions started before the path change can still be recovered
- **Session supersession gap** — `auto-orchestrate.md` Step 2b now loops over ALL in-progress sessions (not just the first match) when a new session starts, adding `superseded_at` and `superseded_by` metadata to each, and creating `.stale` marker files in corresponding `.orchestrate/<session-id>/` directories
- **Crash recovery task state loss** — Checkpoint schema now includes `task_snapshot` field (written every iteration in Step 4.7) containing full task state (id, subject, status, blockedBy, dispatch_hint). Crash Recovery Protocol reads `task_snapshot.tasks` and restores tasks via `TaskCreate` when the task system is empty after a crash
- **spec-creator output path conflict** — Resolved conflict between `docs/specs/` (SKILL.md default) and `.orchestrate/<SESSION_ID>/specs/` (orchestrator directive). orchestrator.md now passes explicit `OUTPUT_DIR` parameter in Stage 2 spawn template; `spec-creator/SKILL.md` supports `OUTPUT_DIR` override with `docs/specs/` fallback for standalone use
- **AUTO-001 delegated-spawn rationalization bypass** — Strengthened the AUTO-001 GUARD in `auto-orchestrate.md` Step 4 to explicitly block the rationalization pattern where auto-orchestrate spawns a non-orchestrator agent because "the orchestrator delegated the routing decision". The GUARD now enumerates five concrete prohibited justifications and clarifies that receiving a routing suggestion from the orchestrator does NOT grant spawn permission — the orchestrator's routing hint becomes context for the next orchestrator re-spawn. A corresponding new anti-pattern row was added to the Anti-Patterns table.

### Added

- **docker-validator skill** — New Stage 5 sub-step (`skills/docker-validator/SKILL.md`, 449 lines) for Docker environment validation, state checkpointing, Docker Compose build/deploy, UX testing (authenticated and unauthenticated), HTTP status code validation (detects 400/500 errors), and post-test state restoration; requires Docker Engine >= 27.1.1
- **Docker validation pipeline integration** — docker-validator registered in `manifest.json`, enforced as mandatory Stage 5a sub-step in `orchestrator.md` (constraint block), and wired into the auto-orchestrate pipeline via `auto-orchestrate.md`; validator skill updated to reference Docker validation as a prerequisite check
- **Researcher agent** — New dedicated researcher agent (`agents/researcher.md`) with WebSearch and WebFetch for internet-enabled research; supports CVE lookup, package analysis, Docker image security, best-practices investigation, and technology evaluation; enforces RES-001 to RES-007 constraints; spawned by orchestrator at Stage 0 (mandatory)
- **No-auto-commit policy** — `dev-workflow` phases G3 and G4 now generate conventional commit messages and display copy-pasteable `git add`/`git commit`/`git push` commands without executing them; the user reviews and runs commands manually
- **File-based task proposal protocol** — Subagents now communicate task proposals via `.orchestrate/<session-id>/proposed-tasks.json` files and `PROPOSED_ACTIONS` JSON blocks in return values, enabling reliable task management without direct tool access (commit `6993c4b`)
- **`dispatch_hint` routing field** — Epic-architect assigns `dispatch_hint` to every task, providing explicit routing keys for auto-orchestrate to route tasks to the correct subagent (commit `3fd2cf1`)
- **`.orchestrate/` session folder structure** — Each auto-orchestrate session creates a per-session directory (`research/`, `architecture/`, `logs/`) for organized output storage (commits `3fd2cf1`, `6993c4b`)
- **`specs/` in session directories** — `mkdir` now creates `specs/` alongside `research/`, `architecture/`, and `logs/` in each session directory; spec-creator outputs are co-located with other session artifacts

### Changed

- **Stage 0 mandatory** — Orchestrator now mandates Stage 0 research before advancing to epic-architect decomposition (Stage 1); previously optional and only triggered when unknowns existed
- **Agent count** — System now has 6 specialized agents (was 5): orchestrator, epic-architect, implementer, documentor, session-manager, researcher
- **dev-workflow G3/G4** — Replaced auto-commit and auto-push with message-generation-only workflow
- **Orchestrator communication protocol** — Orchestrator now receives task state via spawn prompt (`## Current Task State` section) instead of calling TaskList, and proposes task updates via `PROPOSED_ACTIONS` return value instead of TaskCreate/TaskUpdate (commit `6993c4b`)
- **Epic-architect task caps** — Epic-architect updated to enforce task count limits and propose broader, consolidated tasks rather than fine-grained individual tasks (commit `6993c4b`)
- **TOOL-AVAILABILITY.md** — Major overhaul clarifying that TaskCreate, TaskList, TaskUpdate, and TaskGet are NEVER available to subagents; Task tool (for spawning subagents) is unreliable at runtime; workaround documented (commits `3fd2cf1`, `6993c4b`)
- **GAP-CRIT-001 status** — Remains OPEN but now has a documented, implemented workaround via the file-based task proposal protocol (commits `3fd2cf1`, `6993c4b`)
- **Auto-orchestrate command** — Updated to process task proposals from `.orchestrate/<session-id>/proposed-tasks.json` files and `PROPOSED_ACTIONS` blocks in orchestrator return values (commit `6993c4b`)

### Security

- **Removed `Bash(rm *)` from settings.json allow list** — The `Bash(rm *)` permission was temporarily added in `6993c4b` for cleanup operations and removed in `8cbfe02` to reduce the attack surface; `rm` is no longer an explicitly allowed permission in the default configuration (commit `8cbfe02`)

### Fixed

- **Epic-architect ↔ orchestrator communication** — Clarified the task handoff flow between epic-architect and orchestrator, documenting that `dispatch_hint` is the routing key and that PROPOSED_ACTIONS in the orchestrator return value drives task creation (commit `3fd2cf1`)
- **README.md agent count** — Corrected agent count from 5 to 6 throughout `README.md` to include the researcher agent; directory tree now explicitly lists `researcher.md`
- **README.md manifest.schema.json path** — Fixed schema file reference to point to `_shared/schemas/manifest.schema.json` instead of a root-level path that did not exist
- **agents/TOOL-AVAILABILITY.md redirect notice** — Added a redirect notice at the top of `agents/TOOL-AVAILABILITY.md` directing readers to the canonical version at `_shared/references/TOOL-AVAILABILITY.md`
- **install-claude-config.sh documentation install** — Install script now copies documentation files (`ARCHITECTURE.md`, `INTEGRATION.md`, `PERMISSION-MODES.md`) to `~/.claude/` during installation

## [1.0.0] - 2026-02-12

### Added

- **Multi-agent orchestration framework** with 5 specialized agents (orchestrator, epic-architect, implementer, documentor, session-manager)
- **32 task-specific skills** covering testing, security, documentation, DevOps, refactoring, CI/CD, dependency analysis, and workflow management
- **7-stage autonomous pipeline** (research, planning, specification, implementation, testing, validation, documentation) with mandatory completion gates
- **Auto-orchestrate command** (`/auto-orchestrate`) for fully autonomous multi-iteration task completion
- **Session management with crash recovery** via checkpoint-based persistence in `~/.claude/sessions/`
- **Epic-architect agent** with 4-phase planning pipeline (scope analysis, task decomposition, dependency graphs, Program planning)
- **Implementer agent** with single-pass quality pipeline (implementation → self-review → fix → security gate)
- **Documentor agent** with maintain-don't-duplicate principle (docs-lookup → docs-write → docs-review)
- **Zero-error gates** (MAIN-006) — implementation tasks must reach 0 errors and 0 warnings before proceeding
- **Mandatory validation stages** (4.5, 5, 6) — codebase-stats, validator, and documentor must complete before pipeline termination
- **Context-efficient orchestration** — under 10K tokens per agent handoff via manifest summaries
- **Single-file implementer pattern** (SFI-001, IMPL-012) — implementer targets exactly one file per invocation to prevent context exhaustion
- **Task decomposition with parallel execution** — Program-based dependency graphs enable optimized scheduling
- **Constraint system** (MAIN-001 to MAIN-013, IMPL-001 to IMPL-012, AUTO-001 to AUTO-007) for quality and predictability
- **Subagent protocol** (OUT-001 to OUT-004) — standardized output format with manifest entries and key_findings summaries
- **Skill chaining patterns** — single-level spawning, within-agent skill chains, and multi-level orchestration (max 3 levels)
- **Python shared library** (`skills/_shared/python/`) with layered architecture (layer0-layer3) and zero external dependencies
- **Session isolation** via SESSION_ID scoping of checkpoint files
- **Workflow commands** (`/workflow-start`, `/workflow-end`, `/workflow-dash`, `/workflow-focus`, `/workflow-next`, `/workflow-plan`)
- **Install script** (`install-claude-config.sh`) with automatic backup of existing `~/.claude/` configuration
- **Manifest-based component registry** (`manifest.json`) for agent/skill routing with 481-line schema
- **Documentation system** with architecture docs, integration guide, permission modes reference, and agent/skill definitions
- **Anti-pattern detection** across output, research, implementation, testing, validation, and security domains
- **Technical debt measurement** via codebase-stats skill (Stage 4.5) as mandatory gate after implementation
- **Security auditing** via security-auditor skill for shell script vulnerability scanning
- **CI/CD workflow support** via cicd-workflow skill (GitHub Actions, GitLab CI)
- **Docker workflow support** via docker-workflow skill with multi-stage build patterns
- **Refactoring tools** (refactor-analyzer, refactor-executor, hierarchy-unifier, error-standardizer)
- **Test tooling** (test-writer-pytest, test-gap-analyzer) with pytest integration
- **Dependency analysis** (dependency-analyzer) for circular dependency detection and layer validation
- **Schema migration** (schema-migrator) for JSON schema version upgrades
- **Development workflow** (dev-workflow) for atomic commits and release management
- **Python virtual environment management** (python-venv-manager) for venv creation and package installation

### Documentation

- Comprehensive README with quick start, architecture overview, component catalog, and installation instructions
- ARCHITECTURE.md (1,569 lines) with full system architecture, agent decision flows, skill catalog, and cross-reference matrix
- INTEGRATION.md with step-by-step installation and verification guide
- PERMISSION-MODES.md documenting Claude Code permission mode compatibility
- Agent definition files (5 total: orchestrator.md, epic-architect.md, implementer.md, documentor.md, session-manager.md)
- Skill definition files (32 total) with frontmatter triggers, execution sequences, and anti-patterns
- Protocol specifications (4 total) for subagent output, task system integration, and skill chaining
- Style guide for documentation consistency
- Anti-patterns template covering common mistakes across all domains
- Epic-architect reference materials (patterns, examples, output format)
- TOOL-AVAILABILITY.md documenting GAP-CRIT-001 (Task tool availability constraints)

### Infrastructure

- Layered Python library architecture with strict import discipline (layer0: foundation, layer1: basic helpers, layer2: business logic, layer3: orchestration)
- Session checkpoint system with JSON schema v1.0.0
- Manifest JSONL format for agent output tracking and key_findings summaries
- Task system integration using Claude Code native tools (TaskCreate, TaskList, TaskUpdate, TaskGet)
- File scope discipline (MAIN-009) preventing out-of-scope file modifications
- Deletion protection (MAIN-010) requiring user consent
- Context budget management (MAIN-005) with 10K token per-handoff limit
- Large file reading protocol (READ-001 to READ-005) with chunked and targeted reading for files >500 lines
- Manifest size management (MAN-001, MAN-002) with rotation at 200 entries
- Task count limits (LIMIT-001, LIMIT-002) with 50-task ceiling
- Continuation depth limits (CONT-001, CONT-002) with 3-level max to prevent infinite continuation chains
- Early exit protocol (EARLY-001 to EARLY-003) for graceful partial completion on context/turn budget exhaustion
- Stage monotonicity enforcement (AUTO-003) — pipeline stages only increase across iterations
- Mandatory stage enforcement (AUTO-004) — overdue stages (4.5, 5, 6) forced after 2 iterations

### Security

- Zero external dependencies — Python library uses only Python 3 standard library
- Install script with automatic backup and permission preservation
- Atomic file operations in shared library
- Input validation layer (layer2/validation.py)
- Security gate (IMPL-008) — 0 security issues before implementer completion
- Audit trail via manifest entries
- Session isolation preventing concurrent session interference
- File scope discipline preventing unintended modifications

### Known Limitations

- **GAP-CRIT-001**: Task tool availability is context-dependent; TaskCreate, TaskList, TaskUpdate, and TaskGet are NEVER available to subagents. The Task tool (for spawning subagents) is unreliable at runtime. **Workaround implemented**: file-based task proposal protocol via `.orchestrate/<session-id>/proposed-tasks.json` and `PROPOSED_ACTIONS` return blocks. See `claude-code/agents/TOOL-AVAILABILITY.md` for full details.
- **No sandboxing**: Skills and agents execute with user-level permissions (same as Claude Code process)
- **Auto-orchestrate permission modes**: Limited testing across all Claude Code permission modes; compatibility may vary

### Constraints Reference

**Orchestrator (MAIN-001 to MAIN-013)**:
- MAIN-001: Stay high-level (no implementation)
- MAIN-002: Delegate ALL work via Task tool
- MAIN-003: No full file reads (manifest summaries only)
- MAIN-004: Sequential spawning (one subagent at a time)
- MAIN-005: Per-handoff token budget (under 10K tokens)
- MAIN-006: Zero-error gate (0 errors/warnings before advancing)
- MAIN-007: Session folder autonomy (full read of ~/.claude/)
- MAIN-008: Minimal user interruption (autonomous decisions)
- MAIN-009: File scope discipline (no out-of-scope changes)
- MAIN-010: No deletion without consent
- MAIN-011: max_turns on every Task spawn
- MAIN-012: Flow integrity (follow full pipeline, never skip stages)
- MAIN-013: Decomposition gate (verify dispatch_hint before spawning implementer)

**Implementer (IMPL-001 to IMPL-012)**:
- IMPL-001: No placeholders (production-ready code only)
- IMPL-002: Don't ask (make decisions, proceed)
- IMPL-003: Don't explain (just write code)
- IMPL-004: Fix immediately (don't report breakage)
- IMPL-005: One pass (implement → review → fix in single pass)
- IMPL-006: Enterprise production-ready (no mocks, no hardcoded values)
- IMPL-007: Scope-conditional quality pipeline (SMALL/MEDIUM/LARGE)
- IMPL-008: Security gate (0 security issues before completion)
- IMPL-009: Loop limit (max 3 fix-audit iterations)
- IMPL-010: No anti-patterns (code must not match anti-patterns table)
- IMPL-011: Context budget discipline (turn tracking, checkpoints, hard-exit)
- IMPL-012: Single-file scope (targets exactly ONE file per invocation, enforces SFI-001)

**Auto-Orchestrate (AUTO-001 to AUTO-007)**:
- AUTO-001: Orchestrator-only gateway (spawn only orchestrator, no direct agent spawning)
- AUTO-002: Mandatory stage completion before termination (stages 4.5, 5, 6 required)
- AUTO-003: Stage monotonicity (pipeline stages only increase)
- AUTO-004: Post-iteration mandatory stage gate (enforce 4.5/5/6 if overdue 2+ iterations)
- AUTO-005: Checkpoint-before-spawn invariant (write checkpoint before every orchestrator spawn)
- AUTO-006: No direct agent routing in spawn prompt (routing is orchestrator's decision)
- AUTO-007: Iteration history immutability (append-only history)

### Repository Information

- **License**: MIT
- **Python Version**: Python 3 (no version constraint, uses standard library only)
- **Dependencies**: None (zero external dependencies)
- **Commits**: 5 commits on main branch as of v1.0.0
- **Schema Version**: 1.0.0

[1.0.0]: https://github.com/ribatshepo/Auto-Orchestrate /releases/tag/v1.0.0
