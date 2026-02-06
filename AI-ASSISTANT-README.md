# AI Assistant - Voice-Activated AI Panel

> **Branch**: `feature/ai-assistant`  
> **Status**: 🚧 Work in Progress  
> **Based on**: [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)

## 🎯 Overview

This feature transforms the AI panel into a full voice-activated AI assistant with:

- **Wake word detection** ("Hey Assistant")
- **Voice-to-text** via voxd streaming
- **Visual feedback** with aurora glow effect
- **Agent-based task automation** (web search, Spotify, email, browser tabs)
- **Local processing** (privacy-focused, no cloud dependencies)

## 🏗️ Architecture

```
┌─────────────────────┐
│  Wake Word Detector │ (openwakeword)
│   "Hey Assistant"   │
└──────────┬──────────┘
           │ Trigger Event
           ↓
┌─────────────────────┐
│   Event Handler     │
│ Coordinates System  │
└──────────┬──────────┘
           │
           ├─→ Show AI Panel (with aurora glow)
           ├─→ Start voxd streaming
           └─→ Activate agents
           
┌─────────────────────┐
│    voxd (Voice)     │
│  Transcription →    │
└──────────┬──────────┘
           │
           ↓
┌─────────────────────┐
│   Agent Router      │
│  Intent Detection   │
└──────────┬──────────┘
           │
           ├─→ Web Search Agent
           ├─→ Spotify Agent
           ├─→ Email Agent
           └─→ Browser Tab Agent
```

## 📦 Components

### 1. Wake Word Detection
- **Service**: `ai-assistant-wake-word.service`
- **Script**: `wake_word_detector.py`
- **Library**: openwakeword
- **Model**: "hey_assistant" (customizable)
- **Latency**: ~80ms
- **CPU Usage**: ~5-10%

### 2. Event Handler
- **Script**: `ai_assistant_handler.py`
- **Functions**:
  - Monitors wake word triggers
  - Coordinates voxd activation
  - Shows/hides AI panel
  - Manages state machine

### 3. UI Integration (Quickshell/QML)
- **State Manager**: `AIAssistantState.qml`
- **Glow Effect**: `AuroraGlow.qml`
- **Modified Files**:
  - `SidebarLeft.qml` (aurora glow integration)
  - `AiChat.qml` (voxd input routing)

### 4. Agent System
- **Intent Router**: Parses transcription, routes to agents
- **Agents**:
  - `WebSearchAgent`: Opens browser with search query
  - `SpotifyAgent`: Controls Spotify playback
  - `EmailAgent`: Checks email inbox
  - `BrowserTabAgent`: Focuses specific browser tabs

## 🚀 Installation

### Prerequisites

```bash
# System dependencies
sudo pacman -S python python-pip python-pyaudio portaudio

# Playwright for browser automation (optional)
pip install --user playwright
playwright install chromium

# Watchdog for file monitoring
pip install --user watchdog
```

### Install Wake Word Detector

```bash
cd ~/projects/dots-hyprland-dev/ai-assistant/wake-word

# Install Python dependencies
pip install --user -r requirements.txt

# Download wake word models
python -c "from openwakeword import Model; Model()"

# Make script executable
chmod +x wake_word_detector.py

# Install systemd service
mkdir -p ~/.config/systemd/user
cp ai-assistant-wake-word.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now ai-assistant-wake-word
```

### Install Event Handler

```bash
cd ~/projects/dots-hyprland-dev/ai-assistant/event-handler

# Make script executable
chmod +x ai_assistant_handler.py

# Install dependencies
pip install --user watchdog

# Run manually or create service
./ai_assistant_handler.py
```

### Install UI Components

```bash
# Copy QML files
cp dots/quickshell/ii/services/AIAssistantState.qml \
   ~/.config/quickshell/ii/services/

cp dots/quickshell/ii/modules/ii/sidebarLeft/AuroraGlow.qml \
   ~/.config/quickshell/ii/modules/ii/sidebarLeft/

# Restart quickshell
killall quickshell
# Quickshell should auto-restart via Hyprland config
```

## 🎮 Usage

### Basic Voice Activation

1. Say **"Hey Assistant"** 
2. AI panel appears with glowing aurora effect
3. Speak your command
4. voxd transcribes speech to AI panel
5. Agent system processes intent and executes task

### Example Commands

| Command | Agent | Action |
|---------|-------|--------|
| "Search for Python tutorials" | WebSearch | Opens browser with Google search |
| "Play some jazz music" | Spotify | Plays jazz playlist on Spotify |
| "Check my email" | Email | Shows unread email count |
| "Open my Teams tab" | BrowserTab | Focuses Teams tab in browser |
| "What's the weather?" | AI | Queries AI model directly |

### Manual Testing

```bash
# Test wake word detector
cd ~/projects/dots-hyprland-dev/ai-assistant/wake-word
./wake_word_detector.py

# Test event handler
cd ~/projects/dots-hyprland-dev/ai-assistant/event-handler
./ai_assistant_handler.py

# Trigger manually
echo '{"type":"wake_word_detected","wake_word":"test"}' > /tmp/ai-assistant-triggered
```

## ⚙️ Configuration

### Wake Word Settings

Edit `wake_word_detector.py`:

```python
# Change wake word model
WAKE_WORDS = ["hey_jarvis"]  # or "alexa", "hey_mycroft"

# Adjust sensitivity (0.0 - 1.0)
THRESHOLD = 0.5  # Lower = more sensitive, more false positives
```

### voxd Integration

voxd config: `~/.config/voxd/config.yaml`

```yaml
# Ensure streaming is enabled
enable_streaming: true

# Audio device should match wake word detector
audio_input_device: "Lunar Lake-M HD Audio Controller Microphones"
```

### Aurora Glow Colors

Edit `AuroraGlow.qml`:

```qml
property color color1: "#00ff88"  // Teal
property color color2: "#0088ff"  // Blue  
property color color3: "#ff0088"  // Pink
```

## 🤖 Agent Development

### Creating Custom Agents

```python
# agents/base_agent.py
class BaseAgent:
    def can_handle(self, intent: str, entities: dict) -> bool:
        """Return True if this agent can handle the intent"""
        raise NotImplementedError
    
    def execute(self, intent: str, entities: dict) -> dict:
        """Execute the task and return result"""
        raise NotImplementedError

# agents/custom_agent.py
class CustomAgent(BaseAgent):
    def can_handle(self, intent, entities):
        return "custom_keyword" in intent.lower()
    
    def execute(self, intent, entities):
        # Your custom logic here
        return {"status": "success", "message": "Done!"}
```

### Intent Patterns

The system uses simple pattern matching initially:

```python
INTENT_PATTERNS = {
    'web_search': [r'search (for|about)', r'google', r'look up'],
    'spotify': [r'play (music|song)', r'spotify', r'listen to'],
    'email': [r'check (my)? email', r'inbox', r'new messages'],
    'browser_tab': [r'open.*tab', r'switch to', r'show me.*tab'],
}
```

## 🐛 Troubleshooting

### Wake Word Not Detected

```bash
# Check if service is running
systemctl --user status ai-assistant-wake-word

# Check logs
journalctl --user -u ai-assistant-wake-word -f

# Test microphone
arecord -l
arecord -d 5 test.wav && aplay test.wav
```

### AI Panel Not Showing

```bash
# Check state file
cat /tmp/ai-assistant-state.json

# Check quickshell logs
journalctl -t quickshell -f

# Manually toggle panel (default: Super+A)
hyprctl dispatch exec "qdbus org.quickshell /AI toggle"
```

### voxd Not Streaming

```bash
# Check voxd is running
ps aux | grep voxd

# Check voxd socket
ls -la ~/.config/voxd/voxd.sock

# Restart voxd
pkill voxd
voxd &
```

### Python Dependencies

```bash
# Check installed packages
pip list | grep -E 'openwakeword|pyaudio|watchdog'

# Reinstall if needed
pip install --user --force-reinstall openwakeword pyaudio watchdog
```

## 🔒 Privacy & Security

- **Local processing**: All wake word detection runs on your device
- **No cloud**: openwakeword doesn't send data to external servers
- **voxd**: Transcription happens locally
- **Agent actions**: You control what agents can access

### Recommended Practices

1. Review agent code before enabling
2. Don't grant browser agents access to sensitive tabs without review
3. Use application-specific passwords for email agents
4. Monitor system logs for unexpected behavior

## 🚧 Current Status

### ✅ Completed
- Wake word detection service
- Event handler framework
- QML state manager
- Aurora glow effect component
- Basic architecture documentation

### 🔄 In Progress
- voxd streaming mode integration
- Agent router and intent detection
- Browser automation agents

### 📋 TODO
- Spotify D-Bus integration
- Email checking agent
- Context-aware conversations
- Voice feedback/responses
- Custom wake word training
- Multi-language support

## 📚 Additional Resources

- [openwakeword Documentation](https://github.com/dscripka/openWakeWord)
- [Playwright Python API](https://playwright.dev/python/)
- [D-Bus MPRIS Specification](https://specifications.freedesktop.org/mpris-spec/latest/)

---

**Original Repository**: [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)  
**AI Assistant Feature by**: tslove923
