# Process Injection Map: Auto-Orchestrate ↔ Organizational Processes

**Version**: 1.0  
**Date**: 2026-04-06  
**Produced by**: software-engineer (Task #8, SPEC T018)  
**Status**: Active — V1 advisory injection (enforced: false by default)

---

## Executive Summary

The auto-orchestrate pipeline (Stages 0-6) and the organizational process framework (P-001 through P-093) run in parallel but have historically had no structured connection. Each auto-orchestrate stage implicitly produces outputs that organizational processes require, and each organizational process produces artifacts that auto-orchestrate stages need — but there is no explicit mechanism to link them. This document defines the **process injection map**: a cross-reference table identifying exactly which organizational processes apply at each auto-orchestrate stage, the injection event that triggers process engagement, and whether the hook blocks pipeline advancement (enforced) or is advisory (notify/link). V1 defaults to `enforced: false` for all hooks except P-038 (Security by Design), which is always enforced.

---

## Injection Table: Auto-Orchestrate Stage → Organizational Process

| AO Stage | Stage Name | Agent | Primary Org Processes | Injection Event | Action | Enforced |
|----------|-----------|-------|----------------------|----------------|--------|----------|
| Stage 0 | Research | researcher | P-001 (Intent), P-038 (AppSec Scope) | Before Stage 0: Verify P-001 Intent Brief exists in handoff receipt | notify | false |
| Stage 1 | Product Management | product-manager | P-007 (Decompose Deliverables), P-008 (Definition of Done), P-009 (Success Metrics), P-010 (RAID) | During Stage 1: Link task decomposition to P-007; DoD per epic = P-008 | link | false |
| Stage 2 | Specification | spec-creator | P-033 (Technical Design Review), P-038 (Security by Design) | During Stage 2: Spec must reference P-033 design review checklist; P-038 security requirements embedded | gate | **true** (P-038 only) |
| Stage 3 | Implementation | software-engineer | P-034 (Code Review), P-036 (Security Review), P-040 (Dependency Inventory) | After Stage 3: Present P-034 Code Review checklist; P-040 dependency inventory written | notify | false |
| Stage 4 | Test Writing | test-writer-pytest | P-035 (Testing Protocols), P-037 (Automated Testing) | During Stage 4: Tests must cover P-035 test coverage requirements; test results captured via P-037 | link | false |
| Stage 4.5 | Codebase Stats | codebase-stats | P-062 (Technical Debt Audit) | After Stage 4.5: Tech debt report written; link to P-062 audit record | link | false |
| Stage 5 | Validation | validator | P-034 (Code Review), P-036 (Security), P-037 (UAT pass criteria) | Before Stage 5 exit: Confirm P-034 + P-036 + P-037 pass criteria met in validation report | gate | **true** (P-034, P-037) |
| Stage 6 | Documentation | technical-writer | P-058 (Technical Docs), P-059 (API Docs), P-061 (Runbook) | After Stage 6: Link Stage 6 docs to P-058 + P-059 + P-061 process records; P-058 acknowledgment required | gate | **true** (P-058) |

---

## Missing Process Coverage (Stubs Required)

The following organizational processes have **no home** in either pipeline. They are not triggered by any auto-orchestrate stage and are not represented in the `/new-project` 4-stage pipeline. Stub documents are created to acknowledge their existence, define their scope, and provide a minimal process description until a dedicated pipeline integration is built.

| Gap | Between Stages | Missing Processes | Stub File |
|-----|---------------|-------------------|-----------|
| Sprint planning activities (sprint goals, intent trace, story writing) occur between epic decomposition and implementation but have no AO stage | Stage 1 → Stage 3 | P-022 (Sprint Goals), P-023 (Intent Trace), P-024 (Story Writing) | `claude-code/processes/process_stubs/sprint_planning_stub.md` |
| Dependency coordination runs parallel to organizational Stages 1-3 but is never triggered by AO Stages 0-2 | Parallel to Stage 0-2 | P-015 (Register Cross-Team Dependencies), P-016 (Critical Path), P-017 (Resource Conflicts), P-018 (Communication Plan), P-020 (Dependency Standups), P-021 (Escalation Protocol) | `claude-code/processes/process_stubs/dependency_coordination_stub.md` |
| Onboarding and knowledge transfer occur post-Stage 6 but AO pipeline terminates at Stage 6 | Post-Stage 6 | P-090 (Knowledge Handoff), P-091 (Runbook Handover), P-092 (Team Onboarding Brief), P-093 (Lessons Learned) | `claude-code/processes/process_stubs/onboarding_stub.md` |

---

## Hook Format Specification

Each injection hook is defined with the following fields. Hooks are stored in process receipts and logged to the orchestrator output.

```yaml
hook:
  ao_stage: 3
  ao_agent: software-engineer
  event: "after_stage_complete"
  process_ids: ["P-034", "P-036"]
  action: "notify"
  action_detail: >
    After Stage 3 (software-engineer) completes: present P-034 Code Review
    checklist to user. Gate optional — user may proceed without P-034
    in auto mode but must acknowledge the skip.
  output_artifact: null
  enforced: false
```

**Field definitions**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `ao_stage` | integer or string | YES | The AO pipeline stage number (0, 1, 2, 3, 4, 4.5, 5, 6) |
| `ao_agent` | string | YES | The agent name that triggers this hook (e.g., "software-engineer", "validator") |
| `event` | string | YES | When the hook fires: `"before_stage_start"`, `"during_stage"`, `"after_stage_complete"` |
| `process_ids` | string[] | YES | List of organizational process IDs this hook engages (e.g., ["P-034", "P-036"]) |
| `action` | string | YES | One of: `"notify"`, `"gate"`, `"link"` |
| `action_detail` | string | YES | Human-readable description of what happens when this hook fires |
| `output_artifact` | string or null | NO | Path to a file written by this hook, if any. Null if the hook only logs. |
| `enforced` | boolean | YES | `true` = blocks AO pipeline advancement until acknowledged; `false` = advisory only |

**Action type definitions**:

- `notify` — Log a message to orchestrator output at the injection event. Does not block pipeline. The message format is: `[PROCESS-INJECT] Stage {N} ({event}): {process_ids} — {action_detail}`
- `gate` — Block pipeline advancement until the process requirement is explicitly acknowledged by the user or by a passing validation check. Used only when `enforced: true`.
- `link` — Write a cross-reference entry to `.orchestrate/{session_id}/process_receipts.json` mapping the AO stage output to the organizational process record. Does not block pipeline.

---

## Enforcement Philosophy

**V1 Default**: `enforced: false` for all hooks. Advisory injection does not block the auto-orchestrate pipeline. This is intentional — in autonomous mode, blocking the pipeline for every organizational process review would defeat the purpose of automation.

**V1 Exceptions** (always `enforced: true`):

| Process | Stage | Reason |
|---------|-------|--------|
| P-038 (Security by Design) | Stage 2 (spec-creator) | Security requirements cannot be skipped at specification time. A spec that omits security design is structurally incomplete. The auto-orchestrate spec-creator MUST reference P-038 checklist items before the spec is accepted. |

**V2 Enforcement** (current):

| Process | Stage | Enforcement Rationale |
|---------|-------|----------------------|
| P-034 (Code Review) | Stage 5 exit | Code review is a quality gate; validation without review is incomplete |
| P-037 (Automated Testing) | Stage 5 exit | UAT criteria from scope contract must be verified against implementation |
| P-058 (Technical Docs) | Stage 6 exit | Documentation is a mandatory pipeline stage; its process must be enforced |

**V3+ Enforcement Candidates** (future):

- P-036 (Security Review) at Stage 3 — Enforce when automated security review tooling is integrated
- P-040 (Dependency Inventory) at Stage 3 — Enforce when dependency verification tooling is built

---

## Process Stubs Directory

`claude-code/processes/process_stubs/` contains minimal process documents for organizational processes that have no home in either pipeline. Each stub:

1. **Identifies** the process gap (which processes are missing)
2. **Defines the scope** of the missing processes
3. **Provides a minimal process description** that agents can reference
4. **Specifies the trigger condition** for when these processes should be engaged
5. **Notes the integration path** for future pipeline integration

Stubs are NOT full process implementations — they are placeholders that prevent processes from being silently ignored. When a stub process is triggered, the orchestrator logs: `[PROCESS-STUB] {process_ids} — No full implementation. Reference: {stub_file}. Manual engagement required.`

---

## Integration with gate-state.json

Injection hooks that produce pass/fail outcomes (action: `"gate"`) MAY write their result to `.orchestrate/{session_id}/gate-state.json` (defined in SPEC T014 / `claude-code/processes/gate_state_schema.json`). The integration path:

1. Hook fires at its `event` trigger point
2. If `enforced: true` and `action: "gate"`: the hook presents the process checklist
3. If the user confirms all items pass: hook writes `gate_N.status: "passed"` and `checklist_items_passed` to gate-state.json
4. Pipeline advances
5. If any item fails: hook writes `gate_N.status: "failed"` and `fail_reason`; pipeline is blocked

This integration requires the gate enforcement mechanism from SPEC T014 to be operational. Until T015/T016 implement the enforcement in the commands, this integration is advisory.

---

## Implementation Notes for T019: Orchestrator Injection Points

The following locations in `claude-code/agents/orchestrator.md` (and `~/.claude/agents/orchestrator.md`) are the exact insertion points for process injection hooks. **T019 MUST NOT modify the orchestrator without the install.sh guard from SPEC T003 being in place.**

| Injection Point | Location in orchestrator.md | Hook IDs |
|-----------------|------------------------------|----------|
| Stage 0 pre-spawn | Stage 0 researcher spawn template — add after standard instructions | P-001 check, P-038 scope notify |
| Stage 2 post-completion | OODA `continue` branch after Stage 2 — add process gate for P-038 | P-038 gate (enforced) |
| Stage 3 post-impl | Post-impl fix loop completion — after `validation.errors == 0` | P-034 notify, P-036 notify, P-040 link |
| Stage 4.5 completion | After codebase-stats agent completes | P-062 link |
| Stage 5 pre-exit | Zero-error gate check — add process confirmation | P-034 notify, P-036 notify, P-037 notify |
| Stage 6 completion | After technical-writer completes — before PDCA Check phase | P-058 link, P-059 link, P-061 link |
| Run completion hook | `hook:run:complete` emission — add process receipts finalization | All linked processes |

**Exact file**: `claude-code/agents/orchestrator.md` (source) and `~/.claude/agents/orchestrator.md` (runtime).  
**Constraint**: Verify checksums equal before modifying (see `claude-code/agents/agent-reconciliation-notes.md`).  
**Verify post-modification**: `md5sum claude-code/agents/orchestrator.md ~/.claude/agents/orchestrator.md` — they must match after T019 modifies both.

---

## Organizational Process Reference Lookup

For full process definitions, see the following process handbook files:

| Process Range | File |
|--------------|------|
| P-001 to P-006 | `claude-code/processes/01_intent_strategic_alignment.md` |
| P-007 to P-014 | `claude-code/processes/02_scope_contract_management.md` |
| P-015 to P-021 | `claude-code/processes/03_dependency_coordination.md` |
| P-022 to P-031 | `claude-code/processes/04_sprint_delivery_execution.md` |
| P-033 to P-037 | `claude-code/processes/05_quality_assurance_testing.md` |
| P-038 to P-040 | `claude-code/processes/06_security_compliance.md` |
| P-058 to P-062 | `claude-code/processes/10_documentation_knowledge.md` |
| P-090 to P-093 | `claude-code/processes/17_onboarding_knowledge_transfer.md` |

---

*Implements SPEC T018 | References: T009 (bridge protocol), T014 (gate state schema), T019 (orchestrator hooks — future)*
