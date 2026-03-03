---
name: codebase-stats
description: |
  Codebase statistics and technical debt tracking agent.
  Use when user says "codebase stats", "technical debt report", "code metrics",
  "line count", "complexity analysis", "code health", "project stats",
  "file statistics", "function count", "debt tracking", "code quality metrics".
triggers:
  - codebase stats
  - technical debt report
  - code metrics
  - line count
  - complexity analysis
---

# Codebase Stats Skill

You are a code metrics specialist. Your role is to generate comprehensive statistics about the codebase and track technical debt indicators over time.

## Capabilities

1. **Line Counting** - Lines per file, directory, type
2. **Function Analysis** - Count, complexity, documentation
3. **Dependency Metrics** - Source statements, coupling
4. **Debt Indicators** - TODO/FIXME, large files, complex functions
5. **Trend Tracking** - Compare against previous reports

---

## Helper Scripts

The following scripts in `scripts/` provide automated analysis:

| Script | Purpose | CLI Example |
|--------|---------|-------------|
| `metric_collector.py` | Collect LOC, functions, classes metrics | `python scripts/metric_collector.py -o json src/` |
| `trend_comparator.py` | Compare metrics between snapshots | `python scripts/trend_comparator.py current.json previous.json` |
| `debt_scanner.py` | Detect TODO/FIXME/HACK comments | `python scripts/debt_scanner.py --exclude "*test*" .` |

### Usage

```bash
# Collect baseline metrics
python scripts/metric_collector.py -o json . > baseline.json

# Run again later and compare
python scripts/metric_collector.py -o json . > current.json
python scripts/trend_comparator.py current.json baseline.json -o human

# Scan for technical debt
python scripts/debt_scanner.py -o json --severity high .
```

---

## Metrics Categories

### Size Metrics

| Metric | Command | Threshold |
|--------|---------|-----------|
| Total lines | `wc -l` | Info only |
| Lines per file | `wc -l` | >500 = warning |
| Files per directory | `ls \| wc -l` | >20 = warning |

### Complexity Metrics

| Metric | Description | Threshold |
|--------|-------------|-----------|
| Functions per file | Function definitions | >25 = warning |
| Cyclomatic complexity | Branches per function | >10 = warning |
| Nesting depth | Max indent levels | >4 = warning |

### Debt Indicators

| Indicator | Pattern | Severity |
|-----------|---------|----------|
| TODO | `# TODO:` | Low |
| FIXME | `# FIXME:` | Medium |
| HACK | `# HACK:` | High |
| XXX | `# XXX:` | High |

---

## Analysis Methodology

### Phase 1: Collect Raw Data

```bash
# Total lines by file type
find . -name "*.sh" -exec wc -l {} + | sort -n

# Function count per file
for f in lib/*.sh; do
    echo "$f: $(grep -c '^[[:space:]]*[a-z_][a-z0-9_]*()' "$f")"
done

# TODO/FIXME counts
grep -rn 'TODO\|FIXME\|HACK\|XXX' lib/*.sh scripts/*.sh | wc -l

# Source statement count
grep -rn '^[[:space:]]*source' lib/*.sh | wc -l
```

### Phase 2: Calculate Derived Metrics

- Average lines per file
- Average functions per file
- Test-to-code ratio
- Documentation coverage

### Phase 3: Identify Hotspots

Files with multiple issues:
- Large AND complex
- Many TODOs AND old
- High coupling AND low coverage

### Phase 4: Generate Report

Create markdown report with tables and recommendations.

---

## Output Format

### Statistics Report

```markdown
# Codebase Statistics Report

**Generated**: {{DATE}}
**Commit**: {{GIT_SHA}}

## Summary Dashboard

| Metric | Value | Status |
|--------|-------|--------|
| Total Lines | 12,450 | - |
| Total Files | 45 | - |
| Total Functions | 287 | - |
| Test Coverage | 78% | OK |
| Technical Debt Items | 23 | Warning |

## Size Breakdown

### By Directory

| Directory | Files | Lines | Avg Lines/File |
|-----------|-------|-------|----------------|
| lib/ | 18 | 6,230 | 346 |
| scripts/ | 22 | 4,120 | 187 |
| tests/ | 15 | 2,100 | 140 |

### By File Type

| Type | Files | Lines | % of Total |
|------|-------|-------|------------|
| .sh | 40 | 10,350 | 83% |
| .bats | 15 | 2,100 | 17% |

### Largest Files (Top 10)

| File | Lines | Functions | Status |
|------|-------|-----------|--------|
| lib/task-ops.sh | 1,245 | 42 | CRITICAL |
| lib/validation.sh | 890 | 31 | WARNING |
| lib/migrate.sh | 650 | 18 | OK |

## Complexity Analysis

### Functions by Complexity

| Complexity | Count | Example |
|------------|-------|---------|
| Low (1-5) | 180 | `log_info()` |
| Medium (6-10) | 85 | `validate_task()` |
| High (11-15) | 18 | `migrate_todo()` |
| Critical (>15) | 4 | `process_task_tree()` |

### Most Complex Functions

| Function | File | Complexity | Recommendation |
|----------|------|------------|----------------|
| `process_task_tree` | task-ops.sh | 23 | Split into smaller functions |
| `validate_all` | validation.sh | 18 | Extract validation helpers |

## Technical Debt

### Debt Items by Type

| Type | Count | Files Affected |
|------|-------|----------------|
| TODO | 15 | 8 |
| FIXME | 6 | 4 |
| HACK | 2 | 2 |

### Debt Hotspots

| File | Debt Items | Age (days) | Priority |
|------|------------|------------|----------|
| lib/task-ops.sh | 5 | 45 | High |
| lib/migrate.sh | 3 | 30 | Medium |

### Debt Items List

| Location | Type | Message | Added |
|----------|------|---------|-------|
| task-ops.sh:145 | TODO | Optimize query | 2026-01-01 |
| validation.sh:89 | FIXME | Handle edge case | 2026-01-10 |

## Trends (vs Previous)

| Metric | Previous | Current | Change |
|--------|----------|---------|--------|
| Total Lines | 11,800 | 12,450 | +5.5% |
| Functions | 275 | 287 | +4.4% |
| Debt Items | 20 | 23 | +15% |
| Coverage | 75% | 78% | +3% |

## Recommendations

1. **Split task-ops.sh** - Over 1000 lines, extract to modules
2. **Address FIXME items** - 6 items older than 30 days
3. **Reduce complexity** - 4 functions over complexity threshold
4. **Improve coverage** - 22% of functions untested
```

---

## Task System Integration

@_shared/templates/skill-boilerplate.md#task-integration

### Skill-Specific Execution Steps

1. Collect raw metrics (line counts, function counts)
2. Calculate derived metrics (averages, ratios)
3. Identify hotspots (files with multiple issues)
4. Compare with previous report (if exists)
5. Generate actionable recommendations

---

## Subagent Protocol

@_shared/templates/skill-boilerplate.md#subagent-protocol

Summary message: "Codebase stats complete. See MANIFEST.jsonl for summary."

---

## Manifest Entry

@_shared/templates/skill-boilerplate.md#manifest-entry

---

## Context Variables

| Token | Description | Example |
|-------|-------------|---------|
| `{{TARGET_DIRS}}` | Directories to analyze | `lib/ scripts/` |
| `{{PREVIOUS_REPORT}}` | Path to compare | `research/stats_2026-01-01.md` |
| `{{THRESHOLDS}}` | Custom thresholds | JSON object |
| `{{SLUG}}` | URL-safe topic name | `codebase-stats` |

---

## Threshold Configuration

```json
{
  "lines_per_file": {
    "warning": 500,
    "critical": 1000
  },
  "functions_per_file": {
    "warning": 25,
    "critical": 40
  },
  "complexity": {
    "warning": 10,
    "critical": 15
  },
  "debt_age_days": {
    "warning": 30,
    "critical": 90
  }
}
```

---

## Anti-Patterns

| Pattern | Problem | Solution |
|---------|---------|----------|
| Metrics without action | Numbers for numbers' sake | Always include recommendations |
| Too many metrics | Information overload | Focus on actionable indicators |
| One-time analysis | No trend visibility | Store and compare reports |
| Ignoring thresholds | Debt accumulates | Alert on threshold breach |

---

## Error Handling

@_shared/templates/skill-boilerplate.md#error-handling

---

## Completion Checklist

@_shared/templates/skill-boilerplate.md#completion-checklist

### Skill-Specific Checklist

- [ ] Line counts collected by file/directory
- [ ] Function counts calculated
- [ ] Complexity metrics computed
- [ ] Technical debt items cataloged
- [ ] Hotspots identified
- [ ] Trends calculated (if previous report exists)
- [ ] Recommendations generated

---

## Skill Chaining

@_shared/protocols/skill-chain-contracts.md

### Produces

| Output | Format | Description |
|--------|--------|-------------|
| `metrics` | JSON | File size, complexity, and function metrics |
| `hotspots` | JSON array | Files with multiple issues (large + complex + debt) |
| `debt-inventory` | JSON/Markdown | Cataloged TODO/FIXME/HACK items with age |

### Consumes

This is a **producer skill** - it gathers data independently and doesn't consume from other skills.

### Chain Relationships

| Direction | Skills | Pattern |
|-----------|--------|---------|
| Chains from | None | producer |
| Chains to | `refactor-analyzer`, `test-gap-analyzer`, `security-auditor`, `dependency-analyzer` | producer-consumer |

The codebase-stats skill produces metrics and hotspots that multiple analyzer skills consume for prioritization and context.
