---
name: risk
description: Guide the user through Risk & Change Management processes (P-074 to P-077).
---

# /risk — Risk & Change Management

Guides execution of Risk and Change Management processes using technical-program-manager and engineering-manager agents.

## Processes Covered

| Process ID | Process Name | Primary Agent | Lifecycle Stage |
|------------|--------------|---------------|-----------------|
| P-074 | RAID Log Maintenance Process | technical-program-manager | Continuous |
| P-075 | Risk Register at Scope Lock Process | technical-program-manager | Gate 2 (Scope Lock) |
| P-076 | Pre-Launch Risk Review Process (CAB) | engineering-manager | Gate 4 (Pre-Launch) |
| P-077 | Quarterly Risk Review Process | technical-program-manager | Continuous (quarterly) |

## Agents

- **technical-program-manager**: Owns RAID log management and risk mitigation planning (P-074, P-075, P-077)
- **engineering-manager**: Owns Change Advisory Board (CAB) and change control processes (P-076)

## When to Use

Use `/risk` when you need to:
- Maintain or review the RAID (Risks, Assumptions, Issues, Dependencies) log
- Document risk register at scope lock (Gate 2)
- Prepare for or conduct a Change Advisory Board review before release
- Perform quarterly risk review and update risk mitigation plans
- Assess risk acceptance criteria for gate reviews

## Related Commands

- `/new-project` — RAID log initialized in Phase 2 (P-074)
- `/release-prep` — CAB review required before release (P-076)
- `/gate-review` — Risk acceptance as gate criteria

## Process Reference

Full process definitions: `~/.claude/processes/13_risk_change_management.md`

## Usage

```
/risk
```

What risk or change management activity do you need help with? I can:
- Facilitate RAID log updates
- Prepare risk register for scope lock
- Conduct CAB review for change approval
- Run quarterly risk assessment
- Generate risk mitigation plans
