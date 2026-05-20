#!/usr/bin/env bash
# toggle_docker.sh — Start or stop the Docker daemon
# Uses socket activation for start, pkexec (polkit GUI) for stop
# Requires: docker.socket enabled, user in docker group
set -uo pipefail

readonly APP_NAME="Docker"
readonly ICON="docker"

notify() {
    local urgency="${2:-normal}"
    notify-send -h string:suppress-sound:true -a "$APP_NAME" "$1" -i "$ICON" -u "$urgency"
}

if systemctl is-active --quiet docker; then
    # Stop running containers first
    running=$(docker ps -q 2>/dev/null)
    if [[ -n "$running" ]]; then
        notify "Stopping containers..." low
        docker stop $running >/dev/null 2>&1
    fi
    if pkexec systemctl stop docker docker.socket containerd; then
        notify "Docker stopped 🔴"
    else
        notify "Failed to stop Docker" critical
    fi
else
    # Socket activation: pinging docker triggers auto-start
    if docker info >/dev/null 2>&1 && systemctl is-active --quiet docker; then
        notify "Docker started 🟢"
    elif pkexec systemctl start docker; then
        notify "Docker started 🟢"
    else
        notify "Failed to start Docker" critical
    fi
fi
