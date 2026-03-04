> **CANONICAL**: `_shared/references/TOOL-AVAILABILITY.md`. This copy preserved for backward compatibility.

---

# Tool Availability Constraints for Claude Code Agents

## Core Problem (GAP-CRIT-001) — OPEN

Tool availability is determined by **built-in agent type definitions at runtime**, NOT by manifest.json declarations. The manifest documents intent but does not grant access.

**Critical distinctions**:
- `Task` (spawns subagents) ≠ `TaskCreate/TaskList/TaskUpdate/TaskGet` (task management) — separate tools, separate availability
- `Task` is declared for subagents but **NOT reliably provisioned at runtime** when spawned via auto-orchestrate
- `TaskCreate/TaskList/TaskUpdate/TaskGet` are **NEVER available** to any subagent — only the main Claude Code instance (auto-orchestrate loop) has these

**Root cause**: Built-in agent type definitions declare tools that may not be provisioned depending on spawn context, permission mode, and conversation state.

## Runtime Tool Matrix

| Agent | Available | NOT Available |
|-------|-----------|---------------|
| orchestrator | Read, Glob, Grep, Bash | Task*, TaskCreate/List/Update/Get |
| epic-architect | Read, Glob, Grep, Bash | Task*, TaskCreate/List/Update/Get |
| implementer | Read, Write, Edit, Bash, Glob, Grep | Task*, TaskCreate/List/Update/Get |
| documentor | Read, Glob, Grep, Edit, Write | Task*, TaskCreate/List/Update/Get |
| session-manager | Read, Glob, Grep, Bash | Task*, TaskCreate/List/Update/Get |

\* Task declared but unreliably provisioned at runtime via auto-orchestrate.

## Workaround: File-Based Task Proposal Protocol

### Subagent → Auto-Orchestrate (Task Proposals)

Subagents write to `.orchestrate/<session-id>/proposed-tasks.json`:
```json
{
  "tasks": [{
    "subject": "Task title",
    "description": "Detailed description. dispatch_hint: implementer",
    "activeForm": "Working on X",
    "blockedBy": [],
    "dispatch_hint": "implementer",
    "risk": "medium",
    "acceptance_criteria": ["Criterion 1", "Criterion 2"]
  }]
}
```

### Auto-Orchestrate → Orchestrator (Task State)

Task state passed in orchestrator's spawn prompt under `## Current Task State` (replaces TaskList).

### Orchestrator → Auto-Orchestrate (Task Updates)

Orchestrator returns `PROPOSED_ACTIONS` JSON block in its response. Auto-orchestrate parses and executes TaskUpdate calls.

### Auto-Orchestrate Loop (Sole Task Gateway)

Only entity with TaskCreate/List/Update/Get. Reads proposals from file, passes state to orchestrator, executes updates from return values.

## Agent Design Implications

| Agent | Cannot Do | Instead |
|-------|-----------|---------|
| Orchestrator | TaskList | Receives state in spawn prompt |
| Orchestrator | TaskCreate/TaskUpdate | Returns PROPOSED_ACTIONS; auto-orchestrate executes |
| Orchestrator | Reliable Task spawning | Returns PROPOSED_ACTIONS; auto-orchestrate handles dispatch |
| Epic-Architect | TaskCreate | Writes proposals to `.orchestrate/<session-id>/proposed-tasks.json` |
| Implementer | TaskUpdate | Reports completion status in return value |

### Orchestrator: FORBIDDEN Patterns

**The orchestrator MUST NOT "fall back" to implementation work directly.** MAIN-001 (stay high-level) and MAIN-002 (delegate ALL work) are non-negotiable regardless of tool availability. Tool limitations are NEVER a valid justification.

Observed violation patterns (all FORBIDDEN):
1. "Let me take a more practical approach" citing tool limitations → MAIN-001/002 violation
2. "This is more efficient for an audit task anyway" → MAIN-001/002 violation
3. "I'll do the research phase directly by reading the codebase" → MAIN-001/002 violation
4. "I'll create the tasks myself and spawn implementer agents" → MAIN-012/013 violation

**Only correct response**: Return PROPOSED_ACTIONS and let auto-orchestrate handle dispatch.

## What manifest.json Does (and Doesn't)

**Does**: Documentation of intent, agent capability discovery, CI consistency validation.
**Does NOT**: Grant runtime permissions, control runtime availability, override built-in agent type tool access.

## Status

| Date | Event |
|------|-------|
| 2026-02-11 | Discovered (Iteration 1 gap analysis) + Documented (Iteration 2) |
| 2026-02-14 | False resolution — incorrectly claimed RESOLVED |
| 2026-02-15 | Reopened — confirmed Task not available at runtime; TaskCreate/List never available to subagents |
| 2026-02-15 | Workaround implemented (file-based task proposal protocol) |

## See Also

- claude-code/agents/orchestrator.md — Orchestrator with fallback protocol
- claude-code/agents/epic-architect.md — File-based task proposal output
- claude-code/commands/auto-orchestrate.md — Task management proxy
- claude-code/ARCHITECTURE.md — System architecture