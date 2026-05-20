#!/usr/bin/env bash
# startup-apps.sh — Launch apps into specific Hyprland workspaces on login
# Zen Browser → ws 1, Teams PWA → ws 2, VS Code → ws 3+
set -uo pipefail

DELAY=1.5  # seconds between launches

log() { echo "[startup-apps] $*"; }

# Wait for Hyprland to be ready
for _ in $(seq 1 10); do
    hyprctl monitors &>/dev/null && break
    sleep 1
done
hyprctl monitors &>/dev/null || { log "ERROR: Hyprland not ready"; exit 1; }

sleep 2  # let desktop settle

# ── Workspace 1: Zen Browser ──
log "Zen Browser → workspace 1"
hyprctl dispatch -- exec "[workspace 1 silent]" zen-browser
sleep "$DELAY"

# ── Workspace 2: Microsoft Teams PWA ──
log "Teams PWA → workspace 2"
hyprctl dispatch -- exec "[workspace 2 silent]" \
    /usr/bin/chromium --profile-directory=Default --app-id=cifhbcnohmdccbgoicgdjpfamggdegmo
sleep "$DELAY"

# ── Workspace 3+: VS Code (spreads restored windows across workspaces) ──
log "VS Code → workspace 3+"
hyprctl dispatch -- exec "[workspace 3 silent]" code
sleep 3

# Move each Code window to sequential workspaces 3..8
CODE_WINDOWS=$(hyprctl clients -j 2>/dev/null | python3 -c "
import json, sys
clients = json.load(sys.stdin)
for c in clients:
    if c.get('class') == 'code-url-handler':
        print(c['address'])
" 2>/dev/null)

ws=3
while IFS= read -r addr; do
    [[ -z "$addr" ]] && continue
    ((ws > 8)) && break
    log "Moving Code window $addr → workspace $ws"
    hyprctl dispatch movetoworkspacesilent "$ws,address:$addr" 2>/dev/null
    ((ws++))
done <<< "$CODE_WINDOWS"

# Return to workspace 1
sleep 0.5
hyprctl dispatch workspace 1
log "Done."
