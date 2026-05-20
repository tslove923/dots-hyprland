#!/usr/bin/env bash
# apply-custom.sh — Interactive TUI to generate custom Hyprland Lua configs
# Generates: ~/.config/hypr/custom/{keybinds,env,execs}.lua
# Patches:   ~/.config/illogical-impulse/config.json
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HYPR_CUSTOM="$HOME/.config/hypr/custom"
QS_CONFIG="$HOME/.config/illogical-impulse/config.json"
SCRIPTS_SRC="$SCRIPT_DIR/dots/.config/hypr/custom/scripts"
SCRIPTS_DST="$HYPR_CUSTOM/scripts"

# ─── Helpers ──────────────────────────────────────────────────────────────────

die() { echo "ERROR: $*" >&2; exit 1; }

check_deps() {
    command -v dialog >/dev/null || die "dialog is required: sudo pacman -S dialog"
    command -v python3 >/dev/null || die "python3 is required"
    [[ -d "$HYPR_CUSTOM" ]] || die "$HYPR_CUSTOM does not exist. Run the upstream installer first."
}

# Patch a JSON file using python3 (jq alternative without extra deps)
json_set() {
    local file="$1" key="$2" value="$3"
    python3 -c "
import json, sys
path = '$file'
with open(path) as f:
    d = json.load(f)
keys = '$key'.split('.')
obj = d
for k in keys[:-1]:
    obj = obj.setdefault(k, {})
obj[keys[-1]] = json.loads('$value')
with open(path, 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')
"
}

backup_file() {
    local f="$1"
    if [[ -f "$f" ]]; then
        cp "$f" "${f}.bak.$(date +%s)"
    fi
}

# ─── Feature Definitions ─────────────────────────────────────────────────────

# Keybind features: tag, description, lua_code
declare -a KB_TAGS KB_DESCS KB_CODE

KB_TAGS+=("docker_toggle")
KB_DESCS+=("Super+Alt+D: Toggle Docker on/off")
KB_CODE+=('hl.bind("SUPER + ALT + D", hl.dsp.exec_cmd(SCRIPTS .. "/toggle_docker.sh"), { description = "Toggle Docker on/off" })')

KB_TAGS+=("nova_type")
KB_DESCS+=("Super+A: Nova type command")
KB_CODE+=('hl.bind("SUPER + A", hl.dsp.exec_cmd(HOME .. "/projects/nova-npu/.venv/bin/nova --type-command"), { description = "Nova type command" })')

KB_TAGS+=("nova_voice")
KB_DESCS+=("Super+Z: Nova voice typing")
KB_CODE+=('hl.bind("SUPER + Z", hl.dsp.exec_cmd(HOME .. "/projects/nova-npu/.venv/bin/nova --trigger-record"), { description = "Nova voice typing" })')

KB_TAGS+=("nova_wake_toggle")
KB_DESCS+=("Super+Alt+A: Toggle Nova wake word")
KB_CODE+=('hl.bind("SUPER + ALT + A", hl.dsp.exec_cmd(SCRIPTS .. "/nova_toggle.sh wake"), { description = "Toggle wake word" })')

KB_TAGS+=("nova_tts_toggle")
KB_DESCS+=("Super+Alt+Z: Toggle Nova TTS")
KB_CODE+=('hl.bind("SUPER + ALT + Z", hl.dsp.exec_cmd(SCRIPTS .. "/nova_toggle.sh tts"), { description = "Toggle TTS" })')

KB_TAGS+=("bluetui")
KB_DESCS+=("Super+Alt+B: Bluetooth TUI")
KB_CODE+=('hl.bind("SUPER + ALT + B", hl.dsp.exec_cmd("kitty bluetui"), { description = "Bluetooth TUI" })')

KB_TAGS+=("vpn_toggle")
KB_DESCS+=("Super+Alt+V: VPN toggle (needs vpn-indicator)")
KB_CODE+=('hl.bind("SUPER + ALT + V", hl.dsp.exec_cmd(HOME .. "/Documents/vpn-toggle.sh"), { description = "VPN toggle" })')

KB_TAGS+=("move_to_workspace")
KB_DESCS+=("Super+Shift+[0-9]: Move window to workspace")
KB_CODE+=('for i = 1, 9 do
    hl.bind("SUPER + SHIFT + " .. i, hl.dsp.movetoworkspace(i))
end
hl.bind("SUPER + SHIFT + 0", hl.dsp.movetoworkspace(10))')

KB_TAGS+=("workspace_nav")
KB_DESCS+=("Super+Alt+Arrows: Next/prev workspace")
KB_CODE+=('hl.bind("SUPER + ALT + Right", hl.dsp.workspace("+1"), { description = "Next workspace" })
hl.bind("SUPER + ALT + Left", hl.dsp.workspace("-1"), { description = "Previous workspace" })')

# Exec features
declare -a EXEC_TAGS EXEC_DESCS EXEC_CODE

EXEC_TAGS+=("nm_applet")
EXEC_DESCS+=("nm-applet: NetworkManager secret agent (headless)")
EXEC_CODE+=('hl.exec_cmd("env GDK_BACKEND=x11 nm-applet")')

EXEC_TAGS+=("startup_apps")
EXEC_DESCS+=("startup-apps: Launch apps to workspaces on login")
EXEC_CODE+=('hl.exec_cmd(SCRIPTS .. "/startup-apps.sh")')

# Env features
declare -a ENV_TAGS ENV_DESCS ENV_CODE

ENV_TAGS+=("editor_vim")
ENV_DESCS+=("Set EDITOR=vim")
ENV_CODE+=('hl.env("EDITOR", "vim")')

ENV_TAGS+=("xwayland_scaling")
ENV_DESCS+=("Force 1:1 XWayland scaling (HiDPI fix)")
ENV_CODE+=('hl.config({
    xwayland = {
        force_zero_scaling = true,
        use_nearest_neighbor = true,
    },
})')

# config.json patches
declare -a CFG_TAGS CFG_DESCS CFG_KEYS CFG_VALUES

CFG_TAGS+=("us_date_format")
CFG_DESCS+=("US date format (MM/dd) in top bar")
CFG_KEYS+=("time.dateFormat|time.shortDateFormat|time.dateWithYearFormat")
CFG_VALUES+=('"ddd, MM/dd"|"MM/dd"|"MM/dd/yyyy"')

CFG_TAGS+=("copilot_icon")
CFG_DESCS+=("Copilot icon in top-left corner")
CFG_KEYS+=("topLeftIcon")
CFG_VALUES+=('"copilot"')

# ─── TUI ──────────────────────────────────────────────────────────────────────

show_checklist() {
    local title="$1" prompt="$2"
    shift 2
    # args: tag description on/off ...
    dialog --stdout --title "$title" --checklist "$prompt" 0 0 0 "$@"
}

run_tui() {
    local selected

    # ── Keybinds ──
    local kb_args=()
    for i in "${!KB_TAGS[@]}"; do
        kb_args+=("${KB_TAGS[$i]}" "${KB_DESCS[$i]}" "on")
    done
    selected=$(show_checklist "Custom Keybinds" "Select keybinds to enable:" "${kb_args[@]}") || true
    IFS=' ' read -ra SELECTED_KB <<< "$selected"

    # ── Execs ──
    local exec_args=()
    for i in "${!EXEC_TAGS[@]}"; do
        exec_args+=("${EXEC_TAGS[$i]}" "${EXEC_DESCS[$i]}" "on")
    done
    selected=$(show_checklist "Startup Execs" "Select exec-once commands:" "${exec_args[@]}") || true
    IFS=' ' read -ra SELECTED_EXEC <<< "$selected"

    # ── Env ──
    local env_args=()
    for i in "${!ENV_TAGS[@]}"; do
        env_args+=("${ENV_TAGS[$i]}" "${ENV_DESCS[$i]}" "on")
    done
    selected=$(show_checklist "Environment" "Select environment settings:" "${env_args[@]}") || true
    IFS=' ' read -ra SELECTED_ENV <<< "$selected"

    # ── config.json ──
    local cfg_args=()
    for i in "${!CFG_TAGS[@]}"; do
        cfg_args+=("${CFG_TAGS[$i]}" "${CFG_DESCS[$i]}" "on")
    done
    selected=$(show_checklist "QuickShell Config" "Select config.json patches:" "${cfg_args[@]}") || true
    IFS=' ' read -ra SELECTED_CFG <<< "$selected"
}

# ─── Generators ───────────────────────────────────────────────────────────────

generate_keybinds_lua() {
    local out="$HYPR_CUSTOM/keybinds.lua"
    backup_file "$out"
    {
        echo "-- Generated by apply-custom.sh on $(date -I)"
        echo "-- Re-run the script to regenerate"
        echo ""
        echo 'local SCRIPTS = HOME .. "/.config/hypr/custom/scripts"'
        echo ""
        for tag in "${SELECTED_KB[@]}"; do
            for i in "${!KB_TAGS[@]}"; do
                if [[ "${KB_TAGS[$i]}" == "$tag" ]]; then
                    echo "-- ${KB_DESCS[$i]}"
                    echo "${KB_CODE[$i]}"
                    echo ""
                fi
            done
        done
    } > "$out"
    echo "  ✓ $out"
}

generate_execs_lua() {
    local out="$HYPR_CUSTOM/execs.lua"
    backup_file "$out"
    {
        echo "-- Generated by apply-custom.sh on $(date -I)"
        echo "-- Re-run the script to regenerate"
        echo ""
        echo 'local SCRIPTS = HOME .. "/.config/hypr/custom/scripts"'
        echo ""
        echo 'hl.on("hyprland.start", function()'
        for tag in "${SELECTED_EXEC[@]}"; do
            for i in "${!EXEC_TAGS[@]}"; do
                if [[ "${EXEC_TAGS[$i]}" == "$tag" ]]; then
                    echo "    -- ${EXEC_DESCS[$i]}"
                    echo "    ${EXEC_CODE[$i]}"
                fi
            done
        done
        echo "end)"
    } > "$out"
    echo "  ✓ $out"
}

generate_env_lua() {
    local out="$HYPR_CUSTOM/env.lua"
    backup_file "$out"
    {
        echo "-- Generated by apply-custom.sh on $(date -I)"
        echo "-- Re-run the script to regenerate"
        echo ""
        for tag in "${SELECTED_ENV[@]}"; do
            for i in "${!ENV_TAGS[@]}"; do
                if [[ "${ENV_TAGS[$i]}" == "$tag" ]]; then
                    echo "-- ${ENV_DESCS[$i]}"
                    echo "${ENV_CODE[$i]}"
                    echo ""
                fi
            done
        done
    } > "$out"
    echo "  ✓ $out"
}

patch_config_json() {
    if [[ ${#SELECTED_CFG[@]} -eq 0 ]]; then
        return
    fi
    if [[ ! -f "$QS_CONFIG" ]]; then
        echo "  ⚠ $QS_CONFIG not found, skipping config.json patches"
        return
    fi
    backup_file "$QS_CONFIG"
    for tag in "${SELECTED_CFG[@]}"; do
        for i in "${!CFG_TAGS[@]}"; do
            if [[ "${CFG_TAGS[$i]}" == "$tag" ]]; then
                IFS='|' read -ra keys <<< "${CFG_KEYS[$i]}"
                IFS='|' read -ra vals <<< "${CFG_VALUES[$i]}"
                for j in "${!keys[@]}"; do
                    json_set "$QS_CONFIG" "${keys[$j]}" "${vals[$j]}"
                done
            fi
        done
    done
    echo "  ✓ $QS_CONFIG patched"
}

sync_scripts() {
    mkdir -p "$SCRIPTS_DST"
    # Only copy scripts needed by selected features
    local needed=()
    for tag in "${SELECTED_KB[@]}"; do
        case "$tag" in
            docker_toggle) needed+=(toggle_docker.sh) ;;
            nova_wake_toggle|nova_tts_toggle) needed+=(nova_toggle.sh) ;;
            startup_apps) needed+=(startup-apps.sh) ;;
        esac
    done
    for tag in "${SELECTED_EXEC[@]}"; do
        case "$tag" in
            startup_apps) needed+=(startup-apps.sh) ;;
        esac
    done

    # De-duplicate
    local -A seen
    for s in "${needed[@]}"; do
        if [[ -z "${seen[$s]:-}" && -f "$SCRIPTS_SRC/$s" ]]; then
            cp "$SCRIPTS_SRC/$s" "$SCRIPTS_DST/$s"
            chmod +x "$SCRIPTS_DST/$s"
            seen[$s]=1
        fi
    done
    if [[ ${#seen[@]} -gt 0 ]]; then
        echo "  ✓ Synced ${#seen[@]} script(s) to $SCRIPTS_DST"
    fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
    check_deps

    echo "┌─────────────────────────────────────────┐"
    echo "│  dots-hyprland — Custom Config Generator │"
    echo "└─────────────────────────────────────────┘"
    echo ""

    run_tui

    clear
    echo ""
    echo "Generating configs..."
    echo ""

    if [[ ${#SELECTED_KB[@]} -gt 0 ]]; then
        generate_keybinds_lua
    fi
    if [[ ${#SELECTED_EXEC[@]} -gt 0 ]]; then
        generate_execs_lua
    fi
    if [[ ${#SELECTED_ENV[@]} -gt 0 ]]; then
        generate_env_lua
    fi

    sync_scripts
    patch_config_json

    echo ""
    echo "Done! Reload Hyprland to apply:"
    echo "  hyprctl reload"
    echo ""
}

main "$@"
