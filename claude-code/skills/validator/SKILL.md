---
name: validator
description: |
  Compliance validation agent for verifying systems, documents, and code against
  requirements, schemas, or standards. Triggers: "validate", "verify",
  "check compliance", "audit", "compliance check", "validation report".
---

# Validator Skill

Verify that systems, documents, or code comply with specified requirements, schemas, or standards. Produce a PASS / PARTIAL / FAIL report with remediation guidance.

---

## Parameters

| Parameter | Required | Description | Example |
|-----------|----------|-------------|---------|
| `{{VALIDATION_TARGET}}` | Yes | What is being validated | `Schema v2.6.0` |
| `{{TARGET_FILES_OR_SYSTEMS}}` | Yes | Files/paths to check | `schemas/*.json` |
| `{{VALIDATION_CRITERIA}}` | Yes | Checklist of requirements | RFC 2119 compliance items |
| `{{VALIDATION_COMMANDS}}` | No | Specific commands to run | `ajv validate --spec=draft7` |
| `{{SLUG}}` | Yes | URL-safe topic name | `schema-validation` |
| `{{DATE}}` | Yes | Current date (YYYY-MM-DD) | |
| `{{OUTPUT_DIR}}` | Yes | Where to write the report | |

---

## Helper Scripts

| Script | Purpose | Example |
|--------|---------|---------|
| `scripts/schema_validator.py` | Validate JSON/YAML against schemas | `python scripts/schema_validator.py --schema schema.json data.json` |
| `scripts/compliance_checker.py` | Check project conventions | `python scripts/compliance_checker.py --strict .` |

---

## Execution Workflow

1. **Define scope** — identify `{{VALIDATION_TARGET}}` and `{{TARGET_FILES_OR_SYSTEMS}}`.
2. **Identify criteria** — load `{{VALIDATION_CRITERIA}}` and any applicable schemas/standards.
3. **Execute checks** — run automated scripts and manual inspections against every criterion.
4. **Run Docker validation** if applicable (see below).
5. **Document findings** — record each check as PASS/FAIL with details.
6. **Calculate compliance** — compute percentage and assign overall status.
7. **Write report** to `{{OUTPUT_DIR}}/{{DATE}}_{{SLUG}}.md`.
8. **Append manifest** to `{{MANIFEST_PATH}}`.

---

## Status Definitions

| Status | Meaning | Criteria |
|--------|---------|----------|
| **PASS** | Fully compliant | All checks pass, 0 critical issues |
| **PARTIAL** | Mostly compliant | >70% pass, no critical issues |
| **FAIL** | Non-compliant | <70% pass OR any critical issue |

---

## Validation Types

### Schema Validation

Verify data structures against JSON Schema. Check: required fields present, types correct, enum values valid, constraints satisfied.

```python
from lib.layer2.validation import validate_schema, validate_task, validate_config

result = validate_schema(data, schema_path="schemas/todo.schema.json")
is_valid = validate_task(task_dict)
errors = validate_config(config_dict)
```

### Code Compliance

Check: style guide conformance, naming conventions, documentation requirements, security patterns.

### Document Validation

Check: required sections present, frontmatter complete, links valid, format consistent.

### Protocol Compliance

Check: RFC 2119 keywords used correctly, required behaviors implemented, constraints enforced, error handling present.

### Docker Validation

When Docker is available (`docker version` exits 0), invoke `docker-validator` as a **mandatory** sub-step. If Docker is unavailable, skip with a note.

**Delegated phases** (executed by docker-validator): Environment Check → State Audit → Checkpoint → Build & Deploy → UX Testing (unauth + auth) → HTTP Validation → State Restoration.

**Gate rule:** Non-zero errors from docker-validator FAIL the overall validation. Incorporate its error/warning counts into your totals.

**Forward these parameters:** `SESSION_ID`, `TASK_ID`, `DATE`, `SLUG`, `COMPOSE_PATH`, `HEALTHCHECK_ENDPOINT`, `AUTH_ENDPOINT`, `AUTH_CREDENTIALS` (last three from task description if available).

---

## Output File Template

Write to `{{OUTPUT_DIR}}/{{DATE}}_{{SLUG}}.md`:

```markdown
# Validation Report: {{VALIDATION_TARGET}}

## Summary

- **Status**: PASS | PARTIAL | FAIL
- **Compliance**: {X}%
- **Critical Issues**: {N}

## Checklist Results

| Check | Status | Details |
|-------|--------|---------|
| {Check} | PASS/FAIL | {Details} |

## Issues Found

### Critical
{List or "None"}

### Warnings
{List or "None"}

### Suggestions
{List or "None"}

## Remediation

{Required fixes if FAIL/PARTIAL, or "No remediation required" if PASS}
```

---

## Manifest Entry

| Field | Guideline |
|-------|-----------|
| `key_findings` | Overall status + %, critical issue count, main findings summary |
| `actionable` | `true` if any issues found |
| `needs_followup` | Remediation task IDs |
| `topics` | `["validation", "compliance", "{{TOPIC}}"]` |

---

## Skill Chaining

The validator is a **terminal quality-gate skill** — it receives work from executor skills and provides the final pass/fail determination.

| Direction | Skills | What flows |
|-----------|--------|------------|
| Consumes from | `task-executor`, `refactor-executor`, `test-writer-pytest`, `hierarchy-unifier`, `error-standardizer`, `security-auditor`, `docker-validator` | Deliverables and artifacts to validate |
| Produces | — (terminal) | Validation report (Markdown) and structured compliance status (JSON) |

---

## Completion Checklist

- [ ] All validation checks executed
- [ ] Each result documented with PASS/FAIL
- [ ] Compliance percentage calculated
- [ ] Critical issues flagged
- [ ] Docker validation run (if Docker available)
- [ ] Remediation steps provided (if FAIL/PARTIAL)
- [ ] Report written to `{{OUTPUT_DIR}}`
- [ ] Manifest entry appended