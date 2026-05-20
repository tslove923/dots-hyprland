# GitHub Copilot Integration

GitHub Copilot as an AI model option in the QuickShell sidebar chat panel.

![Copilot Integration](../.github/images/copilot-integration.png)

## Features

- **GitHub Copilot CLI integration**: Routes queries through `gh copilot`
- **No API key required**: Uses your existing GitHub Copilot subscription via `gh auth`
- **Custom API strategy**: `CopilotCliApiStrategy.qml` handles CLI communication
- **Copilot icon**: Sets the AI panel icon to the Copilot symbol
- **Full chat support**: Multi-turn conversations, system prompts, streaming responses

## Files

| File | Description |
|------|-------------|
| `services/ai/CopilotCliApiStrategy.qml` | Custom API handler for gh CLI (new) |
| `services/Ai.qml` | Adds `github-copilot` model definition |
| `config.json` | Sets `topLeftIcon` to "copilot" |

Paths relative to `dots/.config/quickshell/ii/` (services) and `dots/.config/illogical-impulse/` (config.json).

## Prerequisites

1. **GitHub CLI**:
   ```bash
   sudo pacman -S github-cli
   ```

2. **GitHub Copilot extension**:
   ```bash
   gh extension install github/gh-copilot
   ```

3. **Authentication**:
   ```bash
   gh auth login
   ```

4. Active GitHub Copilot subscription

## Usage

1. Open the AI sidebar (default: Super+A)
2. Click the model selector dropdown
3. Select "GitHub Copilot"
4. Start chatting

## How It Works

Unlike other AI models that use HTTP APIs directly:
1. Converts chat messages to a format suitable for `gh copilot`
2. Executes `gh copilot explain` or `gh copilot suggest` via CLI subprocess
3. Streams the response back to the QML UI
4. Authentication handled entirely by `gh` — no tokens in config

## Troubleshooting

| Error | Fix |
|-------|-----|
| `gh: command not found` | Install GitHub CLI |
| `Copilot extension not found` | `gh extension install github/gh-copilot` |
| `Failed to log in` | `gh auth login` |
| `The token is invalid` | `gh auth refresh` |
