#!/usr/bin/env bash
# vpn_toggle.sh — Portable wrapper that dispatches to an available VPN toggle script.
set -euo pipefail

candidates=(
  "$HOME/.config/illogical-impulse/scripts/vpn-toggle.sh"
  "$HOME/Documents/vpn-toggle.sh"
)

for script in "${candidates[@]}"; do
  if [[ -x "$script" ]]; then
    exec "$script" "$@"
  fi
  if [[ -f "$script" ]]; then
    chmod +x "$script" 2>/dev/null || true
    exec "$script" "$@"
  fi
done

msg="No VPN toggle script found. Checked: ${candidates[*]}"
if command -v notify-send >/dev/null 2>&1; then
  notify-send -a "VPN" -u normal "$msg"
fi

echo "$msg" >&2
exit 1
