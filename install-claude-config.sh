#!/usr/bin/env bash
# =============================================================================
# Claude Code Configuration Installer
# Installs: skills, agents, commands, _shared, manifest.json, settings.json
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✔]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✘]${NC} $*"; exit 1; }

# --- Configuration ------------------------------------------------------------
SOURCE_DIR="${1:-claude-code}"
CLAUDE_DIR="$HOME/.claude"
BACKUP_DIR="$CLAUDE_DIR/backup-$(date +%Y%m%d-%H%M%S)"

# --- Pre-flight checks --------------------------------------------------------
if [[ ! -d "$SOURCE_DIR" ]]; then
  err "Source directory '$SOURCE_DIR' not found. Usage: $0 [source-dir]"
fi

echo ""
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║       Claude Code Configuration Installer           ║"
echo "  ╚══════════════════════════════════════════════════════╝"
echo ""
echo "  Source:      $SOURCE_DIR"
echo "  Destination: $CLAUDE_DIR"
echo ""

# --- Create directories if needed ---------------------------------------------
mkdir -p "$CLAUDE_DIR"/{skills,agents,commands}

# --- Backup existing config if present ----------------------------------------
backup_if_exists() {
  local target="$1"
  if [[ -e "$target" ]]; then
    mkdir -p "$BACKUP_DIR"
    cp -r "$target" "$BACKUP_DIR/"
    warn "Backed up existing $(basename "$target") → $BACKUP_DIR/"
  fi
}

# --- Install components -------------------------------------------------------

# Skills (auto-discovered by Claude Code)
if [[ -d "$SOURCE_DIR/skills" ]]; then
  backup_if_exists "$CLAUDE_DIR/skills"
  cp -r "$SOURCE_DIR/skills/"* "$CLAUDE_DIR/skills/" 2>/dev/null || true
  log "Skills installed"
else
  warn "No skills directory found in $SOURCE_DIR — skipping"
fi

# Agents (flat .md files)
if [[ -d "$SOURCE_DIR/agents" ]]; then
  backup_if_exists "$CLAUDE_DIR/agents"
  cp -r "$SOURCE_DIR/agents/"* "$CLAUDE_DIR/agents/" 2>/dev/null || true
  log "Agents installed"
else
  warn "No agents directory found in $SOURCE_DIR — skipping"
fi

# Commands
if [[ -d "$SOURCE_DIR/commands" ]]; then
  backup_if_exists "$CLAUDE_DIR/commands"
  cp -r "$SOURCE_DIR/commands/"* "$CLAUDE_DIR/commands/" 2>/dev/null || true
  log "Commands installed"
else
  warn "No commands directory found in $SOURCE_DIR — skipping"
fi

# Shared resources (protocols, templates, references, style-guides, schemas, tokens)
if [[ -d "$SOURCE_DIR/_shared" ]]; then
  backup_if_exists "$CLAUDE_DIR/_shared"
  mkdir -p "$CLAUDE_DIR/_shared"
  cp -r "$SOURCE_DIR/_shared/"* "$CLAUDE_DIR/_shared/" 2>/dev/null || true
  log "Shared resources installed"
else
  warn "No _shared directory found in $SOURCE_DIR — skipping"
fi

# Manifest (required for orchestrator routing)
if [[ -f "$SOURCE_DIR/manifest.json" ]]; then
  backup_if_exists "$CLAUDE_DIR/manifest.json"
  cp "$SOURCE_DIR/manifest.json" "$CLAUDE_DIR/manifest.json"
  log "Manifest installed"
else
  warn "No manifest.json found in $SOURCE_DIR — skipping"
fi

# Settings
if [[ -f "$SOURCE_DIR/settings.json" ]]; then
  backup_if_exists "$CLAUDE_DIR/settings.json"
  cp "$SOURCE_DIR/settings.json" "$CLAUDE_DIR/settings.json"
  log "Settings installed"
else
  warn "No settings.json found in $SOURCE_DIR — skipping"
fi

# Documentation files (optional — copied if present)
for doc_file in ARCHITECTURE.md INTEGRATION.md PERMISSION-MODES.md; do
  if [[ -f "$SOURCE_DIR/$doc_file" ]]; then
    backup_if_exists "$CLAUDE_DIR/$doc_file"
    cp "$SOURCE_DIR/$doc_file" "$CLAUDE_DIR/$doc_file"
    log "$doc_file installed"
  else
    warn "No $doc_file found in $SOURCE_DIR — skipping"
  fi
done

# --- Summary ------------------------------------------------------------------
echo ""
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║            Installation Complete!                    ║"
echo "  ╚══════════════════════════════════════════════════════╝"
echo ""
echo "  Installed to: $CLAUDE_DIR"
echo ""

if [[ -d "$BACKUP_DIR" ]]; then
  warn "Previous config backed up to: $BACKUP_DIR"
  echo ""
fi
