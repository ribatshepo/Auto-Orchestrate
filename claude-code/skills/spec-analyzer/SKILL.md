---
name: spec-analyzer
description: |
  Specification analysis, validation, and multi-phase implementation planning.
  Use when user says "specification", "spec analysis", "analyze spec", "validate spec",
  "implementation plan", "phase planning", "requirements extraction", "acceptance criteria",
  "docs/specs", "break down into phases", "implementation roadmap".
triggers:
  - specification
  - spec analysis
  - analyze spec
  - validate spec
  - implementation plan
  - phase planning
  - requirements extraction
  - acceptance criteria
  - docs/specs
  - break down into phases
  - implementation roadmap
---

# Specification Workflow Skill

Patterns, templates, and references for analyzing specifications and creating phased implementation plans.

## Overview

This skill provides:
- **Spec Analysis** - Extract requirements, dependencies, and acceptance criteria
- **Validation** - Ensure specs are complete and implementable
- **Phase Planning** - Break down specs into manageable implementation phases
- **Documentation** - Templates for implementation documents

## Used By

This skill is referenced by:
- Orchestrator agents - Via Task tool delegation
- Planning workflows requiring specification analysis

## Core Principles

> **Specifications must be complete, unambiguous, and testable before implementation begins.**

---

## Parameters (Orchestrator-Provided)

| Parameter | Description | Required |
|-----------|-------------|----------|
| `{{TASK_ID}}` | Current task identifier | Yes |
| `{{DATE}}` | Current date (YYYY-MM-DD) | Yes |
| `{{SLUG}}` | URL-safe topic name | Yes |
| `{{SPEC_PATH}}` | Path to specification file | Yes |
| `{{VALIDATION_CRITERIA}}` | Custom validation criteria | No |
| `{{EPIC_ID}}` | Parent epic identifier | No |
| `{{SESSION_ID}}` | Session identifier | No |

---

## Task System Integration

@_shared/templates/skill-boilerplate.md#task-integration

### Execution Sequence

1. Get task via `TaskGet`fix GAP-002
2. Set focus via `TaskUpdate` (status: in_progress)
3. Execute spec workflow (analyze, validate, or plan)
4. Write output to `{{OUTPUT_DIR}}/{{DATE}}_{{SLUG}}.md`
5. Append manifest entry to `{{MANIFEST_PATH}}`
6. Complete task via `TaskUpdate` (status: completed)
7. Return summary message only

---

## Workflow

```
+-----------------+     +-----------------+     +-----------------+
|  SPEC-ANALYZER  |---->|  SPEC-VALIDATOR |---->| IMPLEMENTATION  |
|                 |     |                 |     |    PLANNER      |
+-----------------+     +-----------------+     +-----------------+
        |                       |                       |
        v                       v                       v
   Extract from            Validate for            Create phased
   docs/specs/             completeness            docs/implementation/
```

## Directory Structure

```
project/
├── docs/
│   ├── specs/                       # Source specifications
│   │   ├── feature-a.md
│   │   ├── feature-b.md
│   │   └── phase-9-user-lifecycle.md
│   │
│   └── implementation/              # Implementation plans (generated)
│       ├── README.md                # Overview and index
│       ├── phase-1-foundation.md    # Phase 1 document
│       ├── phase-2-enhancement.md   # Phase 2 document
│       └── phase-3-integration.md   # Phase 3 document
```

## Specification Patterns

### Required Sections

Every specification should include:

| Section | Purpose |
|---------|---------|
| **Overview** | What and why |
| **Problem Statement** | What problem this solves |
| **Goals** | What success looks like |
| **Functional Requirements** | What the system must do |
| **Non-Functional Requirements** | How well it must perform |
| **Acceptance Criteria** | How to verify completion |
| **Dependencies** | What this relies on |
| **Out of Scope** | What this does NOT include |

### Requirement Format

```markdown
## Requirements

### Functional Requirements

| ID | Priority | Description |
|----|----------|-------------|
| FR-01 | MUST | System shall allow users to register with email |
| FR-02 | MUST | System shall validate email format |
| FR-03 | SHOULD | System shall support social login |

### Non-Functional Requirements

| ID | Category | Description |
|----|----------|-------------|
| NFR-01 | Performance | Response time < 200ms p95 |
| NFR-02 | Availability | 99.9% uptime SLA |
| NFR-03 | Security | All data encrypted at rest |
```

### Acceptance Criteria Format

```markdown
## Acceptance Criteria

### AC-01: User Registration

**Given** a visitor on the registration page
**When** they submit valid email and password
**Then** account is created and confirmation email sent

### AC-02: Invalid Email

**Given** a visitor on the registration page
**When** they submit invalid email format
**Then** error message displayed, no account created
```

## Phase Planning Patterns

### Vertical Slicing (Recommended)

Each phase delivers complete, end-to-end functionality:

```
Phase 1: Basic user registration (email only)
Phase 2: Add social login (Google, GitHub)
Phase 3: Add MFA support
```

### Phase Document Structure

```markdown
# Phase N: [Name]

## Overview
- Status, dates, prerequisites

## Requirements Addressed
- List of FR/NFR IDs

## Deliverables
- What will be built
- Acceptance criteria for each

## Technical Approach
- Architecture decisions
- Data model changesfix GAP-002
- API changes

## Implementation Tasks
- Ordered task list

## Testing Strategy
- Unit, integration, manual tests

## Definition of Done
- Checklist for completion
```

## Validation Checklist

### Blocking Issues
- Missing acceptance criteria
- Contradicting requirements
- Unresolvable dependencies
- Impossible requirements

### Important Issues
- Vague requirements ("fast", "secure")
- Missing error cases
- Incomplete data model
- Missing security requirements

### Minor Issues
- Inconsistent terminology
- Missing diagrams
- Formatting issues

---

## Subagent Protocol

@_shared/templates/skill-boilerplate.md#subagent-protocol

**Summary message:** "Specification workflow complete. See MANIFEST.jsonl for summary."

---

## Output File Format

Write to `{{OUTPUT_DIR}}/{{DATE}}_{{SLUG}}.md`:

```markdown
# Specification Analysis: {{SLUG}}

## Summary

- **Specification:** {{SPEC_PATH}}
- **Status:** {{READY|NEEDS_WORK|BLOCKED}}
- **Readiness Score:** {{SCORE}}/100

## Requirements Extracted

### Functional Requirements

| ID | Priority | Description |
|----|----------|-------------|
| {{ID}} | {{PRIORITY}} | {{DESCRIPTION}} |

### Non-Functional Requirements

| ID | Category | Description |
|----|----------|-------------|
| {{ID}} | {{CATEGORY}} | {{DESCRIPTION}} |

## Validation Results

| Category | Issues | Severity |
|----------|--------|----------|
| {{Category}} | {{Count}} | {{BLOCKING|IMPORTANT|MINOR}} |

## Recommendations

1. {{Recommendation 1}}
2. {{Recommendation 2}}

## Phase Plan (if generated)

| Phase | Focus | Requirements |
|-------|-------|--------------|
| {{N}} | {{Focus}} | {{FR-IDs}} |

## Linked Tasks

- Epic: {{EPIC_ID}}
- Task: {{TASK_ID}}
```

---

## Manifest Entry

@_shared/templates/skill-boilerplate.md#manifest-entry

**Spec-specific fields:**
- `key_findings`: Validation results and readiness score
- `actionable`: `true` if blocking issues found

---

## Completion Checklist

@_shared/templates/skill-boilerplate.md#completion-checklist

### Skill-Specific Items

- [ ] Requirements extracted with IDs and priorities
- [ ] Validation checklist completed
- [ ] Readiness score calculated
- [ ] Phase plan created (if applicable)

---

## Error Handling

@_shared/templates/skill-boilerplate.md#error-handling

**Skill-specific messages:**
- Partial: "Specification workflow partial. See MANIFEST.jsonl for details."
- Blocked: "Specification workflow blocked. See MANIFEST.jsonl for blocker details."

---

## File Structure

```
claude-code/
└── skills/
    └── spec-analyzer/
        ├── SKILL.md               # This file
        └── references/
            ├── spec-patterns.md
            ├── validation-checklist.md
            └── phase-patterns.md
```

## Common Workflows

### Analyze New Specification

1. Read spec -> Extract requirements -> Identify dependencies
2. Check completeness -> Identify issues -> Score readiness
3. Define phases -> Create documents

### Before Implementation

1. Verify spec in `docs/specs/` exists
2. Run validation to ensure readiness
3. Create implementation plan if not exists
4. Begin with Phase 1

### Update Specification

1. Re-run analysis on updated spec
2. Re-validate completeness
3. Update implementation plan if needed
4. Note changes in implementation README

## References

- `references/spec-patterns.md` - Specification structure patterns
- `references/validation-checklist.md` - Validation criteria
- `references/phase-patterns.md` - Phase planning strategies

---

## Skill Chaining

@_shared/protocols/skill-chain-contracts.md

### Produces

| Output | Format | Description |
|--------|--------|-------------|
| `phase-plan` | Markdown | Multi-phase implementation plan with tasks |
| `requirements` | JSON/Markdown | Extracted requirements with IDs and priorities |
| `validation-report` | Markdown | Spec completeness analysis and readiness score |

### Consumes

| Input | From Skill | Description |
|-------|------------|-------------|
| `specification` | `spec-creator` | Specification document to analyze |
| `findings` | `researcher` | Research findings informing the spec |

### Chain Relationships

| Direction | Skills | Pattern |
|-----------|--------|---------|
| Chains from | `spec-creator` | sequential-pipeline |
| Chains to | `task-executor` | analyzer-executor |

The spec-analyzer validates and decomposes specifications from spec-creator into actionable phase plans for task-executor. It also acts as a quality gate by validating spec completeness.
