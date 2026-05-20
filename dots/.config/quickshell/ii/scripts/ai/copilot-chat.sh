#!/usr/bin/env bash
# Wrapper for GitHub Copilot CLI chat
# Usage: copilot-chat.sh <model> <prompt>
# Streams response line-by-line to stdout for QML consumption

set -eo pipefail

MODEL="${1:-gpt-4.1}"
PROMPT="${2:-}"

if [[ -z "$PROMPT" ]]; then
    echo "Error: No prompt provided"
    exit 1
fi

exec gh copilot -- -p "$PROMPT" --model "$MODEL" --effort medium 2>/dev/null
