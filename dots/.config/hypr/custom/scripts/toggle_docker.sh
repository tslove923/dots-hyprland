#!/usr/bin/env bash
# Toggle Docker daemon on/off
# Requires: docker.socket enabled (for on-demand start)
# Usage: toggle_docker.sh

STATUS=$(systemctl is-active docker)

if [ "$STATUS" = "active" ]; then
    # Stop all running containers, then stop Docker
    running=$(docker ps -q 2>/dev/null)
    if [ -n "$running" ]; then
        notify-send -a "Docker" "Stopping containers..." -i docker -u low
        docker stop $running >/dev/null 2>&1
    fi
    sudo systemctl stop docker docker.socket containerd
    notify-send -a "Docker" "Docker stopped 🔴" -i docker
else
    sudo systemctl start docker
    notify-send -a "Docker" "Docker started 🟢" -i docker
fi
