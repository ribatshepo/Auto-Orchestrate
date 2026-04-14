# Claude Code Integration Guide

Step-by-step guide for integrating the plugins system with Claude Code.

**Version**: 1.2.0
**Last Updated**: 2026-04-06

---

## 1. Prerequisites

Before installing the plugins system, ensure you have:

- **Claude Code CLI** installed and authenticated
  ```bash
  claude --version  # Should show version number
  ```
- **Claude directory exists**: `~/.claude/` (created automatically by Claude Code)
- **Optional**: `jq` for JSON validation
  ```bash
  jq --version  # Optional but recommended
  ```

---

## 2. Quick Start

**Recommended:** Use the install script for a one-command setup:

```bash
./install.sh
```

This installs all skills, agents, commands, shared resources, manifest, and settings in one step.

**Manual alternative** (for selective or custom installs):

```bash
# Install skills (auto-discovered by Claude Code)
cp -r claude-code/skills/* ~/.claude/skills/

# Install agents (flat .md files)
cp -r claude-code/agents/* ~/.claude/agents/

# Install commands
cp -r claude-code/commands ~/.claude/commands/

# Install manifest (required for orchestrator routing)
cp claude-code/manifest.json ~/.claude/manifest.json

# Install settings
cp claude-code/settings.json ~/.claude/settings.json
```

Verify installation:

```bash
ls ~/.claude/skills/ ~/.claude/agents/ ~/.claude/commands/
```

After installation, components are immediately available:
- Skills trigger automatically based on their `triggers:` array
- Agents are available via the Task tool
- Commands are available as slash commands (e.g., `/workflow-start`, `/workflow-dash`)

> For detailed verification steps, see [Section 4: Verification](#4-verification).

---

## 3. Installation Methods

### 3.1 Full Installation

Install all 35 skills, 16 agents, and 14 commands:

```bash
# Create directories if they don't exist
mkdir -p ~/.claude/skills ~/.claude/agents ~/.claude/commands

# Copy all components
cp -r claude-code/skills/* ~/.claude/skills/
cp -r claude-code/_shared ~/.claude/_shared
cp -r claude-code/agents/* ~/.claude/agents/
cp -r claude-code/commands ~/.claude/commands/
cp -r claude-code/lib ~/.claude/lib
cp claude-code/manifest.json ~/.claude/manifest.json
```

> **Note:** There are three key shared directories:
> - `claude-code/_shared/` — Protocols, templates, references, style guides, tokens (installed to `~/.claude/_shared/`)
> - `claude-code/skills/_shared/` — Shared Python library for skill scripts (installed automatically with skills to `~/.claude/skills/_shared/`)
> - `claude-code/lib/` — CI engine and domain memory libraries (installed to `~/.claude/lib/`)

```bash
cp -r claude-code/_shared ~/.claude/_shared
```

### 3.2 Selective Installation

Install only specific categories based on your needs:

**Documentation skills only:**
```bash
cp -r claude-code/skills/docs-lookup ~/.claude/skills/
cp -r claude-code/skills/docs-write ~/.claude/skills/
cp -r claude-code/skills/docs-review ~/.claude/skills/
cp claude-code/agents/documentor.md ~/.claude/agents/
```

**Research and analysis skills:**
```bash
cp -r claude-code/skills/researcher ~/.claude/skills/
cp -r claude-code/skills/codebase-stats ~/.claude/skills/
cp -r claude-code/skills/dependency-analyzer ~/.claude/skills/
cp -r claude-code/skills/security-auditor ~/.claude/skills/
```

**Testing skills:**
```bash
cp -r claude-code/skills/test-writer-pytest ~/.claude/skills/
cp -r claude-code/skills/test-gap-analyzer ~/.claude/skills/
cp -r claude-code/skills/validator ~/.claude/skills/
```

**Implementation skills:**
```bash
cp -r claude-code/skills/task-executor ~/.claude/skills/
cp -r claude-code/skills/library-implementer-python ~/.claude/skills/
cp claude-code/agents/implementer.md ~/.claude/agents/
```

**Debugging subsystem:**
```bash
cp -r claude-code/skills/debug-diagnostics ~/.claude/skills/
cp claude-code/agents/debugger.md ~/.claude/agents/
cp claude-code/commands/auto-debug.md ~/.claude/commands/
```

**Audit subsystem:**
```bash
cp -r claude-code/skills/spec-compliance ~/.claude/skills/
cp claude-code/agents/auditor.md ~/.claude/agents/
cp claude-code/commands/auto-audit.md ~/.claude/commands/
```

### 3.3 Development Mode (Symlinks)

For active development, use symlinks to edit skills in place:

```bash
# Skills (symlink each directory)
for skill in claude-code/skills/*/; do
    ln -sf "$(pwd)/$skill" ~/.claude/skills/
done

# Agents (symlink each file)
for agent in claude-code/agents/*.md; do
    ln -sf "$(pwd)/$agent" ~/.claude/agents/
done

# Commands (symlink entire directory)
ln -sf "$(pwd)/claude-code/commands" ~/.claude/commands
```

**Benefits of symlinks:**
- Edit skills in your project, changes reflect immediately
- Version control friendly (edit in repo, not in `~/.claude`)
- Easy to test changes without reinstalling

**Note:** Symlinks require absolute paths. The `$(pwd)` ensures full paths are used.

---

## 4. Verification

### 4.1 Skills Verification

```bash
# Count installed skills (should be 35)
ls -d ~/.claude/skills/*/ 2>/dev/null | wc -l

# Verify each skill has SKILL.md
for dir in ~/.claude/skills/*/; do
    if [[ ! -f "$dir/SKILL.md" ]]; then
        echo "Missing: $dir/SKILL.md"
    fi
done

# Check a skill's frontmatter
head -20 ~/.claude/skills/researcher/SKILL.md
```

Expected output for frontmatter:
```yaml
---
name: researcher
description: |
  Research and investigation skill for gathering information from multiple sources.
  Use when user says "research", "investigate", "gather information", "look up",
  "find out about", "analyze topic", "explore options", "survey alternatives",
  "collect data on", "background research", "discovery", "fact-finding",
  "information gathering", "due diligence", "explore requirements".
triggers:
  - research
  - investigate
  - gather information
  - look up
  - find out about
  - analyze topic
  - explore options
---
```

### 4.2 Agents Verification

```bash
# List installed agents (should be 16)
ls ~/.claude/agents/*.md

# Verify agent frontmatter exists
for agent in ~/.claude/agents/*.md; do
    if ! head -5 "$agent" | grep -q "^---"; then
        echo "Missing frontmatter: $agent"
    fi
done

# Check an agent's frontmatter
head -15 ~/.claude/agents/orchestrator.md
```

### 4.3 Commands Verification

```bash
# List available commands
ls ~/.claude/commands/
```

Expected structure:
```
commands/
├── auto-orchestrate.md
├── active-dev.md
├── agent-capabilities.md
├── assign-agent.md
├── gate-review.md
├── new-project.md
├── org-ops.md
├── post-launch.md
├── process-lookup.md
├── release-prep.md
├── sprint-ceremony.md
├── workflow.md
├── auto-debug.md
└── auto-audit.md
```

### 4.4 Quick Test

Test that components are functional:

```bash
# In Claude Code, try:
# /workflow-start     # Should display task overview
# /workflow-dash      # Should show project dashboard
# /auto-orchestrate   # Should start autonomous orchestration loop
```

If commands aren't recognized, verify the commands directory exists:
```bash
ls -la ~/.claude/commands/
```

---

## 5. Configuration

### 5.1 Skill Triggers

Customize when skills activate by editing their `triggers:` array in frontmatter:

```yaml
# ~/.claude/skills/researcher/SKILL.md
---
name: researcher
triggers:
  - research
  - investigate
  - gather information
  - explore topic       # Add custom triggers
  - deep dive into
---
```

### 5.2 Agent Model Selection

Agents specify their model in frontmatter. To change an agent's model:

```yaml
# ~/.claude/agents/implementer.md
---
name: implementer
model: opus           # Change from 'sonnet' for complex tasks
tools: Read, Write, Edit, Bash, Glob, Grep
---
```

**Model guidance:**
| Model | Best For |
|-------|----------|
| `haiku` | Simple, quick tasks |
| `sonnet` | Balanced performance (default) |
| `opus` | Complex reasoning, large codebases |

### 5.3 Output Directory Configuration

Skills write outputs using token placeholders. Override defaults by setting these in your project's `.claude/settings.json`:

```json
{
  "plugins": {
    "outputDir": "docs/generated",
    "manifestPath": "docs/generated/MANIFEST.jsonl"
  }
}
```

Default values (if not configured):
- `{{OUTPUT_DIR}}`: `claudedocs/research-outputs`
- `{{MANIFEST_PATH}}`: `{{OUTPUT_DIR}}/MANIFEST.jsonl`

### 5.4 Permissions for Autonomous Operation

The plugins system requires broad tool permissions so agents and skills can operate without prompting the user on every tool call. A `settings.json` file configures these permissions.

**Install:**
A default `settings.json` is shipped with the repository at `claude-code/settings.json`. The recommended installation method is `install.sh`, which copies it along with all other components. For manual installation, copy it directly:
```bash
cp claude-code/settings.json ~/.claude/settings.json
```

**What it configures:**

| Rule | Type | Purpose |
|------|------|---------|
| `Bash` | Allow | Agents and skills run shell commands (git, python, jq, etc.) |
| `Write` | Allow | Unscoped write — ensures subagents can write regardless of path resolution |
| `Edit` | Allow | Unscoped edit — ensures subagents can edit regardless of path resolution |
| `Read(~/.claude/**)` | Allow | Read plugin config, sessions, and manifests |
| `Write(~/.claude/**)` | Allow | Write session data, checkpoints, and manifests |
| `Read(/tmp/**)` | Allow | Read temporary files used during skill execution |
| `Write(/tmp/**)` | Allow | Write temporary files used during skill execution |
| `Read(./**)` | Allow | Read project files relative to working directory |
| `Write(./**)` | Allow | Write project files relative to working directory |
| `Write(/etc/**)`, `Write(/bin/**)`, ... | Deny | Block writes to system directories (14 paths) |
| `Bash(rm *)`, `Bash(kill *)`, ... | Deny | Block destructive shell commands (100+ patterns) |

> **Why bare `Write` and `Edit`?** Subagents spawned via the Task tool resolve file paths to absolute paths (e.g., `/home/user/project/file.ts`). Path-scoped rules like `Write(./**)` use relative globs that don't match these absolute paths, causing silent permission denial under `defaultMode: "dontAsk"`. The bare `Write` and `Edit` entries act as a catch-all so subagents are never blocked. The deny list still protects system directories since **deny rules take precedence over allow rules**.

> **Security note:** The allow rules are intentionally broad to support autonomous orchestration. The extensive deny list (system directories + destructive commands) provides the safety boundary. If you prefer tighter controls, edit `~/.claude/settings.json` after installation.

> **Without these permissions**, Claude Code will prompt for confirmation on every `Bash`, `Write`, and `Edit` tool invocation, making autonomous orchestration impractical.

---

## 6. Directory Structure Reference

| Source | Destination | Purpose |
|--------|-------------|---------|
| `claude-code/skills/*` | `~/.claude/skills/` | Auto-discovered skill directories |
| `claude-code/agents/*` | `~/.claude/agents/` | Agent definition files |
| `claude-code/commands/` | `~/.claude/commands/` | Slash command files |
| `claude-code/manifest.json` | `~/.claude/manifest.json` | Agent/skill routing registry |

### Claude Code Directory Layout

After installation, your `~/.claude/` should look like:

```
~/.claude/
├── settings.json
├── manifest.json
├── agents/
│   ├── orchestrator.md          ← orchestration core
│   ├── researcher.md            ← orchestration core
│   ├── session-manager.md       ← orchestration core
│   ├── cloud-engineer.md        ← team agent
│   ├── data-engineer.md         ← team agent
│   ├── engineering-manager.md   ← team agent
│   ├── ml-engineer.md           ← team agent
│   ├── platform-engineer.md     ← team agent
│   ├── product-manager.md       ← team agent
│   ├── qa-engineer.md           ← team agent
│   ├── security-engineer.md     ← team agent
│   ├── software-engineer.md     ← team agent
│   ├── sre.md                   ← team agent
│   ├── staff-principal-engineer.md ← team agent
│   ├── technical-program-manager.md ← team agent
│   └── technical-writer.md      ← team agent
├── skills/
│   ├── researcher/
│   │   └── SKILL.md
│   ├── docs-write/
│   │   └── SKILL.md
│   └── ... (35 total)
└── commands/
    ├── auto-orchestrate.md
    ├── active-dev.md
    ├── agent-capabilities.md
    ├── assign-agent.md
    ├── gate-review.md
    ├── new-project.md
    ├── org-ops.md
    ├── post-launch.md
    ├── process-lookup.md
    ├── release-prep.md
    ├── sprint-ceremony.md
    ├── workflow.md
    ├── auto-debug.md
    └── auto-audit.md
```

---

## 7. Updating & Uninstalling

### 7.1 Updating Components

**Backup and update (recommended):**
```bash
# Backup existing installation
cp -r ~/.claude/skills ~/.claude/skills.backup
cp -r ~/.claude/agents ~/.claude/agents.backup

# Update with fresh copy
cp -r claude-code/skills/* ~/.claude/skills/
cp -r claude-code/agents/* ~/.claude/agents/
cp -r claude-code/commands ~/.claude/commands/
cp claude-code/manifest.json ~/.claude/manifest.json
```

**Update specific skill:**
```bash
cp -r claude-code/skills/researcher ~/.claude/skills/
```

### 7.2 Uninstalling

**Uninstall all components (recommended):**
```bash
./uninstall.sh --dry-run    # Preview what will be removed
./uninstall.sh --yes        # Execute removal without prompts
```

**Manual alternative (all components):**
```bash
rm -rf ~/.claude/skills/*
rm -rf ~/.claude/agents/*
rm -rf ~/.claude/commands
```

**Uninstall specific skill:**
```bash
rm -rf ~/.claude/skills/researcher
```

**Uninstall specific agent:**
```bash
rm ~/.claude/agents/documentor.md
```

---

## 8. Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Skill not triggering | Missing or incorrect triggers | Check `triggers:` array in SKILL.md frontmatter |
| Unknown slash command | Command not installed correctly | Verify `~/.claude/commands/auto-orchestrate.md` exists |
| Permission denied | File permissions | Run `chmod -R u+rw ~/.claude/` |
| Agent not found | Missing agent file | Verify `.md` file exists in `~/.claude/agents/` |
| Symlink not working | Relative path used | Use absolute paths: `ln -sf $(pwd)/path ~/.claude/target` |
| Command exists but fails | Corrupted command file | Re-copy: `cp claude-code/commands/auto-orchestrate.md ~/.claude/commands/` |
| Constant permission prompts | Missing tool permissions | Create `~/.claude/settings.json` with appropriate permissions |

### Common Fixes

**Skills not auto-discovering:**
```bash
# Ensure SKILL.md (not skill.md) exists
ls ~/.claude/skills/*/SKILL.md

# Check for valid YAML frontmatter
head -10 ~/.claude/skills/researcher/SKILL.md | grep -A5 "^---"
```

**Commands not appearing:**
```bash
# Verify commands directory exists
ls -la ~/.claude/commands/
```

**Reset to clean state:**
```bash
# Remove all plugin components
rm -rf ~/.claude/skills/* ~/.claude/agents/* ~/.claude/commands

# Fresh install
cp -r claude-code/skills/* ~/.claude/skills/
cp -r claude-code/agents/* ~/.claude/agents/
cp -r claude-code/commands ~/.claude/commands/
```

---

## 9. Next Steps

After successful installation:

1. **Start a session**: Run `/workflow-start` in Claude Code to see task overview
2. **View dashboard**: Run `/workflow-dash` to see project status
3. **Invoke a skill**: Ask Claude to "research [topic]" to trigger the researcher skill
4. **Read the docs**:
   - [ARCHITECTURE.md](ARCHITECTURE.md) - Detailed system architecture

### Typical First Session

```
You: /workflow-start
Claude: [Displays task overview and suggests focus]

You: /workflow-dash
Claude: [Shows project dashboard grouped by status]

You: research the authentication patterns in this codebase
Claude: [Researcher skill activates, writes findings to manifest]

You: /workflow-end
Claude: [Summarizes session progress]
```

---

## 10. Reference

### Installed Components Summary

| Category | Count | Location |
|----------|-------|----------|
| Skills | 35 | `~/.claude/skills/` |
| Agents | 16 | `~/.claude/agents/` |
| Commands | 14 | `~/.claude/commands/` |

### Skill Categories

| Category | Skills |
|----------|--------|
| Documentation | docs-lookup, docs-write, docs-review |
| Testing | test-writer-pytest, test-gap-analyzer, validator |
| Research | researcher, dependency-analyzer, codebase-stats, security-auditor |
| Implementation | task-executor, spec-creator, library-implementer-python, schema-migrator, dev-workflow |
| Refactoring | refactor-executor, hierarchy-unifier, error-standardizer |
| DevOps | production-code-workflow, docker-workflow, spec-analyzer, cicd-workflow |
| Utility | skill-creator, skill-lookup, python-venv-manager |

### Available Commands

| Command | Purpose |
|---------|---------|
| `/workflow-start` | Start work session |
| `/workflow-end` | End work session |
| `/workflow-dash` | Project dashboard |
| `/workflow-focus` | Set/show task focus |
| `/workflow-next` | Get next task suggestion |
| `/workflow-plan` | Plan mode manager |
| `/auto-orchestrate` | Autonomous orchestration loop |
| `/new-project` | Guide 4-stage organizational pipeline (Intent → Scope → Dependencies → Sprint) |
| `/gate-review` | Run gate checklist and record gate passage state |
| `/sprint-ceremony` | Sprint retrospective and close |
| `/assign-agent` | Route a task to the appropriate team agent |
| `/active-dev` | Active development phase management |
| `/agent-capabilities` | Discover available agent capabilities |
| `/org-ops` | Organizational operations and reporting |
| `/post-launch` | Post-launch operations and monitoring |
| `/process-lookup` | Look up processes by category or ID |
| `/release-prep` | Release preparation checklist and automation |
| `/workflow` | Workflow overview and navigation |
| `/auto-debug` | Autonomous cyclic error-fix-verify loop |
| `/auto-audit` | Autonomous spec compliance audit-remediate loop |

---

## 11. Python Infrastructure

The plugins system includes Python scripts that power skill automation. These require the shared library to be available.

### 11.1 Directory Overview

| Folder | Purpose | Installation |
|--------|---------|--------------|
| `skills/_shared/python/` | Shared Python library (layered utilities) | Included with skills |
| `_shared/protocols/` | Communication contracts (RFC 2119 specs) | Included with shared |
| `_shared/templates/` | Skill boilerplate and anti-patterns | Included with shared |

### 11.2 Library Architecture

The `skills/_shared/python/` folder uses a layered dependency architecture:

```
skills/_shared/python/
├── layer0/    # Zero-dependency (constants, colors, exit_codes)
├── layer1/    # Basic utilities (logging, config, file_ops)
├── layer2/    # Business logic (validation, task_ops)
└── layer3/    # Orchestration (migrate, backup, doctor)
```

Each layer can only import from layers below it.

### 11.3 How Skills Use the Library

Skill scripts import via the `_shared/python/` path:

```python
# In skills/*/scripts/*.py
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "_shared" / "python"))
from layer0 import EXIT_SUCCESS, EXIT_ERROR
from layer1 import emit_error, output
```

The `skills/_shared/python/` directory contains the layer directories directly (not symlinks):

```
skills/_shared/python/
├── layer0/
├── layer1/
├── layer2/
└── layer3/
```

### 11.4 Installation (Skills with Scripts)

When installing skills, the `_shared/` directory must also be copied:

```bash
# Standard installation (includes skills/_shared/python/)
cp -r claude-code/skills/* ~/.claude/skills/
cp -r claude-code/_shared ~/.claude/_shared
```

Or with symlinks for development:

```bash
ln -sf $(pwd)/claude-code/_shared ~/.claude/_shared
```

### 11.5 Development Notes

The Python library lives entirely within `skills/_shared/python/`. There are no separate `dev/`, `scripts/`, or `tests/` directories in this repository. To create new skills, use the `skill-creator` skill or manually follow the template in `_shared/templates/skill-boilerplate.md`.

### 11.6 Verification

Test that Python imports work:

```bash
# From the claude-code directory
cd claude-code
python3 -c "
import sys
from pathlib import Path
sys.path.insert(0, str(Path('skills/_shared/python')))
from layer0.exit_codes import EXIT_SUCCESS
print(f'Import successful: EXIT_SUCCESS = {EXIT_SUCCESS}')
"
```

Expected output:
```
Import successful: EXIT_SUCCESS = 0
```

---

## 12. Organizational Workflow Integration

**Added**: 2026-04-06 (Session: auto-orc-20260406-gapintg, gap remediation)

The auto-orchestrate system integrates with a human-facing organizational workflow pipeline via the **bridge protocol**. This enables projects scoped in `/new-project` to flow into `/auto-orchestrate` without manual re-entry of project context.

### 12.1 Commands Overview

| Command | Purpose | Integration Point |
|---------|---------|-------------------|
| `/new-project` | Guide 4-stage org pipeline (Intent → Scope → Dependencies → Sprint) | Phase 5: hands off to /auto-orchestrate |
| `/gate-review` | Run gate checklist, write gate state | Writes `.orchestrate/{session_id}/gate-state.json` |
| `/auto-orchestrate` | 7-stage autonomous implementation pipeline | Reads handoff receipt, produces Stage 6 artifacts |
| `/sprint-ceremony` | Sprint retrospective and close | Reads Stage 6 artifacts; requires Gate 4 passed |

### 12.2 Using the Bridge Protocol

**Step 1**: Complete the organizational pipeline via `/new-project` through at least Gate 2 (Scope Lock).

**Step 2**: After Gate 4 (Sprint Readiness) — or Gate 2 for early handoff — Phase 5 automatically:
1. Extracts `task_description` from the Scope Contract artifact
2. Generates a `session_id`: `"auto-orc-YYYYMMDD-{project_slug}"`
3. Writes a handoff receipt to `.orchestrate/{session_id}/handoff-receipt.json`
4. Launches: `/auto-orchestrate "{task_description}" --scope {F|B|S} --session_id {session_id}`

**Reference**: `claude-code/processes/bridge_protocol.md`

### 12.3 Gate State File

The gate state file tracks organizational gate passage and enforces stage sequencing:

**Path**: `.orchestrate/{session_id}/gate-state.json`  
**Schema**: `claude-code/processes/gate_state_schema.json` (JSON Schema Draft-7)  
**Created by**: `/gate-review` on first use for a session  
**Read by**: `/new-project`, `/gate-review`, `/sprint-ceremony`  
**Written by**: `/gate-review` only

**Initialization**: When `/gate-review` is first invoked for a session without a gate-state.json, it creates the file with all 4 gates at `status: "pending"`. Template in `claude-code/processes/gate_enforcement_spec.md` — Initialization section.

**Valid transitions per gate**:
```
pending → in_review → passed
              └──→ failed → in_review (retry permitted)
```

**Gate checks in /new-project** (GATE-BLOCK errors block stage advancement):
- Before Stage 2 (Scope Contract): `gate_1_intent_review.status == "passed"`
- Before Stage 3 (Dependency Coordination): `gate_2_scope_lock.status == "passed"`
- Before Stage 4 (Sprint Bridge): `gate_3_dependency_acceptance.status == "passed"`
- Before /sprint-ceremony: `gate_4_sprint_readiness.status == "passed"`

**Override**: Include `override` object with `reason` (≥10 chars), `authorized_by`, and `timestamp` to waive enforcement for a single gate.

### 12.4 Deferred Handoff

If `/auto-orchestrate` is unavailable at handoff time:

1. Phase 5 writes the handoff receipt with `auto_orchestrate_status: "deferred"`
2. Team proceeds with manual implementation sprint
3. Resume later: `/auto-orchestrate c --session_id {session_id}` — reads the handoff receipt to restore full context

### 12.5 Return Path

After `/auto-orchestrate` completes Stage 6:
1. Update `handoff-receipt.json`: set `auto_orchestrate_status: "completed"`
2. Link Stage 6 documentation to the project record
3. Present Stage 5 validation report as sprint completion evidence
4. Run `/sprint-ceremony` to close the sprint

**Artifact locations**:
- Stage 6 docs: `.orchestrate/{session_id}/stage-6/`
- Stage 5 validation: `.orchestrate/{session_id}/stage-5/`

### 12.6 Process Injection Points

The process injection map (`claude-code/processes/process_injection_map.md`) defines advisory hooks at each auto-orchestrate stage for organizational process alignment. All hooks are advisory (non-blocking) in V1 except P-038 (Security by Design) at Stage 2, which is enforced.

Hook log format: `[PROCESS-INJECT] Stage {N} ({event}): {process_ids} — {action_detail}`

For processes with no pipeline home (sprint planning, dependency coordination, onboarding), process stubs in `claude-code/processes/process_stubs/` provide minimal documentation and manual engagement guidance.

### 12.7 install.sh Safety Note

Three agents are dual-defined (runtime `~/.claude/agents/` + source `claude-code/agents/`): researcher, session-manager, orchestrator. Before any `install.sh` run that touches agent files, verify checksums:

```bash
md5sum ~/.claude/agents/orchestrator.md claude-code/agents/orchestrator.md
# Both MUST match. orchestrator.md (32479 bytes) IS the live system prompt.
# Divergence breaks the entire auto-orchestrate pipeline.
```

See `claude-code/agents/agent-reconciliation-notes.md` for the recommended install.sh guard script and full checksum table.

---

## 13. Team Agent Installation

**Added**: 2026-04-06 (Session: auto-orc-20260406-gapintg, gap remediation)

The system includes 13 team agents covering the full organizational engineering role hierarchy. These agents are distinct from the 3 orchestration-core agents (orchestrator, researcher, session-manager) — they model specific human engineering roles and are used to route tasks to a domain-appropriate AI collaborator.

### 13.1 Team Agent Roster

| Agent | Role Coverage | Model | Key Skills |
|-------|--------------|-------|------------|
| `cloud-engineer` | Cloud Engineer (AWS/Azure/GCP), Cloud Architect | sonnet | researcher, dependency-analyzer |
| `data-engineer` | Data Engineer, Analytics Engineer, Data Platform | opus | library-implementer-python, schema-migrator, python-venv-manager, production-code-workflow, test-writer-pytest |
| `engineering-manager` | Engineering Manager, Director, VP Engineering, CTO | sonnet | spec-analyzer, task-executor, workflow-dash |
| `ml-engineer` | ML Engineer, MLOps Engineer, AI Engineer | opus | library-implementer-python, python-venv-manager, docker-workflow, test-writer-pytest, production-code-workflow |
| `platform-engineer` | Platform Engineer, DevOps Engineer, Infrastructure | opus | cicd-workflow, dev-workflow, docker-workflow, docker-validator, validator |
| `product-manager` | Product Manager, GPM, Associate PM | sonnet | spec-analyzer, spec-creator, task-executor |
| `qa-engineer` | QA Engineer, SDET, Performance Engineer | sonnet | test-writer-pytest, test-gap-analyzer, spec-compliance, codebase-stats |
| `security-engineer` | AppSec Engineer, Security Engineer, Cloud Security | opus | security-auditor, debug-diagnostics, researcher |
| `software-engineer` | Software Engineer L3–L5, Tech Lead | opus | production-code-workflow, dev-workflow, refactor-analyzer, refactor-executor, test-writer-pytest, codebase-stats |
| `sre` | Site Reliability Engineer, Platform SRE | sonnet | docker-workflow, docker-validator, validator, error-standardizer |
| `staff-principal-engineer` | Staff Engineer L6, Principal L7, Distinguished L8, Fellow | sonnet | hierarchy-unifier, dependency-analyzer, codebase-stats, researcher |
| `technical-program-manager` | TPM, Release Manager, Program Manager | sonnet | task-executor, dependency-analyzer, spec-analyzer |
| `technical-writer` | Technical Writer, Documentation Lead | sonnet | docs-lookup, docs-write, docs-review |

### 13.2 Installation via install.sh

All 13 team agents are installed automatically by `install.sh` — no extra flags required:

```bash
./install.sh
```

The script copies all `.md` files from `claude-code/agents/` to `~/.claude/agents/`, including all team agents.

**Dry-run / verify before installing:**

```bash
./install.sh --check
```

The `--check` flag shows what would be installed or updated without making any changes to `~/.claude/`. Use this to audit the current installation state or verify after a git pull.

**Manual install (team agents only):**

```bash
# Install all team agents
for agent in cloud-engineer data-engineer engineering-manager ml-engineer \
             platform-engineer product-manager qa-engineer security-engineer \
             software-engineer sre staff-principal-engineer \
             technical-program-manager technical-writer; do
    cp "claude-code/agents/${agent}.md" ~/.claude/agents/
done
```

### 13.3 Verifying Team Agent Installation

```bash
# Total agent count (should be 16)
ls ~/.claude/agents/*.md | wc -l

# List all installed agents
ls ~/.claude/agents/*.md | xargs -I{} basename {}

# Verify a specific team agent
head -10 ~/.claude/agents/software-engineer.md
```

Expected: 16 agent files total (3 orchestration-core + 13 team agents).

> **Note on legacy agents**: The runtime may also contain `auditor.md`, `debugger.md`, `documentor.md`, `epic-architect.md`, and `implementer.md` from previous installations. These are legacy orchestration-pipeline subagents and remain functional. They are not counted in the 16 team/core agents above since they live in `~/.claude/agents/` but are not currently in `claude-code/agents/`.

> **Manifest completeness**: As of 2026-04-09, `manifest.json` includes all 16 agents and all 14 commands in its `agents[]` and `commands[]` arrays (plus all 35 skills). This ensures full orchestrator routing coverage — every agent can be dispatched by `dispatch_triggers`, and every command is registered for discovery. Verify with: `python3 -c "import json; m=json.load(open('claude-code/manifest.json')); print('agents:', len(m['agents']), '| commands:', len(m['commands']), '| skills:', len(m['skills']))"`

### 13.4 Routing Tasks with /assign-agent

The `/assign-agent` command routes a task description to the most appropriate team agent:

```
/assign-agent "Review the Terraform plan for the new VPC peering setup"
```

The command:
1. Reads the task description
2. Matches against agent role coverage and key skills
3. Recommends the best-fit agent (e.g., `cloud-engineer` for the example above)
4. Optionally spawns the agent immediately if `--spawn` flag is provided

**Common routing examples:**

| Task Type | Routed Agent |
|-----------|-------------|
| Production code implementation | `software-engineer` |
| CI/CD pipeline changes | `platform-engineer` |
| Data pipeline or ETL work | `data-engineer` |
| Model training or ML inference | `ml-engineer` |
| Security review or threat model | `security-engineer` |
| Test plan or test automation | `qa-engineer` |
| API documentation | `technical-writer` |
| Sprint planning or OKR alignment | `engineering-manager` |
| Release coordination | `technical-program-manager` |
| Cross-cutting architectural decision | `staff-principal-engineer` |
| Product requirements or user stories | `product-manager` |
| SLO/SLA or on-call response | `sre` |
| Cloud cost or multi-cloud strategy | `cloud-engineer` |

---

## 14. Process Injection Enforcement Roadmap

**Added**: 2026-04-06 (Session: auto-orc-20260406-gapintg, gap remediation)

The process injection map (`claude-code/processes/process_injection_map.md`) defines 8 hooks that fire at specific auto-orchestrate pipeline events, aligning the autonomous implementation pipeline with the organization's 93-process framework.

### 14.1 What the Process Injection Map Does

At each pipeline stage (0 through 6) and at run completion, the injection map specifies which organizational processes should be engaged. Each hook emits a log line:

```
[PROCESS-INJECT] Stage {N} ({event}): {process_ids} — {action_detail}
```

This provides an audit trail of which organizational processes were applied during each autonomous run, supporting compliance, retrospectives, and process improvement.

### 14.2 V1 State: Advisory Hooks with One Enforced Exception

In V1 (current), **all 8 stage hooks are advisory (non-blocking)** — the pipeline continues regardless of whether the process was followed. The one exception is **P-038 (Security by Design)** at Stage 2, which is **enforced (blocking)**.

**Hook enforcement state (V1):**

| Stage | Event | Process IDs | Enforcement |
|-------|-------|-------------|-------------|
| Stage 0 | before | P-061, P-062 (Research standards) | Advisory |
| Stage 1 | before | P-001, P-002 (Epic decomposition) | Advisory |
| Stage 2 | before | **P-038** (Security by Design) | **ENFORCED — blocks if not acknowledged** |
| Stage 2 | before | P-010, P-011 (Spec standards) | Advisory |
| Stage 3 | before | P-020 through P-025 (Implementation standards) | Advisory |
| Stage 4 | before | P-030 through P-033 (Testing standards) | Advisory |
| Stage 5 | before | P-040 through P-043 (Validation standards) | Advisory |
| Stage 6 | before | P-050 through P-052 (Documentation standards) | Advisory |
| Run complete | after | P-070 (Retrospective) | Advisory |

### 14.3 Why P-038 Is the Only Enforced Hook

Security by Design (P-038) is enforced at Stage 2 because security requirements identified after the specification phase are significantly more expensive to remediate. The spec is the last point before implementation where security constraints can be incorporated at zero cost. All other process hooks are positioned as advisory because V1 prioritizes adoption over enforcement — teams should build familiarity with the process framework before enforcement gates are added.

### 14.4 V2 Enforcement Roadmap

Additional hooks may be promoted to enforced in V2 under the following conditions:

1. **Adoption threshold**: The candidate process shows voluntary compliance rate >80% for 3 consecutive sprints across all teams using auto-orchestrate. This is measured via the `[PROCESS-INJECT]` audit log.
2. **Retrospective confirmation**: At least 2 sprint retrospectives have identified the process as adding measurable value (reduced defects, faster delivery, or improved handoff quality).
3. **Team approval**: Engineering leadership sign-off confirming the enforcement will not block critical hotfix or incident response flows.

**Processes most likely to be promoted in V2** (based on voluntary compliance data):
- P-001 (Epic decomposition standards) — Stage 1
- P-030 (Test coverage requirements) — Stage 4
- P-050 (Documentation completeness) — Stage 6

The V2 enforcement promotion mechanism is documented in `claude-code/processes/process_injection_map.md` under the "Enforcement Policy" section.

### 14.5 Process Stubs for Uncovered Workflows

Three organizational processes have no natural home in the auto-orchestrate pipeline (they are human-team workflows, not automatable stages):

| Process | Stub File | Engagement Method |
|---------|-----------|-------------------|
| Sprint Planning | `process_stubs/sprint_planning_stub.md` | Manual — run before /auto-orchestrate |
| Dependency Coordination | `process_stubs/dependency_coordination_stub.md` | Manual — run after /gate-review Gate 3 |
| Team Onboarding | `process_stubs/onboarding_stub.md` | Manual — run once per new team member |

These stubs provide minimal documentation and manual engagement guidance to prevent process gaps during the transition to the full organizational workflow system.

**Reference**: `claude-code/processes/process_injection_map.md`
