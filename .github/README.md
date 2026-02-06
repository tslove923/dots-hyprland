# dots-hyprland - Custom Keybindings

> **Branch**: `feature/custom-keybinds`  
> **Based on**: [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)

## ⌨️ Custom Hyprland Keybindings

This branch contains personalized keyboard shortcuts for Hyprland.

### Files Modified

- `dots/hypr/custom/keybinds.conf` - Custom key bindings

### Added Keybindings

| Shortcut | Action | Description |
|----------|--------|-------------|
| `Super + Alt + V` | VPN Toggle | Opens VPN toggle script in kitty |
| `Super + Alt + B` | Bluetui | Opens Bluetooth TUI manager |
| `Super + Z` | Voxd Record | Triggers voxd recording |
| `Super + Shift + [1-9]` | Move to Workspace | Moves active window to workspace 1-9 |
| `Super + Alt + →` | Next Workspace | Switches to next workspace on current monitor |
| `Super + Alt + ←` | Previous Workspace | Switches to previous workspace on current monitor |

### Installation

```bash
cp dots/hypr/custom/keybinds.conf ~/.config/hypr/custom/
```

Hyprland should automatically reload the configuration.

### Customization

Edit `~/.config/hypr/custom/keybinds.conf` to add your own keybindings.

Format:
```conf
bind = MODIFIERS, KEY, ACTION, PARAMETERS
```

Examples:
```conf
bind = Super, T, exec, kitty           # Open terminal
bind = Super Shift, Q, killactive,     # Close window
bind = Super, F, fullscreen,           # Toggle fullscreen
```

See [Hyprland Binds Wiki](https://wiki.hyprland.org/Configuring/Binds/) for more options.

### Dependencies

These keybindings require:
- `kitty` - Terminal emulator
- `bluetui` - Bluetooth TUI (optional)
- `voxd` - Voice recording tool (optional)
- VPN toggle script at `~/Documents/vpn-toggle.sh` (optional)

---

**Original Repository**: [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)  
**Customization by**: tslove923
