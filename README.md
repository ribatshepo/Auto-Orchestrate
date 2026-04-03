# Auto-Orchestrate

Multi-agent orchestration framework that extends Claude Code with autonomous software engineering workflows.

## Overview

Auto-Orchestrate is a Claude Code extension that adds autonomous multi-agent orchestration to your development workflow. It coordinates specialized AI agents through a structured pipeline — from research and planning through implementation, testing, validation, and documentation — so you can hand off complex engineering tasks and get production-ready results.

The system enforces strict quality gates, manages context budgets across agent handoffs, and supports session persistence with crash recovery, enabling fully autonomous software engineering pipelines.

## Features

- **7-stage autonomous pipeline** — Research, planning, specification, implementation, testing, validation, and documentation stages with mandatory completion gates
- **8 specialized agents** — Orchestrator, implementer, documentor, epic-architect, session-manager, researcher, debugger, and auditor, each with defined roles and constraints
- **2 autonomous subsystems** — `/auto-debug` for cyclic error-fix loops; `/auto-audit` for spec-compliance verification loops
- **35 task-specific skills** — Testing, security auditing, documentation, DevOps, Docker validation, refactoring, CI/CD, dependency analysis, debugging diagnostics, spec compliance, and more
- **Session management with crash recovery** — Checkpoint-based sessions that persist across interruptions and can be resumed
- **Task decomposition with parallel execution** — Epic-architect decomposes work into dependency graphs for optimized scheduling (Program planning)
- **Zero-error gates and mandatory validation** — Security audits, compliance checks, and technical debt measurement enforced before completion
- **Context-efficient orchestration** — Under 10K tokens per agent handoff, keeping orchestration overhead minimal
- **No-auto-commit policy** — The dev-workflow skill generates conventional commit messages and displays copy-pasteable git commands without executing them automatically

## Prerequisites

- **Claude Code CLI** — [Anthropic's official CLI for Claude](https://docs.anthropic.com/en/docs/claude-code)
- **Python 3** — Required for skill scripts (no pip dependencies needed)
- **Docker Engine >= 27.1.1** — Required for docker-validator skill (Stage 5a); includes Docker Compose

## Installation

Clone the repository and run the install script:

```bash
git clone https://github.com/ribatshepo/Auto-Orchestrate.git
cd Auto-Orchestrate
chmod +x install.sh
./install.sh
```

The install script copies the following into `~/.claude/`:

- `agents/` — Agent definition files
- `skills/` — All 35 skill directories
- `commands/` — Command definitions (auto-orchestrate, auto-debug, auto-audit)
- `_shared/` — Protocols, templates, references, and style guides
- `manifest.json` — Component registry used for agent routing
- `settings.json` — Permission and configuration settings

> **Note:** The installer automatically backs up your existing `~/.claude/` configuration to `~/.claude/backup-<timestamp>/` before making changes.

## Quick Start

### Autonomous orchestration

Launch a fully autonomous pipeline with a single command:

```
/auto-orchestrate Build a REST API for user management with authentication, tests, and documentation
```

**Scope flags** target the pipeline at a specific stack layer with pre-built quality specifications:

```
/auto-orchestrate B                          # Backend scope (default objective)
/auto-orchestrate F build the dashboard      # Frontend scope with custom objective
/auto-orchestrate S implement all features   # Fullstack scope
```

| Flag | Scope | Description |
|------|-------|-------------|
| `B`/`b` | Backend | Models, migrations, services, controllers, routes, auth, persistence |
| `F`/`f` | Frontend | Pages, forms, API integrations, child-friendly usability |
| `S`/`s` | Fullstack | Both backend and frontend, production-ready end-to-end |
| *(omitted)* | Custom | No scope injection — follows user input as-is |

The system will:
1. Research requirements and unknowns
2. Decompose the task into an execution plan
3. Write technical specifications
4. Implement production code
5. Generate tests
6. Run validation and security gates
7. Produce documentation

### Session management

Start, monitor, and manage work sessions:

```
/workflow-start    # Initialize a new work session
/workflow-dash     # View project task dashboard
/workflow-next     # Get the next suggested task
/workflow-focus    # Set focus on a specific task
/workflow-plan     # Enter interactive planning mode
/workflow-end      # Wrap up the current session
```

### Resuming sessions

Sessions are checkpointed automatically in `.orchestrate/<session-id>/checkpoint.json` (project-local). If a session is interrupted, restarting `/auto-orchestrate` with the same task description will detect and resume from the last checkpoint. Legacy sessions from `~/.claude/sessions/` are also detected as a backward-compatible fallback.

You can also use the shorthand `/auto-orchestrate c` to quickly resume the most recent in-progress session.

### Autonomous debugging

Debug errors autonomously with a cyclic triage-fix-verify loop:

```
/auto-debug paste-error-here
/auto-debug debug docker           # Docker-specific debugging
/auto-debug c                      # Resume most recent debug session
```

### Autonomous audit

Verify a codebase against a specification document:

```
/auto-audit path/to/spec.md
/auto-audit path/to/spec.md scope=B    # Backend scope
/auto-audit c                          # Resume most recent audit session
```

## Architecture Overview

```
User Input
    |
    v
/auto-orchestrate  (command)
    |
    v
orchestrator  (agent) ──> session-manager
    |                          |
    |── researcher ──────────> Research (Stage 0, mandatory)
    |── epic-architect ────> Task decomposition
    |── implementer ───────> Code + self-review + security gate
    |── documentor ────────> Docs (maintain-don't-duplicate)
    |
    v
Completion (all mandatory gates passed)

/auto-debug  (command)
    |
    v
debugger  (agent) ──> debug-diagnostics
    |── researcher (optional: unfamiliar errors)
    v
Fix verified ──> Debug report in .debug/<session-id>/

/auto-audit  (command)
    |
    v
auditor  (agent) ──> spec-compliance
    |
    v
Compliance report ──> Gap found? ──> orchestrator (remediation) ──> Re-audit
```


### Pipeline Stages

| Stage | Component | Purpose | Required |
|-------|-----------|---------|----------|
| 0 | researcher | Gather unknowns and context | **Yes** |
| 1 | epic-architect | Decompose into tasks with dependencies | **Yes** |
| 2 | spec-creator | Write technical specifications | **Yes** |
| 3 | implementer | Produce production-ready code | No |
| 4 | test-writer-pytest | Generate tests | No |
| 4.5 | codebase-stats | Measure technical debt impact | **Yes** |
| 5 | validator | Validate compliance and correctness | **Yes** |
| 5a | docker-validator | Docker environment validation, UX testing, state checkpointing | **Yes** (sub-step of 5) |
| 6 | documentor | Write/update documentation | **Yes** |

Stages 0, 1, 2, 4.5, 5, and 6 are mandatory — the pipeline will not terminate until they complete successfully (AUTO-002).

### Constraint System

The framework enforces three constraint sets to maintain quality and predictability:

- **MAIN-001 to MAIN-015** — Orchestrator constraints (delegation-only, context budgets, zero-error gates, file scope discipline, no auto-commit, always-visible processing)
- **IMPL-001 to IMPL-013** — Implementer constraints (no placeholders, one-pass quality, security gates, anti-pattern detection)
- **AUTO-001 to AUTO-007** — Auto-orchestrate constraints (stage monotonicity, mandatory completion, checkpoint integrity)
- **CEILING-001, CHAIN-001** — Pipeline enforcement (stage ceiling limits orchestrator to next incomplete stage, mandatory blockedBy chains between stages)
- **PROGRESS-001, DISPLAY-001** — Visibility constraints (always-visible processing, task board at every iteration)
- **SCOPE-001, SCOPE-002** — Scope constraints (verbatim spec passthrough, template integrity)

See `claude-code/ARCHITECTURE.md` for the full constraint matrix.

## Available Components

### Agents

| Agent | Mandatory Skills | Description |
|-------|-----------------|-------------|
| orchestrator | *(delegates to agents)* | Coordinates workflows by delegating to subagents; enforces MAIN constraints |
| epic-architect | spec-analyzer, dependency-analyzer | Decomposes work into task graphs with dependency analysis (4-phase pipeline) |
| implementer | production-code-workflow, security-auditor, codebase-stats, refactor-analyzer, refactor-executor | Single-pass implementation with self-review, quality pipeline, and security gate |
| documentor | docs-lookup, docs-write, docs-review | Documentation specialist; chains skills for full docs workflow |
| session-manager | workflow-start/end/dash/focus/next/plan | Manages session lifecycle, checkpoints, and crash recovery |
| researcher | researcher (skill), docs-lookup | Internet-enabled research for best practices, CVEs, package analysis |
| debugger | debug-diagnostics | Autonomous debugger: triage, research, fix, verify with minimal blast radius; supports Docker debugging mode |
| auditor | spec-compliance | Read-only spec compliance auditor; produces compliance report + gap-report.json; never modifies code |

### Skills (by domain)

**Quality and Validation**
validator, docker-validator, test-writer-pytest, test-gap-analyzer, security-auditor, codebase-stats

**Debugging and Auditing**
debug-diagnostics, spec-compliance

**Code Implementation**
task-executor, library-implementer-python, production-code-workflow

**Analysis and Planning**
researcher, spec-creator, spec-analyzer, dependency-analyzer

**Documentation**
docs-lookup, docs-write, docs-review

**Refactoring and Infrastructure**
refactor-analyzer, refactor-executor, schema-migrator, error-standardizer, hierarchy-unifier, docker-workflow, cicd-workflow

**Workflow and Session Management**
workflow-start, workflow-dash, workflow-focus, workflow-next, workflow-plan, workflow-end

**Utility and Discovery**
skill-lookup, skill-creator, dev-workflow, python-venv-manager

## Project Structure

```
Auto-Orchestrate/
├── README.md                    # This file
├── LICENSE                      # MIT License
├── SECURITY.md                  # Security policy and vulnerability reporting
├── CHANGELOG.md                 # Version history and changes
├── RELEASE-NOTES.md             # v1.0.0 release notes
├── SECURITY-AUDIT-v1.0.0.md     # Security audit report for v1.0.0
├── protect-branches.sh          # GitHub branch protection manager
├── install.sh     # Installer script
├── uninstall.sh   # Uninstaller script
│
├── .orchestrate/                # Per-session orchestration output (gitignored)
│
└── claude-code/                 # Main system directory
    ├── ARCHITECTURE.md          # System architecture documentation
    ├── INTEGRATION.md           # Integration guide
    ├── PERMISSION-MODES.md      # Permission mode documentation
    ├── manifest.json            # Component registry (agent/skill routing)
    ├── settings.json            # Configuration and permissions
    │
    ├── agents/                  # Agent definitions (8 agents)
    │   ├── orchestrator.md
    │   ├── epic-architect.md
    │   ├── implementer.md
    │   ├── documentor.md
    │   ├── researcher.md
    │   ├── session-manager.md
    │   ├── debugger.md
    │   └── auditor.md
    │
    ├── commands/                # Command definitions
    │   ├── auto-orchestrate.md  # Autonomous orchestration loop
    │   ├── auto-debug.md        # Autonomous debug loop
    │   └── auto-audit.md        # Autonomous audit loop
    │
    ├── skills/                  # Skill definitions (35 skills)
    │   ├── codebase-stats/
    │   ├── cicd-workflow/
    │   ├── dependency-analyzer/
    │   ├── docker-validator/
    │   ├── ... (35 skill directories total)
    │   └── _shared/             # Shared Python libraries
    │
    └── _shared/                 # Shared resources
        ├── protocols/           # Agent communication protocols
        ├── references/          # Agent-specific reference docs
        ├── schemas/             # JSON schemas (manifest.schema.json)
        ├── templates/           # Skill boilerplate and anti-patterns
        ├── style-guides/        # Documentation style guide
        └── tokens/              # Placeholder token definitions
```

### .orchestrate/ Directory

The `.orchestrate/` directory is created automatically during autonomous orchestration sessions. It stores intermediate output produced by subagents for a given session and is **gitignored** — it never enters version control.

Each session gets its own subdirectory named by session ID:

```
.orchestrate/
└── <session-id>/
    ├── checkpoint.json      # Session checkpoint (task state, iteration history)
    ├── proposed-tasks.json  # Task proposals queued for auto-orchestrate
    ├── stage-0/             # Researcher output (Stage 0)
    ├── stage-1/             # Epic-architect plans (Stage 1)
    ├── stage-2/             # Spec-creator output (Stage 2)
    ├── stage-3/             # Implementer output (Stage 3)
    ├── stage-4/             # Test writer output (Stage 4)
    ├── stage-4.5/           # Codebase stats output (Stage 4.5)
    ├── stage-5/             # Validator output (Stage 5)
    └── stage-6/             # Documentor output (Stage 6)
```

The auto-orchestrate loop reads `proposed-tasks.json` to create tasks on behalf of the orchestrator (which cannot call TaskCreate directly). `checkpoint.json` stores iteration history and task snapshots for crash recovery. All output files use date-prefixed filenames: `YYYY-MM-DD_<descriptor>.<ext>`. Contents are safe to delete between sessions.

## Utilities

### Branch Protection (`protect-branches.sh`)

Manages GitHub branch protection rules and rulesets via the `gh` CLI. Use it to enforce PR-based workflows, restrict who can push to protected branches, and prevent accidental branch deletion.

**Prerequisites:** `gh` CLI >= 2.63.0, `jq`, authenticated via `gh auth login`

**Quick start:**

```bash
# Protect the main branch (require PRs, enforce for admins)
./protect-branches.sh setup-main

# Protect a contributor branch
./protect-branches.sh protect-branch feature/my-feature

# Protect a branch and allow specific users to push (org repos only)
./protect-branches.sh protect-branch feature/my-feature --users alice,bob
```

**Commands:**

| Command | Description |
|---------|-------------|
| `setup-main` | Protect main branch (PR required, admin enforced) |
| `protect-branch <branch> [--users u1,u2]` | Protect a contributor branch, optionally grant push access |
| `grant-access <branch> <user>` | Grant push access to a protected branch (org repos only) |
| `revoke-access <branch> <user>` | Revoke push access from a protected branch (org repos only) |
| `status [branch]` | Show protection status for a branch or the whole repo |
| `help` | Show full usage details |

**Org vs user repos:** Push restrictions (`--users`, `grant-access`, `revoke-access`) are only available for organization-owned repositories. For user-owned repos, the script falls back to PR-only enforcement. The script auto-detects the repo type.

**Repository detection:** The script auto-detects the repository from the current git remote. Override with `REPO=owner/repo`.

**Security:** The script enforces a minimum `gh` CLI version (>= 2.63.0) to mitigate CVE-2024-53858. All inputs are validated against strict patterns to prevent command injection. All API operations are idempotent. See [SECURITY.md](SECURITY.md) for the full security policy.

Run `./protect-branches.sh help` for complete usage details, examples, environment variables, and exit codes.

## Documentation

- **[README.md](README.md)** — Getting started guide (this file)
- **[ARCHITECTURE.md](claude-code/ARCHITECTURE.md)** — System architecture and constraint matrix
- **[INTEGRATION.md](claude-code/INTEGRATION.md)** — Integration patterns and workflows  
- **[PERMISSION-MODES.md](claude-code/PERMISSION-MODES.md)** — Permission model documentation
- **[SECURITY.md](SECURITY.md)** — Security policy and vulnerability reporting
- **[CHANGELOG.md](CHANGELOG.md)** — Version history and release changes
- **[RELEASE-NOTES.md](RELEASE-NOTES.md)** — Latest release notes (v1.0.0)
- **[SECURITY-AUDIT-v1.0.0.md](SECURITY-AUDIT-v1.0.0.md)** — Security audit report for v1.0.0

## Contributing

Contributions are welcome. See **[CONTRIBUTING.md](CONTRIBUTING.md)** for the full guide, including dev setup, skill creation, agent modification, testing, code style, and PR process.

Quick start:

1. Open an issue to discuss the change you'd like to make
2. Fork the repository and create a feature branch
3. Follow the setup steps in CONTRIBUTING.md
4. Submit a pull request with a clear description of the changes

## License

This project is licensed under the [MIT License](LICENSE).
