# dots-hyprland - GitHub Copilot Integration

> **Branch**: `feature/copilot-integration`  
> **Based on**: [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)

## 🤖 GitHub Copilot AI Integration

This branch adds GitHub Copilot as an AI model option in the sidebar AI panel.

### Screenshot

![Copilot Integration in action](images/copilot-integration.png)

### Features

- **GitHub Copilot CLI integration**: Uses `gh copilot` command for queries
- **No API key required**: Uses your existing GitHub Copilot subscription
- **Custom API strategy**: Implements CopilotCliApiStrategy for gh CLI
- **Copilot icon**: Changes the AI panel icon to the Copilot symbol

### Files Added/Modified

#### New Files
- `dots/quickshell/ii/services/ai/CopilotCliApiStrategy.qml` - Custom API handler for gh CLI

#### Modified Files
- `dots/quickshell/ii/services/Ai.qml` - Adds github-copilot model definition (around line 315)
- `dots/illogical-impulse/config.json` - Changes `topLeftIcon` to "copilot" (line 165)

### Installation

#### Prerequisites

1. GitHub CLI installed:
   ```bash
   # Arch/Manjaro
   sudo pacman -S github-cli
   
   # Or via yay
   yay -S github-cli
   ```

2. GitHub Copilot extension:
   ```bash
   gh extension install github/gh-copilot
   ```

3. Active GitHub Copilot subscription and authentication:
   ```bash
   gh auth login
   ```

#### Install the Feature

```bash
# Copy the API strategy
cp dots/quickshell/ii/services/ai/CopilotCliApiStrategy.qml \
   ~/.config/quickshell/ii/services/ai/

# Copy the updated Ai service
cp dots/quickshell/ii/services/Ai.qml \
   ~/.config/quickshell/ii/services/

# Optional: Update the icon
cp dots/illogical-impulse/config.json \
   ~/.config/illogical-impulse/
```

### Usage

1. Open the AI sidebar (default: Super+A)
2. Click the model selector dropdown
3. Select "GitHub Copilot"
4. Start chatting!

### How It Works

Unlike other AI models that use HTTP APIs, this integration:
1. Converts chat messages to a format suitable for `gh copilot`
2. Executes `gh copilot explain` or `gh copilot suggest` via CLI
3. Streams the response back to the UI
4. No API keys needed - uses your gh CLI authentication

### Customization

The implementation handles:
- Multi-turn conversations
- System prompts
- Streaming responses
- Error handling

To modify behavior, edit `CopilotCliApiStrategy.qml`.

### Troubleshooting

**"gh: command not found"**
- Install GitHub CLI (see prerequisites)

**"Copilot extension not found"**
```bash
gh extension install github/gh-copilot
```

**"Failed to log in to github.com"**
```bash
gh auth login
# Follow the prompts to authenticate
```

**"The token is invalid"**
```bash
gh auth refresh
```

---

**Original Repository**: [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)  
**Customization by**: tslove923
