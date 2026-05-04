#!/usr/bin/env bash
# jobs.sh — convenience wrapper pro Filipa.
# Resolves venv automatically + forwards args to cli.py.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_PY="/root/.venvs/jobs-cz/bin/python"

if [[ ! -x "$VENV_PY" ]]; then
    # Mac fallback (development) — use system python3 with playwright + bs4 installed
    if command -v python3 >/dev/null && python3 -c "import playwright, bs4" 2>/dev/null; then
        VENV_PY="python3"
    else
        echo "ERROR: venv $VENV_PY missing and Mac python3 nemá playwright/bs4." >&2
        exit 1
    fi
fi

exec "$VENV_PY" "$ROOT/cli.py" "$@"
