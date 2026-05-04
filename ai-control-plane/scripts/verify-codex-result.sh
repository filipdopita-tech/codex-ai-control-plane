#!/usr/bin/env bash
# verify-codex-result.sh — anti-halucination gate after Codex run
#
# Captures real git diff in the target project + size of result.md
# vs what Codex claimed. Surfaces empty diffs, files-touched-mismatch,
# secret-leak risk, and binary noise.
#
# Use after delegate-to-codex.sh:
#   ./verify-codex-result.sh /path/to/project           # last result
#   ./verify-codex-result.sh /path/to/project <result>  # specific result.md
#
# Exit codes:
#   0  verification report produced (does not assert success/fail of task)
#   1  bad usage
#   2  project path missing
#   3  no result.md found

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: verify-codex-result.sh PROJECT_PATH [RESULT_FILE]

Captures real ground truth after a Codex delegation:
  - git diff statistics in the project (files changed, insertions, deletions)
  - first 60 lines of git diff
  - result file size & whether Codex actually claimed changes
  - quick secret-leak heuristic on diff
  - residual untracked files

Writes a structured verification markdown next to the result file.
Print summary to stdout. Read-only — never mutates project state.

Designed for anti-halucination: catches "Codex said it did X but git says no".
EOF
  exit "${1:-1}"
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage 0
fi

[ $# -ge 1 ] || usage

PROJECT="$1"
RESULT_FILE="${2:-}"

if [ ! -d "$PROJECT" ]; then
  echo "Project path does not exist: $PROJECT" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HANDOFF_DIR="$ROOT/handoffs"

# Find latest *.result.md if not specified
if [ -z "$RESULT_FILE" ]; then
  RESULT_FILE="$(ls -1t "$HANDOFF_DIR"/*.result.md 2>/dev/null | head -1 || true)"
fi

if [ -z "$RESULT_FILE" ] || [ ! -f "$RESULT_FILE" ]; then
  echo "No result file found in $HANDOFF_DIR" >&2
  exit 3
fi

VERIFY_FILE="${RESULT_FILE%.result.md}.verify.md"
PROJECT_ABS="$(cd "$PROJECT" && pwd)"

echo "Verifying Codex result"
echo "  project:  $PROJECT_ABS"
echo "  result:   $RESULT_FILE"
echo "  verify:   $VERIFY_FILE"
echo

cd "$PROJECT_ABS"

# Git status against last commit
if [ ! -d "$PROJECT_ABS/.git" ]; then
  IS_GIT=0
else
  IS_GIT=1
fi

if [ "$IS_GIT" -eq 1 ]; then
  CHANGED_TOTAL=$(git status --short 2>/dev/null | wc -l | tr -d ' ')
  STAGED=$(git diff --cached --shortstat 2>/dev/null || echo "")
  UNSTAGED=$(git diff --shortstat 2>/dev/null || echo "")
  UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
  DIFF_PREVIEW=$(git diff --no-color 2>/dev/null | head -60 || true)

  # Compute Codex-only delta when caller provided a pre-run snapshot.
  # Snapshot path comes via CODEX_BEFORE_SNAPSHOT env (set by delegate-to-codex.sh).
  # Delta = files in current `git status --short` that were NOT in before snapshot.
  if [ -n "${CODEX_BEFORE_SNAPSHOT:-}" ] && [ -f "${CODEX_BEFORE_SNAPSHOT}" ]; then
    CURRENT_SNAP=$(mktemp -t codex-after.XXXXXX)
    git status --porcelain 2>/dev/null > "$CURRENT_SNAP" || true
    # diff returns 1 when differences exist — swallow with || true
    CHANGED=$(diff <(sort "$CODEX_BEFORE_SNAPSHOT") <(sort "$CURRENT_SNAP") 2>/dev/null | grep -cE '^>' || true)
    CHANGED="${CHANGED:-0}"
    DELTA_PREVIEW=$(diff <(sort "$CODEX_BEFORE_SNAPSHOT") <(sort "$CURRENT_SNAP") 2>/dev/null | grep -E '^>' | head -20 | sed 's/^> //' || true)
    SNAPSHOT_USED=1
    rm -f "$CURRENT_SNAP" 2>/dev/null || true
  else
    CHANGED="$CHANGED_TOTAL"
    DELTA_PREVIEW=""
    SNAPSHOT_USED=0
  fi

  # Detect Codex-made commits: HEAD moved during Codex run.
  # Codex sandboxed with workspace-write CAN run `git commit` / `git reset` /
  # `git rebase` itself. Three cases to handle:
  #   1) HEAD advanced (commit/amend forward)  → rev-list before..HEAD
  #   2) HEAD rewound  (reset --hard backward) → rev-list HEAD..before (lost)
  #   3) Diverged      (rebase to new branch)  → use symmetric diff with --left-right
  # We always also compute a flat name-only diff between the two HEADs which
  # captures the file-level delta regardless of direction.
  CODEX_COMMITS=0
  CODEX_COMMITS_LIST=""
  CODEX_COMMITS_FILES=0
  CODEX_HEAD_DIRECTION=""
  if [ -n "${CODEX_BEFORE_HEAD:-}" ]; then
    CURRENT_HEAD="$(git rev-parse HEAD 2>/dev/null || true)"
    if [ -n "$CURRENT_HEAD" ] && [ "$CURRENT_HEAD" != "$CODEX_BEFORE_HEAD" ]; then
      # Determine direction
      if git merge-base --is-ancestor "$CODEX_BEFORE_HEAD" "$CURRENT_HEAD" 2>/dev/null; then
        CODEX_HEAD_DIRECTION="forward"
        RANGE="${CODEX_BEFORE_HEAD}..HEAD"
      elif git merge-base --is-ancestor "$CURRENT_HEAD" "$CODEX_BEFORE_HEAD" 2>/dev/null; then
        CODEX_HEAD_DIRECTION="rewound"
        # before contains current → Codex did `reset --hard` to drop commits
        RANGE="HEAD..${CODEX_BEFORE_HEAD}"
      else
        CODEX_HEAD_DIRECTION="diverged"
        # Symmetric — neither is ancestor (rebase to different parent)
        RANGE="${CODEX_BEFORE_HEAD}...HEAD"
      fi
      CODEX_COMMITS=$(git rev-list --count "$RANGE" 2>/dev/null || echo 0)
      CODEX_COMMITS_LIST=$(git log --format="%h %s" "$RANGE" 2>/dev/null | head -10 || true)
      # Flat name-only diff catches all cases regardless of rev-list direction
      CODEX_COMMITS_FILES=$(git diff --name-only "${CODEX_BEFORE_HEAD}" "${CURRENT_HEAD}" 2>/dev/null | wc -l | tr -d ' ' || echo 0)
      # Treat committed file changes as part of the Codex delta
      CHANGED=$(( CHANGED + CODEX_COMMITS_FILES ))
    fi
  fi
else
  CHANGED=0
  CHANGED_TOTAL=0
  STAGED=""
  UNSTAGED=""
  UNTRACKED=0
  DIFF_PREVIEW=""
  DELTA_PREVIEW=""
  SNAPSHOT_USED=0
  CODEX_COMMITS=0
  CODEX_COMMITS_LIST=""
  CODEX_COMMITS_FILES=0
  CODEX_HEAD_DIRECTION=""
fi

# Result file metrics
RESULT_BYTES=$(wc -c < "$RESULT_FILE" 2>/dev/null | tr -d ' ' || echo 0)
RESULT_LINES=$(wc -l < "$RESULT_FILE" 2>/dev/null | tr -d ' ' || echo 0)

# Codex claimed-action heuristic — common phrases in Codex outputs.
# Use (grep || true) to swallow non-zero when no matches; wc gives final count.
CLAIM_CHANGED=$( ( grep -ciE '^\s*(změnil|upravil|vytvořil|smazal|fixed|edited|created|deleted|modified|added|wrote)\b' "$RESULT_FILE" 2>/dev/null || true ) | tr -d ' \n' )
CLAIM_NOOP=$( ( grep -ciE '\b(no changes|nothing to do|already|žádné změny|nic neměnit|read-only|nezměnil)\b' "$RESULT_FILE" 2>/dev/null || true ) | tr -d ' \n' )
CLAIM_CHANGED="${CLAIM_CHANGED:-0}"
CLAIM_NOOP="${CLAIM_NOOP:-0}"

# Secret-leak heuristic on diff (basic)
SECRET_HITS=0
if [ "$IS_GIT" -eq 1 ]; then
  SECRET_HITS=$( ( git diff 2>/dev/null | grep -ciE '(api[_-]?key|secret|password|token|bearer)\s*=\s*["\x27][^"\x27]{16,}' || true ) | tr -d ' \n' )
  SECRET_HITS="${SECRET_HITS:-0}"
fi

# Verdict
VERDICT="UNKNOWN"
NOTE=""

if [ "$IS_GIT" -eq 0 ]; then
  VERDICT="N/A"
  NOTE="project is not a git repository — diff verification unavailable"
elif [ "$CHANGED" -eq 0 ] && [ "$CLAIM_CHANGED" -gt 0 ] && [ "$CLAIM_NOOP" -eq 0 ]; then
  VERDICT="MISMATCH"
  NOTE="Codex output claims edits but git shows no changes — inspect result manually"
elif [ "$CHANGED" -gt 0 ] && [ "$CLAIM_NOOP" -gt 0 ] && [ "$CLAIM_CHANGED" -eq 0 ]; then
  VERDICT="MISMATCH"
  NOTE="Codex output claims no-op but git shows changes — review the diff"
elif [ "$SECRET_HITS" -gt 0 ]; then
  VERDICT="ALERT"
  NOTE="diff contains $SECRET_HITS potential secret-like assignment(s) — review before commit"
elif [ "$CHANGED" -eq 0 ] && [ "$CLAIM_NOOP" -gt 0 ]; then
  VERDICT="OK_NOOP"
  NOTE="Codex correctly reported no-op and git confirms"
elif [ "$CHANGED" -gt 0 ] && [ "$CLAIM_CHANGED" -gt 0 ]; then
  VERDICT="OK_CHANGED"
  NOTE="$CHANGED file(s) changed and Codex claimed edits — consistent"
elif [ "$CHANGED" -gt 0 ]; then
  VERDICT="REVIEW"
  if [ "$CODEX_COMMITS" -gt 0 ]; then
    NOTE="$CHANGED file(s) changed (incl. $CODEX_COMMITS Codex commit(s)) but Codex output not explicit about it"
  else
    NOTE="$CHANGED file(s) changed but Codex output is not explicit about it"
  fi
else
  VERDICT="OK_NOOP"
  NOTE="no changes detected"
fi

{
  echo "# Codex Verify Report"
  echo
  echo "- Project:   $PROJECT_ABS"
  echo "- Result:    $RESULT_FILE"
  echo "- Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "- Verdict:   $VERDICT"
  echo "- Note:      $NOTE"
  echo
  echo "## Git diff facts"
  echo
  if [ "$IS_GIT" -eq 1 ]; then
    if [ "$SNAPSHOT_USED" -eq 1 ]; then
      echo "- Changed paths (Codex delta): $CHANGED"
      echo "  - uncommitted-diff delta: $(( CHANGED - CODEX_COMMITS_FILES ))"
      echo "  - committed-by-Codex delta: $CODEX_COMMITS_FILES"
      echo "- Total dirty paths in tree: $CHANGED_TOTAL (pre-existing + Codex uncommitted)"
      echo "- Snapshot mode: ENABLED (before/after diff)"
      if [ -n "$DELTA_PREVIEW" ]; then
        echo
        echo "### Codex-only delta (first 20 status lines, uncommitted)"
        echo
        echo '```'
        printf '%s\n' "$DELTA_PREVIEW"
        echo '```'
      fi
    else
      echo "- Changed paths: $CHANGED"
      echo "- Snapshot mode: disabled (no pre-run snapshot — verdict uses total tree state)"
    fi
    if [ "$CODEX_COMMITS" -gt 0 ] || [ "$CODEX_COMMITS_FILES" -gt 0 ]; then
      echo
      DIR_LABEL="$CODEX_HEAD_DIRECTION"
      [ -z "$DIR_LABEL" ] && DIR_LABEL="forward"
      echo "### Codex-made commits ($CODEX_COMMITS, $CODEX_COMMITS_FILES file(s), HEAD-$DIR_LABEL)"
      if [ "$DIR_LABEL" = "rewound" ]; then
        echo
        echo "**WARNING:** Codex moved HEAD backward — commits below were DROPPED, not added."
      elif [ "$DIR_LABEL" = "diverged" ]; then
        echo
        echo "**WARNING:** Codex rebased — symmetric diff (commits unique to either side)."
      fi
      echo
      echo '```'
      printf '%s\n' "$CODEX_COMMITS_LIST"
      echo '```'
    fi
    echo "- Untracked (new) files: $UNTRACKED"
    echo "- Unstaged: ${UNSTAGED:-none}"
    echo "- Staged: ${STAGED:-none}"
    echo "- Secret-like patterns in diff: $SECRET_HITS"
  else
    echo "- Not a git repository — diff verification skipped"
  fi
  echo
  echo "## Result claim signals"
  echo
  echo "- claim-edits matches: $CLAIM_CHANGED"
  echo "- claim-noop matches: $CLAIM_NOOP"
  echo "- Result size: ${RESULT_BYTES} bytes / ${RESULT_LINES} lines"
  echo
  echo "## Diff preview (first 60 lines)"
  echo
  echo '```diff'
  if [ -n "$DIFF_PREVIEW" ]; then
    printf '%s\n' "$DIFF_PREVIEW"
  else
    echo "(no diff)"
  fi
  echo '```'
} > "$VERIFY_FILE"

echo "Verdict: $VERDICT"
echo "Note:    $NOTE"
echo
echo "Written: $VERIFY_FILE"
