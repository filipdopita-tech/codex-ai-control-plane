#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="$HOME/.claude/logs"
STAMP="$(date '+%Y%m%d-%H%M%S')"
REPORT="$LOG_DIR/workspace-1000-pass-$STAMP.md"

mkdir -p "$LOG_DIR"

pass=0
fail=0
warn=0

usage() {
  cat <<'EOF'
Usage: workspace-1000-pass.sh

Runs a broad, low-risk health pass across the Codex workspace:
  - git state and ignored sensitive artifacts
  - shell syntax for local scripts
  - JSON validity for config/search/package files
  - Python syntax compile for active local projects
  - npm build for projects with package.json and existing node_modules
  - project hygiene inventory

It does not install dependencies, delete files, hit production endpoints, or send messages.
EOF
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

write_header() {
  cat > "$REPORT" <<EOF
# Workspace 1000 Pass

- Timestamp: $(date '+%Y-%m-%d %H:%M:%S %Z')
- Root: $ROOT

EOF
}

run_section() {
  local title="$1"
  shift

  echo "== $title =="
  {
    echo
    echo "## $title"
    echo
    echo '```text'
  } >> "$REPORT"

  set +e
  "$@" 2>&1 | tee -a "$REPORT"
  local rc=${PIPESTATUS[0]}
  set -e

  echo '```' >> "$REPORT"
  if [ "$rc" -eq 0 ]; then
    pass=$((pass + 1))
    echo "- Result: PASS" >> "$REPORT"
    echo "PASS $title"
  else
    fail=$((fail + 1))
    echo "- Result: FAIL exit=$rc" >> "$REPORT"
    echo "FAIL $title exit=$rc"
  fi
  echo
  return "$rc"
}

run_warn_section() {
  local title="$1"
  shift
  if ! run_section "$title" "$@"; then
    warn=$((warn + 1))
    fail=$((fail - 1))
  fi
}

write_header

run_section "Git State" git -C "$ROOT" status --short --branch || true

run_section "Security Audit" "$ROOT/ai-control-plane/scripts/security-audit.sh"

run_section "Sensitive Ignore Gate" bash -lc '
  set -euo pipefail
  cd "$1"
  candidates=$(find . -path ./.git -prune -o -path "*/node_modules/*" -prune -o -type f \( -iname "*creds*.json" -o -iname "*credentials*.json" -o -iname ".env" -o -iname ".env.*" -o -iname "*.pem" -o -iname "*.key" \) -print)
  if [ -z "$candidates" ]; then
    echo "No sensitive-looking files found."
    exit 0
  fi
  bad=0
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if git check-ignore -q "$f"; then
      echo "IGNORED $f"
    else
      echo "UNIGNORED $f"
      bad=$((bad + 1))
    fi
  done <<< "$candidates"
  [ "$bad" -eq 0 ]
' bash "$ROOT"

run_section "Shell Syntax" bash -lc '
  set -euo pipefail
  cd "$1"
  mapfile -t files < <(find . -path ./.git -prune -o -path "*/node_modules/*" -prune -o -path "./external-mirrors/*" -prune -o -type f -name "*.sh" -print | sort)
  [ "${#files[@]}" -gt 0 ] || exit 0
  for f in "${files[@]}"; do
    bash -n "$f"
  done
  echo "Checked ${#files[@]} shell scripts."
' bash "$ROOT"

run_section "JSON Validity" bash -lc '
  set -euo pipefail
  cd "$1"
  mapfile -t files < <(find . -path ./.git -prune -o -path "*/node_modules/*" -prune -o -path "./contacts-cleanup-*" -prune -o -path "./external-mirrors/*" -prune -o -type f \( -name "*.json" -o -name "package.json" \) -print | sort)
  [ "${#files[@]}" -gt 0 ] || exit 0
  for f in "${files[@]}"; do
    jq empty "$f" >/dev/null
  done
  echo "Checked ${#files[@]} JSON files."
' bash "$ROOT"

run_section "Python Compile" bash -lc '
  set -euo pipefail
  cd "$1"
  for dir in ai-control-plane/scripts scripts tools jobs-cz-system reverse-recruiter distressed-leads; do
    [ -d "$dir" ] || continue
    python3 -m compileall -q "$dir"
    echo "compiled $dir"
  done
' bash "$ROOT"

run_warn_section "Dialdeck Build" bash -lc '
  set -euo pipefail
  cd "$1/dialdeck"
  [ -d node_modules ] || { echo "SKIP node_modules missing"; exit 10; }
  npm run build
' bash "$ROOT"

run_section "Project Hygiene Inventory" bash -lc '
  set -euo pipefail
  cd "$1"
  for dir in dialdeck distressed-leads jobs-cz-system reverse-recruiter dluhopisy-cz-scraper ai-control-plane; do
    [ -d "$dir" ] || continue
    printf "%-24s" "$dir"
    [ -f "$dir/README.md" ] && printf " README" || printf " NO_README"
    [ -f "$dir/AGENTS.md" ] && printf " AGENTS" || true
    [ -f "$dir/package.json" ] && printf " package.json" || true
    [ -f "$dir/pyproject.toml" ] && printf " pyproject.toml" || true
    [ -f "$dir/requirements.txt" ] && printf " requirements.txt" || true
    echo
  done
' bash "$ROOT"

{
  echo
  echo "## Summary"
  echo
  echo "- Pass sections: $pass"
  echo "- Warn sections: $warn"
  echo "- Failed sections: $fail"
  echo "- Report: $REPORT"
} >> "$REPORT"

echo "Workspace 1000 pass complete"
echo "Report: $REPORT"
echo "Pass sections: $pass"
echo "Warn sections: $warn"
echo "Failed sections: $fail"

[ "$fail" -eq 0 ]
