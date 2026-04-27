#!/usr/bin/env bash
###############################################################################
# apply-features.sh
#
# Merges selected feature branches from dots-hyprland-dev into a single
# integration branch, then deploys the merged config files to ~/.config.
#
# Designed to run on a FRESH install that has just completed:
#   ./setup install   (from the main branch)
#
# What it does:
#   1. Presents a TUI checklist to select features (or applies all via CLI)
#   2. Creates a temporary integration branch from main
#   3. Sequentially merges selected feature branches (dependency-aware order)
#   4. Auto-resolves known conflicts (READMEs, keybinds, BarContent, Config)
#   5. Backs up your current live config
#   6. Copies the merged dotfiles into ~/.config, ~/.local/share, etc.
#   7. Intelligently merges overlay files (dots/quickshell/) on top
#   8. Optionally installs the AI assistant wake-word service
#   9. Reloads Hyprland
#
# Usage:
#   chmod +x apply-features.sh
#   ./apply-features.sh              # TUI mode (interactive feature picker)
#   ./apply-features.sh --all        # Apply all features (no TUI)
#   ./apply-features.sh --tui        # Force TUI mode
#
# Flags:
#   --tui               Interactive TUI feature picker (default when no --all)
#   --all               Apply all features without prompting
#   --no-ai-assistant   Skip AI assistant (wake word) installation
#   --no-backup         Skip backing up current config
#   --dry-run           Create integration branch but don't deploy to live config
#   --keep-branch       Don't delete the integration branch after deploying
###############################################################################

set -euo pipefail

# ─── Configuration ──────────────────────────────────────────────────────────────

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$HOME/.config-backup-features-${TIMESTAMP}"
INTEGRATION_BRANCH="integration/features-${TIMESTAMP}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RST='\033[0m'

# Flags
INSTALL_AI_ASSISTANT=true
DO_BACKUP=true
DRY_RUN=false
KEEP_BRANCH=false
USE_TUI=auto   # auto = TUI if interactive terminal, else all
APPLY_ALL=false

# ─── Feature catalog (order matters — dependency-aware) ────────────────────────
#
# Each feature has: branch name, short label, description, default on/off,
# and optional dependency (branch that must be included first).
#
# Order rationale:
#   1. Small independent fixes first (clean merges from main)
#   2. Copilot integration (mostly new files)
#   3. custom-configs (base for homeassistant/overview chains)
#   4. us-clock-view-worldclocks (shares base with custom-configs, adds clocks)
#   5. homeassistant-integration (builds on custom-configs ancestry)
#   6. gpu-npu-monitoring (bar indicators for Intel GPU + NPU)
#   7. vpn-indicator (VPN status indicator in bar)

# Parallel arrays (bash 4+ associative arrays are fragile; parallel is simpler)
FEATURE_BRANCHES=(
    "fix/wifi-reconnect-after-password"
    "feature/mpris-active-player-fix-main"
    "feature/copilot-integration"
    "feature/custom-configs"
    "feature/us-clock-view-worldclocks"
    "feature/homeassistant-integration"
    "feature/gpu-npu-monitoring"
    "feature/vpn-indicator"
)
FEATURE_LABELS=(
    "WiFi Reconnect Fix"
    "MPRIS Active Player Fix"
    "Copilot Integration"
    "Custom Configs & Keybinds"
    "US Date & World Clocks"
    "Home Assistant Panel"
    "GPU/NPU Monitoring"
    "VPN Status Indicator"
)
FEATURE_DESCS=(
    "Auto-reconnect WiFi after entering saved password"
    "Fix media controls to target the active player"
    "GitHub Copilot AI panel in sidebar"
    "Custom keybinds, scripts, xwayland, Docker/VPN/proxy toggles"
    "US date format in sidebar + configurable world clocks"
    "Home Assistant smart home panel in bar"
    "Intel GPU + NPU utilization indicators in resource bar"
    "WireGuard/OpenVPN status icon with toggle in bar"
)
FEATURE_DEFAULTS=(
    on on on on on on on on
)
# Dependencies: index of required branch, or -1 for none
FEATURE_DEPS=(
    -1 -1 -1 -1 3 3 -1 -1
)
# Track which features are selected (1=selected, 0=not)
FEATURE_SELECTED=()
for d in "${FEATURE_DEFAULTS[@]}"; do
    [[ "$d" == "on" ]] && FEATURE_SELECTED+=(1) || FEATURE_SELECTED+=(0)
done

# ─── Parse arguments ───────────────────────────────────────────────────────────

for arg in "$@"; do
    case "$arg" in
        --tui)             USE_TUI=yes ;;
        --all)             APPLY_ALL=true; USE_TUI=no ;;
        --no-ai-assistant) INSTALL_AI_ASSISTANT=false ;;
        --no-backup)       DO_BACKUP=false ;;
        --dry-run)         DRY_RUN=true ;;
        --keep-branch)     KEEP_BRANCH=true ;;
        -h|--help)
            sed -n '2,/^###/p' "$0" | head -n -1 | sed 's/^# \?//'
            exit 0
            ;;
        *) echo -e "${RED}Unknown option: $arg${RST}"; exit 1 ;;
    esac
done

# ─── Helper functions ──────────────────────────────────────────────────────────

log()  { echo -e "${GREEN}[✓]${RST} $*"; }
warn() { echo -e "${YELLOW}[!]${RST} $*"; }
err()  { echo -e "${RED}[✗]${RST} $*"; }
info() { echo -e "${CYAN}[i]${RST} $*"; }
step() { echo -e "\n${BOLD}${CYAN}═══ $* ═══${RST}\n"; }

cleanup() {
    local exit_code=$?
    if [[ -n "${ORIGINAL_BRANCH:-}" ]]; then
        info "Restoring original branch: ${ORIGINAL_BRANCH}"
        git -C "$REPO_DIR" checkout "$ORIGINAL_BRANCH" 2>/dev/null || true
    fi
    if [[ "$KEEP_BRANCH" == false && -n "${INTEGRATION_BRANCH:-}" ]]; then
        git -C "$REPO_DIR" branch -D "$INTEGRATION_BRANCH" 2>/dev/null || true
    fi
    if [[ $exit_code -ne 0 ]]; then
        err "Script failed! Your repo has been restored to its original state."
        if [[ -d "$BACKUP_DIR" ]]; then
            info "Backup remains at: $BACKUP_DIR"
        fi
    fi
}
trap cleanup EXIT

# ─── TUI: Feature selection ────────────────────────────────────────────────────

show_tui() {
    local tui_tool=""

    # Detect available TUI backend
    if command -v dialog &>/dev/null; then
        tui_tool="dialog"
    elif command -v whiptail &>/dev/null; then
        tui_tool="whiptail"
    else
        warn "No TUI backend found (dialog or whiptail). Falling back to plain menu."
        tui_tool="plain"
    fi

    local num_features=${#FEATURE_BRANCHES[@]}

    if [[ "$tui_tool" == "dialog" || "$tui_tool" == "whiptail" ]]; then
        # Build checklist arguments
        local -a checklist_args=()
        for (( i=0; i<num_features; i++ )); do
            local state="off"
            [[ "${FEATURE_SELECTED[$i]}" -eq 1 ]] && state="on"
            checklist_args+=("$i" "${FEATURE_LABELS[$i]}  —  ${FEATURE_DESCS[$i]}" "$state")
        done

        # Calculate dialog size
        local rows=$(( num_features + 8 ))
        [[ $rows -gt 24 ]] && rows=24
        local cols=78

        local result
        if [[ "$tui_tool" == "dialog" ]]; then
            result="$(dialog \
                --title " Apply Features " \
                --backtitle "dots-hyprland-dev Feature Installer" \
                --ok-label "Apply" \
                --cancel-label "Cancel" \
                --checklist "\nSelect features to apply (Space to toggle, Enter to confirm):\n" \
                "$rows" "$cols" "$num_features" \
                "${checklist_args[@]}" \
                3>&1 1>&2 2>&3)" || { echo ""; info "Cancelled."; exit 0; }
        else
            result="$(whiptail \
                --title " Apply Features " \
                --checklist "\nSelect features to apply (Space to toggle, Enter to confirm):\n" \
                "$rows" "$cols" "$num_features" \
                "${checklist_args[@]}" \
                3>&1 1>&2 2>&3)" || { echo ""; info "Cancelled."; exit 0; }
        fi

        # Clear screen after dialog
        clear 2>/dev/null || true

        # Parse result — dialog outputs quoted indices: "0" "2" "4"
        # Reset all to 0, then enable selected
        for (( i=0; i<num_features; i++ )); do
            FEATURE_SELECTED[$i]=0
        done
        for idx in $result; do
            # Strip quotes
            idx="${idx//\"/}"
            FEATURE_SELECTED[$idx]=1
        done

    else
        # Plain terminal fallback
        echo ""
        echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════╗${RST}"
        echo -e "${BOLD}${CYAN}║           dots-hyprland-dev Feature Installer            ║${RST}"
        echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════╝${RST}"
        echo ""
        echo -e "Toggle features with their number, ${BOLD}a${RST} = all, ${BOLD}n${RST} = none, ${BOLD}Enter${RST} = confirm:"
        echo ""

        while true; do
            for (( i=0; i<num_features; i++ )); do
                local mark="  "
                [[ "${FEATURE_SELECTED[$i]}" -eq 1 ]] && mark="${GREEN}✓ ${RST}"
                printf "  ${BOLD}%d${RST}) %s%-28s${RST}  %s\n" "$((i+1))" "$mark" "${FEATURE_LABELS[$i]}" "${FEATURE_DESCS[$i]}"
            done
            echo ""
            read -rp "Toggle [1-${num_features}], (a)ll, (n)one, Enter to confirm: " choice
            case "$choice" in
                "")  break ;;
                a|A) for (( i=0; i<num_features; i++ )); do FEATURE_SELECTED[$i]=1; done ;;
                n|N) for (( i=0; i<num_features; i++ )); do FEATURE_SELECTED[$i]=0; done ;;
                [0-9]*)
                    local idx=$((choice - 1))
                    if (( idx >= 0 && idx < num_features )); then
                        [[ "${FEATURE_SELECTED[$idx]}" -eq 1 ]] && FEATURE_SELECTED[$idx]=0 || FEATURE_SELECTED[$idx]=1
                    else
                        echo -e "${RED}Invalid selection${RST}"
                    fi
                    ;;
                *) echo -e "${RED}Invalid input${RST}" ;;
            esac
            # Move cursor up to redraw
            printf "\033[%dA" "$((num_features + 2))"
        done
    fi

    # Enforce dependencies: if a feature is selected, its dependency must be too
    for (( i=0; i<num_features; i++ )); do
        if [[ "${FEATURE_SELECTED[$i]}" -eq 1 && "${FEATURE_DEPS[$i]}" -ne -1 ]]; then
            local dep_idx="${FEATURE_DEPS[$i]}"
            if [[ "${FEATURE_SELECTED[$dep_idx]}" -eq 0 ]]; then
                FEATURE_SELECTED[$dep_idx]=1
                warn "Auto-enabled '${FEATURE_LABELS[$dep_idx]}' (required by '${FEATURE_LABELS[$i]}')"
            fi
        fi
    done

    # Build the filtered SELECTED_BRANCHES array
    SELECTED_BRANCHES=()
    for (( i=0; i<num_features; i++ )); do
        [[ "${FEATURE_SELECTED[$i]}" -eq 1 ]] && SELECTED_BRANCHES+=("${FEATURE_BRANCHES[$i]}")
    done

    if [[ ${#SELECTED_BRANCHES[@]} -eq 0 ]]; then
        info "No features selected. Nothing to do."
        exit 0
    fi

    # Show summary
    echo ""
    info "Selected features (${#SELECTED_BRANCHES[@]}/${num_features}):"
    for (( i=0; i<num_features; i++ )); do
        if [[ "${FEATURE_SELECTED[$i]}" -eq 1 ]]; then
            echo -e "  ${GREEN}✓${RST} ${FEATURE_LABELS[$i]}"
        fi
    done
    echo ""
}

# ─── Determine TUI mode ───────────────────────────────────────────────────────

if [[ "$USE_TUI" == "auto" ]]; then
    if [[ -t 0 && -t 1 ]]; then
        USE_TUI=yes
    else
        USE_TUI=no
        APPLY_ALL=true
    fi
fi

if [[ "$APPLY_ALL" == true ]]; then
    # Select all features
    SELECTED_BRANCHES=("${FEATURE_BRANCHES[@]}")
elif [[ "$USE_TUI" == "yes" ]]; then
    show_tui
else
    SELECTED_BRANCHES=("${FEATURE_BRANCHES[@]}")
fi

# ─── Preflight checks ─────────────────────────────────────────────────────────

step "Preflight checks"

if [[ ! -d "$REPO_DIR/.git" ]]; then
    err "Not a git repository: $REPO_DIR"
    exit 1
fi

cd "$REPO_DIR"

# Save current branch
ORIGINAL_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
info "Current branch: ${ORIGINAL_BRANCH}"

# Check for uncommitted changes
if ! git diff --quiet HEAD 2>/dev/null; then
    warn "You have uncommitted changes. Stashing them..."
    git stash push -m "apply-features auto-stash ${TIMESTAMP}"
    STASHED=true
else
    STASHED=false
fi

# Verify selected feature branches exist locally
for branch in "${SELECTED_BRANCHES[@]}"; do
    if ! git rev-parse --verify "$branch" &>/dev/null; then
        # Try to create from remote
        if git rev-parse --verify "origin/$branch" &>/dev/null; then
            info "Creating local branch from origin/$branch"
            git branch "$branch" "origin/$branch"
        else
            err "Branch not found (local or remote): $branch"
            exit 1
        fi
    fi
done

log "All ${#SELECTED_BRANCHES[@]} selected feature branches verified"

# ─── Step 1: Create integration branch ────────────────────────────────────────

step "Step 1: Create integration branch from main"

git checkout main
git checkout -b "$INTEGRATION_BRANCH"
log "Created branch: $INTEGRATION_BRANCH"

# ─── Step 2: Merge all feature branches ───────────────────────────────────────

step "Step 2: Merge feature branches (${#SELECTED_BRANCHES[@]} selected)"

MERGE_FAILURES=0

for branch in "${SELECTED_BRANCHES[@]}"; do
    echo -e "${CYAN}  Merging: ${BOLD}${branch}${RST}"

    if git merge --no-edit "$branch" 2>/dev/null; then
        log "  Merged cleanly: $branch"
    else
        # Handle known conflicts
        CONFLICT_FILES="$(git diff --name-only --diff-filter=U 2>/dev/null || true)"
        RESOLVED=true

        while IFS= read -r cfile; do
            [[ -z "$cfile" ]] && continue
            case "$cfile" in
                .github/README.md|README.md)
                    # README conflicts: accept the incoming branch version
                    git checkout --theirs "$cfile" 2>/dev/null
                    git add "$cfile"
                    info "  Auto-resolved (accept theirs): $cfile"
                    ;;
                dots/.config/hypr/custom/keybinds.conf)
                    # Custom keybinds: use feature/custom-configs version (most complete)
                    # It has proxy toggle + services + workspace management
                    if git show "feature/custom-configs:$cfile" &>/dev/null; then
                        git show "feature/custom-configs:$cfile" > "$cfile"
                        git add "$cfile"
                        info "  Auto-resolved (custom-configs version): $cfile"
                    else
                        git checkout --theirs "$cfile" 2>/dev/null
                        git add "$cfile"
                        info "  Auto-resolved (accept theirs): $cfile"
                    fi
                    ;;
                dots/.config/hypr/hyprland/keybinds.conf)
                    # Core keybinds: both custom-configs and overview modify
                    # Super+C/V for universal copy/paste and clipboard history.
                    # Accept theirs (overview has overview-specific bindings +
                    # the same universal copy/paste concept).
                    git checkout --theirs "$cfile" 2>/dev/null
                    git add "$cfile"
                    info "  Auto-resolved (accept theirs): $cfile"
                    ;;
                *.md|DEVELOPMENT.md|HOME_ASSISTANT.md|.github/HOME_ASSISTANT.md)
                    # Documentation conflicts: accept theirs
                    git checkout --theirs "$cfile" 2>/dev/null
                    git add "$cfile"
                    info "  Auto-resolved (accept theirs): $cfile"
                    ;;
                .gitignore)
                    # Gitignore: combine both versions
                    if git show :2:"$cfile" &>/dev/null && git show :3:"$cfile" &>/dev/null; then
                        { git show :2:"$cfile"; echo ""; git show :3:"$cfile"; } | sort -u > "$cfile"
                        git add "$cfile"
                        info "  Auto-resolved (combined): $cfile"
                    else
                        git checkout --theirs "$cfile" 2>/dev/null
                        git add "$cfile"
                    fi
                    ;;
                apply-features.sh)
                    # The apply script itself: keep ours (the version driving this merge)
                    git checkout --ours "$cfile" 2>/dev/null
                    git add "$cfile"
                    info "  Auto-resolved (keep ours): $cfile"
                    ;;
                dots/.config/quickshell/ii/modules/ii/bar/BarContent.qml|\
                dots/quickshell/ii/modules/ii/bar/BarContent.qml)
                    # BarContent: multiple branches modify this (HA, GPU, VPN).
                    # 3-way merge using main as ancestor, ours + theirs combined.
                    ancestor="$(mktemp)"
                    ours="$(mktemp)"
                    theirs="$(mktemp)"
                    git show "main:$cfile" > "$ancestor" 2>/dev/null || touch "$ancestor"
                    git show :2:"$cfile" > "$ours" 2>/dev/null || touch "$ours"
                    git show :3:"$cfile" > "$theirs" 2>/dev/null || touch "$theirs"
                    if diff3 -m "$ours" "$ancestor" "$theirs" > "$cfile.merged" 2>/dev/null && ! grep -q '<<<<<<<' "$cfile.merged"; then
                        mv "$cfile.merged" "$cfile"
                        git add "$cfile"
                        info "  Auto-resolved (3-way merge): $cfile"
                    else
                        # Fallback: accept theirs (later branch wins), 
                        # overlay step will reconcile
                        rm -f "$cfile.merged"
                        git checkout --theirs "$cfile" 2>/dev/null
                        git add "$cfile"
                        info "  Auto-resolved (accept theirs, overlay will reconcile): $cfile"
                    fi
                    rm -f "$ancestor" "$ours" "$theirs"
                    ;;
                dots/.config/quickshell/ii/modules/common/Config.qml|\
                dots/.config/quickshell/ii/modules/settings/ServicesConfig.qml|\
                dots/.config/quickshell/ii/modules/settings/BarConfig.qml)
                    # Config/Settings: multiple branches add sections.
                    # 3-way merge using main as ancestor.
                    ancestor="$(mktemp)"
                    ours="$(mktemp)"
                    theirs="$(mktemp)"
                    git show "main:$cfile" > "$ancestor" 2>/dev/null || touch "$ancestor"
                    git show :2:"$cfile" > "$ours" 2>/dev/null || touch "$ours"
                    git show :3:"$cfile" > "$theirs" 2>/dev/null || touch "$theirs"
                    if diff3 -m "$ours" "$ancestor" "$theirs" > "$cfile.merged" 2>/dev/null && ! grep -q '<<<<<<<' "$cfile.merged"; then
                        mv "$cfile.merged" "$cfile"
                        git add "$cfile"
                        info "  Auto-resolved (3-way merge): $cfile"
                    else
                        rm -f "$cfile.merged"
                        git checkout --theirs "$cfile" 2>/dev/null
                        git add "$cfile"
                        info "  Auto-resolved (accept theirs): $cfile"
                    fi
                    rm -f "$ancestor" "$ours" "$theirs"
                    ;;
                dots/.config/hypr/hyprland/general.conf|dots/.config/hypr/hypridle.conf)
                    # Hyprland configs: 3-way merge, fallback to accept ours
                    ancestor="$(mktemp)"
                    ours="$(mktemp)"
                    theirs="$(mktemp)"
                    git show "main:$cfile" > "$ancestor" 2>/dev/null || touch "$ancestor"
                    git show :2:"$cfile" > "$ours" 2>/dev/null || touch "$ours"
                    git show :3:"$cfile" > "$theirs" 2>/dev/null || touch "$theirs"
                    if diff3 -m "$ours" "$ancestor" "$theirs" > "$cfile.merged" 2>/dev/null && ! grep -q '<<<<<<<' "$cfile.merged"; then
                        mv "$cfile.merged" "$cfile"
                        git add "$cfile"
                        info "  Auto-resolved (3-way merge): $cfile"
                    else
                        rm -f "$cfile.merged"
                        git checkout --ours "$cfile" 2>/dev/null
                        git add "$cfile"
                        info "  Auto-resolved (keep ours): $cfile"
                    fi
                    rm -f "$ancestor" "$ours" "$theirs"
                    ;;
                *)
                    err "  UNHANDLED CONFLICT: $cfile"
                    RESOLVED=false
                    ;;
            esac
        done <<< "$CONFLICT_FILES"

        if $RESOLVED; then
            git commit --no-edit -m "Merge $branch (auto-resolved conflicts)"
            log "  Merged with auto-resolved conflicts: $branch"
        else
            err "  Could not auto-resolve all conflicts for: $branch"
            err "  Conflicting files:"
            git diff --name-only --diff-filter=U 2>/dev/null | while read f; do echo "    - $f"; done
            git merge --abort
            MERGE_FAILURES=$((MERGE_FAILURES + 1))
            warn "  Skipped branch: $branch (merge aborted)"
        fi
    fi
done

if [[ $MERGE_FAILURES -gt 0 ]]; then
    warn "$MERGE_FAILURES branch(es) could not be merged. The rest were applied successfully."
else
    log "All branches merged successfully!"
fi

# ─── Step 3: Show summary of changes ──────────────────────────────────────────

step "Step 3: Integration summary"

TOTAL_FILES=$(git diff --stat main..HEAD | tail -1)
info "Changes from main: $TOTAL_FILES"

if $DRY_RUN; then
    info "DRY RUN — integration branch created but not deployed."
    info "Branch: $INTEGRATION_BRANCH"
    info "Inspect with: git log --oneline main..${INTEGRATION_BRANCH}"
    KEEP_BRANCH=true
    exit 0
fi

# ─── Step 4: Backup current live config ───────────────────────────────────────

step "Step 4: Backup current config"

if $DO_BACKUP; then
    mkdir -p "$BACKUP_DIR"

    # Backup directories that will be modified
    BACKUP_TARGETS=(
        "$CONFIG_HOME/quickshell"
        "$CONFIG_HOME/hypr"
        "$CONFIG_HOME/fish"
        "$CONFIG_HOME/foot"
        "$CONFIG_HOME/fuzzel"
        "$CONFIG_HOME/kitty"
        "$CONFIG_HOME/matugen"
        "$CONFIG_HOME/mpv"
        "$CONFIG_HOME/wlogout"
        "$CONFIG_HOME/fontconfig"
        "$CONFIG_HOME/Kvantum"
        "$CONFIG_HOME/xdg-desktop-portal"
        "$CONFIG_HOME/kde-material-you-colors"
    )

    for target in "${BACKUP_TARGETS[@]}"; do
        if [[ -d "$target" ]]; then
            rel="${target#$HOME/}"
            mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
            cp -a "$target" "$BACKUP_DIR/$rel"
        fi
    done

    # Backup individual config files
    for f in "$CONFIG_HOME/starship.toml" \
             "$CONFIG_HOME/chrome-flags.conf" \
             "$CONFIG_HOME/code-flags.conf" \
             "$CONFIG_HOME/thorium-flags.conf" \
             "$CONFIG_HOME/darklyrc" \
             "$CONFIG_HOME/dolphinrc" \
             "$CONFIG_HOME/kdeglobals" \
             "$CONFIG_HOME/konsolerc"; do
        if [[ -f "$f" ]]; then
            rel="${f#$HOME/}"
            mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
            cp -a "$f" "$BACKUP_DIR/$rel"
        fi
    done

    log "Config backed up to: $BACKUP_DIR"
else
    warn "Skipping backup (--no-backup)"
fi

# ─── Step 5: Deploy merged config to live system ─────────────────────────────

step "Step 5: Deploy merged configs"

# ─── Surgical deploy helpers ────────────────────────────────────────────────
# Only touch files whose content actually differs from what's already live.
# No .bak or .new files — either deploy cleanly or 3-way merge.

DEPLOY_NEW=0
DEPLOY_UPDATED=0
DEPLOY_SKIPPED=0
DEPLOY_MERGED=0

# deploy_file SRC DEST — copy only if content differs or dest is new
deploy_file() {
    local src="$1" dest="$2"
    mkdir -p "$(dirname "$dest")"
    if [[ ! -f "$dest" ]]; then
        cp "$src" "$dest"
        DEPLOY_NEW=$((DEPLOY_NEW + 1))
        return 0
    fi
    if ! cmp -s "$src" "$dest"; then
        cp "$src" "$dest"
        DEPLOY_UPDATED=$((DEPLOY_UPDATED + 1))
        return 0
    fi
    DEPLOY_SKIPPED=$((DEPLOY_SKIPPED + 1))
    return 1
}

# deploy_tree SRC_DIR DEST_DIR [EXCLUDE...] — recursively deploy only changed files
deploy_tree() {
    local src_dir="$1" dest_dir="$2"
    shift 2
    local -a excludes=("$@")
    while IFS= read -r src_file; do
        local rel="${src_file#$src_dir/}"
        # Check excludes
        local skip=false
        for excl in "${excludes[@]}"; do
            [[ "$rel" == $excl ]] && skip=true && break
        done
        $skip && continue
        deploy_file "$src_file" "$dest_dir/$rel"
    done < <(find "$src_dir" -type f)
}

# deploy_merge SRC DEST ANCESTOR_REF — 3-way merge preserving user changes
# Uses main's version as common ancestor. If user hasn't changed the file,
# just deploy. If user has changes, attempt to merge both.
deploy_merge() {
    local src="$1" dest="$2" ancestor_ref="$3"
    mkdir -p "$(dirname "$dest")"

    if [[ ! -f "$dest" ]]; then
        cp "$src" "$dest"
        DEPLOY_NEW=$((DEPLOY_NEW + 1))
        return 0
    fi

    # If src and dest are identical, nothing to do
    if cmp -s "$src" "$dest"; then
        DEPLOY_SKIPPED=$((DEPLOY_SKIPPED + 1))
        return 1
    fi

    # Get the common ancestor (main's version of this file)
    local ancestor
    ancestor="$(mktemp)"
    if ! git show "$ancestor_ref" > "$ancestor" 2>/dev/null; then
        # No ancestor available — can't merge, just deploy
        cp "$src" "$dest"
        DEPLOY_UPDATED=$((DEPLOY_UPDATED + 1))
        rm -f "$ancestor"
        return 0
    fi

    # If dest is unchanged from ancestor, user never customized → just deploy
    if cmp -s "$ancestor" "$dest"; then
        cp "$src" "$dest"
        DEPLOY_UPDATED=$((DEPLOY_UPDATED + 1))
        rm -f "$ancestor"
        return 0
    fi

    # Both sides changed — attempt 3-way merge
    # ours=dest (user's live), ancestor=main's base, theirs=src (new from branch)
    local merged
    merged="$(mktemp)"
    if diff3 -m "$dest" "$ancestor" "$src" > "$merged" 2>/dev/null && ! grep -q '<<<<<<<' "$merged"; then
        cp "$merged" "$dest"
        DEPLOY_MERGED=$((DEPLOY_MERGED + 1))
        info "  3-way merged: $(basename "$dest")"
    else
        # Conflict — keep user's version, warn
        warn "  Merge conflict in $(basename "$dest") — user's version kept"
        warn "    Review new version: git show ${INTEGRATION_BRANCH}:$(git ls-files --full-name "$src" 2>/dev/null || echo "$src")"
    fi
    rm -f "$ancestor" "$merged"
}

# ─── 5a. Deploy configs ────────────────────────────────────────────────────────

info "Deploying dots/.config/ → $CONFIG_HOME/ (surgical — only changed files)"

# Quickshell (main UI config — deploy only changed files)
if [[ -d "dots/.config/quickshell" ]]; then
    deploy_tree "dots/.config/quickshell" "$CONFIG_HOME/quickshell"
    log "Deployed: quickshell config"
fi

# Hyprland — hyprland/ subdir (core configs)
# keybinds.conf gets 3-way merge to preserve user customizations
if [[ -d "dots/.config/hypr/hyprland" ]]; then
    # Deploy everything except keybinds.conf normally
    while IFS= read -r src_file; do
        rel="${src_file#dots/.config/hypr/hyprland/}"
        if [[ "$rel" == "keybinds.conf" ]]; then
            deploy_merge "$src_file" "$CONFIG_HOME/hypr/hyprland/keybinds.conf" \
                "main:dots/.config/hypr/hyprland/keybinds.conf"
        else
            deploy_file "$src_file" "$CONFIG_HOME/hypr/hyprland/$rel"
        fi
    done < <(find "dots/.config/hypr/hyprland" -type f)
    log "Deployed: hypr/hyprland/ (keybinds.conf merged)"
fi

# Hyprland — custom configs
# These are user-facing configs — 3-way merge .conf files, deploy scripts normally
if [[ -d "dots/.config/hypr/custom" ]]; then
    # Scripts: deploy only changed
    if [[ -d "dots/.config/hypr/custom/scripts" ]]; then
        deploy_tree "dots/.config/hypr/custom/scripts" "$CONFIG_HOME/hypr/custom/scripts"
    fi
    # Config files: 3-way merge to preserve user edits
    for conf in "dots/.config/hypr/custom/"*.conf; do
        [[ -f "$conf" ]] || continue
        local_name="$(basename "$conf")"
        deploy_merge "$conf" "$CONFIG_HOME/hypr/custom/$local_name" \
            "main:dots/.config/hypr/custom/$local_name"
    done
    log "Deployed: hypr/custom/"
fi

# Hyprland — top-level configs (deploy only if changed)
# monitors.conf is excluded — hardware-specific, set per-machine.
for conf in hyprland.conf hyprlock.conf workspaces.conf hypridle.conf; do
    if [[ -f "dots/.config/hypr/$conf" ]]; then
        deploy_file "dots/.config/hypr/$conf" "$CONFIG_HOME/hypr/$conf"
    fi
done
log "Deployed: hypr top-level configs (monitors.conf preserved)"

# Fish config (exclude conf.d/ to preserve user's fish plugins)
if [[ -d "dots/.config/fish" ]]; then
    deploy_tree "dots/.config/fish" "$CONFIG_HOME/fish" "conf.d/*"
    log "Deployed: fish config (preserved conf.d/)"
fi

# Misc config dirs — deploy only changed files
for dir in foot fuzzel kitty matugen mpv wlogout Kvantum fontconfig \
           xdg-desktop-portal kde-material-you-colors zshrc.d; do
    if [[ -d "dots/.config/$dir" ]]; then
        deploy_tree "dots/.config/$dir" "$CONFIG_HOME/$dir"
        log "Deployed: $dir"
    fi
done

# Misc config files — deploy only if changed
for f in starship.toml chrome-flags.conf code-flags.conf thorium-flags.conf \
         darklyrc dolphinrc kdeglobals konsolerc; do
    if [[ -f "dots/.config/$f" ]]; then
        deploy_file "dots/.config/$f" "$CONFIG_HOME/$f"
    fi
done
log "Deployed: misc config files"

info "Deploy stats: ${DEPLOY_NEW} new, ${DEPLOY_UPDATED} updated, ${DEPLOY_MERGED} merged, ${DEPLOY_SKIPPED} unchanged"

# 5b. Deploy dots/.local/share/ → ~/.local/share/ (only changed)
if [[ -d "dots/.local/share" ]]; then
    deploy_tree "dots/.local/share" "$DATA_HOME"
    log "Deployed: .local/share (icons, konsole theme)"
fi

# 5c. Deploy Copilot/illogical-impulse config
# config.json is MERGED (user's paths and settings are preserved),
# other files deployed only if changed.
if [[ -d "dots/illogical-impulse" ]]; then
    mkdir -p "$CONFIG_HOME/illogical-impulse"
    local_config="$CONFIG_HOME/illogical-impulse/config.json"
    repo_config="dots/illogical-impulse/config.json"

    if [[ -f "$repo_config" ]]; then
        if [[ -f "$local_config" ]]; then
            # Merge: repo provides defaults, user's existing values take priority
            if cmp -s "$repo_config" "$local_config"; then
                DEPLOY_SKIPPED=$((DEPLOY_SKIPPED + 1))
            else
                python3 -c "
import json, sys
with open('$repo_config') as f:
    repo = json.load(f)
with open('$local_config') as f:
    local = json.load(f)

def deep_merge(base, override):
    result = dict(base)
    for k, v in override.items():
        if k in result and isinstance(result[k], dict) and isinstance(v, dict):
            result[k] = deep_merge(result[k], v)
        else:
            result[k] = v
    return result

merged = deep_merge(repo, local)
with open('$local_config', 'w') as f:
    json.dump(merged, f, indent=4)
    f.write('\\n')
" 2>/dev/null && info "  Merged config.json (user settings preserved)" \
              || { cp "$repo_config" "$local_config"; info "  Deployed config.json (merge failed, used repo version)"; }
            fi
        else
            cp "$repo_config" "$local_config"
            info "  Deployed config.json (new)"
        fi
    fi

    # Deploy non-config.json files only if changed
    while IFS= read -r src_file; do
        rel="${src_file#dots/illogical-impulse/}"
        [[ "$rel" == "config.json" ]] && continue
        deploy_file "$src_file" "$CONFIG_HOME/illogical-impulse/$rel"
    done < <(find "dots/illogical-impulse" -type f)
    log "Deployed: illogical-impulse config (Copilot integration)"
fi

# ─── Step 6: Deploy overlay files from dots/quickshell/ ──────────────────────

step "Step 6: Deploy overlay files"

# Overlay files in dots/quickshell/ are per-branch additions that modify
# upstream quickshell files (BarContent.qml, VpnStatus.qml, etc.).
#
# IMPORTANT: After the branch merge in Step 2, dots/.config/quickshell/ already
# contains the combined changes from ALL merged branches. The overlay files in
# dots/quickshell/ come from individual branches and may be STALE — they lack
# changes introduced by other branches (e.g. the HomeBar loader from
# homeassistant-integration is missing from gpu-npu-monitoring's overlay).
#
# Strategy: For each overlay file, compare it against the merged version already
# deployed. If the merged version is a SUPERSET (contains the overlay's unique
# additions plus everything else), skip the overlay. Otherwise, do a 3-way
# merge using main's version as the common ancestor.

if [[ -d "dots/quickshell" ]]; then
    info "Processing overlay files from dots/quickshell/"
    OVERLAY_APPLIED=0
    OVERLAY_SKIPPED=0
    OVERLAY_MERGED=0

    while IFS= read -r overlay_file; do
        # Compute relative path from dots/quickshell/
        rel="${overlay_file#dots/quickshell/}"
        deployed="$CONFIG_HOME/quickshell/$rel"
        merged_src="dots/.config/quickshell/$rel"

        if [[ ! -f "$deployed" ]]; then
            # Target doesn't exist yet — just copy
            mkdir -p "$(dirname "$deployed")"
            cp "$overlay_file" "$deployed"
            log "  Deployed (new): $rel"
            OVERLAY_APPLIED=$((OVERLAY_APPLIED + 1))
            continue
        fi

        if [[ -f "$merged_src" ]]; then
            # Both the merged dots/.config version and overlay exist.
            # The merged version was already deployed in Step 5a and should
            # contain changes from ALL branches. Check if the overlay adds
            # anything the merged version doesn't have.
            overlay_unique="$(diff "$merged_src" "$overlay_file" 2>/dev/null | grep '^>' | wc -l || echo 0)"
            merged_has_overlay="$(diff "$overlay_file" "$deployed" 2>/dev/null | grep '^>' | wc -l || echo 0)"

            if [[ "$overlay_unique" -eq 0 ]]; then
                # Overlay is identical or a subset of the merged version — skip
                info "  Skipped (merged version is superset): $rel"
                OVERLAY_SKIPPED=$((OVERLAY_SKIPPED + 1))
                continue
            fi

            # Overlay has unique lines not in the merged version.
            # Attempt a 3-way merge: main (ancestor) + merged (ours) + overlay (theirs)
            main_version="$(mktemp)"
            git show "main:dots/.config/quickshell/$rel" > "$main_version" 2>/dev/null || cp "$deployed" "$main_version"

            merged_copy="$(mktemp)"
            cp "$deployed" "$merged_copy"

            if diff3 -m "$merged_copy" "$main_version" "$overlay_file" > "${deployed}.merge-tmp" 2>/dev/null; then
                mv "${deployed}.merge-tmp" "$deployed"
                log "  3-way merged: $rel"
                OVERLAY_MERGED=$((OVERLAY_MERGED + 1))
            else
                # 3-way merge had conflicts — check if it's usable
                if grep -q '<<<<<<<' "${deployed}.merge-tmp" 2>/dev/null; then
                    warn "  Merge conflict in overlay: $rel (keeping merged version)"
                    rm -f "${deployed}.merge-tmp"
                    # Save the overlay as .overlay for manual review
                    cp "$overlay_file" "${deployed}.overlay"
                    info "    Overlay saved as: ${deployed}.overlay"
                    OVERLAY_SKIPPED=$((OVERLAY_SKIPPED + 1))
                else
                    mv "${deployed}.merge-tmp" "$deployed"
                    log "  3-way merged (with warnings): $rel"
                    OVERLAY_MERGED=$((OVERLAY_MERGED + 1))
                fi
            fi

            rm -f "$main_version" "$merged_copy"
        else
            # No merged version in dots/.config — just deploy overlay
            mkdir -p "$(dirname "$deployed")"
            cp "$overlay_file" "$deployed"
            log "  Deployed (overlay only): $rel"
            OVERLAY_APPLIED=$((OVERLAY_APPLIED + 1))
        fi
    done < <(find dots/quickshell -type f)

    log "Overlays: ${OVERLAY_APPLIED} deployed, ${OVERLAY_MERGED} merged, ${OVERLAY_SKIPPED} skipped"
fi

# ─── Step 7: Make scripts executable ─────────────────────────────────────────

step "Step 7: Set permissions"

# Hyprland custom scripts
find "$CONFIG_HOME/hypr/custom/scripts/" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
find "$CONFIG_HOME/hypr/hyprland/scripts/" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

log "Scripts made executable"

# ─── Step 8: AI Assistant installation (optional) ────────────────────────────

step "Step 8: AI Assistant setup"

if $INSTALL_AI_ASSISTANT; then
    if [[ -f "ai-assistant/install.sh" ]]; then
        info "Installing AI assistant (wake word detection, event handler)..."
        info "This requires system packages: python python-pip python-pyaudio portaudio"
        echo ""
        read -p "Install AI assistant now? [y/N] " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            bash "ai-assistant/install.sh"
            log "AI assistant installed"
        else
            warn "Skipped AI assistant installation"
            info "Run later with: cd $REPO_DIR && bash ai-assistant/install.sh"
        fi
    else
        warn "ai-assistant/install.sh not found on this branch"
    fi
else
    info "AI assistant installation skipped (--no-ai-assistant)"
fi

# ─── Step 9: Post-install verification ───────────────────────────────────────

step "Step 9: Verification"

MISSING=()

# Check critical files exist
CRITICAL_FILES=(
    "$CONFIG_HOME/quickshell/ii/services/ResourceUsage.qml"
    "$CONFIG_HOME/quickshell/ii/services/HomeAssistant.qml"
    "$CONFIG_HOME/quickshell/ii/services/MprisController.qml"
    "$CONFIG_HOME/quickshell/ii/services/Network.qml"
    "$CONFIG_HOME/quickshell/ii/services/DateTime.qml"
    "$CONFIG_HOME/quickshell/ii/services/Todo.qml"
    "$CONFIG_HOME/quickshell/ii/services/VpnStatus.qml"
    "$CONFIG_HOME/quickshell/ii/services/AIAssistantState.qml"
    "$CONFIG_HOME/quickshell/ii/modules/common/Config.qml"
    "$CONFIG_HOME/quickshell/ii/modules/ii/bar/BarContent.qml"
    "$CONFIG_HOME/quickshell/ii/modules/ii/sidebarRight/WorldClocks.qml"
    "$CONFIG_HOME/quickshell/ii/modules/ii/overview/OverviewWidget.qml"
    "$CONFIG_HOME/quickshell/ii/modules/settings/ServicesConfig.qml"
    "$CONFIG_HOME/hypr/custom/keybinds.conf"
    "$CONFIG_HOME/hypr/custom/scripts/startup-apps.sh"
)

for f in "${CRITICAL_FILES[@]}"; do
    if [[ ! -f "$f" ]]; then
        MISSING+=("$f")
    fi
done

if [[ ${#MISSING[@]} -eq 0 ]]; then
    log "All critical files verified!"
else
    warn "Missing files (${#MISSING[@]}):"
    for f in "${MISSING[@]}"; do
        echo "    - $f"
    done
fi

# Verify feature integrations in BarContent.qml
BAR_FILE="$CONFIG_HOME/quickshell/ii/modules/ii/bar/BarContent.qml"
BAR_ISSUES=()
if [[ -f "$BAR_FILE" ]]; then
    grep -q "import qs.modules.ii.bar.home" "$BAR_FILE" || BAR_ISSUES+=("Missing: import qs.modules.ii.bar.home")
    grep -q "HomeBar" "$BAR_FILE"                        || BAR_ISSUES+=("Missing: HomeBar loader (Home Assistant)")
    grep -q "VpnStatus\|vpnIcon" "$BAR_FILE"             || BAR_ISSUES+=("Missing: VPN indicator")
    grep -q "import qs.modules.ii.bar.weather" "$BAR_FILE" || BAR_ISSUES+=("Missing: import qs.modules.ii.bar.weather")

    if [[ ${#BAR_ISSUES[@]} -eq 0 ]]; then
        log "BarContent.qml: all feature integrations present"
    else
        warn "BarContent.qml integration issues:"
        for issue in "${BAR_ISSUES[@]}"; do
            echo "    - $issue"
        done
        warn "The overlay step may have overwritten merged changes. Check dots/quickshell/ overlay files."
    fi
fi

# ─── Step 10: Reload Hyprland ────────────────────────────────────────────────

step "Step 10: Reload"

if command -v hyprctl &>/dev/null && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    info "Reloading Hyprland configuration..."
    sleep 1
    hyprctl reload
    log "Hyprland reloaded"
    
    # Restart quickshell if running
    if pgrep -x quickshell &>/dev/null; then
        info "Restarting Quickshell..."
        killall quickshell 2>/dev/null || true
        sleep 2
        # Quickshell should auto-restart via Hyprland exec-once
        if ! pgrep -x quickshell &>/dev/null; then
            info "Quickshell will start automatically on next Hyprland reload"
        fi
        log "Quickshell restarted"
    fi
else
    info "Not running in Hyprland session. Reload manually after logging in."
fi

# ─── Done ────────────────────────────────────────────────────────────────────

step "Complete!"

echo -e "
${GREEN}${BOLD}Features have been applied!${RST}

${CYAN}Features installed (${#SELECTED_BRANCHES[@]}):${RST}"

# Dynamic feature list from selection
for (( i=0; i<${#FEATURE_BRANCHES[@]}; i++ )); do
    if [[ "${FEATURE_SELECTED[$i]}" -eq 1 ]]; then
        echo -e "  ${GREEN}✓${RST} ${FEATURE_LABELS[$i]}"
    fi
done

# Show keybinds only if custom-configs was selected
for branch in "${SELECTED_BRANCHES[@]}"; do
    if [[ "$branch" == "feature/custom-configs" ]]; then
        echo -e "
${CYAN}Key keybinds:${RST}
  Super+Alt+D      Toggle Docker
  Super+Alt+V      VPN toggle
  Super+Alt+P      Proxy toggle
  Super+C / Super+V  Universal copy/paste
  Ctrl+Super+/     Edit shell config
  Ctrl+Super+Alt+/ Edit custom keybinds"
        break
    fi
done

if $DO_BACKUP; then
    echo -e "
${CYAN}Backup location:${RST}
  $BACKUP_DIR

${YELLOW}To restore:${RST}
  cp -a $BACKUP_DIR/.config/* ~/.config/"
fi

if $KEEP_BRANCH; then
    echo -e "
${CYAN}Integration branch preserved:${RST}
  $INTEGRATION_BRANCH
  Inspect: cd $REPO_DIR && git log --oneline main..$INTEGRATION_BRANCH"
fi

echo -e "
${YELLOW}Recommended next steps:${RST}
  1. Press ${BOLD}Ctrl+Super+T${RST} to select a wallpaper
  2. Press ${BOLD}Super+/${RST} for keybind cheatsheet
  3. Edit ${BOLD}~/.config/hypr/custom/keybinds.conf${RST} to customize keybinds
  4. Edit ${BOLD}~/.config/illogical-impulse/config.json${RST} for Quickshell settings
  5. Configure Home Assistant: set url/token in config.json → services.homeAssistant
"
