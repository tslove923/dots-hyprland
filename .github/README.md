# dots-hyprland - Custom Features Fork

> **Fork of**: [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)  
> **Customizations by**: tslove923

This is a fork of end-4's excellent dots-hyprland configuration with custom features and enhancements.

## 🌟 Custom Features

Each feature is developed in its own branch with detailed documentation:

### 🔒 [VPN Indicator](https://github.com/tslove923/dots-hyprland/tree/feature/vpn-indicator)
Adds a real-time VPN status indicator to the Quickshell bar.

- Green icon when connected, grey when disconnected
- Click to toggle VPN connection
- Supports OpenVPN, WireGuard, and tun0 interfaces

**Branch**: [`feature/vpn-indicator`](https://github.com/tslove923/dots-hyprland/tree/feature/vpn-indicator)

---

### 🤖 [GitHub Copilot Integration](https://github.com/tslove923/dots-hyprland/tree/feature/copilot-integration)
Integrates GitHub Copilot as an AI model in the sidebar panel.

- Uses gh CLI for authentication
- No API key required (uses your Copilot subscription)
- Custom icon and seamless integration

**Branch**: [`feature/copilot-integration`](https://github.com/tslove923/dots-hyprland/tree/feature/copilot-integration)

---

### ⌨️ [Custom Keybindings](https://github.com/tslove923/dots-hyprland/tree/feature/custom-keybinds)
Personalized Hyprland keyboard shortcuts.

- VPN toggle shortcut
- Workspace management enhancements
- Quick access to common tools

**Branch**: [`feature/custom-keybinds`](https://github.com/tslove923/dots-hyprland/tree/feature/custom-keybinds)

---

## 📦 Installation

### Use All Features
```bash
# Clone this repository
git clone https://github.com/tslove923/dots-hyprland
cd dots-hyprland

# Merge all features
git checkout -b all-features
git merge feature/vpn-indicator
git merge feature/copilot-integration
git merge feature/custom-keybinds

# Then follow end-4's installation instructions
```

### Use Individual Features
Each feature branch has its own installation instructions. Visit the branch README for details.

```bash
# Example: Install just VPN indicator
git clone -b feature/vpn-indicator https://github.com/tslove923/dots-hyprland
cd dots-hyprland
# Follow instructions in README.md
```

## 🔄 Staying Updated

This fork tracks upstream changes from end-4's original repository:

```bash
git remote add upstream https://github.com/end-4/dots-hyprland
git fetch upstream
git merge upstream/main
```

## 📚 Original Repository

This is based on [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) - an amazing Hyprland configuration. All credit for the base configuration goes to end-4 and contributors.

## 🤝 Contributing

Feel free to:
- Use these features in your own setup
- Suggest improvements via issues
- Submit pull requests for enhancements

## 📝 License

Same as the original repository. See [LICENSE](LICENSE) for details.

---

**Upstream**: [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)  
**This Fork**: Custom features by tslove923
