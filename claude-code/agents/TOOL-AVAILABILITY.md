> **REDIRECT NOTICE**: This file is a secondary copy. The canonical version of this document
> is maintained at `_shared/references/TOOL-AVAILABILITY.md`. Please refer to that file
> for the most up-to-date tool availability constraints and workarounds.

---

# Tool Availability Constraints for Claude Code Agents

## Overview

Tool availability in Claude Code is determined by the **built-in agent type definitions**, NOT by manifest.json declarations. The manifest documents intended tool usage but does not grant tool access at runtime.

**Critical distinction**: The `Task` tool (spawns subagents) is a DIFFERENT tool from `TaskCreate`/`TaskList`/`TaskUpdate`/`TaskGet` (task management). These are separate tools with separate availability.

## The Gap (GAP-CRIT-001) — OPEN

**Problem**: Subagents spawned via `Task(subagent_type: "...")` receive a LIMITED set of tools defined by Claude Code's built-in agent type registry. Critically:

1. **Task tool**: Listed in agent type definitions but **NOT reliably available at runtime** when spawned by auto-orchestrate. The orchestrator has confirmed it cannot spawn subagents.
2. **TaskCreate/TaskList/TaskUpdate/TaskGet**: These task management tools are **NEVER available** to any subagent. They are only available to the main Claude Code instance (the auto-orchestrate loop).

**Root Cause**: Claude Code's built-in agent type definitions declare tools that may not be provisioned at runtime depending on the spawn context, permission mode, and conversation state. The manifest.json mirrors these declarations but neither document controls actual runtime availability.

**Status**: OPEN — Workaround implemented via file-based task proposal protocol.

## Tool Availability Matrix (Actual Runtime)

| Agent | Declared Tools | Actually Available | NOT Available |
|-------|---------------|-------------------|---------------|
| orchestrator | Read, Glob, Grep, Bash, Task | Read, Glob, Grep, Bash | Task*, TaskCreate, TaskList, TaskUpdate, TaskGet |
| epic-architect | Read, Glob, Grep, Bash, Task | Read, Glob, Grep, Bash | Task*, TaskCreate, TaskList, TaskUpdate, TaskGet |
| implementer | Read, Write, Edit, Bash, Glob, Grep, Task | Read, Write, Edit, Bash, Glob, Grep | Task*, TaskCreate, TaskList, TaskUpdate, TaskGet |
| documentor | Read, Glob, Grep, Edit, Write, Task | Read, Glob, Grep, Edit, Write | Task*, TaskCreate, TaskList, TaskUpdate, TaskGet |
| session-manager | Read, Glob, Grep, Bash, Task | Read, Glob, Grep, Bash | Task*, TaskCreate, TaskList, TaskUpdate, TaskGet |

\* Task tool availability is unreliable — declared but not consistently provisioned at runtime when spawned via auto-orchestrate.

**Key Finding**: TaskCreate, TaskList, TaskUpdate, and TaskGet are NEVER available to subagents. Only the auto-orchestrate loop (main Claude Code instance) has these tools.

## Workaround: File-Based Task Proposal Protocol

Since subagents cannot create or manage tasks directly, the system uses a file-based protocol:

### Task Proposals (Subagent → Auto-Orchestrate)

Subagents write task proposals to `.orchestrate/<session-id>/proposed-tasks.json`:

```json
{
  "tasks": [
    {
      "subject": "Task title",
      "description": "Detailed description. dispatch_hint: implementer",
      "activeForm": "Working on X",
      "blockedBy": [],
      "dispatch_hint": "implementer",
      "risk": "medium",
      "acceptance_criteria": ["Criterion 1", "Criterion 2"]
    }
  ]
}
```

The auto-orchestrate loop reads this file after each orchestrator iteration and creates tasks via TaskCreate.

### Task State (Auto-Orchestrate → Orchestrator)

The auto-orchestrate loop passes current task state in the orchestrator's spawn prompt under a `## Current Task State` section. The orchestrator reads task state from this context instead of calling TaskList.

### Task Updates (Orchestrator → Auto-Orchestrate)

The orchestrator returns proposed task updates in its response using a `PROPOSED_ACTIONS` JSON block. The auto-orchestrate loop parses this and executes TaskUpdate calls.

## What the Manifest.json Does (and Doesn't Do)

The manifest.json serves three purposes:
1. **Documentation** — declares intended tool usage patterns
2. **Discovery** — helps agents understand capabilities of other agents
3. **Validation** — CI checks for consistency

It does NOT:
- Grant tool permissions at runtime
- Control runtime tool availability
- Override Claude Code's built-in agent type tool access

## Implications for Agent Design

### Orchestrator
- Cannot call TaskList → receives task state in spawn prompt
- Cannot call TaskCreate → proposes tasks via files or return values
- Cannot call TaskUpdate → proposes updates via return values
- Cannot reliably call Task → reports back via PROPOSED_ACTIONS; auto-orchestrate retries or handles delegation. **The orchestrator MUST NOT "fall back" to performing implementation work directly** — MAIN-001 (stay high-level) and MAIN-002 (delegate ALL work) are non-negotiable regardless of tool availability

  **Observed violation patterns** (from production — these are FORBIDDEN):
  1. "Let me take a more practical approach" citing tool limitations → MAIN-001/MAIN-002 violation
  2. "This is more efficient for an audit task anyway" → MAIN-001/MAIN-002 violation
  3. "I'll do the research phase directly by reading the codebase" → MAIN-001/MAIN-002 violation
  4. "I'll create the tasks myself and spawn implementer agents" → MAIN-012/MAIN-013 violation
  Tool limitations are NEVER a valid justification. Return PROPOSED_ACTIONS and let auto-orchestrate handle dispatch.

### Epic-Architect
- Cannot call TaskCreate → writes task proposals to `.orchestrate/<session-id>/proposed-tasks.json`
- Cannot call TaskList → receives relevant task context in spawn prompt
- Task proposals follow the JSON format above

### Implementer
- Cannot call TaskUpdate → reports completion status in return value
- Can read/write/edit files (its core function works correctly)

### Auto-Orchestrate Loop (Main Claude Code Instance)
- HAS TaskCreate, TaskList, TaskUpdate, TaskGet (sole gateway for task management)
- Reads task proposals from `.orchestrate/<session-id>/proposed-tasks.json`
- Passes task state to orchestrator in spawn prompt
- Executes task updates based on orchestrator return values
- Is the ONLY entity that can create, list, update, or get tasks

## See Also

- claude-code/agents/orchestrator.md — Orchestrator with fallback protocol
- claude-code/agents/epic-architect.md — File-based task proposal output
- claude-code/commands/auto-orchestrate.md — Task management proxy
- claude-code/ARCHITECTURE.md — System architecture

## Status

- **Discovered**: 2026-02-11 (Iteration 1 gap analysis)
- **Documented**: 2026-02-11 (Iteration 2 remediation)
- **False Resolution**: 2026-02-14 (Documentation incorrectly claimed RESOLVED)
- **Reopened**: 2026-02-15 (Confirmed Task tool NOT available at runtime; TaskCreate/TaskList never available to subagents)
- **Workaround**: 2026-02-15 (File-based task proposal protocol implemented)

---

> **Relocated**: This file has been moved to `claude-code/_shared/references/TOOL-AVAILABILITY.md`.
> This copy is preserved for backward compatibility. Please update any references to use the new path.
