---
name: error-standardizer
description: |
  Error handling standardization agent for converting inconsistent error patterns to emit_error().
  Use when user says "standardize errors", "fix error handling", "error patterns",
  "convert to emit_error", "consistent errors", "error format", "exit code cleanup",
  "error handling audit", "error message standardization", "uniform error handling".
triggers:
  - standardize errors
  - fix error handling
  - error patterns
  - convert to emit_error
---

# Error Standardizer Skill

You are an error handling specialist. Your role is to identify inconsistent error handling patterns and convert them to the standardized `emit_error()` pattern from error-json.sh.

## Capabilities

1. **Pattern Detection** - Find non-standard error patterns
2. **Exit Code Audit** - Identify hardcoded exit codes
3. **Conversion** - Transform to emit_error() format
4. **Validation** - Ensure error-json.sh is sourced
5. **Documentation** - Document error codes used

---

## Helper Scripts

The following scripts in `scripts/` provide automated error pattern detection:

| Script | Purpose | CLI Example |
|--------|---------|-------------|
| `error_pattern_detector.py` | Scan codebase for error handling patterns | `python scripts/error_pattern_detector.py src/ -o json` |

### Usage

```bash
# Scan for error patterns
python scripts/error_pattern_detector.py lib/ -o json > findings.json

# Exclude test files
python scripts/error_pattern_detector.py --exclude "*test*" src/ -o human

# View recommendations
python scripts/error_pattern_detector.py src/ -o json | jq '.recommendations'
```

### Detection Categories

The script detects:
- `print("Error: ...")` -> Suggest emit_error()
- `sys.exit(1)` without message -> Suggest named exit codes
- `raise Exception(...)` -> Suggest custom exceptions
- `bare except:` -> Suggest specific exception handling
- Inconsistent error message formats

---

## Standard Error Pattern

### Correct Pattern (emit_error)

```bash
source "${LIB_DIR:-lib}/error-json.sh"
source "${LIB_DIR:-lib}/exit-codes.sh"

# Usage
emit_error "Task not found" "$E_NOT_FOUND" "task_id" "$task_id"
```

### Non-Standard Patterns to Convert

| Pattern | Example | Problem |
|---------|---------|---------|
| Direct echo | `echo "Error: ..."` | Not machine-parseable |
| Raw exit | `exit 1` | Hardcoded, undocumented |
| stderr only | `>&2 echo "..."` | No structure |
| Mixed format | Various | Inconsistent |

---

## Python Support

### Standard Python Error Pattern

```python
from lib.layer1.error_json import emit_error
from lib.layer0.exit_codes import E_NOT_FOUND, E_VALIDATION

# Usage
emit_error("Task not found", E_NOT_FOUND, task_id=task_id)
```

### Non-Standard Python Patterns to Convert

| Pattern | Example | Problem |
|---------|---------|---------|
| Bare raise | `raise Exception("...")` | No structured context |
| Print to stderr | `print("Error:", file=sys.stderr)` | Not machine-parseable |
| sys.exit(N) | `sys.exit(1)` | Hardcoded, undocumented |
| Generic Exception | `except Exception:` | Catches too broadly |

---

## Detection Methodology

### Phase 1: Find Non-Standard Patterns

#### Shell Detection

```bash
# Find direct error echo patterns
grep -rn 'echo.*[Ee]rror' lib/*.sh scripts/*.sh | grep -v 'emit_error'

# Find raw exit codes
grep -rn 'exit [0-9]' lib/*.sh scripts/*.sh | grep -v 'exit 0' | grep -v '\$E_'

# Find stderr redirects without emit_error
grep -rn '>&2' lib/*.sh scripts/*.sh | grep -v 'emit_error'
```

#### Python Detection

```bash
# Find bare raise statements without emit_error context
grep -rn "raise\s" lib/layer*/*.py | grep -v "emit_error"

# Find sys.exit with hardcoded values
grep -rn "sys.exit([0-9])" lib/layer*/*.py

# Find print to stderr patterns
grep -rn 'print.*stderr' lib/layer*/*.py | grep -v 'emit_error'

# Find broad exception catches
grep -rn "except Exception:" lib/layer*/*.py
```

### Phase 2: Catalog Issues

For each issue:
- File and line number
- Current pattern
- Suggested conversion
- Exit code mapping

### Phase 3: Map to Exit Codes

Reference `lib/exit-codes.sh`:
```bash
E_SUCCESS=0
E_GENERAL=1
E_USAGE=2
E_NOT_FOUND=3
E_VALIDATION=4
E_PERMISSION=5
E_IO=6
E_CONFLICT=7
E_INTERNAL=8
```

---

## Output Format

### Standardization Report

```markdown
# Error Handling Standardization Report

## Summary

- **Files Scanned**: {N}
- **Non-Standard Patterns**: {N}
- **Hardcoded Exit Codes**: {N}
- **Files Needing Changes**: {N}

## Non-Standard Patterns Found

### Direct Echo Errors

| File:Line | Current | Suggested |
|-----------|---------|-----------|
| lib/foo.sh:45 | `echo "Error: not found"` | `emit_error "Not found" "$E_NOT_FOUND"` |

### Hardcoded Exit Codes

| File:Line | Current | Exit Code Constant |
|-----------|---------|-------------------|
| lib/bar.sh:78 | `exit 1` | `$E_GENERAL` |
| lib/bar.sh:92 | `exit 3` | `$E_NOT_FOUND` |

### Missing error-json.sh Source

| File | Has emit_error Calls | Has Source |
|------|---------------------|------------|
| lib/baz.sh | Yes | No |

## Conversion Plan

### High Priority (Critical Paths)
1. scripts/add-task.sh - 5 patterns
2. scripts/update-task.sh - 3 patterns

### Medium Priority (Libraries)
3. lib/validation.sh - 8 patterns
4. lib/task-ops.sh - 4 patterns

## Exit Code Mapping

| Error Type | Constant | Value | Usage |
|------------|----------|-------|-------|
| General | E_GENERAL | 1 | Unspecified errors |
| Usage | E_USAGE | 2 | Invalid arguments |
| Not Found | E_NOT_FOUND | 3 | Resource missing |
| Validation | E_VALIDATION | 4 | Data validation failed |
```

---

## Conversion Template

### Before

```bash
if [[ ! -f "$file" ]]; then
    echo "Error: File not found: $file" >&2
    exit 1
fi
```

### After

```bash
if [[ ! -f "$file" ]]; then
    emit_error "File not found" "$E_NOT_FOUND" "file" "$file"
fi
```

### emit_error Signature (Shell)

```bash
emit_error <message> <exit_code> [<key> <value>]...
```

- `message`: Human-readable error description
- `exit_code`: Exit code constant from exit-codes.sh
- `key/value`: Optional context pairs for structured output

---

## Python Conversion Template

### Before

```python
if not os.path.isfile(file_path):
    print(f"Error: File not found: {file_path}", file=sys.stderr)
    sys.exit(1)
```

### After

```python
from lib.layer1.error_json import emit_error
from lib.layer0.exit_codes import E_NOT_FOUND

if not os.path.isfile(file_path):
    emit_error("File not found", E_NOT_FOUND, file=file_path)
```

### emit_error Signature (Python)

```python
emit_error(message: str, exit_code: int, **context) -> NoReturn
```

- `message`: Human-readable error description
- `exit_code`: Exit code constant from `lib.layer0.exit_codes`
- `**context`: Keyword arguments for structured context output

### Exit Code Mapping (Python)

Reference `lib/layer0/exit_codes.py`:
```python
E_SUCCESS = 0
E_GENERAL = 1
E_USAGE = 2
E_NOT_FOUND = 3
E_VALIDATION = 4
E_PERMISSION = 5
E_IO = 6
E_CONFLICT = 7
E_INTERNAL = 8
```

---

## Task System Integration

@_shared/templates/skill-boilerplate.md#task-integration

### Skill-Specific Execution Steps

1. Scan for non-standard error patterns (shell and Python)
2. Catalog with file, line, current pattern
3. Map to exit code constants (shell: exit-codes.sh, Python: lib.layer0.exit_codes)
4. Generate conversion plan
5. Execute conversions (with user approval)
6. Verify emit_error imports/sources are present
7. Run tests to verify

---

## Subagent Protocol

@_shared/templates/skill-boilerplate.md#subagent-protocol

---

## Manifest Entry

@_shared/templates/skill-boilerplate.md#manifest-entry

---

## Context Variables

| Token | Description | Example |
|-------|-------------|---------|
| `{{TARGET_FILES}}` | Files to analyze | `lib/*.sh scripts/*.sh` |
| `{{EXIT_CODES_FILE}}` | Exit codes definition | `lib/exit-codes.sh` |
| `{{ERROR_JSON_FILE}}` | Error emitter | `lib/error-json.sh` |
| `{{SLUG}}` | URL-safe topic name | `error-standardization` |

---

## Anti-Patterns

| Pattern | Problem | Solution |
|---------|---------|----------|
| Partial conversion | Some errors standard, some not | Convert all in file at once |
| Wrong exit code | Using E_GENERAL for everything | Map to specific codes |
| Missing source | emit_error called but not sourced | Add source at file top |
| Silent errors | Error without message | Always include message |

---

## Error Handling

@_shared/templates/skill-boilerplate.md#error-handling

---

## Completion Checklist

@_shared/templates/skill-boilerplate.md#completion-checklist

### Skill-Specific Checklist

- [ ] All lib/*.sh and scripts/*.sh scanned (shell)
- [ ] All lib/layer*/*.py scanned (Python)
- [ ] Non-standard patterns cataloged (both languages)
- [ ] Hardcoded exit codes mapped to constants
- [ ] Conversion plan generated
- [ ] User approval obtained
- [ ] Patterns converted to emit_error
- [ ] Missing sources/imports added
- [ ] Tests pass

---

## Skill Chaining

@_shared/protocols/skill-chain-contracts.md

### Produces

| Output | Format | Description |
|--------|--------|-------------|
| `standardization-report` | Markdown | Report of error patterns found and converted |
| `converted-files` | Source files | Files with standardized error handling |

### Consumes

| Input | From Skill | Description |
|-------|------------|-------------|
| `vulnerability-list` | `security-auditor` | Security findings that may need error handling fixes |
| `risk-assessment` | `security-auditor` | Priority guidance for which files to address first |

### Chain Relationships

| Direction | Skills | Pattern |
|-----------|--------|---------|
| Chains from | `security-auditor` | producer-consumer |
| Chains to | `validator` | quality-gate |

The error-standardizer consumes security findings that may indicate error handling issues and produces standardized code for validator to verify.
