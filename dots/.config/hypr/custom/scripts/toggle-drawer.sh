#!/usr/bin/env bash
set -u

drawer_visible() {
    hyprctl layers -j 2>/dev/null | jq -e '.. | objects | select(.namespace? == "nwg-drawer")' >/dev/null
}

wait_for_drawer_state() {
    local want="$1"
    local i

    for ((i = 0; i < 20; i++)); do
        if drawer_visible; then
            [ "$want" = "visible" ] && return 0
        else
            [ "$want" = "hidden" ] && return 0
        fi
        sleep 0.1
    done

    return 1
}

if drawer_visible; then
    nwg-drawer -close
    wait_for_drawer_state hidden || true
else
    nwg-drawer -open
    wait_for_drawer_state visible || true
fi
