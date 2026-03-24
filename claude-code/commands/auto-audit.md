---
name: auto-audit
description: |
  Autonomous audit-remediate loop. Audits codebase against spec, identifies gaps,
  invokes orchestrator to implement missing features, re-audits until compliant.
  Crash recovery via session checkpoints.
triggers:
  - auto-audit
  - auto audit
  - audit against spec
  - spec compliance loop
  - audit until compliant
  - verify implementation
  - audit and fix
arguments:
  - name: spec_path
    type: string
    required: true
    description: Path to spec/requirements document to audit against. Pass "c" to continue the most recent in-progress audit session.
  - name: scope
    type: string
    required: false
    description: |
      Scope flag: "F"/"f" (Frontend), "B"/"b" (Backend), "S"/"s" (Full stack).
      Passed through to orchestrator during remediation phase.
  - name: max_audit_cycles
    type: integer
    required: false
    default: 5
    description: Maximum audit-remediate cycles before stopping.
  - name: max_orchestrate_iterations
    type: integer
    required: false
    default: 100
    description: Max orchestrator spawns per remediation phase.
  - name: docker
    type: boolean
    required: false
    default: false
    description: Enable Docker service auditing. Auto-enabled if spec mentions docker/container/compose.
  - name: compliance_threshold
    type: integer
    required: false
    default: 90
    description: Minimum compliance percentage to accept (100 = all requirements must fully pass).
  - name: resume
    type: boolean
    required: false
    default: false
    description: Explicitly resume the latest in-progress audit session.
---

# Autonomous Audit-Remediate Loop

## Core Constraints — IMMUTABLE

| ID | Rule |
|----|------|
| AUD-LOOP-001 | **Dual-gateway** — Spawn ONLY `subagent_type: "auditor"` (Phase A) or `subagent_type: "orchestrator"` (Phase B). Never spawn implementer, researcher, debugger, etc. directly. If 2 consecutive retries return empty output, abort with `[AUD-LOOP-001]` message. |
| AUD-LOOP-002 | **Cycle-based termination** — Cannot declare `completed` unless the most recent audit returned verdict PASS or ACCEPTABLE (score ≥ threshold). |
| AUD-LOOP-003 | **Spec context passthrough** — Every auditor spawn receives the FULL spec path. Every orchestrator spawn receives the FULL gap report as enhanced prompt context. Never summarize. |
| AUD-LOOP-004 | **Checkpoint-before-spawn** — Write checkpoint to disk before every agent spawn. |
| AUD-LOOP-005 | **No direct work** — Auto-audit is a meta-loop controller. Never read spec files, scan codebase, run Docker commands, or implement fixes. The auditor and orchestrator agents do all work. |
| AUD-LOOP-006 | **Docker auto-detection** — If spec filename or user arguments contain "docker", "container", "compose", "deploy" (case-insensitive), auto-set `docker: true`. |
| AUD-LOOP-007 | **Cycle history immutability** — Only append to `cycle_history`; never modify existing entries. |
| AUD-LOOP-008 | **Remediation scope injection** — Gap findings from the auditor are injected VERBATIM into the orchestrator spawn prompt. Never summarize, filter, or reinterpret gaps. |
| AUD-LOOP-009 | **Phase ordering** — Phase A (audit) ALWAYS precedes Phase B (remediation) within a cycle. Never remediate without auditing first. |
| PROGRESS-001 | **Always-visible processing** — Output status lines before/after every tool call, spawn, and processing step. |
| MANIFEST-001 | **Manifest-driven pipeline** — Read `~/.claude/manifest.json` at boot. Pass manifest path to all agent spawns. |

## Execution Guard — AUTO-AUDIT IS A META-LOOP CONTROLLER, NOT A WORKER

╔══════════════════════════════════════════════════════════════════════════╗
║  AUTO-AUDIT MUST NEVER:                                                 ║
║                                                                         ║
║  1. Read spec files, project source code, or Docker state              ║
║  2. Analyze requirements, scan for implementations, or run tests       ║
║  3. Apply fixes, edit files, or modify any project state               ║
║  4. Run Docker commands, build processes, or endpoint tests            ║
║  5. Spawn ANY agent type other than auditor or orchestrator            ║
║                                                                         ║
║  AUTO-AUDIT ONLY:                                                       ║
║  - Collects audit parameters from user (Step 1)                        ║
║  - Creates session infrastructure (Step 2)                             ║
║  - Spawns auditor agent for compliance analysis (Step 3)               ║
║  - Processes audit results (Step 4)                                    ║
║  - If gaps found: spawns orchestrator for remediation (Step 5)         ║
║  - After remediation: loops back to Step 3 (re-audit)                  ║
║  - Evaluates termination (Step 6)                                      ║
║                                                                         ║
║  If you catch yourself reading specs, scanning code, running Docker     ║
║  commands, or applying fixes — STOP. You are violating this guard.     ║
╚══════════════════════════════════════════════════════════════════════════╝

## Audit-Remediate Pipeline — Meta-Loop

Auto-audit orchestrates TWO agent types in an outer loop:

```
    ┌──────────────────────────────────────────────────────────┐
    │                                                          │
    ▼                                                          │
Phase A: AUDIT (spawn auditor)                                 │
    │ Produces: compliance score + gap-report.json             │
    │                                                          │
    ├─ If PASS/ACCEPTABLE → DONE                               │
    │                                                          │
    ▼                                                          │
Phase B: REMEDIATE (spawn orchestrator)                        │
    │ Orchestrator runs full pipeline to fix gaps               │
    │ (research → architect → spec → implement → validate)     │
    │                                                          │
    └────────────── loop back to Phase A ──────────────────────┘
```

**Key distinction from auto-orchestrate**: Auto-orchestrate uses a single-gateway (only orchestrator). Auto-audit uses a **dual-gateway** (auditor for analysis, orchestrator for remediation).

**Key distinction from auto-debug**: Auto-debug cycles triage→fix→verify within a single agent type. Auto-audit alternates between TWO different agent types.

## Configuration Defaults

| Parameter | Default | Description |
|-----------|---------|-------------|
| `MAX_AUDIT_CYCLES` | 5 | Max audit-remediate-reaudit cycles |
| `MAX_ORCHESTRATE_ITERATIONS` | 100 | Max orchestrator spawns per remediation phase |
| `COMPLIANCE_THRESHOLD` | 90 | Minimum compliance % for ACCEPTABLE verdict |
| `STALL_THRESHOLD` | 2 | Consecutive no-improvement cycles before stall |
| `CHECKPOINT_DIR` | `.audit/<session-id>/` | Session checkpoint directory |

---

## Step 0: Autonomous Mode Declaration

### 0-pre. Continue Shorthand

If `spec_path` is `"c"` (case-insensitive): treat as `resume: true`, skip Steps 0a and 1, jump to Step 2b. If no in-progress audit session found, abort.

### 0a. Permission Grant

Display once:

> **Audit mode requested.** This will:
> - Read and analyze the spec at `<spec_path>`
> - Scan the codebase for implementation evidence
> - If Docker enabled: check Docker services and endpoints
> - If gaps found: invoke orchestrator to implement missing features
> - Re-audit until compliant or max cycles reached
> - Run up to {{MAX_AUDIT_CYCLES}} audit-remediate cycles
>
> **Proceed with audit?** (Y/n)

If declined, abort: `"Audit session cancelled."`

Record in checkpoint: `"permissions": { "autonomous_operation": true, "audit_access": true, "remediation_access": true, "docker_access": <bool>, "granted_at": "<ISO-8601>" }`

### 0b. Docker Auto-Detection (AUD-LOOP-006)

Scan `spec_path` filename for Docker keywords (case-insensitive):
```
docker, container, compose, deploy, infrastructure, service
```

If ANY keyword found AND `docker` argument not explicitly set:
- Set `docker: true`
- Output: `[AUD-LOOP-006] Docker mode auto-enabled based on spec path`

### 0c. Scope Resolution

Same as auto-orchestrate: parse scope flag (F/B/S) if provided. This scope is passed through to the orchestrator during remediation.

### 0d. Inline Processing Rule

Step 1 runs INLINE. Do NOT delegate to agents or use `EnterPlanMode`.

---

## Step 1: Collect Audit Context (Inline)

> **GUARD**: Do NOT read the spec file. Collection uses ONLY the user's arguments. All spec analysis is the auditor agent's job.

Parse arguments and create structured audit context:

```json
{
  "spec_path": "<path>",
  "docker_mode": false,
  "scope": { "flag": null, "resolved": "custom", "layers": [] },
  "compliance_threshold": 90,
  "max_audit_cycles": 5,
  "max_orchestrate_iterations": 100
}
```

Verify spec_path exists (file existence check only — do NOT read contents):
```bash
test -f "$SPEC_PATH" && echo "exists" || echo "not found"
```

If spec not found, abort: `"Spec file not found at <spec_path>. Please provide a valid path."`

---

## Step 2: Initialize Session Checkpoint

### 2a. Ensure directories

```bash
mkdir -p .audit/${SESSION_ID}
```

### 2b. Check for existing audit sessions

```bash
find .audit -name "checkpoint.json" -exec grep -l '"status": "in_progress"' {} \; 2>/dev/null
```

For EVERY in-progress session: set `"status": "superseded"`, add `"superseded_at"` and `"superseded_by"`. Non-destructive — never delete. If superseded session's `spec_path` matches current: **resume** (skip to Step 3).

### 2c. Create new session

**Session ID**: `auto-aud-<DATE>-<8-char-slug>` (slug from spec filename).

Create parent tracking task via `TaskCreate`, then write checkpoint to `.audit/<session-id>/checkpoint.json`:

```json
{
  "schema_version": "1.0.0",
  "session_id": "<session-id>",
  "type": "audit",
  "created_at": "<ISO-8601>",
  "updated_at": "<ISO-8601>",
  "status": "in_progress",
  "audit_cycle": 0,
  "max_audit_cycles": 5,
  "max_orchestrate_iterations": 100,
  "compliance_threshold": 90,
  "stall_threshold": 2,
  "docker_mode": false,
  "spec_path": "<path>",
  "scope": { "flag": null, "resolved": "custom", "layers": [] },
  "permissions": {
    "autonomous_operation": true,
    "audit_access": true,
    "remediation_access": true,
    "docker_access": false,
    "granted_at": "<ISO-8601>"
  },
  "parent_task_id": "<TaskCreate ID>",
  "cycle_history": [],
  "current_phase": "audit",
  "last_compliance_score": null,
  "last_gap_count": null,
  "stall_counter": 0,
  "terminal_state": null
}
```

---

## Step 3: Spawn Auditor — Phase A (Audit)

> **CRITICAL GUARD**: You should arrive here with ZERO knowledge of the spec or project internals. If you have read the spec, scanned the codebase, or run Docker commands — STOP. You are violating the Execution Guard.

**Before spawning** (AUD-LOOP-004): Increment `audit_cycle`, set `current_phase: "audit"`, update `updated_at`, write checkpoint.

### 3a. Display cycle banner

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 AUDIT CYCLE <N> of <max> | Session: <session_id>
 Phase: AUDIT | Docker: ON/OFF | Threshold: <N>%
 Previous Score: <N>% (or "First audit") | Previous Gaps: <N>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 3b. Pre-spawn self-check

Before spawning, verify:
- [ ] Spawning exactly ONE agent with `subagent_type: "auditor"`
- [ ] Have NOT read the spec file or any project files
- [ ] Have NOT run any Docker commands
- [ ] NOT about to "analyze the spec myself because it seems simple"

### 3c. Spawn auditor

Spawn EXACTLY ONE agent: `Agent(subagent_type: "auditor")` using the **Appendix A** template.

---

## Step 4: Process Audit Results

After auditor returns:

### 4.1 Parse auditor DONE block

Extract:
- `Verdict`: PASS, ACCEPTABLE, or FAIL
- `Compliance-Score`: percentage
- `Requirements-Total`, `Requirements-PASS`, `Requirements-PARTIAL`, `Requirements-MISSING`, `Requirements-FAIL`
- `Services-Total`, `Services-Healthy`, `Services-Unhealthy` (or N/A)
- `Gap-Report`: path to gap-report.json
- `Audit-Report`: path to audit report
- `Remediation-Items`: count of items needing fixes

If DONE block is missing or unparseable, treat as Verdict=FAIL, Compliance-Score=0.

### 4.2 Display compliance board

```
 COMPLIANCE BOARD (Cycle <N>):
 ┌─ Requirements ──────────────────────────
 │  PASS:    12/20 (60%)
 │  PARTIAL:  3/20 (15%)
 │  MISSING:  4/20 (20%)
 │  FAIL:     1/20 (5%)
 ├─ Services (Docker) ─────────────────────
 │  Healthy:  3/4
 │  Unhealthy: 1/4 (redis)
 ├─ Score ─────────────────────────────────
 │  67.5% [FAIL — below 90% threshold]
 └─────────────────────────────────────────
```

### 4.3 Record cycle history (AUD-LOOP-007)

```json
{
  "cycle": N,
  "phase": "audit",
  "verdict": "FAIL",
  "compliance_score": 67.5,
  "requirements": {
    "total": 20,
    "pass": 12,
    "partial": 3,
    "missing": 4,
    "fail": 1
  },
  "services": {
    "total": 4,
    "healthy": 3,
    "unhealthy": 1
  },
  "gap_report_path": ".audit/<session-id>/gap-report.json",
  "remediation_items": 8,
  "delta_from_previous": "+17.5%"
}
```

### 4.4 Save checkpoint

Update checkpoint with: `audit_cycle`, `last_compliance_score`, `last_gap_count`, cycle history, `updated_at`.

### 4.5 Evaluate termination (Step 6)

If terminated, exit. Otherwise continue.

### 4.6 Route based on verdict

- If Verdict = PASS or ACCEPTABLE → proceed to termination (Step 6)
- If Verdict = FAIL → proceed to Step 5 (Remediation)

---

## Step 5: Spawn Orchestrator — Phase B (Remediation)

> **AUD-LOOP-001 GUARD**: Only spawn `subagent_type: "orchestrator"` here. Never spawn implementer, researcher, or any other agent type.

### 5a. Read gap report

Read the gap report from `.audit/<session-id>/gap-report.json`.

### 5b. Build remediation prompt

Convert gap findings into an orchestrator task description (AUD-LOOP-008 — verbatim injection):

See **Appendix B** for the full remediation spawn template.

### 5c. Display remediation banner

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 AUDIT CYCLE <N> | Phase: REMEDIATION
 Gaps to Fix: <count> | Max Orchestrator Iterations: <max>
 Scope: <resolved> | Docker: ON/OFF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 5d. Set phase and checkpoint

Set `current_phase: "remediation"`, write checkpoint (AUD-LOOP-004).

### 5e. Spawn orchestrator

Spawn EXACTLY ONE agent: `Agent(subagent_type: "orchestrator")` using the **Appendix B** template.

The orchestrator runs its full internal pipeline (research → architecture → spec → implementation → validation → documentation). Auto-audit does NOT manage the orchestrator's internal stages — it only receives the final result.

### 5f. Process orchestrator result

Record remediation in cycle_history:
```json
{
  "cycle": N,
  "phase": "remediation",
  "orchestrator_summary": "<first 500 chars of orchestrator output>",
  "tasks_completed": [],
  "tasks_pending": []
}
```

### 5g. Save checkpoint

### 5h. Loop back to Step 3 (re-audit)

Return to Step 3 to re-audit the codebase after remediation.

---

## Step 6: Termination Conditions

Evaluate in order:

| # | Condition | Status |
|---|-----------|--------|
| 1 | Verdict = PASS (100% compliance) | `fully_compliant` |
| 2 | Verdict = ACCEPTABLE (score ≥ threshold) | `acceptable_compliance` |
| 3 | `audit_cycle >= MAX_AUDIT_CYCLES` | `max_cycles_reached` |
| 4 | `stall_counter >= STALL_THRESHOLD` | `stalled` |
| 5 | User requests stop | `user_stopped` |

**Stall detection**: Compare compliance_score with previous cycle:
- Same or worse score → increment `stall_counter`
- Any improvement (even 0.1%) → reset `stall_counter` to 0

### On Termination

Set `terminal_state` and `status` in checkpoint, update parent task, display:

```
## Auto-Audit Complete

**Session**: <session_id> | **Status**: <terminal_state> | **Cycles**: N/max
**Spec**: <spec_path> | **Final Score**: N% | **Threshold**: N%
**Docker Mode**: ON/OFF | **Scope**: <resolved>

### Compliance Summary
| Status | Count | % |
|--------|-------|---|
| PASS | 15 | 75% |
| PARTIAL | 3 | 15% |
| MISSING | 1 | 5% |
| FAIL | 1 | 5% |

### Docker Services (if applicable)
| Service | Status | Details |
|---------|--------|---------|
| postgres | PASS | Running, healthy, port 5432 |
| redis | FAIL | Unhealthy, ECONNREFUSED |

### Cycle Timeline
| # | Phase | Score | Gaps | Delta | Action |
|---|-------|-------|------|-------|--------|
| 1 | Audit | 67.5% | 8 | — | Initial audit |
| 1 | Remediate | — | — | — | Orchestrator ran 12 iterations |
| 2 | Audit | 85% | 3 | +17.5% | Improvement after remediation |
| 2 | Remediate | — | — | — | Orchestrator ran 8 iterations |
| 3 | Audit | 95% | 1 | +10% | Acceptable (≥90%) |

### Remaining Gaps (if any)
- [PARTIAL] REQ-015: Full-text search — basic works, advanced filters missing
  Evidence: src/search/basic.py exists, no advanced_search module

### Git Commit Instructions
> Auto-audit NEVER commits automatically. Review and commit manually.
**Suggested commits**: [collected from orchestrator DONE blocks]

### Reports
- Final audit: .audit/<session-id>/audit-report-<cycle>.md
- Gap report: .audit/<session-id>/gap-report.json

### Iteration Timeline (Remediation Details)
| Cycle | Orchestrator Iterations | Tasks Completed | Tasks Pending |
|-------|------------------------|-----------------|---------------|
| 1 | 12 | 5 | 0 |
| 2 | 8 | 3 | 0 |
```

---

## Crash Recovery Protocol

Runs at the START of every invocation:

1. Ensure `.audit/` exists
2. Scan for `"status": "in_progress"` checkpoints in `.audit/*/checkpoint.json`
3. If found: same/no spec_path → **Resume**; different spec_path → supersede, start fresh
4. If not found → proceed normally

### Resume

1. Read checkpoint: restore `audit_cycle`, `cycle_history`, `last_compliance_score`, `stall_counter`, `current_phase`
2. If `current_phase` was "remediation": the orchestrator may have been interrupted — skip to re-audit (Step 3)
3. If `current_phase` was "audit": the auditor may have been interrupted — re-run audit (Step 3)
4. Display recovery summary
5. Resume from current cycle, skip Step 1

---

## Appendix A: Auditor Spawn Prompt Template

Use `Agent(subagent_type: "auditor")` with this prompt:

```
## Audit Session Context

SESSION_ID: <session_id>
AUDIT_CYCLE: <N> of <max_audit_cycles>
DOCKER_MODE: <true/false>
COMPLIANCE_THRESHOLD: <percentage>
MANIFEST_PATH: ~/.claude/manifest.json

## Spec to Audit Against
SPEC_PATH: <spec_path>

## Previous Audit Results (if cycle > 1)
Previous compliance score: <N>%
Previous gaps: <N> remediation items
Changes since last audit: Orchestrator ran <N> iterations implementing fixes

<Previous gap summary — which items were flagged for remediation>

## Autonomous Mode Permissions (pre-granted)
Operate without confirmations. Read any project file. Run read-only Bash commands.
NEVER modify any file. NEVER git commit/push. NEVER run docker compose up/down.

## MANDATORY: Skill Loading
╔══════════════════════════════════════════════════════════════╗
║  You MUST read ~/.claude/skills/spec-compliance/SKILL.md     ║
║  BEFORE starting Phase 1.                                    ║
║  Follow its execution flow for requirements extraction       ║
║  and compliance mapping.                                     ║
║                                                              ║
║  ALSO read and use:                                          ║
║  ~/.claude/skills/spec-analyzer/SKILL.md (spec validation)   ║
║  ~/.claude/skills/codebase-stats/SKILL.md (code metrics)     ║
║  ~/.claude/skills/test-gap-analyzer/SKILL.md (test evidence) ║
║  ~/.claude/skills/security-auditor/SKILL.md (security scan)  ║
║                                                              ║
║  When DOCKER_MODE=true, ALSO read:                           ║
║  ~/.claude/skills/docker-validator/SKILL.md                  ║
╚══════════════════════════════════════════════════════════════╝

## Instructions

1. **Phase 1 (Spec Ingestion)**: Read spec at SPEC_PATH. Validate structure
   with spec-analyzer. Parse requirements with spec-compliance/spec_parser.py.

2. **Phase 2 (Codebase Scanning)**: Run spec-compliance/compliance_checker.py.
   Supplement with codebase-stats and test-gap-analyzer for evidence.

3. **Phase 3 (Docker Audit)**: If DOCKER_MODE, run
   spec-compliance/service_discovery.py. Cross-reference with spec requirements.
   READ-ONLY: do NOT run docker compose up/down.

4. **Phase 4 (Report)**: Run security-auditor. Aggregate all findings.
   Write audit report and gap-report.json. Determine verdict.

5. **Return DONE block** with all required fields.

## Constraints
- AUD-001: Read-only — NEVER modify files or Docker state
- AUD-002: Spec-first — read spec before scanning code
- AUD-003: Evidence-based — cite file paths and line numbers
- AUD-005: Structured output — both report and gap-report.json
- AUD-007: Complete coverage — audit ALL requirements
- AUD-008: Docker only when DOCKER_MODE=true

## Session Isolation
SESSION_ID: <session_id>. All output to .audit/<session_id>/.
```

---

## Appendix B: Orchestrator Remediation Spawn Prompt Template

Use `Agent(subagent_type: "orchestrator", max_turns: 30)` with this prompt:

```
## MANDATORY FIRST ACTION (before boot)
Write `.orchestrate/<SESSION_ID>/proposed-tasks.json` with task proposals for implementing the gaps identified below.

## Remediation Context (from Audit Cycle <N>)

PARENT_TASK_ID: <parent_task_id>
SESSION_ID: <session_id>
AUDIT_CYCLE: <N>
SCOPE: <resolved scope>
SCOPE_LAYERS: <layers array>
STAGE_CEILING: 6
MANIFEST_PATH: ~/.claude/manifest.json

## STAGE_CEILING — HARD STRUCTURAL LIMIT
╔══════════════════════════════════════════════════════════════╗
║  STAGE_CEILING = 6 (full pipeline available)                 ║
║  Follow the standard pipeline:                               ║
║  Stage 0 (Research) → 1 (Architecture) → 2 (Specs) →        ║
║  3 (Implementation) → 4.5 (Stats) → 5 (Validation) →        ║
║  6 (Documentation)                                           ║
╚══════════════════════════════════════════════════════════════╝

## Gap Findings (VERBATIM from auditor — AUD-LOOP-008)

<For each gap from gap-report.json, include full detail:>

### MISSING Requirements
<REQ-ID>: <description>
  Source: <spec source location>
  Priority: <MUST/SHOULD/MAY>
  Evidence: <what was searched, what was NOT found>
  Remediation: <what needs to be built>

### PARTIAL Requirements
<REQ-ID>: <description>
  Source: <spec source location>
  Priority: <MUST/SHOULD/MAY>
  What exists: <evidence of partial implementation>
  What's missing: <specific gaps to fill>

### FAIL Requirements
<REQ-ID>: <description>
  Source: <spec source location>
  Priority: <MUST/SHOULD/MAY>
  What's broken: <specific error/issue>
  Fix needed: <what to fix>

### Unhealthy Services (if Docker)
<SVC-ID>: <service name>
  Status: <FAIL/PARTIAL>
  Current state: <details>
  Fix needed: <what to fix>

## Spec Reference
SPEC_PATH: <spec_path>
The auditor has already analyzed this spec. Focus on implementing the gaps above.

## Autonomous Mode Permissions (pre-granted)
Operate without confirmations. Access ~/.claude/ freely. Make assumptions.
Do NOT call EnterPlanMode. NEVER git commit/push.

## Delegation Guard — YOU ARE A COORDINATOR, NOT A WORKER
╔══════════════════════════════════════════════════════════════╗
║  Delegate ALL work to subagents. NEVER implement yourself.   ║
║  Spawn researcher, epic-architect, spec-creator, implementer ║
║  as needed following the standard pipeline.                  ║
╚══════════════════════════════════════════════════════════════╝

## Instructions
1. Focus ONLY on the gaps identified above. Do not re-implement working features.
2. Follow the standard pipeline: research → architect → spec → implement → validate → doc.
3. Propose tasks via .orchestrate/<SESSION_ID>/proposed-tasks.json.
4. Spawn subagents to do ALL work. Never implement yourself.
5. NO AUTO-COMMIT: Never git commit/push.
6. Return PROPOSED_ACTIONS JSON block at end.

{{#if scope != "custom"}}
## Scope
Only work on layers in SCOPE_LAYERS: <layers>
{{/if}}
```
