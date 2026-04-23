#!/usr/bin/env bash
# Only suspend if caffeine mode is not active.
# Used as the on-timeout command in hypridle.conf.
FLAG="$XDG_RUNTIME_DIR/caffeine_active"

if [[ -f "$FLAG" ]]; then
    exit 0
fi
systemctl suspend || loginctl suspend
