#!/usr/bin/env bash
# ofs brand — OneFlow brand voice audit
# Source of truth: ~/Documents/oneflow-claude-project/BANNED_WORDS.md
# Anti-halucinace: jen real grep, exact line numbers
set -euo pipefail

BANNED_SOURCE="$HOME/Documents/oneflow-claude-project/BANNED_WORDS.md"

usage() {
  cat <<'EOF'
Usage: ofs brand FILE_OR_TEXT
       echo "text" | ofs brand -
       ofs brand --explain          # show banned word categories
       ofs brand --update-cache     # rebuild local pattern cache

Audit OneFlow brand voice:
  - Banned CZ corporate bullshit (inovativní, revoluční, win-win, ...)
  - Weak openers (dovoluji si, rád bych, s pozdravem, ...)
  - AI-sounding phrases (v dnešní době, není žádným tajemstvím, ...)
  - Banned EN buzzwords (innovative, leverage, paradigm shift, ...)
  - Cold email DOA openers (I hope this finds you well, ...)

Exit:
  0 PASS  — žádné nálezy
  2 WARN  — nálezy detected (line numbers + suggestions)

Příklady:
  ofs brand my-outreach.md
  ofs brand draft-post.txt
  echo "Dovoluji si Vás kontaktovat..." | ofs brand -
EOF
  exit "${1:-1}"
}

[ $# -ge 1 ] || usage

# ─── Inline pattern set (fallback if BANNED_SOURCE missing) ───
build_patterns() {
  cat <<'PATTERNS'
inovativní|revoluční|komplexní řešení|win-win|synergie|paradigma|disruptivní|klíčový hráč|na trhu|přinášíme hodnotu|nabízíme řešení|strategické partnerství|holistický přístup
dovoluji si|rád bych|ráda bych|s pozdravem,|doufám že|chtěl bych se zeptat|pokud byste měl
v dnešní době|v současné éře|není žádným tajemstvím|jak všichni víme|je důležité zmínit|nelze opomenout|v neposlední řadě|závěrem lze konstatovat|z výše uvedeného vyplývá
innovative|revolutionary|cutting-edge|game-changing|leverage|paradigm shift|disruptive|best-in-class|world-class|state-of-the-art|next-generation
I hope this finds you well|I hope you're doing well|I wanted to reach out|I'm reaching out because|Just checking in|Following up on my previous|I trust this email
Furthermore,|Moreover,|In conclusion,|It is important to note|It should be noted
PATTERNS
}

ALL_PATTERNS=$(build_patterns | tr '\n' '|' | sed 's/|$//')

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage 0
fi

if [ "${1:-}" = "--explain" ]; then
  cat <<'EOF'
OneFlow Brand Voice — Banned Categories

CZ Corporate Bullshit:
  inovativní, revoluční, komplexní řešení, win-win, synergie,
  paradigma, disruptivní, klíčový hráč, na trhu, holistický

CZ Weak Openers:
  dovoluji si, rád bych, s pozdravem (use "Dopita"),
  doufám že, chtěl bych se zeptat

CZ AI-Sounding:
  v dnešní době, v současné éře, není žádným tajemstvím,
  jak všichni víme, závěrem lze konstatovat

EN Buzzwords:
  innovative, revolutionary, cutting-edge, game-changing,
  leverage (verb), paradigm shift, disruptive, world-class

EN Cold Email DOA:
  I hope this finds you well, I wanted to reach out,
  Just checking in, Following up on my previous

EN AI-Sounding:
  Furthermore, Moreover, In conclusion, It is important to note

Source of truth: ~/Documents/oneflow-claude-project/BANNED_WORDS.md
EOF
  exit 0
fi

color() {
  case "$1" in
    bold) printf "\033[1m%s\033[0m" "$2" ;;
    red) printf "\033[31m%s\033[0m" "$2" ;;
    green) printf "\033[32m%s\033[0m" "$2" ;;
    yellow) printf "\033[33m%s\033[0m" "$2" ;;
    blue) printf "\033[34m%s\033[0m" "$2" ;;
    dim) printf "\033[2m%s\033[0m" "$2" ;;
    *) printf "%s" "$2" ;;
  esac
}

# Determine input source
if [ "${1:-}" = "-" ]; then
  INPUT_FILE=$(mktemp -t ofs-brand.XXXXXX)
  cat > "$INPUT_FILE"
  SOURCE_LABEL="<stdin>"
  TEMP=1
else
  INPUT_FILE="$1"
  SOURCE_LABEL="$1"
  TEMP=0
  if [ ! -f "$INPUT_FILE" ]; then
    echo "File not found: $INPUT_FILE" >&2
    exit 1
  fi
fi

echo
color bold "ofs brand — $SOURCE_LABEL"; echo
echo "================================================="

# Real grep with line numbers, case-insensitive
HITS=$(grep -inE "$ALL_PATTERNS" "$INPUT_FILE" 2>/dev/null || true)

if [ -z "$HITS" ]; then
  color green "  ✓ PASS — žádné banned slovo nenalezeno"
  echo
  [ "$TEMP" -eq 1 ] && rm -f "$INPUT_FILE"
  exit 0
fi

HIT_COUNT=$(printf '%s\n' "$HITS" | wc -l | tr -d ' ')
color yellow "  ⚠ FAIL — $HIT_COUNT nález(ů):"; echo
echo
printf '%s\n' "$HITS" | while IFS=: read -r line content; do
  echo "  L$line:"
  echo "    $(color dim "$content")"
done | head -30

[ "$HIT_COUNT" -gt 15 ] && {
  echo
  color dim "  ... showing first 15 of $HIT_COUNT"; echo
}

echo
echo "================================================="
color dim "Náhrady (top 5):"; echo
cat <<'EOF'
  inovativní        → nový, jiný, odlišný
  revoluční         → konkrétní benefit (e.g. "5x rychleji")
  komplexní řešení  → konkrétní seznam (3 tečky)
  dovoluji si       → smaž, jdi rovnou k věci
  s pozdravem       → "Dopita" nebo "Filip Dopita"
  v dnešní době     → smaž, "teď"
EOF

[ "$TEMP" -eq 1 ] && rm -f "$INPUT_FILE"
exit 2
