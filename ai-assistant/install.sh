#!/bin/bash
# Quick Start Installation Script for AI Assistant
# Run this to set up the AI Assistant feature

set -e

echo "🤖 AI Assistant Installation"
echo "=============================="
echo

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running from correct directory
if [[ ! -d "ai-assistant" ]]; then
    echo -e "${RED}Error: Please run this script from the dots-hyprland-dev directory${NC}"
    exit 1
fi

echo "Step 1: Installing system dependencies..."
if command -v pacman &> /dev/null; then
    sudo pacman -S --needed python python-pip python-pyaudio portaudio
else
    echo -e "${YELLOW}Warning: Not an Arch-based system. Please install manually:${NC}"
    echo "  - python3, pip, pyaudio, portaudio"
    read -p "Press Enter when ready..."
fi

echo
echo "Step 2: Installing Python dependencies..."
pip install --user -r ai-assistant/wake-word/requirements.txt

echo
echo "Step 3: Downloading wake word models..."
python3 -c "from openwakeword import Model; Model()" || {
    echo -e "${RED}Failed to download models${NC}"
    exit 1
}

echo
echo "Step 4: Installing wake word service..."
mkdir -p ~/.config/systemd/user
cp ai-assistant/wake-word/ai-assistant-wake-word.service ~/.config/systemd/user/
systemctl --user daemon-reload

echo
echo "Step 5: Installing QML UI components..."
mkdir -p ~/.config/quickshell/ii/services
mkdir -p ~/.config/quickshell/ii/modules/ii/sidebarLeft

cp dots/quickshell/ii/services/AIAssistantState.qml \
   ~/.config/quickshell/ii/services/

cp dots/quickshell/ii/modules/ii/sidebarLeft/AuroraGlow.qml \
   ~/.config/quickshell/ii/modules/ii/sidebarLeft/

echo
echo "✅ Installation complete!"
echo
echo "Next steps:"
echo "1. Test wake word detector:"
echo "   cd ai-assistant/wake-word && ./wake_word_detector.py"
echo
echo "2. Enable service (optional):"
echo "   systemctl --user enable --now ai-assistant-wake-word"
echo
echo "3. Test event handler:"
echo "   cd ai-assistant/event-handler && ./ai_assistant_handler.py"
echo
echo "4. Restart Quickshell to load UI components"
echo
echo "See AI-ASSISTANT-README.md for full documentation"
