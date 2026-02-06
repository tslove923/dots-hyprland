#!/bin/bash
# Script to test changes from dev repo to live config

DEV_DIR="$HOME/projects/dots-hyprland-dev"
LIVE_CONFIG="$HOME/.config"

if [ ! -d "$DEV_DIR" ]; then
    echo "❌ Development directory not found: $DEV_DIR"
    echo "Run: bash /tmp/development_workflow.sh first"
    exit 1
fi

cd "$DEV_DIR" || exit 1

CURRENT_BRANCH=$(git branch --show-current)
echo "📍 Current branch: $CURRENT_BRANCH"
echo ""

case "$1" in
    vpn)
        echo "🔄 Syncing VPN indicator feature to live config..."
        cp -v dots/quickshell/ii/services/VpnStatus.qml "$LIVE_CONFIG/quickshell/ii/services/"
        echo "⚠️  Note: BarContent.qml changes need manual merge"
        echo "   Dev:  $DEV_DIR/dots/quickshell/ii/modules/ii/bar/BarContent.qml"
        echo "   Live: $LIVE_CONFIG/quickshell/ii/modules/ii/bar/BarContent.qml"
        ;;
    gpu-npu)
        echo "🔄 Syncing GPU/NPU monitoring feature to live config..."
        cp -v dots/.config/quickshell/ii/services/ResourceUsage.qml "$LIVE_CONFIG/quickshell/ii/services/"
        cp -v dots/.config/quickshell/ii/modules/ii/bar/Resources.qml "$LIVE_CONFIG/quickshell/ii/modules/ii/bar/"
        cp -v dots/.config/quickshell/ii/modules/ii/bar/ResourcesPopup.qml "$LIVE_CONFIG/quickshell/ii/modules/ii/bar/"
        cp -v dots/.config/quickshell/ii/modules/ii/verticalBar/Resources.qml "$LIVE_CONFIG/quickshell/ii/modules/ii/verticalBar/"
        cp -v dots/.config/quickshell/ii/modules/ii/overlay/resources/Resources.qml "$LIVE_CONFIG/quickshell/ii/modules/ii/overlay/resources/"
        cp -v dots/.config/quickshell/ii/modules/common/Config.qml "$LIVE_CONFIG/quickshell/ii/modules/common/"
        echo ""
        echo "📦 Required package: intel-gpu-tools"
        echo "   Install with: sudo pacman -S intel-gpu-tools"
        ;;
    copilot)
        echo "🔄 Syncing Copilot integration to live config..."
        cp -v dots/quickshell/ii/services/ai/CopilotCliApiStrategy.qml "$LIVE_CONFIG/quickshell/ii/services/ai/"
        cp -v dots/quickshell/ii/services/Ai.qml "$LIVE_CONFIG/quickshell/ii/services/"
        cp -v dots/illogical-impulse/config.json "$LIVE_CONFIG/illogical-impulse/"
        ;;
    keybinds)
        echo "🔄 Syncing custom keybinds to live config..."
        cp -v dots/hypr/custom/keybinds.conf "$LIVE_CONFIG/hypr/custom/"
        ;;
    pull)
        echo "🔄 Pulling changes FROM live config to dev repo..."
        echo "Current branch: $CURRENT_BRANCH"
        read -p "Copy files from live to dev for this branch? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            case "$CURRENT_BRANCH" in
                feature/vpn-indicator)
                    cp -v "$LIVE_CONFIG/quickshell/ii/services/VpnStatus.qml" dots/quickshell/ii/services/
                    ;;
                feature/copilot-integration)
                    cp -v "$LIVE_CONFIG/quickshell/ii/services/ai/CopilotCliApiStrategy.qml" dots/quickshell/ii/services/ai/
                    cp -v "$LIVE_CONFIG/quickshell/ii/services/Ai.qml" dots/quickshell/ii/services/
                    cp -v "$LIVE_CONFIG/illogical-impulse/config.json" dots/illogical-impulse/
                    ;;
                feature/custom-keybinds)
                    cp -v "$LIVE_CONFIG/hypr/custom/keybinds.conf" dots/hypr/custom/
                    ;;
                feature/gpu-npu-monitoring)
                    cp -v "$LIVE_CONFIG/quickshell/ii/services/ResourceUsage.qml" dots/.config/quickshell/ii/services/
                    cp -v "$LIVE_CONFIG/quickshell/ii/modules/ii/bar/Resources.qml" dots/.config/quickshell/ii/modules/ii/bar/
                    cp -v "$LIVE_CONFIG/quickshell/ii/modules/ii/bar/ResourcesPopup.qml" dots/.config/quickshell/ii/modules/ii/bar/
                    cp -v "$LIVE_CONFIG/quickshell/ii/modules/ii/verticalBar/Resources.qml" dots/.config/quickshell/ii/modules/ii/verticalBar/
                    cp -v "$LIVE_CONFIG/quickshell/ii/modules/ii/overlay/resources/Resources.qml" dots/.config/quickshell/ii/modules/ii/overlay/resources/
                    cp -v "$LIVE_CONFIG/quickshell/ii/modules/common/Config.qml" dots/.config/quickshell/ii/modules/common/
                    ;;
            esac
            git status
        fi
        ;;
    *)
        echo "Usage: $0 {vpn|gpu-npu|copilot|keybinds|pull}"
        echo ""
        echo "Commands:"
        echo "  vpn      - Copy VPN indicator to live config (for testing)"
        echo "  gpu-npu  - Copy GPU/NPU monitoring to live config"
        echo "  copilot  - Copy Copilot integration to live config"
        echo "  keybinds - Copy keybinds to live config"
        echo "  pull     - Pull changes from live config back to dev repo"
        echo ""
        echo "Workflow:"
        echo "  1. Edit files in: $DEV_DIR"
        echo "  2. Test: bash $0 {feature}"
        echo "  3. Pull back: bash $0 pull"
        echo "  4. Commit: cd $DEV_DIR && git add -A && git commit"
        echo "  5. Push: git push origin \$BRANCH"
        exit 1
        ;;
esac

echo ""
echo "✅ Done! Reload your config to test changes."
echo "   (Super+Shift+R or restart Hyprland)"

