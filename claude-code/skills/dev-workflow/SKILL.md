---
name: dev-workflow
description: |
  Development workflow skill for atomic commits, conventional commits, and release management.
  Use when user says "commit", "release", "run the workflow", "prepare release",
  "atomic commit", "conventional commit", "version bump", "create release",
  "commit and push", "finalize changes", "ship it", "cut a release".
triggers:
  - commit
  - release
  - run the workflow
  - prepare release
  - atomic commit
  - version bump
---

# Development Workflow Skill

You are a development workflow executor. Your role is to ensure proper atomic commits with task traceability, conventional commit messages, and systematic release processes.

## Core Principle: Task-Driven Development

> **CRITICAL**: NO code changes or commits without a tracked task.

Every commit MUST be traceable to a task. This ensures:
- Work is planned and tracked
- Changes are reviewable and reversible
- Progress is measurable
- Context is preserved for future agents

---

## Immutable Constraints (WORKFLOW)

| ID | Rule | Enforcement |
|----|------|-------------|
| WF-001 | Task required | NO commits without task reference |
| WF-002 | Branch discipline | NO commits to main/master |
| WF-003 | Atomic commits | ONE logical change per commit |
| WF-004 | Conventional format | `<type>(<scope>): <description>` |
| WF-005 | Tests before push | Relevant tests MUST pass |

---

## Task Tracking Integration

### Before Any Work

Use Claude Code's native task tools:

1. **Verify you have a task**: Use `TaskList` to see current tasks
2. **If no task, create one**: Use `TaskCreate` with subject, description, and activeForm
3. **Set focus**: Use `TaskUpdate` to set status to `in_progress`

### Commit Message Format

**MUST** include task reference:

```
<type>(<scope>): <description>

<body explaining why>

Task: T123
Co-Authored-By: Claude <noreply@anthropic.com>
```

**Example:**
```
fix(auth): prevent token expiry race condition

The refresh token was being invalidated before the new access
token was validated, causing intermittent auth failures.

Task: T1456
Co-Authored-By: Claude <noreply@anthropic.com>
```

---

## Branch & Subagent Awareness

### Single Branch Reality

Subagents share the parent session's branch. This means:

- All work happens on the same branch
- No parallel feature branches from subagents
- Commits are sequential, not parallel
- Commits and pushes are manual — the workflow generates commands for the user

### Branch Strategy

```bash
# Check current branch
git branch --show-current

# Feature work (typical pattern)
main -> feature/T123-description -> PR -> main

# Branch naming
feature/T123-auth-improvements     # Task-prefixed
fix/T456-token-validation          # Bug fix
```

---

## Gate System (Simplified)

Not all gates apply to all changes. Follow the decision matrix.

### G0: Pre-Flight Check

**Always required.**

1. **Verify task context**: Use `TaskList` to find task with `status: in_progress`
   - MUST have a focused task
2. **Check branch**: `git branch --show-current`
   - MUST NOT be main/master
3. **Check for uncommitted work**: `git status --porcelain`
   - Review staged/unstaged changes

### G1: Classify Change

| Type | Description | Tests Needed | Version Bump |
|------|-------------|--------------|--------------|
| `feat` | New feature | Related tests | MINOR |
| `fix` | Bug fix | Regression test | PATCH |
| `docs` | Documentation | None | None |
| `refactor` | Code restructure | Affected tests | PATCH |
| `test` | Test additions | The new tests | None |
| `chore` | Maintenance | None | None |
| `perf` | Performance | Perf tests | PATCH |
| `security` | Security fix | Security tests | PATCH |

### G2: Testing (Smart Scope)

**NOT always full test suite.** CI runs full tests on push.

| Change Type | Test Scope | Command |
|-------------|------------|---------|
| `feat` | Related module tests | `bats tests/unit/feature.bats` |
| `fix` | Regression + affected | `bats tests/unit/affected.bats` |
| `docs` | None (CI validates) | Skip |
| `refactor` | Affected modules | `bats tests/unit/module*.bats` |
| `test` | The new tests only | `bats tests/unit/new.bats` |
| `chore` | Syntax check only | `bash -n scripts/*.sh` |

**When to run full suite locally:**
- Before release (version bump)
- Major refactoring
- Cross-cutting changes
- User explicitly requests

```bash
# Full suite (when needed)
./tests/run-all-tests.sh

# Targeted tests (typical)
bats tests/unit/specific-feature.bats
bats tests/integration/workflow.bats

# Quick syntax check
bash -n scripts/*.sh lib/*.sh
```

### G3: Generate Commit Message (No Auto-Commit)

1. **Get task info**: Use `TaskList` to find your in-progress task ID
2. **Stage changes** (be specific for atomic commits):
   ```bash
   git add scripts/specific-file.sh lib/related.sh
   ```
3. **Generate commit message and display with copy-pasteable commands**:

```
### Generated Commit

**Commit message:**
type(scope): description

body

Task: #ID
Co-Authored-By: Claude <noreply@anthropic.com>

**To commit your changes, run:**
git add file1 file2
git commit -m "$(cat <<'EOF'
type(scope): description

body

Task: #ID
Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

DO NOT execute `git commit`. The user will run it manually.

### G4: Push Instructions (No Auto-Push)

Display the push command for the user to run manually:

```
**To push your changes:**
git push origin HEAD
```

DO NOT execute `git push`. The user will run it manually.

### G5: Version Bump (Release Only)

**Only for releases**, not every commit.

```bash
# 1. Preview
./dev/bump-version.sh --dry-run patch

# 2. Execute
./dev/bump-version.sh patch

# 3. Validate
./dev/validate-version.sh
```

### G6: Tag & Release

**GitHub Actions handles release creation.**

```bash
# 1. Create annotated tag
git tag -a v${VERSION} -m "${TYPE}: ${SUMMARY}"

# 2. Push tag (triggers release workflow)
git push origin v${VERSION}

# 3. Push branch
git push origin HEAD

# GitHub Actions automatically:
# - Builds release tarball
# - Creates GitHub Release
# - Generates release notes
# - Uploads artifacts
```

---

## Quick Decision Matrix

### What Tests to Run?

| Change | Local Tests | Rely on CI |
|--------|-------------|------------|
| Single file fix | Related unit test | [x] |
| New feature | Feature tests | [x] |
| Docs only | None | [x] |
| Schema change | Schema tests | [x] |
| Cross-cutting refactor | Full suite | [x] |
| Release prep | Full suite | [x] |

### Do I Need a Version Bump?

| Change | Bump | Tag |
|--------|------|-----|
| `feat` | minor | Yes |
| `fix` | patch | Yes |
| `docs` | No | No |
| `refactor` | patch | Yes |
| `test` | No | No |
| `chore` | No | No |
| `perf` | patch | Yes |
| `security` | patch | Yes |

### Push Flow

```
Local commit -> Push -> CI tests -> PR -> Review -> Merge to main
                                                    v
                                        CHANGELOG.md updated
                                                    v
                                    (Auto-PR for Mintlify docs)
                                                    v
                                        Version bump commit
                                                    v
                                        Tag push (v*.*.*)
                                                    v
                                    GitHub Release (automated)
```

---

## Automated CI/CD Pipelines

### What GitHub Actions Handles

| Trigger | Workflow | Actions |
|---------|----------|---------|
| Push/PR to main | `ci.yml` | Tests, lint, JSON validation, docs drift, install test |
| Push to main (CHANGELOG.md) | `docs-update.yml` | Auto-PR for Mintlify changelog regeneration |
| Tag push (v*.*.*) | `release.yml` | Build tarball, create GitHub Release, upload artifacts |
| Push to docs/ | `mintlify-deploy.yml` | Validate MDX, check required files |

### What YOU Handle

| Action | When | How |
|--------|------|-----|
| Update CHANGELOG.md | Before release | Manual edit with release notes |
| Version bump | When releasing | `./dev/bump-version.sh patch\|minor\|major` |
| Create tag | After version bump | `git tag -a v0.X.Y -m "..."` |
| Push tag | After tagging | `git push origin v0.X.Y` |
| Merge auto-PRs | When changelog PR created | Review and merge the auto-generated PR |

### Release Sequence

```bash
# 1. Ensure all changes are merged to main

# 2. Update CHANGELOG.md with release notes
# (edit CHANGELOG.md manually)

# 3. Commit changelog
git add CHANGELOG.md
git commit -m "docs(changelog): Add v0.X.Y release notes"
git push origin main

# 4. (Auto) docs-update.yml creates PR for Mintlify
# -> Review and merge the auto-PR

# 5. Version bump
./dev/bump-version.sh minor  # or patch/major
./dev/validate-version.sh

# 6. Commit version bump
git add -A
git commit -m "chore: bump version to v0.X.Y"
git push origin main

# 7. Tag and push (triggers release.yml)
git tag -a v0.X.Y -m "feat: Description of release"
git push origin v0.X.Y

# 8. (Auto) release.yml creates GitHub Release
```

---

## Complete Workflow Examples

### Example 1: Bug Fix (Typical)

1. **Verify task**: Use `TaskList` to confirm in-progress task (e.g., #1456 - Fix token validation)
2. **Make changes**: Edit files as needed
3. **Run relevant test**: `bats tests/unit/auth.bats`
4. **Stage specific files**: `git add lib/auth.sh scripts/login.sh`
5. **Generate commit message** (G3): Display the commit message and copy-pasteable `git commit` command for user to run manually
6. **Push instructions** (G4): Display the `git push origin HEAD` command for user to run manually
7. **Mark task complete**: Use `TaskUpdate` with `status: completed`

### Example 2: New Feature

1. **Verify task**: Use `TaskList` to confirm in-progress task (e.g., #1500 - Add export command)
2. **Make changes**: Implement feature
3. **Run feature tests**:
   ```bash
   bats tests/unit/export.bats
   bats tests/integration/export.bats
   ```
4. **Stage changes**: `git add scripts/export.sh lib/export-utils.sh tests/unit/export.bats`
5. **Generate commit message** (G3): Display the commit message and copy-pasteable `git commit` command for user to run manually
6. **Push instructions** (G4): Display the `git push origin HEAD` command for user to run manually
7. **Complete task**: Use `TaskUpdate` with `status: completed`

### Example 3: Release

1. **Verify all tasks complete**: Use `TaskList` to confirm no pending tasks
2. **Run full test suite**: `./tests/run-all-tests.sh`
3. **Update CHANGELOG**: Edit CHANGELOG.md
4. **Version bump**:
   ```bash
   ./dev/bump-version.sh minor
   ./dev/validate-version.sh
   ```
5. **Generate commit message** (G3): Display the version bump commit message and copy-pasteable `git commit` command for user to run manually
6. **Tag and push instructions** (G4): Display the following commands for the user to run manually:
   ```bash
   git tag -a v0.63.0 -m "feat: Add export command and improvements"
   git push origin v0.63.0
   git push origin HEAD
   ```

GitHub Actions creates the release automatically.

### Example 4: Documentation Only

1. **Verify task**: Use `TaskList` to confirm in-progress task (e.g., #1550 - Update README)
2. **Make doc changes**: Edit docs
3. **No tests needed** (CI validates)
4. **Generate commit message** (G3): Display the commit message and copy-pasteable `git commit` command for user to run manually
5. **Push instructions** (G4): Display the `git push origin HEAD` command for user to run manually
6. **Complete**: Use `TaskUpdate` with `status: completed`

---

## Anti-Patterns

| Pattern | Problem | Solution |
|---------|---------|----------|
| No task reference | Untracked work | Create/find task first |
| Committing to main | Bypass review | Use feature branches |
| Running full tests always | Slow iteration | Use smart test scope |
| Skipping CI | Missing validations | Always push, let CI run |
| Manual release creation | Inconsistent releases | Use tag -> GH Actions |
| Giant commits | Hard to review/revert | Atomic commits |
| Vague commit messages | Lost context | Conventional + task ref |
| Auto-committing/pushing | Bypasses user review | Generate commands, let user execute |

---

## Task Tool Integration

Use Claude Code's native task tools:

| Action | Tool | Usage |
|--------|------|-------|
| View all tasks | `TaskList` | Get overview of all tasks |
| Get task details | `TaskGet` | Retrieve specific task by ID |
| Create task | `TaskCreate` | New task with subject, description, activeForm |
| Set focus | `TaskUpdate` | Set `status: in_progress` |
| Mark done | `TaskUpdate` | Set `status: completed` |
| Add dependencies | `TaskUpdate` | Use `addBlockedBy` or `addBlocks` |

---

## Critical Rules Summary

1. **Always have a task** before making changes
2. **Always include task reference** in commit message
3. **Never commit to main/master** directly
4. **Run relevant tests** locally, not always full suite
5. **Let CI validate** with full test suite on push
6. **Use tags for releases** - GitHub Actions handles the rest
7. **One logical change** per commit (atomic)
8. **Conventional commit format** with task reference

---

## Trigger Phrases

This skill activates when user says:
- "commit", "commit changes"
- "release", "prepare release", "cut a release"
- "run the workflow"
- "atomic commit", "conventional commit"
- "version bump"
- "ship it", "finalize changes"
- "push changes"
