#!/usr/bin/env bash
set -euo pipefail

PROFILE=""
TARGET="$HOME/.config/hypr/hypridle.conf"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_DEFAULT="$REPO_ROOT/dots/.config/hypr/hypridle.conf"

usage() {
  cat <<'EOF'
Usage:
  scripts/apply_hypridle_profile.sh --profile <profile> [--target <path>]

Profiles:
  default                 Copy repo hypridle.conf as-is
  desktop-no-lock-suspend Disable lock/suspend, keep DPMS sleep after 10 minutes

Examples:
  scripts/apply_hypridle_profile.sh --profile desktop-no-lock-suspend
  scripts/apply_hypridle_profile.sh --profile default
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE="${2:-}"
      shift 2
      ;;
    --target)
      TARGET="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$PROFILE" ]]; then
  echo "Missing required argument: --profile" >&2
  usage
  exit 1
fi

mkdir -p "$(dirname "$TARGET")"

if [[ -f "$TARGET" ]]; then
  cp "$TARGET" "$TARGET.bak.$(date +%Y%m%d-%H%M%S)"
fi

case "$PROFILE" in
  default)
    if [[ ! -f "$REPO_DEFAULT" ]]; then
      echo "Repo default file not found: $REPO_DEFAULT" >&2
      exit 1
    fi
    cp "$REPO_DEFAULT" "$TARGET"
    ;;

  desktop-no-lock-suspend)
    cat > "$TARGET" <<'EOF'
$lock_cmd = hyprctl dispatch 'hl.dsp.global("quickshell:lock")' & pidof qs quickshell hyprlock || hyprlock
# $lock_cmd = pidof hyprlock || hyprlock
$suspend_cmd = systemctl suspend || loginctl suspend

general {
    lock_cmd = true
    before_sleep_cmd = true
    after_sleep_cmd = true
    inhibit_sleep = 0
}

listener {
    timeout = 600 # 10mins
    on-timeout = hyprctl dispatch 'hl.dsp.dpms(false)'
    on-resume = hyprctl dispatch 'hl.dsp.dpms(true)'
}
EOF
    ;;

  *)
    echo "Unknown profile: $PROFILE" >&2
    usage
    exit 1
    ;;
esac

echo "Applied profile '$PROFILE' to $TARGET"
