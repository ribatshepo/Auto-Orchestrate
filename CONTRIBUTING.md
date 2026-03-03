# Contributing to Auto-Orchestrate 

Thank you for your interest in contributing. This guide covers everything you need to get started: dev setup, how to create skills or modify agents, testing, code style, and the PR process.

See [ARCHITECTURE.md](claude-code/ARCHITECTURE.md) for the system architecture and [COOKBOOK.md](claude-code/COOKBOOK.md) for common patterns and recipes.

---

## Table of Contents

1. [Development Setup](#development-setup)
2. [Project Layout](#project-layout)
3. [Creating a New Skill](#creating-a-new-skill)
4. [Modifying an Agent](#modifying-an-agent)
5. [Testing](#testing)
6. [Code Style](#code-style)
7. [Pull Request Process](#pull-request-process)

---

## Development Setup

### Prerequisites

- **Claude Code CLI** — [install guide](https://docs.anthropic.com/en/docs/claude-code)
- **Python 3.10+** — required for skill scripts and tests
- No additional pip packages are required for the core library (stdlib only)

### Clone and install

```bash
git clone https://github.com/ribatshepo/Auto-Orchestrate .git
cd Auto-Orchestrate 
chmod +x install-claude-config.sh
./install-claude-config.sh
```

The installer copies all files from `claude-code/` into `~/.claude/` and backs up your existing config first.

### Verify the installation

```bash
python3 -m pytest claude-code/skills/_shared/python/tests/ -v
```

All tests should pass. If any fail, check that Python 3.10+ is your active interpreter.

### Working locally without reinstalling

After making changes to skill scripts or agent definitions, re-run the installer to push changes into `~/.claude/`. The installer is idempotent and always backs up first.



---

## Project Layout

```
Auto-Orchestrate /
├── install-claude-config.sh     # Copies claude-code/ → ~/.claude/
├── uninstall-claude-config.sh   # Removes ~/.claude/ installed files
└── claude-code/
    ├── agents/                  # Agent definitions (Markdown)
    ├── commands/                # Slash command definitions (Markdown)
    ├── skills/                  # Skill definitions (Markdown + Python scripts)
    │   └── _shared/python/      # Shared Python library (layered)
    │       ├── layer0/          # Foundation (colors, constants, exit codes)
    │       ├── layer1/          # Core utilities (config, file ops, logging)
    │       ├── layer2/          # Mid-level (memory, output format)
    │       ├── layer3/          # High-level (backup, webhooks, hooks)
    │       └── tests/           # pytest test suite (477+ tests)
    ├── _shared/
    │   ├── protocols/           # Agent communication contracts
    │   ├── references/          # Agent-specific reference docs
    │   ├── templates/           # Skill boilerplate and anti-patterns
    │   ├── style-guides/        # Documentation style guide
    │   └── tokens/              # Placeholder token definitions
    ├── manifest.json            # Component registry for agent routing
    └── ARCHITECTURE.md          # Full architecture documentation
```

The shared Python library uses a layered import model. Higher layers may import from lower layers but not vice versa.

---

## Creating a New Skill

Skills are the atomic units of work in the system. Each skill lives in its own directory under `claude-code/skills/<skill-name>/`.

### Minimum required files

```
claude-code/skills/<skill-name>/
├── SKILL.md          # Skill definition (instructions for the AI)
└── scripts/          # Optional: Python scripts invoked by the skill
    └── my_script.py
```

### Step-by-step

1. **Copy the boilerplate** from `claude-code/_shared/templates/skill-boilerplate.md` as a starting point for `SKILL.md`.

2. **Define the skill interface** in `SKILL.md`:
   - What inputs it accepts (task context, file paths, config)
   - What actions it performs
   - What outputs it produces (manifest entry, output file)

3. **Write Python scripts** if the skill needs executable logic. Place them in `scripts/`. Follow the shared library patterns (see `layer0`–`layer3` in `_shared/python/`).

4. **Add tests** for any Python scripts in `claude-code/skills/_shared/python/tests/`. Name the file `test_<skill_name>.py`. See existing tests for patterns.

5. **Register the skill** in `claude-code/manifest.json`. Add an entry under `"skills"` with:
   - `name` — kebab-case skill name
   - `description` — one sentence, plain language
   - `dispatch_triggers` — keywords agents use to route to this skill
   - `path` — relative path to `SKILL.md`

6. **Re-install** to push changes: `./install-claude-config.sh`

### Manifest entry format

```json
{
  "name": "my-skill",
  "description": "One-sentence description of what this skill does.",
  "dispatch_triggers": ["trigger phrase", "another trigger"],
  "path": "skills/my-skill/SKILL.md"
}
```

---

## Modifying an Agent

Agents are defined in `claude-code/agents/<agent-name>.md`. They are Markdown files that describe the agent's role, decision flow, and constraints.

### Guidelines

- **Do not remove constraints** (MAIN-*, IMPL-*, AUTO-* blocks) without understanding their purpose. These gates enforce quality and safety.
- **Update `dispatch_triggers`** in `manifest.json` if you change what the agent responds to.
- **Update ARCHITECTURE.md** if the agent's capabilities or pipeline stage changes.
- **Test the change** by running a real orchestration task and verifying the agent behaves as expected.

### Adding a new agent

1. Create `claude-code/agents/<agent-name>.md` following the structure of an existing agent.
2. Add the agent entry to `manifest.json` under `"agents"`.
3. Update `ARCHITECTURE.md` to document the new agent's role.
4. Re-install: `./install-claude-config.sh`

---

## Testing

The project uses **pytest** for all automated tests.

### Run the full suite

```bash
python3 -m pytest claude-code/skills/_shared/python/tests/ -v
```

### Run a specific test file

```bash
python3 -m pytest claude-code/skills/_shared/python/tests/test_config.py -v
```

### Run tests matching a keyword

```bash
python3 -m pytest claude-code/skills/_shared/python/tests/ -k "backup" -v
```

### Test coverage

All Python functions added to the shared library (`layer0`–`layer3`) must have corresponding tests. Place them in the existing test file for that module, or create `test_<module>.py` if one does not exist.

### What to test

- Happy paths (normal inputs produce expected outputs)
- Error paths (bad inputs raise correct exceptions or return error codes)
- Edge cases (empty inputs, large inputs, concurrent access where relevant)

---

## Code Style

### Python

- Follow **PEP 8** for formatting.
- Use **type hints** for all public functions.
- Write **docstrings** for public functions (one-line summary + parameter/return docs for complex functions).
- Keep functions short — if a function exceeds 40 lines, consider splitting it.
- Use only **standard library** modules. Do not add third-party dependencies to the shared library.
- Import only from the same layer or lower layers. Cross-layer import violations break the layered architecture.

### Markdown (agent definitions, skill docs)

- Follow the style guide at `claude-code/_shared/style-guides/style-guide.md`.
- Use plain, direct language. Avoid "utilize", "leverage", "powerful", "robust".
- Use active voice.
- Keep headings short and descriptive.
- Code examples must be complete and runnable.

### manifest.json

- Keep entries alphabetically sorted within `"agents"` and `"skills"` arrays.
- All string values use double quotes.
- No trailing commas.
- Validate with: `python3 claude-code/skills/_shared/python/validate_manifest.py`

---

## Pull Request Process

1. **Open an issue first** for non-trivial changes to discuss the approach before writing code.

2. **Fork** the repository and create a feature branch:
   ```bash
   git checkout -b feat/my-feature
   ```

3. **Write tests** for any new Python code.

4. **Run the test suite** and make sure all tests pass:
   ```bash
   python3 -m pytest claude-code/skills/_shared/python/tests/ -v
   ```

5. **Validate manifest.json** if you changed it:
   ```bash
   python3 claude-code/skills/_shared/python/validate_manifest.py
   ```

6. **Update documentation** as needed: README.md, ARCHITECTURE.md, or the relevant SKILL.md.

7. **Submit the PR** with:
   - A clear title describing what changed (not what you did)
   - A description explaining *why* the change is needed
   - Reference to the issue number if one exists

8. **Keep PRs focused** — one logical change per PR. Split unrelated changes into separate PRs.

### Commit messages

Use the imperative mood and keep the subject line under 72 characters:

```
Add webhook retry with exponential backoff
Fix config loader ignoring empty values
Update skill-boilerplate with anti-patterns section
```

> **Note:** When using `/auto-orchestrate` or the `dev-workflow` skill, commit messages are generated automatically following conventional commit format. The skill displays copy-pasteable `git add`/`git commit`/`git push` commands but does NOT run them — you review and run the commands yourself.

---

## Questions

If something is unclear, open an issue or start a discussion. The project follows the architecture documented in [ARCHITECTURE.md](claude-code/ARCHITECTURE.md) — reading that first often answers structural questions.
