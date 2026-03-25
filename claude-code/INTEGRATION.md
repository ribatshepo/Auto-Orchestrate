# Claude Code Integration Guide

Step-by-step guide for integrating the plugins system with Claude Code.

**Version**: 1.1.0
**Last Updated**: 2026-03-25

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
./install-claude-config.sh
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

Install all 35 skills, 8 agents, and 3 commands:

```bash
# Create directories if they don't exist
mkdir -p ~/.claude/skills ~/.claude/agents ~/.claude/commands

# Copy all components
cp -r claude-code/skills/* ~/.claude/skills/
cp -r claude-code/_shared ~/.claude/_shared
cp -r claude-code/agents/* ~/.claude/agents/
cp -r claude-code/commands ~/.claude/commands/
cp claude-code/manifest.json ~/.claude/manifest.json
```

> **Note:** The `_shared/` directory contains the shared Python library required by skill scripts. See [Section 11: Python Infrastructure](#11-python-infrastructure) for details:
>
> **Note:** There are two separate `_shared/` directories with different purposes:
> - `claude-code/_shared/` — Protocols, templates, references, style guides, tokens (installed to `~/.claude/_shared/`)
> - `claude-code/skills/_shared/` — Shared Python library for skill scripts (installed automatically with skills to `~/.claude/skills/_shared/`)

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
# List installed agents (should be 8)
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
A default `settings.json` is shipped with the repository at `claude-code/settings.json`. The recommended installation method is `install-claude-config.sh`, which copies it along with all other components. For manual installation, copy it directly:
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
│   ├── orchestrator.md
│   ├── documentor.md
│   ├── epic-architect.md
│   ├── implementer.md
│   ├── session-manager.md
│   ├── researcher.md
│   ├── debugger.md
│   └── auditor.md
├── skills/
│   ├── researcher/
│   │   └── SKILL.md
│   ├── docs-write/
│   │   └── SKILL.md
│   └── ... (35 total)
└── commands/
    ├── auto-orchestrate.md
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
./uninstall-claude-config.sh --dry-run    # Preview what will be removed
./uninstall-claude-config.sh --yes        # Execute removal without prompts
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
| Agents | 8 | `~/.claude/agents/` |
| Commands | 3 | `~/.claude/commands/` |

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
