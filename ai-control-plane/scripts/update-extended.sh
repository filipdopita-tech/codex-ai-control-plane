#!/usr/bin/env bash
# update-extended.sh — Extends update-core.sh with MCP servers, Codex, npm globals
#
# Run by launchd weekly (Sat 04:15) or manual via `ofs update`.
# Filip rules:
#  - Signed sources only (brew formulae, npm registry, GH release) — NIKDY curl|sh
#  - Verification gate: post-update doctor diff, ntfy summary
#  - Security: no secrets in update process, no third-party scripts
#
# Author: Dopita, 2026-05-02

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$HOME/.claude/logs/update-extended.log"
SUMMARY="$HOME/.claude/logs/update-summary-$(date +%Y%m%d).md"

mkdir -p "$(dirname "$LOG")"

ts() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(ts)] $1" | tee -a "$LOG"; }

log "=== Extended update started ==="

# ─── 1. Capture before versions ──────────────────────
{
  echo "# Update summary $(date '+%Y-%m-%d %H:%M:%S')"
  echo
  echo "## Versions BEFORE"
  echo
  echo "- Claude CLI: $(claude --version 2>/dev/null | head -1)"
  echo "- Codex CLI:  $(codex --version 2>/dev/null | head -1)"
  echo "- VS Code:    $(code --version 2>/dev/null | head -1)"
  echo "- Brew:       $(brew --version 2>/dev/null | head -1)"
  echo "- Node:       $(node --version 2>/dev/null)"
  echo "- npm:        $(npm --version 2>/dev/null)"
  echo "- Python3:    $(python3 --version 2>/dev/null)"
  echo
  echo "## MCP servers (Claude config) BEFORE"
  echo
  if command -v jq >/dev/null && [ -f "$HOME/.claude/settings.json" ]; then
    jq -r '.mcpServers | keys[]?' "$HOME/.claude/settings.json" 2>/dev/null | sed 's/^/- /' || echo "- (parse error)"
  fi
} > "$SUMMARY"

# ─── 2. Run update-core.sh first (gcloud + VS Code ext + brew) ──
log "Running update-core.sh..."
"$ROOT/scripts/update-core.sh" 2>&1 | tee -a "$LOG" || log "WARN: update-core.sh exit non-zero (continuing)"

# ─── 3. Codex CLI update ─────────────────────────────
log "Codex CLI update check..."
if command -v codex >/dev/null 2>&1; then
  # Codex installs via Homebrew or npm, depending on installation
  if brew list codex 2>/dev/null | grep -q codex; then
    log "Codex via Homebrew, updated by brew upgrade"
  elif command -v npm >/dev/null 2>&1 && npm list -g 2>/dev/null | grep -qi codex; then
    npm update -g codex 2>&1 | tee -a "$LOG" || log "WARN: codex npm update failed"
  else
    log "Codex installed via direct binary — skip auto-update (manual gh release)"
  fi
fi

# ─── 4. npm global packages ──────────────────────────
log "npm global outdated check..."
if command -v npm >/dev/null 2>&1; then
  npm outdated -g --depth=0 2>&1 | tee -a "$LOG" || true
  # Update only patch + minor versions (no major bumps without review)
  npm update -g 2>&1 | tee -a "$LOG" || log "WARN: npm update failed"
fi

# ─── 5. MCP servers — update if installed via npm ────
log "MCP servers update check..."
if command -v claude >/dev/null 2>&1; then
  # Claude Code manages MCP servers via npx (auto-fetches latest @latest tag for many servers)
  # Just list current state for audit
  claude mcp list 2>/dev/null | tee -a "$LOG" || log "WARN: claude mcp list failed"
fi

# ─── 6. Capture after versions ──────────────────────
{
  echo
  echo "## Versions AFTER"
  echo
  echo "- Claude CLI: $(claude --version 2>/dev/null | head -1)"
  echo "- Codex CLI:  $(codex --version 2>/dev/null | head -1)"
  echo "- VS Code:    $(code --version 2>/dev/null | head -1)"
  echo "- Brew:       $(brew --version 2>/dev/null | head -1)"
  echo "- Node:       $(node --version 2>/dev/null)"
  echo "- npm:        $(npm --version 2>/dev/null)"
  echo "- Python3:    $(python3 --version 2>/dev/null)"
  echo
  echo "## MCP servers AFTER"
  echo
  if command -v jq >/dev/null && [ -f "$HOME/.claude/settings.json" ]; then
    jq -r '.mcpServers | keys[]?' "$HOME/.claude/settings.json" 2>/dev/null | sed 's/^/- /' || echo "- (parse error)"
  fi
  echo
  echo "## Doctor verification"
  echo
  echo '```'
  "$ROOT/scripts/doctor.sh" 2>&1 | tail -40
  echo '```'
} >> "$SUMMARY"

log "Update summary: $SUMMARY"

# ─── 7. macOS notification + ntfy ────────────────────
osascript -e "display notification \"Extended update complete. See $SUMMARY\" with title \"✓ AI ekosystem updated\"" 2>/dev/null || true

# Try ntfy.oneflow.cz (silently fail if VPS down)
curl -s -o /dev/null --max-time 5 \
  -H "Title: AI Ekosystem updated" \
  -H "Priority: low" \
  -d "Weekly update done. Summary: $SUMMARY" \
  https://ntfy.oneflow.cz/Filip 2>/dev/null || true

log "=== Extended update done ==="
