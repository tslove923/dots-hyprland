#!/usr/bin/env bash
# Toggle suspend inhibition ("caffeine mode")
# When active, hypridle's suspend timeout will be skipped.
FLAG="$XDG_RUNTIME_DIR/caffeine_active"

if [[ -f "$FLAG" ]]; then
    rm "$FLAG"
    notify-send -a "Caffeine" -i caffeine-cup-empty "Caffeine OFF" "Suspend re-enabled"
else
    touch "$FLAG"
    notify-send -a "Caffeine" -i caffeine-cup-full "Caffeine ON" "Suspend inhibited"
fi
