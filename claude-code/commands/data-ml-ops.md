---
name: data-ml-ops
description: Guide the user through Data & ML Operations processes (P-049 to P-053).
---

# /data-ml-ops — Data & ML Operations

Guides execution of Data & ML Operations processes using data-engineer and ml-engineer agents.

## Processes Covered

| Process ID | Name | Owner | Description |
|------------|------|-------|-------------|
| P-049 | Data Pipeline Quality Assurance | data-engineer | Every data pipeline includes freshness checks, schema validation, row count validation, and null checks. These checks are automated and alert the Data Engineer when they fail. |
| P-050 | Data Schema Migration | data-engineer | All schema changes go through versioned migration scripts. Destructive changes (drops, renames, type changes) require a manual review flag and explicit approval before execution. |
| P-051 | ML Experiment Logging | ml-engineer | Every ML training run is logged in an experiment tracking system (MLflow/W&B) with hyperparameters, metrics, data version, and artifacts before a model can be considered for production. |
| P-052 | Model Canary Deployment | ml-engineer | Route a small percentage of production traffic to a new model version, validate performance metrics against the baseline, then progressively promote. Never deploy a new model to 100% of traffic directly. |
| P-053 | Data Drift Monitoring | data-engineer/ml-engineer | Automated alerting when input data distribution or model performance metrics drift beyond defined thresholds. Prevents silent model degradation in production. |

## Agents

- **data-engineer**: Owns data pipeline, ingestion, transformation, and storage processes
- **ml-engineer**: Owns model training, evaluation, deployment, and monitoring processes

## When to Use

Use /data-ml-ops when:
- Setting up or modifying data pipelines
- Training, evaluating, or deploying ML models
- Managing feature stores or model registries
- Handling data quality or drift issues

## How to Use

1. Select the process you need from the table above
2. The command will route to the appropriate agent (data-engineer or ml-engineer)
3. Follow the process steps defined in `claude-code/processes/08_data_ml_operations.md`

## Related Commands

- `/active-dev` — Sprint execution (may invoke data/ML processes)
- `/release-prep` — Pre-release quality checks (includes data validation)
- `/post-launch` — Post-launch monitoring (includes ML model monitoring)

## Process Reference

Full process definitions: `claude-code/processes/08_data_ml_operations.md`
