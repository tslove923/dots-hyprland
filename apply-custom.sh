#!/usr/bin/env bash
# apply-custom.sh — Interactive TUI to generate custom Hyprland Lua configs
# Generates: ~/.config/hypr/custom/{keybinds,env,execs}.lua
# Patches:   ~/.config/illogical-impulse/config.json
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HYPR_CUSTOM="$HOME/.config/hypr/custom"
QS_CONFIG="$HOME/.config/illogical-impulse/config.json"
SCRIPTS_SRC="$SCRIPT_DIR/dots/.config/hypr/custom/scripts"
SCRIPTS_DST="$HYPR_CUSTOM/scripts"
BACKUP_DIR="$HOME/.config/hypr/custom/.backups"

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
        mkdir -p "$BACKUP_DIR"
        cp "$f" "$BACKUP_DIR/$(basename "$f").$(date +%s)"
    fi
}

# ─── Feature Definitions ─────────────────────────────────────────────────────

# Keybind features: tag, description, lua_code
declare -a KB_TAGS KB_DESCS KB_CODE

KB_TAGS+=("docker_toggle")
KB_DESCS+=("Super+Alt+D: Toggle Docker on/off")
KB_CODE+=('hl.bind("SUPER + ALT + D", hl.dsp.exec_cmd(SCRIPTS .. "/toggle_docker.sh"), { description = "Toggle Docker on/off" })')

KB_TAGS+=("bluetui")
KB_DESCS+=("Super+Alt+B: Bluetooth TUI")
KB_CODE+=('hl.bind("SUPER + ALT + B", hl.dsp.exec_cmd("kitty bluetui"), { description = "Bluetooth TUI" })')

KB_TAGS+=("vpn_toggle")
KB_DESCS+=("Super+Alt+V: VPN toggle (needs vpn-indicator)")
KB_CODE+=('hl.bind("SUPER + ALT + V", hl.dsp.exec_cmd(HOME .. "/Documents/vpn-toggle.sh"), { description = "VPN toggle" })')

KB_TAGS+=("move_to_workspace")
KB_DESCS+=("Super+Shift+[0-9]: Move window to workspace")
KB_CODE+=('for i = 1, 10 do
    hl.bind("SUPER + SHIFT + " .. (i % 10), hl.dsp.window.move({ workspace = i, follow = false }),
        { description = "Window: Send to workspace " .. i })
end')

KB_TAGS+=("workspace_nav")
KB_DESCS+=("Super+Alt+Arrows: Next/prev workspace")
KB_CODE+=('hl.bind("SUPER + ALT + Right", hl.dsp.focus({ workspace = "r+1" }), { description = "Workspace: Next" })
hl.bind("SUPER + ALT + Left", hl.dsp.focus({ workspace = "r-1" }), { description = "Workspace: Previous" })')

KB_TAGS+=("backup_omarchy_remaps")
KB_DESCS+=("Backup remaps (Omarchy-style workflow): Super+W close, Super+B browser, Super+Alt+C/Ctrl+Super+C code, Ctrl+Super+X text, Super+Alt+I ii idle inhibitor (right-panel synced), Super+Shift+V clipboard history")
KB_CODE+=('hl.bind("SUPER + W", hl.dsp.window.close(), { description = "Window: Close (backup remap)" })
hl.bind("SUPER + B", hl.dsp.exec_cmd(HOME .. "/.config/hypr/hyprland/scripts/launch_first_available.sh \"zen-browser\" \"google-chrome-stable\" \"firefox\" \"brave\" \"chromium\" \"microsoft-edge-stable\" \"opera\" \"librewolf\""), { description = "App: Browser (backup remap)" })
hl.bind("SUPER + ALT + C", hl.dsp.exec_cmd(HOME .. "/.config/hypr/hyprland/scripts/launch_first_available.sh \"code\" \"codium\" \"cursor\" \"zed\" \"zedit\" \"zeditor\" \"kate\" \"gnome-text-editor\" \"emacs\" \"command -v nvim && kitty -1 nvim\" \"command -v micro && kitty -1 micro\""), { description = "App: Code editor (backup remap)" })
hl.bind("CTRL + SUPER + C", hl.dsp.exec_cmd(HOME .. "/.config/hypr/hyprland/scripts/launch_first_available.sh \"code\" \"codium\" \"cursor\" \"zed\" \"zedit\" \"zeditor\" \"kate\" \"gnome-text-editor\" \"emacs\" \"command -v nvim && kitty -1 nvim\" \"command -v micro && kitty -1 micro\""), { description = "App: Code editor (backup remap)" })
hl.bind("CTRL + SUPER + X", hl.dsp.exec_cmd(HOME .. "/.config/hypr/hyprland/scripts/launch_first_available.sh \"kate\" \"gnome-text-editor\" \"emacs\""), { description = "App: Text editor (backup remap)" })
hl.bind("SUPER + ALT + I", hl.dsp.exec_cmd("qs -c $qsConfig ipc call idle toggle"), { description = "Services: Toggle suspend inhibit" })
hl.bind("SUPER + SHIFT + V", hl.dsp.global("quickshell:overviewClipboardToggle"), { description = "Utilities: Clipboard history >> clipboard" })
hl.bind("SUPER + SHIFT + V", hl.dsp.exec_cmd("qs -c $qsConfig ipc call TEST_ALIVE || pkill fuzzel || cliphist list | fuzzel --match-mode fzf --dmenu | cliphist decode | wl-copy"))')

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

# QML feature deployments: tag, description, file list (pipe-separated, relative to dots/.config/quickshell/ii/)
# Files that modify existing upstream files vs new files — all get copied from repo to live
declare -a QML_TAGS QML_DESCS QML_FILES

QML_TAGS+=("vpn_indicator")
QML_DESCS+=("VPN status indicator in bar (click to toggle)")
QML_FILES+=("services/VpnStatus.qml|modules/ii/bar/BarContent.qml")

QML_TAGS+=("homeassistant")
QML_DESCS+=("Home Assistant panel in bar")
QML_FILES+=("services/HomeAssistant.qml|modules/ii/bar/BarContent.qml|modules/ii/bar/home/HomeBar.qml|modules/ii/bar/home/HomePopup.qml|modules/settings/BarConfig.qml|modules/settings/ServicesConfig.qml")

QML_TAGS+=("gpu_npu_monitoring")
QML_DESCS+=("GPU & NPU usage indicators in bar")
QML_FILES+=("services/ResourceUsage.qml|modules/ii/bar/Resources.qml|modules/ii/bar/ResourcesPopup.qml|modules/ii/verticalBar/Resources.qml|modules/ii/overlay/resources/Resources.qml")

QML_TAGS+=("us_clock_worldclocks")
QML_DESCS+=("US date format, work week, world clocks sidebar")
QML_FILES+=("services/DateTime.qml|modules/ii/bar/ClockWidget.qml|modules/ii/sidebarRight/SidebarRightContent.qml|modules/ii/sidebarRight/WorldClocks.qml")

QML_TAGS+=("mpris_fix")
QML_DESCS+=("MPRIS active player priority fix")
QML_FILES+=("services/MprisController.qml|modules/ii/bar/Media.qml|modules/ii/mediaControls/MediaControls.qml")

QML_TAGS+=("copilot_ai")
QML_DESCS+=("GitHub Copilot in AI chat panel")
QML_FILES+=("services/Ai.qml")

QML_TAGS+=("wifi_fix")
QML_DESCS+=("WiFi reconnect after password fix")
QML_FILES+=("services/Network.qml")

# Copilot has extra files from different source paths
QML_COPILOT_EXTRA="dots/quickshell/ii/services/ai/CopilotCliApiStrategy.qml"
QML_COPILOT_AI_OVERLAY="dots/quickshell/ii/services/Ai.qml"
QML_COPILOT_ICON="dots/.config/quickshell/ii/assets/icons/copilot-symbolic.svg"

# Config.qml is shared by multiple features — always deploy if any QML feature is selected
QML_SHARED="modules/common/Config.qml"

# ─── TUI ──────────────────────────────────────────────────────────────────────

show_checklist() {
    local title="$1" prompt="$2"
    shift 2
    # args: tag description on/off ...
    dialog --stdout --title "$title" --checklist "$prompt" 0 0 0 "$@"
}

run_tui() {
    local selected

    # Initialize selection arrays
    SELECTED_KB=()
    SELECTED_EXEC=()
    SELECTED_ENV=()
    SELECTED_CFG=()
    SELECTED_QML=()

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

    # ── QML Features ──
    local qml_args=()
    for i in "${!QML_TAGS[@]}"; do
        qml_args+=("${QML_TAGS[$i]}" "${QML_DESCS[$i]}" "on")
    done
    selected=$(show_checklist "QuickShell Features" "Select QML features to deploy:" "${qml_args[@]}") || true
    IFS=' ' read -ra SELECTED_QML <<< "$selected"
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

deploy_qml() {
    if [[ ${#SELECTED_QML[@]} -eq 0 ]]; then
        return
    fi

    local qs_live="$HOME/.config/quickshell/ii"
    local qs_repo="$SCRIPT_DIR/dots/.config/quickshell/ii"
    local -A deployed
    local count=0

    # Deploy shared Config.qml (modified by multiple features)
    local shared_src="$qs_repo/$QML_SHARED"
    local shared_dst="$qs_live/$QML_SHARED"
    if [[ -f "$shared_src" ]]; then
        backup_file "$shared_dst"
        mkdir -p "$(dirname "$shared_dst")"
        cp "$shared_src" "$shared_dst"
        deployed["$QML_SHARED"]=1
        ((count++))
    fi

    # Deploy per-feature files
    for tag in "${SELECTED_QML[@]}"; do
        for i in "${!QML_TAGS[@]}"; do
            if [[ "${QML_TAGS[$i]}" == "$tag" ]]; then
                IFS='|' read -ra files <<< "${QML_FILES[$i]}"
                for f in "${files[@]}"; do
                    if [[ -n "${deployed[$f]:-}" ]]; then
                        continue  # already copied (shared file)
                    fi
                    local src="$qs_repo/$f"
                    local dst="$qs_live/$f"
                    if [[ -f "$src" ]]; then
                        backup_file "$dst"
                        mkdir -p "$(dirname "$dst")"
                        cp "$src" "$dst"
                        deployed["$f"]=1
                        ((count++))
                    else
                        echo "  ⚠ Missing: $src"
                    fi
                done

                # Handle Copilot extra files
                if [[ "$tag" == "copilot_ai" ]]; then
                    # Use overlay Ai.qml (has Copilot model) instead of base
                    if [[ -f "$SCRIPT_DIR/$QML_COPILOT_AI_OVERLAY" ]]; then
                        cp "$SCRIPT_DIR/$QML_COPILOT_AI_OVERLAY" "$qs_live/services/Ai.qml"
                        ((count++))
                    fi
                    # Deploy CopilotCliApiStrategy
                    if [[ -f "$SCRIPT_DIR/$QML_COPILOT_EXTRA" ]]; then
                        mkdir -p "$qs_live/services/ai"
                        cp "$SCRIPT_DIR/$QML_COPILOT_EXTRA" "$qs_live/services/ai/CopilotCliApiStrategy.qml"
                        ((count++))
                    fi
                    # Deploy icon
                    if [[ -f "$SCRIPT_DIR/$QML_COPILOT_ICON" ]]; then
                        mkdir -p "$qs_live/assets/icons"
                        cp "$SCRIPT_DIR/$QML_COPILOT_ICON" "$qs_live/assets/icons/"
                        ((count++))
                    fi
                fi
            fi
        done
    done

    echo "  ✓ Deployed $count QML file(s) to $qs_live"
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
    deploy_qml

    echo ""
    echo "Done! Reload to apply:"
    echo "  hyprctl reload && qs -c ii &"
    echo ""
}

main "$@"
