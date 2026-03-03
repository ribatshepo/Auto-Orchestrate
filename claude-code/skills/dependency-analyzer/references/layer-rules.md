# Dependency Layer Rules

## Layer Architecture

The Python shared libraries follow a strict layered architecture to prevent circular dependencies:

```
Layer 3 (Orchestration)
  ↓ can import from
Layer 2 (Business Logic)
  ↓ can import from
Layer 1 (Core Utilities)
  ↓ can import from
Layer 0 (Primitives)
```

## Layer Definitions

### Layer 0: Primitives
**Purpose:** Foundation types, constants, exit codes
**No dependencies** (cannot import from any other layer)
**Modules:**
- `colors.py` — ANSI color codes
- `constants.py` — Global constants
- `exit_codes.py` — Exit code definitions

### Layer 1: Core Utilities
**Purpose:** File I/O, logging, output formatting
**Can import:** Layer 0 only
**Modules:**
- `file_ops.py` — File operations
- `logging.py` — Logging utilities
- `output_format.py` — Output formatting
- `error_json.py` — JSON error formatting
- `config.py` — Configuration loading

### Layer 2: Business Logic
**Purpose:** Validation, task operations
**Can import:** Layers 0-1
**Modules:**
- `validation.py` — Input validation
- `task_ops.py` — Task system operations

### Layer 3: Orchestration
**Purpose:** Complex workflows, migrations, backups
**Can import:** Layers 0-2
**Modules:**
- `doctor.py` — Health checks
- `hierarchy_unified.py` — Hierarchy operations
- `migrate.py` — Migration utilities
- `backup.py` — Backup management

## Import Rules

### Allowed Import Patterns

✅ **Layer 0 imports:**
```python
# No imports from shared library (only stdlib)
import os
import sys
from pathlib import Path
```

✅ **Layer 1 imports:**
```python
from layer0.colors import colorize, RED, GREEN
from layer0.exit_codes import EXIT_ERROR, exit_code_to_message
```

✅ **Layer 2 imports:**
```python
from layer0.constants import MAX_TASK_DEPTH
from layer1.file_ops import read_file, write_file
from layer1.logging import emit_error, emit_warning
```

✅ **Layer 3 imports:**
```python
from layer0.exit_codes import EXIT_SUCCESS
from layer1.config import load_config
from layer2.validation import validate_path, ValidationResult
```

### Forbidden Import Patterns

❌ **Cross-layer violations:**
```python
# Layer 0 CANNOT import from Layer 1
from layer1.logging import get_logger  # VIOLATION

# Layer 1 CANNOT import from Layer 2
from layer2.validation import validate_path  # VIOLATION

# Layer 2 CANNOT import from Layer 3
from layer3.backup import create_backup  # VIOLATION
```

❌ **Circular dependencies:**
```python
# file_ops.py
from layer1.logging import emit_error  # OK

# logging.py
from layer1.file_ops import read_file  # CIRCULAR - both in Layer 1
```

## Violation Detection

### Static Analysis Check

```python
import ast
import re
from pathlib import Path

def detect_layer_violations(file_path: Path) -> list:
    """Detect layer dependency violations."""
    violations = []

    # Determine file's layer
    if '/layer0/' in str(file_path):
        current_layer = 0
    elif '/layer1/' in str(file_path):
        current_layer = 1
    elif '/layer2/' in str(file_path):
        current_layer = 2
    elif '/layer3/' in str(file_path):
        current_layer = 3
    else:
        return []

    # Parse imports
    content = file_path.read_text()
    tree = ast.parse(content)

    for node in ast.walk(tree):
        if isinstance(node, ast.ImportFrom):
            if node.module and node.module.startswith('layer'):
                # Extract imported layer number
                match = re.match(r'layer(\d+)', node.module)
                if match:
                    imported_layer = int(match.group(1))

                    # Check violation
                    if imported_layer >= current_layer:
                        violations.append({
                            'file': str(file_path),
                            'line': node.lineno,
                            'current_layer': current_layer,
                            'imported_layer': imported_layer,
                            'import': node.module
                        })

    return violations
```

### Command-Line Check

```bash
# Check all Python files for violations
find . -name "*.py" -path "*/layer*" | while read file; do
    python dependency_checker.py "$file"
done
```

## Refactoring Guide

### Moving Code Between Layers

When moving code UP layers (e.g., Layer 1 → Layer 2):
1. Update imports in the moved module
2. Update `__init__.py` in both old and new layers
3. Update all files that import the moved module
4. Run violation detection

When moving code DOWN layers (e.g., Layer 2 → Layer 1):
1. Ensure no dependencies on higher layers
2. Remove higher-layer imports
3. Update `__init__.py` files
4. Update importers
5. Run full test suite

### Breaking Circular Dependencies

If module A and B in same layer need each other:
1. Extract shared logic to lower layer
2. Use dependency injection
3. Pass dependencies as function parameters
4. Consider if one should move to higher layer

## Common Violations and Fixes

### Violation: Layer 0 importing Layer 1

❌ **Problem:**
```python
# layer0/exit_codes.py
from layer1.logging import emit_error
```

✅ **Solution:** Layer 0 cannot use logging. Remove dependency.

### Violation: Circular import in same layer

❌ **Problem:**
```python
# layer1/file_ops.py
from layer1.config import get_config_path

# layer1/config.py
from layer1.file_ops import read_file
```

✅ **Solution:** Extract common logic to Layer 0 or pass dependencies as parameters.

## Testing Layer Compliance

```python
def test_layer_dependencies():
    """Ensure all files respect layer rules."""
    from pathlib import Path

    violations = []
    python_dir = Path(__file__).parent.parent

    for layer_dir in python_dir.glob("layer*"):
        for py_file in layer_dir.glob("*.py"):
            if py_file.name == "__init__.py":
                continue
            violations.extend(detect_layer_violations(py_file))

    assert len(violations) == 0, f"Layer violations found: {violations}"
```
