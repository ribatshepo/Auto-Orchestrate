---
name: docker-workflow
description: |
  Docker image building, container execution, and debugging patterns with security checklists.
  Use when user says "Docker", "Dockerfile", "container", "containerize", "docker-compose",
  "docker compose", "image build", "multi-stage build", "container debug", "container crash",
  "docker run", "docker build".
triggers:
  - Docker
  - Dockerfile
  - container
  - containerize
  - docker-compose
  - docker compose
  - image build
  - multi-stage build
  - container debug
  - container crash
  - docker run
  - docker build
---

# Docker Workflow Skill

Patterns, templates, and references for building, running, and debugging Docker containers.

## Overview

This skill provides:
- **Dockerfile Patterns** - Best practices by language/framework
- **Compose Templates** - Production-ready docker-compose configurations
- **Security Checklist** - Container security requirements
- **Troubleshooting Guide** - Common issues and solutions

## Used By

This skill is referenced by:
- Orchestrator agents - Via Task tool delegation
- Implementation workflows requiring containerization

## Core Principles

> **ALL containers MUST be production-ready: secure, resource-limited, and properly configured.**

---

## Parameters (Orchestrator-Provided)

| Parameter | Description | Required |
|-----------|-------------|----------|
| `{{TASK_ID}}` | Current task identifier | Yes |
| `{{DATE}}` | Current date (YYYY-MM-DD) | Yes |
| `{{SLUG}}` | URL-safe topic name | Yes |
| `{{DOCKERFILE_PATH}}` | Path to Dockerfile | No |
| `{{COMPOSE_PATH}}` | Path to compose file | No |
| `{{EPIC_ID}}` | Parent epic identifier | No |
| `{{SESSION_ID}}` | Session identifier | No |

---

## Task System Integration

@_shared/templates/skill-boilerplate.md#task-integration

### Execution Sequence

1. Get task via `TaskGet`
2. Set focus via `TaskUpdate` (status: in_progress)
3. Execute Docker workflow (build, run, or debug)
4. Write output to `{{OUTPUT_DIR}}/{{DATE}}_{{SLUG}}.md`
5. Append manifest entry to `{{MANIFEST_PATH}}`
6. Complete task via `TaskUpdate` (status: completed)
7. Return summary message only

---

## Quick Reference

### Build Commands

```bash
# Standard build
docker build -t app:1.0.0 .

# With BuildKit (faster, better caching)
DOCKER_BUILDKIT=1 docker build -t app:1.0.0 .

# Multi-platform
docker buildx build --platform linux/amd64,linux/arm64 -t app:1.0.0 --push .

# No cache (clean build)
docker build --no-cache -t app:1.0.0 .
```

### Run Commands

```bash
# Development
docker run -d -p 8080:8080 --name app-dev app:dev

# Production (with all security options)
docker run -d \
  --name app \
  --restart unless-stopped \
  --security-opt no-new-privileges:true \
  --cap-drop ALL \
  --read-only \
  --cpus 2 --memory 2g \
  -p 8080:8080 \
  app:1.0.0
```

### Debug Commands

```bash
# Logs
docker logs -f [container]

# Shell access
docker exec -it [container] /bin/sh

# Inspect
docker inspect [container]

# Resource usage
docker stats [container]
```

## Dockerfile Best Practices

### Multi-Stage Build Template

```dockerfile
# ============================================
# Build Stage
# ============================================
FROM [build-image] AS builder
WORKDIR /app

# Dependencies first (layer caching)
COPY package*.json ./
RUN npm ci --only=production

# Source code
COPY . .
RUN npm run build

# ============================================
# Runtime Stage
# ============================================
FROM [runtime-image] AS runtime

# Non-root user
RUN addgroup -g 1001 app && adduser -u 1001 -G app -D app
USER app

WORKDIR /app

# Copy artifacts only
COPY --from=builder --chown=app:app /app/dist ./dist
COPY --from=builder --chown=app:app /app/node_modules ./node_modules

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

EXPOSE 8080

ENTRYPOINT ["node"]
CMD ["dist/main.js"]
```

### Base Images by Language

| Language | Build Stage | Runtime Stage |
|----------|-------------|---------------|
| **Java** | `eclipse-temurin:21-jdk` | `eclipse-temurin:21-jre-alpine` |
| **Scala** | `sbtscala/scala-sbt` | `eclipse-temurin:21-jre-alpine` |
| **Node.js** | `node:20-alpine` | `node:20-alpine` |
| **Python** | `python:3.12-slim` | `python:3.12-slim` |
| **Go** | `golang:1.22-alpine` | `scratch` or `gcr.io/distroless/static` |
| **Rust** | `rust:1.75-alpine` | `scratch` or `gcr.io/distroless/cc` |
| **.NET** | `mcr.microsoft.com/dotnet/sdk:8.0` | `mcr.microsoft.com/dotnet/aspnet:8.0-alpine` |

## Prohibited Patterns

| Pattern | Issue | Fix |
|---------|-------|-----|
| `FROM image:latest` | Unpredictable builds | Pin version: `image:1.2.3` |
| `USER root` (runtime) | Security risk | Use non-root user |
| `ADD` for local files | Less explicit | Use `COPY` |
| Secrets in ENV/ARG | Exposed in layers | Use runtime secrets |
| No resource limits | Resource exhaustion | Set --cpus, --memory |
| No health check | No visibility | Add HEALTHCHECK |
| Default network | Less isolation | Use custom networks |

## Security Checklist

### Image Security

- [ ] Base image pinned to specific version
- [ ] Multi-stage build (no build tools in runtime)
- [ ] Non-root user
- [ ] No secrets in image layers
- [ ] Security scan passed (0 critical/high CVEs)
- [ ] .dockerignore excludes sensitive files

### Runtime Security

- [ ] `--security-opt=no-new-privileges:true`
- [ ] `--cap-drop=ALL` (add only what's needed)
- [ ] `--read-only` (where possible)
- [ ] Resource limits set (CPU, memory)
- [ ] No Docker socket mounted
- [ ] Internal network for backend services

---

## Subagent Protocol

@_shared/templates/skill-boilerplate.md#subagent-protocol

**Summary message:** "Docker workflow complete. See MANIFEST.jsonl for summary."

---

## Output File Format

Write to `{{OUTPUT_DIR}}/{{DATE}}_{{SLUG}}.md`:

```markdown
# Docker Workflow Report: {{SLUG}}

## Summary

- **Task Type:** {{BUILD|RUN|DEBUG}}
- **Image:** {{IMAGE_NAME}}:{{TAG}}
- **Status:** {{SUCCESS|PARTIAL|BLOCKED}}

## Configuration

### Dockerfile

{{Dockerfile content or path}}

### Compose Configuration

{{docker-compose.yml content or path}}

## Security Checklist Results

| Check | Status | Notes |
|-------|--------|-------|
| {{Check}} | {{PASS|FAIL}} | {{Notes}} |

## Recommendations

1. {{Recommendation 1}}
2. {{Recommendation 2}}

## Linked Tasks

- Epic: {{EPIC_ID}}
- Task: {{TASK_ID}}
```

---

## Manifest Entry

@_shared/templates/skill-boilerplate.md#manifest-entry

**Docker-specific fields:**
- `key_findings`: Security checklist results and issues
- `actionable`: `true` if security issues found

---

## Completion Checklist

@_shared/templates/skill-boilerplate.md#completion-checklist

### Skill-Specific Items

- [ ] Dockerfile follows multi-stage pattern
- [ ] Security checklist completed
- [ ] Base images pinned to specific versions
- [ ] Non-root user configured

---

## Error Handling

@_shared/templates/skill-boilerplate.md#error-handling

**Skill-specific messages:**
- Partial: "Docker workflow partial. See MANIFEST.jsonl for details."
- Blocked: "Docker workflow blocked. See MANIFEST.jsonl for blocker details."

---

## File Structure

```
claude-code/
└── skills/
    └── docker-workflow/
        ├── SKILL.md              # This file
        └── references/
            ├── dockerfile-patterns.md
            ├── compose-patterns.md
            ├── security-checklist.md
            └── troubleshooting.md
```

## Common Workflows

### New Application Containerization

1. Analyze app -> Create Dockerfile -> Optimize -> Build
2. Configure compose -> Set resources -> Run
3. (if issues) Diagnose -> Fix -> Verify

### Debug Failing Container

1. Classify problem -> Gather logs -> Identify root cause -> Fix

### Production Deployment

1. Multi-stage build -> Security scan -> Tag
2. Production compose -> Secrets -> Resources -> Health checks

## References

- `references/dockerfile-patterns.md` - Dockerfile patterns by language
- `references/compose-patterns.md` - Docker Compose configurations
- `references/security-checklist.md` - Container security requirements
- `references/troubleshooting.md` - Common issues and solutions
