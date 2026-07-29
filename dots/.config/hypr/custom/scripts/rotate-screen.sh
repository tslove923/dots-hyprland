#!/bin/bash
# File to store rotation toggle state (0 = off, 1 = on)
TOGGLE_FILE="$HOME/.config/hypr/rotation-toggle"

# Ensure toggle file exists, default to enabled (1)
[ -f "$TOGGLE_FILE" ] || echo "1" > "$TOGGLE_FILE"

# Monitor sensor and adjust screen based on orientation
monitor-sensor | while read -r line; do
    # Check if rotation is enabled
    if [ "$(cat "$TOGGLE_FILE")" -eq 1 ]; then
        if [[ $line == *"orientation changed: normal"* ]]; then
            # Kill keyboard before rotation to prevent crash
            pkill -9 wvkbd-deskintl 2>/dev/null
            sleep 0.2
            hyprctl keyword monitor "eDP-1,1920x1080@60,0x0,1,transform,0"
            hyprctl keyword input:touchdevice:transform 0
            hyprctl keyword input:tablet:transform 0
            sleep 0.1
            wvkbd-deskintl &>/dev/null &
            sleep 0.3
            kill -34 $(pgrep wvkbd-deskintl) 2>/dev/null
        elif [[ $line == *"orientation changed: right-up"* ]]; then
            pkill -9 wvkbd-deskintl 2>/dev/null
            sleep 0.2
            hyprctl keyword monitor "eDP-1,1920x1080@60,0x0,1,transform,3"
            hyprctl keyword input:touchdevice:transform 3
            hyprctl keyword input:tablet:transform 3
            sleep 0.1
            wvkbd-deskintl &>/dev/null &
            sleep 0.3
            kill -34 $(pgrep wvkbd-deskintl) 2>/dev/null
        elif [[ $line == *"orientation changed: left-up"* ]]; then
            pkill -9 wvkbd-deskintl 2>/dev/null
            sleep 0.2
            hyprctl keyword monitor "eDP-1,1920x1080@60,0x0,1,transform,1"
            hyprctl keyword input:touchdevice:transform 1
            hyprctl keyword input:tablet:transform 1
            sleep 0.1
            wvkbd-deskintl &>/dev/null &
            sleep 0.3
            kill -34 $(pgrep wvkbd-deskintl) 2>/dev/null
        elif [[ $line == *"orientation changed: bottom-up"* ]]; then
            pkill -9 wvkbd-deskintl 2>/dev/null
            sleep 0.2
            hyprctl keyword monitor "eDP-1,1920x1080@60,0x0,1,transform,2"
            hyprctl keyword input:touchdevice:transform 2
            hyprctl keyword input:tablet:transform 2
            sleep 0.1
            wvkbd-deskintl &>/dev/null &
            sleep 0.3
            kill -34 $(pgrep wvkbd-deskintl) 2>/dev/null
        fi
    fi
done
