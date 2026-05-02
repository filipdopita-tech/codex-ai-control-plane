#!/usr/bin/env bash
# ofs eval — auto-eval high-stakes výstupy proti Filip-specific rubric
# Použij PŘED odesláním: cold email, DD report, IG post, investor memo, sales letter
# Outputs: 0-100 score per dimension + verdict
# Note: NO pipefail — grep -o pipelines fail when no match, but that's normal scoring path
set -eu

usage() {
  cat <<'EOF'
Usage: ofs eval [--type TYPE] FILE_OR_TEXT
       echo "text" | ofs eval [--type TYPE] -

Type:
  outreach     — cold email / DM / podcast pitch
  content      — IG post / carousel / LinkedIn / newsletter
  dd           — DD report / investor memo / due diligence
  sales        — sales letter / nabídka / pricing email
  generic      — generic copy (default)

Rubric dimensions (0-100):
  brand-voice    — banned words penalty + voice fit
  hook-strength  — opener power (specific vs vague)
  cta-quality    — Voss calibrated vs ano/ne otázka
  specificity    — concrete numbers/dates vs vague claims
  ai-tells       — Furthermore/Moreover/em-dash/uniform sentences
  length-fit     — type-appropriate length

Verdict:
  90-100 PASS-EXCELLENT — ship as-is
  75-89  PASS-GOOD      — minor polish optional
  50-74  REVISE         — needs rewrite of weak dimensions
  0-49   BLOCK          — full rewrite needed

Příklady:
  ofs eval --type outreach draft-email.md
  echo "..." | ofs eval --type content -
  ofs eval my-dd-report.md
EOF
  exit "${1:-1}"
}

[ $# -ge 1 ] || usage
[ "${1:-}" = "--help" ] && usage 0

TYPE="generic"
if [ "${1:-}" = "--type" ]; then
  TYPE="${2:-generic}"
  shift 2
fi

[ $# -ge 1 ] || usage

# Input handling
if [ "${1:-}" = "-" ]; then
  INPUT_FILE=$(mktemp -t ofs-eval.XXXXXX)
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

# Helper: count regex matches in string, always returns one integer
count_match() {
  local pattern="$1" input="$2"
  printf '%s\n' "$input" | awk -v p="$pattern" 'BEGIN{IGNORECASE=1; n=0} $0 ~ p {n++} END{print n+0}'
}

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

CONTENT=$(cat "$INPUT_FILE")
WORD_COUNT=$(printf '%s' "$CONTENT" | wc -w | tr -d ' ')
LINE_COUNT=$(printf '%s\n' "$CONTENT" | wc -l | tr -d ' ')

# ─── DIMENSION 1: BRAND VOICE (banned word penalty) ───
BANNED_PATTERN='inovativní|revoluční|komplexní řešení|win-win|synergie|paradigma|disruptivní|dovoluji si|rád bych|s pozdravem,|v dnešní době|není žádným tajemstvím|závěrem lze konstatovat|innovative|revolutionary|cutting-edge|game-changing|leverage|paradigm shift|state-of-the-art|I hope this finds you well|I wanted to reach out|Just checking in'
BANNED_HITS=$(count_match "$BANNED_PATTERN" "$CONTENT")
BRAND_SCORE=100
[ "$BANNED_HITS" -gt 0 ] && BRAND_SCORE=$((100 - BANNED_HITS * 20))
[ "$BRAND_SCORE" -lt 0 ] && BRAND_SCORE=0

# ─── DIMENSION 2: HOOK STRENGTH ───
# Strong = first 80 chars contain: number, name, specific claim, question
FIRST_LINE=$(printf '%s' "$CONTENT" | head -c 200)
HOOK_SCORE=50
# +20 if number in first 80 chars
printf '%s' "$FIRST_LINE" | head -c 80 | grep -qE '[0-9]' && HOOK_SCORE=$((HOOK_SCORE + 20))
# +15 if question mark in first 200 chars (engagement)
printf '%s' "$FIRST_LINE" | grep -q '?' && HOOK_SCORE=$((HOOK_SCORE + 15))
# -30 if starts with greeting variant
printf '%s' "$FIRST_LINE" | head -c 80 | grep -qiE '^(ahoj|dobrý den|hello|hi |dear |hey )' && HOOK_SCORE=$((HOOK_SCORE - 30))
# -25 if starts with banned opener
printf '%s' "$FIRST_LINE" | head -c 80 | grep -qiE '^(dovoluji|rád bych|i hope|i wanted|just checking)' && HOOK_SCORE=$((HOOK_SCORE - 25))
# +15 capital letter punch (not "I" alone)
printf '%s' "$FIRST_LINE" | head -c 50 | grep -qE '\b[A-Z][A-Za-z]{3,}' && HOOK_SCORE=$((HOOK_SCORE + 15))
[ "$HOOK_SCORE" -gt 100 ] && HOOK_SCORE=100
[ "$HOOK_SCORE" -lt 0 ] && HOOK_SCORE=0

# ─── DIMENSION 3: CTA QUALITY ───
CTA_SCORE=50
# Search last 30% of content for CTA patterns
CTA_AREA=$(printf '%s' "$CONTENT" | tail -c $((${#CONTENT} / 3 + 100)))
# Voss calibrated +30
printf '%s' "$CTA_AREA" | grep -qiE '(co by muselo|jak by pro vás|bylo by mimo|co je nejdůležitější|what would have to|how would it|would it be ridiculous)' && CTA_SCORE=$((CTA_SCORE + 30))
# Specific date/time +20
printf '%s' "$CTA_AREA" | grep -qE '(202[6-9]-[0-9]{2}|úter[ýa]|středu|čtvrtek|pátek|tuesday|wednesday|thursday|friday|[0-9]{1,2}:[0-9]{2})' && CTA_SCORE=$((CTA_SCORE + 20))
# Yes/no question -20 (pasivní)
printf '%s' "$CTA_AREA" | grep -qiE '(zajímalo by Vás|měl byste zájem|are you interested|would you like|would you be open)' && CTA_SCORE=$((CTA_SCORE - 20))
# CTA verb (Comment/Save/Reply/DM) +10
printf '%s' "$CTA_AREA" | grep -qiE '(napiš mi|odpověz|reply|comment [A-Z]|save this|dm me)' && CTA_SCORE=$((CTA_SCORE + 10))
[ "$CTA_SCORE" -gt 100 ] && CTA_SCORE=100
[ "$CTA_SCORE" -lt 0 ] && CTA_SCORE=0

# ─── DIMENSION 4: SPECIFICITY ───
# Count concrete numbers, percentages, dates, named entities
SPEC_SCORE=40
NUM_COUNT=$(printf '%s' "$CONTENT" | grep -oE '[0-9]+([.,][0-9]+)?(\s*(%|Kč|EUR|USD|měs|let|hodin|min))?' | wc -l | tr -d ' ')
[ "$NUM_COUNT" -ge 3 ] && SPEC_SCORE=$((SPEC_SCORE + 20))
[ "$NUM_COUNT" -ge 6 ] && SPEC_SCORE=$((SPEC_SCORE + 15))
# Named entities (Capitalized words, not at sentence start)
ENTITIES=$(printf '%s' "$CONTENT" | grep -oE '\b[A-Z][a-zěščřžýáíéúůA-Z]{2,}' | sort -u | wc -l | tr -d ' ')
[ "$ENTITIES" -ge 5 ] && SPEC_SCORE=$((SPEC_SCORE + 15))
# Vague claims penalty
VAGUE=$(count_match '(mnoho|hodně|spousta|řada|několik|lots of|many|various|several)' "$CONTENT")
SPEC_SCORE=$((SPEC_SCORE - VAGUE * 5))
[ "$SPEC_SCORE" -gt 100 ] && SPEC_SCORE=100
[ "$SPEC_SCORE" -lt 0 ] && SPEC_SCORE=0

# ─── DIMENSION 5: AI TELLS ───
AI_SCORE=100
# Em-dash abuse
EMDASH=$(printf '%s' "$CONTENT" | grep -oE '—' | wc -l | tr -d ' ')
[ "$EMDASH" -gt 3 ] && AI_SCORE=$((AI_SCORE - 15))
# Furthermore/Moreover
TRANSITION=$(count_match '(furthermore|moreover|in conclusion|it is important to note|závěrem|kromě toho lze)' "$CONTENT")
AI_SCORE=$((AI_SCORE - TRANSITION * 10))
# Exact 5 or 10-item lists (AI tell)
LIST_5=$(printf '%s\n' "$CONTENT" | awk '/^[0-9]\./' | wc -l | tr -d ' ')
[ "$LIST_5" = "5" ] || [ "$LIST_5" = "10" ] && AI_SCORE=$((AI_SCORE - 5))
# Uniform sentence length (low variance)
[ "$AI_SCORE" -lt 0 ] && AI_SCORE=0

# ─── DIMENSION 6: LENGTH FIT ───
LEN_SCORE=70
case "$TYPE" in
  outreach)
    # Cold email sweet spot: 50-150 words
    if [ "$WORD_COUNT" -ge 50 ] && [ "$WORD_COUNT" -le 150 ]; then LEN_SCORE=100
    elif [ "$WORD_COUNT" -lt 30 ]; then LEN_SCORE=50
    elif [ "$WORD_COUNT" -gt 250 ]; then LEN_SCORE=40
    else LEN_SCORE=75; fi
    ;;
  content)
    # IG/social: 80-300 words
    if [ "$WORD_COUNT" -ge 80 ] && [ "$WORD_COUNT" -le 300 ]; then LEN_SCORE=100
    elif [ "$WORD_COUNT" -lt 50 ]; then LEN_SCORE=50
    elif [ "$WORD_COUNT" -gt 500 ]; then LEN_SCORE=50
    else LEN_SCORE=75; fi
    ;;
  dd)
    # DD: 1000-5000 words minimum
    if [ "$WORD_COUNT" -ge 1000 ]; then LEN_SCORE=100
    elif [ "$WORD_COUNT" -ge 500 ]; then LEN_SCORE=70
    else LEN_SCORE=40; fi
    ;;
  sales)
    if [ "$WORD_COUNT" -ge 100 ] && [ "$WORD_COUNT" -le 400 ]; then LEN_SCORE=100
    else LEN_SCORE=70; fi
    ;;
  *) LEN_SCORE=70 ;;
esac

# ─── COMPOSITE SCORE (weighted by type) ───
case "$TYPE" in
  outreach)
    # brand 25, hook 25, cta 20, spec 15, ai 10, len 5
    COMPOSITE=$(awk "BEGIN { printf \"%.0f\", $BRAND_SCORE * 0.25 + $HOOK_SCORE * 0.25 + $CTA_SCORE * 0.20 + $SPEC_SCORE * 0.15 + $AI_SCORE * 0.10 + $LEN_SCORE * 0.05 }")
    ;;
  content)
    # brand 20, hook 30, cta 15, spec 15, ai 15, len 5
    COMPOSITE=$(awk "BEGIN { printf \"%.0f\", $BRAND_SCORE * 0.20 + $HOOK_SCORE * 0.30 + $CTA_SCORE * 0.15 + $SPEC_SCORE * 0.15 + $AI_SCORE * 0.15 + $LEN_SCORE * 0.05 }")
    ;;
  dd)
    # spec 35, brand 15, ai 15, hook 10, cta 5, len 20
    COMPOSITE=$(awk "BEGIN { printf \"%.0f\", $BRAND_SCORE * 0.15 + $HOOK_SCORE * 0.10 + $CTA_SCORE * 0.05 + $SPEC_SCORE * 0.35 + $AI_SCORE * 0.15 + $LEN_SCORE * 0.20 }")
    ;;
  sales)
    # cta 30, brand 20, hook 20, spec 15, ai 10, len 5
    COMPOSITE=$(awk "BEGIN { printf \"%.0f\", $BRAND_SCORE * 0.20 + $HOOK_SCORE * 0.20 + $CTA_SCORE * 0.30 + $SPEC_SCORE * 0.15 + $AI_SCORE * 0.10 + $LEN_SCORE * 0.05 }")
    ;;
  *)
    COMPOSITE=$(awk "BEGIN { printf \"%.0f\", ($BRAND_SCORE + $HOOK_SCORE + $CTA_SCORE + $SPEC_SCORE + $AI_SCORE + $LEN_SCORE) / 6 }")
    ;;
esac

# Verdict
if [ "$COMPOSITE" -ge 90 ]; then
  VERDICT="PASS-EXCELLENT"
  V_COLOR="green"
elif [ "$COMPOSITE" -ge 75 ]; then
  VERDICT="PASS-GOOD"
  V_COLOR="green"
elif [ "$COMPOSITE" -ge 50 ]; then
  VERDICT="REVISE"
  V_COLOR="yellow"
else
  VERDICT="BLOCK"
  V_COLOR="red"
fi

# Print scorecard
echo
color bold "ofs eval — $SOURCE_LABEL [$TYPE]"; echo
echo "================================================="
printf "  Brand voice:    "; color bold "$BRAND_SCORE/100"; printf "  ("; [ "$BANNED_HITS" -gt 0 ] && color yellow "$BANNED_HITS banned hits" || color dim "0 banned hits"; echo ")"
printf "  Hook strength:  "; color bold "$HOOK_SCORE/100"; echo
printf "  CTA quality:    "; color bold "$CTA_SCORE/100"; echo
printf "  Specificity:    "; color bold "$SPEC_SCORE/100"; printf "  ("; color dim "$NUM_COUNT numbers, $ENTITIES entities"; echo ")"
printf "  AI tells:       "; color bold "$AI_SCORE/100"; printf "  ("; color dim "$EMDASH em-dashes, $TRANSITION transitions"; echo ")"
printf "  Length fit:     "; color bold "$LEN_SCORE/100"; printf "  ("; color dim "$WORD_COUNT words, type=$TYPE"; echo ")"
echo "  ─────────────────────────"
printf "  COMPOSITE:      "; color bold "$COMPOSITE/100"; printf "  → "; color "$V_COLOR" "$VERDICT"; echo
echo "================================================="
echo

# Suggestions for low dimensions
if [ "$VERDICT" != "PASS-EXCELLENT" ]; then
  color dim "Suggestions:"; echo
  [ "$BRAND_SCORE" -lt 75 ] && echo "  • Brand: ofs brand $SOURCE_LABEL (vidět jaké banned slova)"
  [ "$HOOK_SCORE" -lt 70 ] && echo "  • Hook: začni číslem nebo jmenem osoby (ne 'Ahoj' / 'Dovoluji si')"
  [ "$CTA_SCORE" -lt 70 ] && echo "  • CTA: použij Voss calibrated ('Co by muselo platit, abyste...')"
  [ "$SPEC_SCORE" -lt 70 ] && echo "  • Specificity: přidej čísla, jména, data (vague → konkrétní)"
  [ "$AI_SCORE" -lt 80 ] && echo "  • AI tells: smaž 'Furthermore/Moreover/—', short-long-short rytmus"
  [ "$LEN_SCORE" -lt 70 ] && echo "  • Length: $WORD_COUNT slov je mimo sweet-spot pro $TYPE"
  echo
fi

[ "$TEMP" -eq 1 ] && rm -f "$INPUT_FILE"

# Exit code by verdict
case "$VERDICT" in
  PASS-EXCELLENT|PASS-GOOD) exit 0 ;;
  REVISE) exit 2 ;;
  BLOCK) exit 1 ;;
esac
