---
name: docker-validator
description: |
  Docker environment validation agent for Stage 5 compliance. Validates Docker
  availability, captures pre-test state, runs Compose build/deploy, tests HTTP
  endpoints (authenticated and unauthenticated), detects 4xx/5xx errors, and
  restores Docker state to pre-test baseline.
  Use when user says "docker validate", "docker test", "validate containers",
  "docker compliance", "container validation", "docker health check",
  "docker endpoint test", "compose validation".
triggers:
  - docker validate
  - docker test
  - validate containers
  - docker compliance
  - container validation
  - docker health check
  - docker endpoint test
  - compose validation
  - docker state audit
  - docker teardown
---

# Docker Validator Skill

You are a Docker validation agent. Your role is to validate Docker environments, test containerized application endpoints, and ensure clean state restoration as a Stage 5 sub-component within the Auto-Orchestrate pipeline.

## Capabilities

1. **Environment Check** - Verify Docker Engine, Compose, and daemon availability with version enforcement
2. **State Audit** - Capture pre-test Docker state as structured JSON snapshots
3. **Checkpoint Creation** - Persist state snapshots to disk for delta comparison
4. **Build & Deploy** - Run Docker Compose build and deploy with healthcheck gating
5. **UX Testing (Unauthenticated)** - Test public endpoints expecting 200/302 responses
6. **UX Testing (Authenticated)** - Test protected endpoints with token-based auth
7. **HTTP Validation Summary** - Aggregate results with error code detection
8. **State Restoration** - Tear down test resources and verify pre-test baseline match

---

## Parameters (Orchestrator-Provided)

| Parameter | Description | Required | Example |
|-----------|-------------|----------|---------|
| `{{SESSION_ID}}` | Session identifier for file path scoping | Yes | `auto-orc-20260303-docker-v` |
| `{{TASK_ID}}` | Current task identifier | Yes | `5` |
| `{{DATE}}` | Current date (YYYY-MM-DD) | Yes | `2026-03-03` |
| `{{SLUG}}` | URL-safe topic name | Yes | `docker-validation` |
| `{{COMPOSE_PATH}}` | Path to `docker-compose.yml` file | Yes | `./docker-compose.yml` |
| `{{BASE_URL}}` | Base URL for HTTP endpoint testing | Yes | `http://localhost:8080` |
| `{{HEALTHCHECK_ENDPOINT}}` | Primary healthcheck URL path | No | `/health` |
| `{{AUTH_ENDPOINT}}` | Authentication endpoint for obtaining tokens | No | `http://localhost:8080/api/auth/login` |
| `{{AUTH_CREDENTIALS}}` | Credentials for authenticated testing (JSON object) | No | `{"username":"test","password":"test"}` |
| `{{EPIC_ID}}` | Parent epic identifier | No | `auto-orc-20260303-docker-v` |

---

## Task System Integration

@_shared/templates/skill-boilerplate.md#task-integration

### Execution Sequence

1. Get task via `TaskGet`
2. Set focus via `TaskUpdate` (status: in_progress)
3. Execute Docker validation (Phases 1-8)
4. Write output to `{{OUTPUT_DIR}}/{{DATE}}_{{SLUG}}.md`
5. Append manifest entry to `{{MANIFEST_PATH}}`
6. Complete task via `TaskUpdate` (status: completed)
7. Return summary message: "Docker validation complete. See MANIFEST.jsonl for summary."

---

## Execution Sequence (Phases 1-8)

If any phase fails, the skill MUST halt, record the failure in the validation report, and proceed to Phase 8 (State Restoration) before returning.

### Phase 1: Environment Check

**Purpose**: Verify Docker Engine, Docker Compose, and the Docker daemon are installed and operational.

**Commands**:

```bash
# Check Docker client+daemon communication
DOCKER_VERSION=$(docker version --format '{{.Server.Version}}' 2>/dev/null) || {
  echo "FAIL: Docker daemon is not running or not installed."
  exit 1
}

# Check daemon state and resource availability
docker info --format '{{.ServerVersion}}' 2>/dev/null || {
  echo "FAIL: Docker daemon info unavailable."
  exit 1
}

# Check Docker Compose plugin is installed
docker compose version 2>/dev/null || {
  echo "FAIL: Docker Compose plugin is not installed."
  exit 1
}
```

**Version Enforcement**:

```bash
MINIMUM_VERSION="27.1.1"
RECOMMENDED_VERSION="28.5.2"

if [[ "$(printf '%s\n' "$MINIMUM_VERSION" "$DOCKER_VERSION" | sort -V | head -n1)" != "$MINIMUM_VERSION" ]]; then
  echo "FAIL: Docker Engine $DOCKER_VERSION is below minimum $MINIMUM_VERSION (CVE-2024-41110)"
  exit 1
fi

if [[ "$(printf '%s\n' "$RECOMMENDED_VERSION" "$DOCKER_VERSION" | sort -V | head -n1)" != "$RECOMMENDED_VERSION" ]]; then
  echo "WARN: Docker Engine $DOCKER_VERSION is below recommended $RECOMMENDED_VERSION (runc CVE patches)"
fi
```

**Validation Rules**:
- All three commands MUST exit with code 0.
- Docker Engine version MUST be >= 27.1.1 (CVE-2024-41110 AuthZ bypass fix). RECOMMENDED: >= 28.5.2 (runc container-escape CVE patches).
- If any check fails, record the failure reason and skip to Phase 8 (no-op if no state was captured).

### Phase 2: State Audit

**Purpose**: Capture the pre-test state of Docker resources as structured JSON snapshots.

**Commands**:

```bash
PRE_CONTAINERS=$(docker ps -a --format '{{json .}}' | jq -s '.')
PRE_IMAGES=$(docker images --format '{{json .}}' | jq -s '.')
PRE_VOLUMES=$(docker volume ls --format '{{json .}}' | jq -s '.')
PRE_NETWORKS=$(docker network ls --format '{{json .}}' | jq -s '.')
```

**Output Structure** (JSON):

```json
{
  "captured_at": "<ISO-8601>",
  "session_id": "{{SESSION_ID}}",
  "docker_version": "<version>",
  "containers": [],
  "images": [],
  "volumes": [],
  "networks": []
}
```

### Phase 3: Checkpoint Creation

**Purpose**: Persist the pre-test state snapshot to disk for delta comparison during state restoration.

**File Path**: `.orchestrate/{{SESSION_ID}}/logs/docker-checkpoint.json`

```bash
mkdir -p .orchestrate/{{SESSION_ID}}/logs
echo "$SNAPSHOT_JSON" > .orchestrate/{{SESSION_ID}}/logs/docker-checkpoint.json
```

**Validation**: The file MUST be valid JSON and MUST be readable. If the write fails, abort with a BLOCKED status.

### Phase 4: Build & Deploy

**Purpose**: Build Docker images and start services using Docker Compose with healthcheck gating.

**Commands**:

```bash
# Build images
docker compose -f {{COMPOSE_PATH}} build

# Start services and wait for healthchecks to pass
docker compose -f {{COMPOSE_PATH}} up -d --wait
```

**Requirements**:
- The `docker-compose.yml` file at `{{COMPOSE_PATH}}` MUST exist and be valid.
- All services SHOULD define a `healthcheck:` block. If `--wait` times out, this phase fails.
- `depends_on: condition: service_healthy` SHOULD be used for services with upstream dependencies.

**On Failure**: Record the error output. Proceed to Phase 8 for teardown.

### Phase 5: UX Testing (Unauthenticated)

**Purpose**: Test publicly accessible endpoints without authentication credentials.

**Test Pattern**:

```bash
ERRORS=0
ENDPOINTS=(
  "/"
  "{{HEALTHCHECK_ENDPOINT}}"
  "/api/status"
)

for ENDPOINT in "${ENDPOINTS[@]}"; do
  HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}" "{{BASE_URL}}${ENDPOINT}")
  if [[ "$HTTP_CODE" != "200" && "$HTTP_CODE" != "302" ]]; then
    echo "FAIL: Unauthenticated ${ENDPOINT} returned ${HTTP_CODE} (expected 200 or 302)"
    ERRORS=$((ERRORS + 1))
  else
    echo "PASS: Unauthenticated ${ENDPOINT} returned ${HTTP_CODE}"
  fi
done
```

**Expected Status Codes**:

| Method | Expected | Interpretation |
|--------|----------|----------------|
| GET (public) | 200 | Resource served successfully |
| GET (public, redirect) | 302 | Redirect to login or canonical URL |
| Any | 4xx | Client error -- FAIL |
| Any | 5xx | Server error -- FAIL |

### Phase 6: UX Testing (Authenticated)

**Purpose**: Test protected endpoints using authentication tokens.

**Conditional Execution**: If `{{AUTH_ENDPOINT}}` or `{{AUTH_CREDENTIALS}}` are not provided, this phase MUST be skipped with a note: "Authenticated testing skipped -- no AUTH_ENDPOINT or AUTH_CREDENTIALS provided."

**Test Pattern**:

```bash
# Obtain auth token
TOKEN=$(curl -s -X POST "{{AUTH_ENDPOINT}}" \
  -H "Content-Type: application/json" \
  -d '{{AUTH_CREDENTIALS}}' | jq -r '.token // .access_token // .jwt')
[[ -n "$TOKEN" && "$TOKEN" != "null" ]] || {
  echo "FAIL: Could not obtain authentication token"; ERRORS=$((ERRORS + 1))
}

# Authenticated GET (expect 200)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $TOKEN" "{{BASE_URL}}/api/profile")
[[ "$HTTP_CODE" == "200" ]] || {
  echo "FAIL: GET /api/profile returned $HTTP_CODE (expected 200)"; ERRORS=$((ERRORS + 1))
}

# Authenticated POST (expect 201)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"docker-validator-test"}' "{{BASE_URL}}/api/items")
[[ "$HTTP_CODE" == "201" ]] || {
  echo "FAIL: POST /api/items returned $HTTP_CODE (expected 201)"; ERRORS=$((ERRORS + 1))
}
```

**Expected Status Codes**:

| Method | Expected | Interpretation |
|--------|----------|----------------|
| GET (authenticated) | 200 | Resource served successfully |
| POST (authenticated) | 201 | Resource created successfully |
| PUT (authenticated) | 201 | Resource updated/created successfully |
| Any | 4xx | Client error -- FAIL |
| Any | 5xx | Server error -- FAIL |

### Phase 7: HTTP Validation Summary

**Purpose**: Aggregate all HTTP test results from Phases 5 and 6.

**Output Table Format**:

```markdown
## HTTP Validation Summary

| # | Endpoint | Method | Auth | Status Code | Expected | Result |
|---|----------|--------|------|-------------|----------|--------|
| 1 | /        | GET    | No   | 200         | 200/302  | PASS   |
| 2 | /health  | GET    | No   | 200         | 200      | PASS   |
| 3 | /api/profile | GET | Yes  | 200         | 200      | PASS   |
| 4 | /api/items   | POST | Yes  | 201         | 201      | PASS   |

**Totals**: 4 tested, 4 passed, 0 failed
**4xx errors**: 0
**5xx errors**: 0
```

**Zero-Error Gate Integration**: If ANY endpoint returns a 4xx or 5xx status code, the overall validation result is FAIL. This integrates with the validator's zero-error gate (MAIN-006).

### Phase 8: State Restoration

**Purpose**: Tear down all test containers, volumes, and networks, then verify Docker state matches the pre-test checkpoint.

**Teardown Command** (NON-NEGOTIABLE):

```bash
docker compose -f {{COMPOSE_PATH}} down --volumes --remove-orphans
```

**CRITICAL**: The `--volumes` flag is NON-OPTIONAL. Omitting `--volumes` causes named volumes to persist, leading to state bleed between test runs. The `--remove-orphans` flag removes containers for services not defined in the current compose file.

**Delta Verification**: Re-capture state using the same commands from Phase 2 (`docker ps -a`, `docker images`, `docker volume ls`, `docker network ls` with `--format '{{json .}}'` piped through `jq -s '.'`). Compare counts against the checkpoint from Phase 3.

**Delta Rules**:
- Images may legitimately increase (build cache). This is a WARNING, not a FAIL.
- Containers, volumes, and networks MUST return to pre-test counts or the restoration fails.
- Report a table with Resource, Pre-Test Count, Post-Teardown Count, Delta, and Status (CLEAN/WARN/FAIL) per resource type.

---

## Security Considerations

| Concern | Requirement | Reference |
|---------|-------------|-----------|
| Docker Engine minimum version | >= 27.1.1 (CVE-2024-41110 AuthZ plugin bypass -- CRITICAL) | NVD |
| Docker Engine recommended version | >= 28.5.2 (CVE-2025-31133, CVE-2025-52565, CVE-2025-52881 runc container-escape -- HIGH) | Docker Engine v28 release notes |
| Docker Desktop (if applicable) | >= 4.44.3 (CVE-2025-9074 API access via subnet -- HIGH) | Docker Security Announcements |
| docker Python SDK (if used) | docker >= 7.1.0 (no known CVEs as of 2026-03) | Snyk, PyPI |
| Docker Compose | No standalone CVEs found; inherits from Engine | N/A |
| Credential handling | `{{AUTH_CREDENTIALS}}` MUST NOT be logged to output files. Mask in validation report | Best practice |
| Socket mounting | `docker.sock` MUST NOT be mounted in test containers | docker-workflow security checklist |
| Non-root containers | All test containers SHOULD run as non-root user | CIS Docker Benchmark |

---

## Subagent Protocol

@_shared/templates/skill-boilerplate.md#subagent-protocol

**MAIN-014**: Do NOT run `git commit`, `git push`, or any git write operation.

**Summary message:** "Docker validation complete. See MANIFEST.jsonl for summary."

---

## Output Format

Write to `{{OUTPUT_DIR}}/{{DATE}}_{{SLUG}}.md` with these sections:

1. **Summary** - Status (PASS/PARTIAL/FAIL), Docker Engine version, Compose version, compose file path, total endpoints tested, error count, warning count
2. **Phase Results** - Table with all 8 phases, each showing phase number, name, status (PASS/FAIL/WARN/SKIPPED), and detail string
3. **HTTP Validation Summary** - Table from Phase 7 with per-endpoint results
4. **State Restoration** - Table from Phase 8 with per-resource delta counts
5. **Security Notes** - Docker Engine version vs minimum (27.1.1) and recommended (28.5.2), CVE status determination
6. **Linked Tasks** - Epic ID, Task ID, Session ID

---

## Manifest Entry

@_shared/templates/skill-boilerplate.md#manifest-entry

**Docker-validator-specific fields:**

```json
{"id":"{{SLUG}}-{{DATE}}","file":"{{DATE}}_{{SLUG}}.md","title":"Docker Validation: {{SLUG}}","date":"{{DATE}}","status":"complete","topics":["docker","validation","containers","endpoint-testing","stage-5"],"key_findings":["Docker Engine <version> validated (minimum 27.1.1)","<N> endpoints tested: <passed> passed, <failed> failed","State restoration: <CLEAN|WARN|FAIL>","Security: <CVE status summary>"],"actionable":true,"needs_followup":["{{REMEDIATION_TASK_IDS}}"],"linked_tasks":["{{EPIC_ID}}","{{TASK_ID}}"]}
```

---

## Skill Chaining

@_shared/protocols/skill-chain-contracts.md

### Produces

| Output | Format | Description |
|--------|--------|-------------|
| `docker-validation-report` | Markdown | Full Docker validation report with phase results |
| `docker-checkpoint` | JSON | Pre-test Docker state snapshot |

### Consumes

| Input | From Skill | Description |
|-------|------------|-------------|
| `compose-config` | `docker-workflow` | Docker Compose file path and configuration |
| `deliverables` | `task-executor` | Implementation artifacts with Docker setup |

### Chain Relationships

| Direction | Skills | Pattern |
|-----------|--------|---------|
| Chains from | `docker-workflow`, `task-executor`, `implementer` | quality-gate |
| Chains to | `validator` | sub-component |

The docker-validator is a **quality gate sub-component** -- it is invoked by the `validator` skill as a mandatory sub-step when Docker is available. Its output feeds into the validator's overall compliance determination.

## Completion Checklist

@_shared/templates/skill-boilerplate.md#completion-checklist

### Skill-Specific Items

- [ ] Docker environment verified (Phase 1 passed)
- [ ] Pre-test state captured and checkpointed (Phases 2-3)
- [ ] Docker Compose build and deploy succeeded (Phase 4)
- [ ] Unauthenticated endpoint tests executed (Phase 5)
- [ ] Authenticated endpoint tests executed or skipped with reason (Phase 6)
- [ ] HTTP validation summary generated with 0 errors (Phase 7)
- [ ] State restored to pre-test baseline (Phase 8)
- [ ] Security version check completed
- [ ] Validation report written to output directory
- [ ] Manifest entry appended

---

## Context Variables

All parameters from the Parameters table above, plus these orchestrator-injected tokens:

| Token | Description | Example |
|-------|-------------|---------|
| `{{OUTPUT_DIR}}` | Output directory path | `.orchestrate/<SESSION_ID>/logs/` |
| `{{MANIFEST_PATH}}` | Path to MANIFEST.jsonl | `.orchestrate/<SESSION_ID>/MANIFEST.jsonl` |

---

## Error Handling

@_shared/templates/skill-boilerplate.md#error-handling

**Skill-specific messages:**
- Partial: "Docker validation partial. See MANIFEST.jsonl for details."
- Blocked: "Docker validation blocked. See MANIFEST.jsonl for blocker details."

**Phase failure behavior**: If any phase (1-7) fails, the skill MUST skip remaining phases and proceed directly to Phase 8 (State Restoration) to ensure teardown occurs. The failure is recorded in the Phase Results table with the specific error details.

---

## Anti-Patterns

| Pattern | Issue | Fix |
|---------|-------|-----|
| Running tests without state checkpoint | No baseline for delta comparison | Always execute Phases 2-3 before Phase 4 |
| Skipping teardown/restoration | State bleed between test runs | Always execute Phase 8 even on failure |
| Ignoring 4xx/5xx errors | Silent failures in endpoint testing | Fail validation on any 4xx/5xx response |
| `docker compose down` without `--volumes --remove-orphans` | Named volumes persist, orphan containers remain | Always use full teardown command |
| Testing against production endpoints | Risk of data corruption or service disruption | Use only local/staging BASE_URL |
| Logging `{{AUTH_CREDENTIALS}}` to output files | Credential exposure in reports | Mask credentials in all output |
| Skipping Phase 8 after Phase 4 failure | Containers and networks left running | Phase 8 is always mandatory after Phase 4 |
| Using `docker stop` instead of `docker compose down` | Incomplete cleanup, network/volume leaks | Use Compose-level teardown |

---

## File Structure

```
claude-code/
  skills/
    docker-validator/
      SKILL.md              # This file
```
