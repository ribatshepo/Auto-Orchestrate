---
status: STUB
related_process: claude-code/processes/04_sprint_delivery_execution.md
category: category-04-sprint
last_reviewed: 2026-04-14
---

> **STATUS: STUB** — This is a quick-reference stub for sprint planning. 
> For full process definitions see `04_sprint_delivery_execution.md`.
> TODO: Complete or promote to full process status.

# Process Stub: Sprint Planning (P-022, P-023, P-024)

**Type**: Process stub — minimal placeholder  
**Status**: STUB — No auto-orchestrate pipeline stage implements these processes  
**Date**: 2026-04-06  
**Produced by**: software-engineer (Task #8, SPEC T018)

---

## Gap Description

Sprint planning processes P-022 through P-024 occur **between Stage 1 (Product Management) and Stage 3 (Implementation)** in the auto-orchestrate pipeline but have no dedicated AO stage. The product-manager (Stage 1) produces task decomposition aligned with P-007 (Decompose Deliverables) and P-008 (Definition of Done), but the subsequent sprint goal authoring, intent tracing, and story writing steps are not performed by any AO stage.

In autonomous mode, the orchestrator treats each Stage 1 task as a story. In human-led mode, these three processes MUST be performed manually between Stage 1 completion and Stage 3 start.

---

## Processes Covered

### P-022: Sprint Goals

**Owner**: Engineering Manager  
**When**: After Stage 1 (Product Management) completes, before Stage 3 (Implementation) begins  
**Purpose**: Author clear, measurable sprint objectives that define what the team will deliver in this sprint

**Minimum required actions**:
1. Review Stage 1 task decomposition output (`.orchestrate/{session_id}/stage-1/`)
2. Group tasks into a sprint goal statement: "By the end of this sprint, we will have {deliverable} so that {outcome}"
3. Confirm the sprint goal traces to the Intent Brief (P-001) — see P-023
4. Document the sprint goal in the Sprint Kickoff Brief artifact

**In auto-orchestrate mode**: The orchestrator's task list from Stage 1 serves as the sprint backlog. Sprint goal is implicit: "Implement all Stage 1 tasks."

### P-023: Intent Trace

**Owner**: Product Manager  
**When**: Alongside P-022  
**Purpose**: Verify every story/task traces back to the original intent brief

**Minimum required actions**:
1. For each Stage 1 task, confirm it maps to at least one deliverable in the Scope Contract
2. Flag any orphan tasks (no deliverable mapping) — these may be infrastructure or risk mitigation; document them as such
3. Document the trace in the Sprint Kickoff Brief

**In auto-orchestrate mode**: The Stage 1 product-manager is instructed to produce tasks driven by the research output (Stage 0) and the spec (Stage 2). Intent tracing is implicit through the research → epic → spec chain. For compliance, the Stage 1 output should be reviewed for deliverable alignment before Stage 3 begins.

### P-024: Story Writing

**Owner**: Software Engineers + Product Manager  
**When**: After P-022 Sprint Goals authored, before Stage 3  
**Purpose**: Write detailed user stories with acceptance criteria

**Minimum required actions**:
1. Convert each Stage 1 task into a user story: "As a {user}, I want {feature} so that {benefit}"
2. Attach acceptance criteria (already produced by spec-creator in Stage 2)
3. Estimate effort (story points or hours)
4. Confirm stories fit within sprint capacity

**In auto-orchestrate mode**: Stage 2 (spec-creator) produces acceptance criteria per task. User story format is not required in autonomous mode, but implementation quality (IMPL-006) must meet the DoD from P-008.

---

## Integration Path (Future T019+)

When the orchestrator injection framework (T019) is implemented:
- Hook point: After Stage 1 completes, before Stage 3 begins
- Action: `notify` — log `[PROCESS-STUB] P-022/P-023/P-024 — Sprint planning processes. Reference: claude-code/processes/process_stubs/sprint_planning_stub.md. Manual engagement required in human-led mode.`
- Enforced: `false` (advisory in V1)

---

*Stub for: P-022 (Sprint Goals), P-023 (Intent Trace), P-024 (Story Writing)*  
*Full process: `claude-code/processes/04_sprint_delivery_execution.md`*
