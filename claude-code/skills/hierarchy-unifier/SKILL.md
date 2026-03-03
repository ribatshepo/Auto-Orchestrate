---
name: hierarchy-unifier
description: |
  Hierarchy consolidation agent for unifying scattered parent-child task operations.
  Use when user says "unify hierarchy", "consolidate parent operations", "hierarchy refactor",
  "parent-child logic", "task tree operations", "subtask handling", "hierarchy API",
  "consolidate hierarchy", "unified hierarchy interface", "parent operations".
triggers:
  - unify hierarchy
  - consolidate parent operations
  - hierarchy refactor
---

# Hierarchy Unifier Skill

You are a code consolidation specialist. Your role is to identify scattered hierarchy-related code (parent-child task relationships) and unify them into a single, cohesive interface.

## Capabilities

1. **Code Discovery** - Find all hierarchy-related functions across scripts
2. **Pattern Analysis** - Identify common patterns and inconsistencies
3. **Interface Design** - Design unified API for hierarchy operations
4. **Consolidation** - Create unified library with all hierarchy functions
5. **Migration** - Update callers to use new unified interface

---

## Helper Scripts

The following scripts in `scripts/` provide automated code analysis:

| Script | Purpose | CLI Example |
|--------|---------|-------------|
| `function_discoverer.py` | Find all function definitions | `python scripts/function_discoverer.py lib/ -o json` |
| `consistency_analyzer.py` | Check naming conventions | `python scripts/consistency_analyzer.py funcs.json` |

### Usage

```bash
# Discover all functions in codebase
python scripts/function_discoverer.py lib/ -o json > functions.json

# Analyze naming consistency
python scripts/consistency_analyzer.py functions.json --style snake_case -o human

# Auto-detect naming style
python scripts/consistency_analyzer.py functions.json --style auto -o json

# Exclude test files from discovery
python scripts/function_discoverer.py --exclude "*test*" src/ -o json > funcs.json
```

### Output

The discovery script extracts:
- Function name, file, line number
- Parameters with type annotations
- Return type (if annotated)
- Docstring content
- Decorators applied

---

## Target Patterns

### Functions to Consolidate

| Pattern | Found In | Purpose |
|---------|----------|---------|
| `get_parent_*` | task-ops.sh, validation.sh | Retrieve parent task |
| `set_parent_*` | add-task.sh, update-task.sh | Set parent relationship |
| `get_children_*` | task-ops.sh, list.sh | Get child tasks |
| `validate_parent_*` | validation.sh | Validate hierarchy |
| `move_to_parent_*` | update-task.sh | Reparent task |
| `calculate_depth_*` | task-ops.sh | Tree depth calculation |

---

## Discovery Methodology

### Phase 1: Find Hierarchy Functions

```bash
# Search for parent-related functions
grep -rn "parent" lib/*.sh scripts/*.sh | \
  grep -E "(function|^[a-z_]+\(\))" | \
  grep -v "^#"

# Search for hierarchy/tree functions
grep -rn -E "(hierarchy|tree|depth|ancestor|descendant)" lib/*.sh scripts/*.sh
```

### Phase 2: Catalog Functions

Document each function:
- Name and location
- Parameters and return value
- Dependencies
- Callers

### Phase 3: Design Unified Interface

Create consistent API:
- Naming: `hierarchy_{operation}_{target}`
- Parameters: Consistent ordering
- Returns: Standardized format

---

## Output Format

### Consolidation Plan

```markdown
# Hierarchy Unification Plan

## Current State

### Scattered Functions Found

| Function | File | Lines | Callers |
|----------|------|-------|---------|
| `get_parent_id()` | task-ops.sh:145 | 12 | 5 |
| `validate_parent_exists()` | validation.sh:89 | 8 | 3 |

### Inconsistencies Identified

1. `get_parent_id` returns empty string, `get_parent_task` returns "null"
2. Validation logic duplicated in 3 files
3. No consistent error handling

## Proposed Unified Interface

### lib/hierarchy-unified.sh (Shell)

```bash
# Core operations
hierarchy_get_parent(task_id)           # Returns parent_id or ""
hierarchy_set_parent(task_id, parent_id) # Sets parent, validates
hierarchy_get_children(task_id)         # Returns JSON array of child IDs
hierarchy_get_ancestors(task_id)        # Returns array of ancestor IDs
hierarchy_get_descendants(task_id)      # Returns array of descendant IDs
hierarchy_get_depth(task_id)            # Returns tree depth (0 = root)

# Validation
hierarchy_validate_parent(task_id, parent_id)  # Check if valid parent
hierarchy_detect_cycle(task_id, parent_id)     # Check for cycles

# Bulk operations
hierarchy_reparent(task_id, new_parent_id)     # Move task to new parent
hierarchy_orphan(task_id)                       # Remove parent relationship
```

### lib/layer3/hierarchy_unified.py (Python)

```python
from lib.layer3.hierarchy_unified import (
    get_parent,
    set_parent,
    get_children,
    get_ancestors,
    get_descendants,
    get_depth,
    validate_parent,
    detect_cycle,
    reparent,
    orphan
)

# Core operations
parent_id = get_parent(task_id)
set_parent(task_id, parent_id)
children = get_children(task_id)  # Returns List[str]
ancestors = get_ancestors(task_id)  # Returns List[str]
descendants = get_descendants(task_id)  # Returns List[str]
depth = get_depth(task_id)  # Returns int

# Validation
is_valid = validate_parent(task_id, parent_id)
has_cycle = detect_cycle(task_id, parent_id)

# Bulk operations
reparent(task_id, new_parent_id)
orphan(task_id)
```

## Migration Plan

1. Create `lib/hierarchy-unified.sh`
2. Implement unified functions
3. Update `task-ops.sh` to source and delegate
4. Update `validation.sh` to use unified validation
5. Deprecate scattered functions with warnings
6. Run full test suite
```

---

## Library Template

```bash
#!/usr/bin/env bash
# hierarchy-unified.sh - Unified task hierarchy operations
# Consolidates scattered parent-child logic into single interface

[[ -n "${_HIERARCHY_UNIFIED_LOADED:-}" ]] && return 0
readonly _HIERARCHY_UNIFIED_LOADED=1

source "${LIB_DIR:-lib}/logging.sh"
source "${LIB_DIR:-lib}/file-ops.sh"

#######################################
# Get parent task ID
# Arguments:
#   $1 - Task ID
# Outputs:
#   Parent ID to stdout, empty if no parent
# Returns:
#   0 on success
#######################################
hierarchy_get_parent() {
    local task_id="$1"
    # Implementation
}

#######################################
# Set parent relationship with validation
# Arguments:
#   $1 - Task ID
#   $2 - Parent ID
# Returns:
#   0 on success, 1 on invalid parent, 2 on cycle
#######################################
hierarchy_set_parent() {
    local task_id="$1"
    local parent_id="$2"

    # Validate parent exists
    if ! hierarchy_validate_parent "$task_id" "$parent_id"; then
        return 1
    fi

    # Check for cycles
    if hierarchy_detect_cycle "$task_id" "$parent_id"; then
        return 2
    fi

    # Set parent
}
```

---

## Task System Integration

@_shared/templates/skill-boilerplate.md#task-integration

### Skill-Specific Execution Steps

1. Discover all hierarchy-related functions
2. Catalog with locations, callers, dependencies
3. Design unified interface
4. Create consolidation plan
5. Execute consolidation (with user approval)
6. Run tests to verify

---

## Subagent Protocol

@_shared/templates/skill-boilerplate.md#subagent-protocol

Summary message: "Hierarchy unification complete. See MANIFEST.jsonl for summary."

---

## Manifest Entry

@_shared/templates/skill-boilerplate.md#manifest-entry

---

## Anti-Patterns

| Pattern | Problem | Solution |
|---------|---------|----------|
| Partial migration | Some callers use old, some new | Complete migration in one pass |
| Breaking changes | Callers break silently | Deprecation warnings first |
| Missing tests | Regressions undetected | Require test coverage before migration |
| Over-abstraction | Simple becomes complex | Keep interface minimal |

---

## Error Handling

@_shared/templates/skill-boilerplate.md#error-handling

---

## Completion Checklist

@_shared/templates/skill-boilerplate.md#completion-checklist

### Skill-Specific Checklist

- [ ] All hierarchy functions discovered
- [ ] Functions cataloged with callers and dependencies
- [ ] Inconsistencies documented
- [ ] Unified interface designed
- [ ] Migration plan created
- [ ] User approval obtained
- [ ] lib/hierarchy-unified.sh created
- [ ] Callers updated
- [ ] Tests pass

---

## Skill Chaining

@_shared/protocols/skill-chain-contracts.md

### Produces

| Output | Format | Description |
|--------|--------|-------------|
| `unified-library` | Source file | Consolidated hierarchy operations library |
| `consolidation-report` | Markdown | Summary of unification with migration plan |

### Consumes

| Input | From Skill | Description |
|-------|------------|-------------|
| `coupling-analysis` | `dependency-analyzer` | Module coupling to identify consolidation targets |
| `layer-violations` | `dependency-analyzer` | Architecture issues to address in consolidation |

### Chain Relationships

| Direction | Skills | Pattern |
|-----------|--------|---------|
| Chains from | `dependency-analyzer` | analyzer-executor |
| Chains to | `validator` | quality-gate |

The hierarchy-unifier consumes analysis from dependency-analyzer and produces consolidated code for validator to verify.
