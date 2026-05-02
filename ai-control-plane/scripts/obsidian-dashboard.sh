#!/usr/bin/env bash
# obsidian-dashboard.sh — Auto-generate Ecosystem-Status.md in OneFlow-Vault
#
# Reads: resource-monitor.jsonl + usage-daily.jsonl + ofs.jsonl + recent handoffs
# Writes: ~/Documents/OneFlow-Vault/00-Claude-Dashboard/Ecosystem-Status.md
# Run: every 15 min via cron (Mac side)
#
# Filip rules:
#  - Read-only metrics, no secrets in vault
#  - Compact (one-screen dashboard)
#  - Real data, no predict
#
# Author: Dopita, 2026-05-02

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VAULT="$HOME/Documents/OneFlow-Vault"
DASH_DIR="$VAULT/00-Claude-Dashboard"
# FDA-safe target — launchd nemá Full Disk Access do ~/Documents
# Symlink existuje: $DASH_DIR/Ecosystem-Status.md -> $DASH_PHYSICAL
DASH_PHYSICAL="$HOME/.claude/logs/ecosystem-status.md"
DASH="$DASH_PHYSICAL"

mkdir -p "$(dirname "$DASH_PHYSICAL")"
# Idempotentní symlink z Vault na fyzický soubor
if [ -d "$DASH_DIR" ] && [ ! -L "$DASH_DIR/Ecosystem-Status.md" ]; then
  if [ -f "$DASH_DIR/Ecosystem-Status.md" ]; then
    cp "$DASH_DIR/Ecosystem-Status.md" "$DASH_PHYSICAL" 2>/dev/null || true
    rm "$DASH_DIR/Ecosystem-Status.md" 2>/dev/null || true
  fi
  ln -sf "$DASH_PHYSICAL" "$DASH_DIR/Ecosystem-Status.md" 2>/dev/null || true
fi

# Latest resource snapshot
RES_LATEST=""
if [ -f "$HOME/.claude/logs/resource-monitor.jsonl" ]; then
  RES_LATEST=$(tail -1 "$HOME/.claude/logs/resource-monitor.jsonl" 2>/dev/null)
fi

# Latest usage snapshot
USE_LATEST=""
if [ -f "$HOME/.claude/logs/usage-daily.jsonl" ]; then
  USE_LATEST=$(tail -1 "$HOME/.claude/logs/usage-daily.jsonl" 2>/dev/null)
fi

# Recent ofs ops (last 10)
OFS_RECENT=""
if [ -f "$HOME/.claude/logs/ofs.jsonl" ]; then
  OFS_RECENT=$(tail -10 "$HOME/.claude/logs/ofs.jsonl" 2>/dev/null)
fi

# Recent handoffs (last 5)
HANDOFFS_LIST=""
if [ -d "$ROOT/handoffs" ]; then
  HANDOFFS_LIST=$(ls -1t "$ROOT/handoffs/"*.md 2>/dev/null | head -5)
fi

# Render dashboard
{
cat <<EOF
---
title: Ecosystem Status (auto-generated)
tags: [ekosystem, dashboard, monitoring, auto]
updated: $(date '+%Y-%m-%d %H:%M:%S %Z')
---

# 🧩 OneFlow Ecosystem Status

> Auto-generated každých 15 min ze \`resource-monitor.jsonl\` + \`usage-daily.jsonl\` + \`ofs.jsonl\`.
> Master blueprint: [project_ecosystem_master_blueprint_2026_05_02.md](../09-Agent-Memory/project_ecosystem_master_blueprint_2026_05_02.md)
> Dispatcher CLI: \`ofs <command>\` (Mac terminal)

## 🖥 Live snapshot

EOF

if [ -n "$RES_LATEST" ]; then
  # Python script uses single quotes throughout (no escape conflicts in f-strings)
  RES_LATEST="$RES_LATEST" python3 -c "
import json, os
d = json.loads(os.environ['RES_LATEST'])
m = d['mac']; v = d['vps']; c = d['conductor']
print('### Mac (notebook, 8GB RAM)')
print(f\"- **Load:** {m['load1']} (1min) / {m['load5']} (5min)\")
print(f\"- **Swap:** {m['swap_pct']}% ({m['swap_used_mb']} / {m['swap_total_mb']} MB)\")
press = m['pressure_level']
press_label = 'OK' if press > 60 else ('WARN' if press > 30 else 'CRITICAL')
print(f'- **Memory pressure:** {press} ({press_label})')
top_ram = m['top_ram']
print(f'- **Top RAM:** \`{top_ram}\`')
stressed = 'YES' if m['stressed'] else 'no'
print(f'- **Stressed:** {stressed}')
print()
print('### VPS Flash (Contabo, 12GB RAM)')
state = v['state']
state_label = {'wg': 'UP via WG tunel', 'public': 'UP public-only (WG down)', 'down': 'DOWN'}.get(state, state)
print(f'- **State:** {state_label}')
if state != 'down':
    print(f\"- **Load:** {v['load']}\")
    print(f\"- **RAM:** {v['ram_used']} / {v['ram_total']} MB\")
    print(f\"- **Disk:** {v['disk_pct']}%\")
print()
print('### Conductor queue (VPS daemon)')
print(f\"- **Inbox:** {c['inbox']} pending\")
print(f\"- **Active:** {c['active']} running\")
print()
print('### Auto-route hint')
hint = d['route_hint']
hint_label = {'mac': 'Mac OK pro nove ukoly', 'vps': 'Delegate na VPS (Mac stressed)', 'wait_or_mac_only': 'Mac stressed + VPS down -> quit apps, retry pozdeji'}.get(hint, hint)
print(f'**{hint_label}**')
"
else
  echo "_No resource snapshot yet (cron has not run). Run \`/Users/filipdopita/Desktop/Codex/ai-control-plane/scripts/resource-monitor.sh\` manually._"
fi

cat <<EOF

## 📊 Usage last 24h

EOF

if [ -n "$USE_LATEST" ]; then
  USE_LATEST="$USE_LATEST" python3 -c "
import json, os
d = json.loads(os.environ['USE_LATEST'])
print(f\"- **Claude Code:** {d['claude']['tool_calls']} tool calls (~{d['claude']['token_estimate']} tokens)\")
print(f\"- **Codex CLI:** {d['codex']['sessions']} sessions (~{d['codex']['token_estimate']} tokens)\")
print(f\"- **Handoffs:** {d['handoffs']} (Mac dispatch via ofs)\")
print(f\"- **Conductor:** {d['conductor_done']} tasks done (VPS queue)\")
print()
print('Cost: **\$0 raw API** (Anthropic Max + OpenAI Plus flat rates)')
print('Monthly stack: **~\$230** (Anthropic \$200 + OpenAI \$20 + Contabo Flash \$9.62)')
"
else
  echo "_Usage tracker hasn't run yet today. Will run at 09:00 daily._"
fi

cat <<EOF

## 🔄 Recent dispatches (\`ofs\` audit trail)

EOF

if [ -n "$OFS_RECENT" ]; then
  echo '```'
  echo "$OFS_RECENT" | python3 -c 'import json,sys
for line in sys.stdin:
    try:
        d = json.loads(line)
        print(f"{d[\"ts\"]}  {d[\"action\"]:10s}  {d[\"status\"]:8s}  {d[\"detail\"][:60]}")
    except: pass' 2>/dev/null
  echo '```'
else
  echo "_No ofs activity yet._"
fi

cat <<EOF

## 📁 Recent handoffs (audit trail)

EOF

if [ -n "$HANDOFFS_LIST" ]; then
  echo "$HANDOFFS_LIST" | while read -r f; do
    fname="$(basename "$f")"
    mtime="$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f" 2>/dev/null)"
    echo "- \`$mtime\` — \`$fname\`"
  done
else
  echo "_No handoffs yet._"
fi

cat <<EOF

## 🛠 Quick actions

\`\`\`bash
ofs status           # full ecosystem snapshot
ofs mac              # Mac RAM/CPU/swap detail
ofs vps              # VPS Flash status (when up)
ofs route "task"     # intelligent routing (codex/claude/local)
ofs delegate "task"  # Codex implementation
ofs handoffs         # recent handoffs
ofs logs             # ofs audit log
\`\`\`

## 🔗 Architektura (visual)

\`\`\`
Filip ──┬──> Mac (Claude Code v VS Code, 8GB RAM)
        ├──> Telefon (Telegram dispatch — Wave 2)
        └──> Browser (Obsidian dashboard)
                            │
                ai-control-plane router
                /Codex/ai-control-plane/
                            │
              ┌─────────────┴─────────────┐
        Codex CLI                  Claude CLI
        (implementation)           (review/strategy)
                            │
                    Mutagen (WG)
                            │
                    VPS Flash (12GB, 24/7)
                    ├ Conductor (queue)
                    ├ Hermes (multi-platform gateway)
                    ├ Paseo (agent UI)
                    └ Caddy + services
\`\`\`

## 📚 Knowledge graph

- [Project_master_blueprint](../09-Agent-Memory/project_ecosystem_master_blueprint_2026_05_02.md)
- [Core mantras](../09-Agent-Memory/feedback_ecosystem_core_mantras_2026_05_02.md)
- [Cloud orchestrator](../09-Agent-Memory/project_cloud_orchestrator_2026_04_28.md)
- [Hermes Agent](../09-Agent-Memory/project_hermes_agent_2026_04_30.md)
- [Conductor](../09-Agent-Memory/project_conductor.md)
- [Paseo](../09-Agent-Memory/project_paseo.md)
- [VPS Flash infra](../09-Agent-Memory/infra_vps.md)
- [Sync architecture](../09-Agent-Memory/reference_sync_architecture.md)
- [VPS-first rules](../09-Agent-Memory/feedback_vps_first.md)

---
*Auto-generated by \`obsidian-dashboard.sh\` ($(date -u '+%Y-%m-%dT%H:%M:%SZ'))*
EOF
} > "$DASH"

if [ -t 1 ]; then
  echo "Dashboard updated: $DASH"
fi
