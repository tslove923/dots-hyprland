#!/usr/bin/env bash
# Toggle Docker daemon on/off
# Requires: docker.socket enabled, user in docker group
# Uses pkexec (polkit GUI prompt) instead of sudo for stop operations
# Usage: toggle_docker.sh

STATUS=$(systemctl is-active docker)

if [ "$STATUS" = "active" ]; then
    # Stop all running containers, then stop Docker
    running=$(docker ps -q 2>/dev/null)
    if [ -n "$running" ]; then
        notify-send -a "Docker" "Stopping containers..." -i docker -u low
        docker stop $running >/dev/null 2>&1
    fi
    # pkexec shows a GUI auth dialog (polkit) — works without a terminal
    pkexec systemctl stop docker docker.socket containerd
    if [ $? -eq 0 ]; then
        notify-send -a "Docker" "Docker stopped 🔴" -i docker
    else
        notify-send -a "Docker" "Failed to stop Docker" -i docker -u critical
    fi
else
    # docker.socket is enabled, so just pinging docker triggers auto-start
    docker info >/dev/null 2>&1
    if systemctl is-active --quiet docker; then
        notify-send -a "Docker" "Docker started 🟢" -i docker
    else
        # Fallback: use pkexec if socket activation didn't work
        pkexec systemctl start docker
        if [ $? -eq 0 ]; then
            notify-send -a "Docker" "Docker started 🟢" -i docker
        else
            notify-send -a "Docker" "Failed to start Docker" -i docker -u critical
        fi
    fi
fi
