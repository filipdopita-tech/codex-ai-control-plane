#!/bin/bash
# sops-load.sh — decrypt sops file and source / exec with secrets
# Usage:
#   . sops-load.sh source /path/to/master.sops.env       # source vars to current shell
#   sops-load.sh exec /path/to/master.sops.env CMD...    # exec CMD with decrypted env
#   sops-load.sh dump /path/to/master.sops.env [out]     # write to /run/oneflow-secrets.env (tmpfs, 600)
#   sops-load.sh check /path/to/master.sops.env          # decrypt & count, no output
#
# Requires: sops, age, SOPS_AGE_KEY_FILE env var or default ~/.config/sops/age/keys.txt
set -euo pipefail

SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-${HOME}/.config/sops/age/keys.txt}"
[ -r "$SOPS_AGE_KEY_FILE" ] || SOPS_AGE_KEY_FILE=/root/.config/sops/age/keys.txt
export SOPS_AGE_KEY_FILE

usage() {
  echo "usage: sops-load.sh {source|exec|dump|check} FILE [args...]" >&2
  exit 1
}

MODE="${1:-}"
SOPS_FILE="${2:-}"
[ -z "$MODE" ] && usage
[ -z "$SOPS_FILE" ] && usage
[ ! -r "$SOPS_FILE" ] && { echo "sops file not readable: $SOPS_FILE" >&2; exit 1; }

case "$MODE" in
  source)
    set -a
    eval "$(sops --decrypt --input-type=dotenv --output-type=dotenv "$SOPS_FILE" | grep -E '^[A-Za-z_][A-Za-z0-9_]*=')"
    set +a
    ;;
  exec)
    shift 2
    [ $# -eq 0 ] && { echo "exec mode requires a command" >&2; exit 1; }
    TMP=$(mktemp)
    chmod 600 "$TMP"
    trap 'shred -u "$TMP" 2>/dev/null || : > "$TMP"' EXIT
    sops --decrypt --input-type=dotenv --output-type=dotenv "$SOPS_FILE" | grep -E '^[A-Za-z_][A-Za-z0-9_]*=' > "$TMP"
    set -a
    . "$TMP"
    set +a
    exec "$@"
    ;;
  dump)
    OUT="${3:-/run/oneflow-secrets.env}"
    umask 077
    sops --decrypt --input-type=dotenv --output-type=dotenv "$SOPS_FILE" | grep -E '^[A-Za-z_][A-Za-z0-9_]*=' > "$OUT"
    chmod 600 "$OUT"
    echo "decrypted -> $OUT"
    ;;
  check)
    N=$(sops --decrypt --input-type=dotenv --output-type=dotenv "$SOPS_FILE" | grep -cE '^[A-Za-z_][A-Za-z0-9_]*=')
    echo "OK: $N keys decryptable from $SOPS_FILE"
    ;;
  *)
    usage
    ;;
esac
