#!/usr/bin/env bash
# nova_toggle.sh — Toggle Nova features via REST API
# Usage: nova_toggle.sh [tts|wake]
# Sends a toggle request to the local Nova API and shows a notification
set -euo pipefail

readonly TOKEN_FILE="$HOME/.config/nova/api_token"
readonly API="http://127.0.0.1:9876/api/v1"
readonly APP_NAME="Nova"
readonly ICON="nova-npu"

die() {
    notify-send -h string:suppress-sound:true -a "$APP_NAME" "$1" -i "$ICON" -u critical
    exit 1
}

feature="${1:-}"
case "$feature" in
    tts)
        endpoint="toggle_tts"
        field="tts_enabled"
        on_msg="TTS ON 🔊"
        off_msg="TTS OFF 🔇"
        ;;
    wake)
        endpoint="toggle_wake"
        field="wake_enabled"
        on_msg="Wake word ON 🟢"
        off_msg="Wake word OFF 🔴"
        ;;
    *)
        echo "Usage: ${0##*/} [tts|wake]" >&2
        exit 1
        ;;
esac

[[ -f "$TOKEN_FILE" ]] || die "Nova is not running"
TOKEN=$(<"$TOKEN_FILE")

RESPONSE=$(curl -sf -X POST "$API/$endpoint" \
    -H "Authorization: Bearer $TOKEN") || die "Nova is not running"

# Parse the enabled field from JSON response
if [[ "$RESPONSE" =~ \"$field\":[[:space:]]*(true|false) ]]; then
    [[ "${BASH_REMATCH[1]}" == "true" ]] && msg="$on_msg" || msg="$off_msg"
else
    msg="Toggled $feature (unknown state)"
fi

notify-send -h string:suppress-sound:true -a "$APP_NAME" "$msg" -i "$ICON"
