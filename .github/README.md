# dots-hyprland (tslove923 fork)

> **Fork of**: [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) · illogical-impulse  
> **Target Hardware**: Intel Lunar Lake (Arc GPU + NPU)

A personal fork of end-4's dots-hyprland QuickShell configuration with custom features for Intel hardware monitoring, home automation, and daily-driver QoL improvements.

> [!WARNING]
> Hyprland 0.55 update: if your distro has not shipped Hyprland 0.55 yet, use the pre-Luaification branch or wait for the proper update path before switching. See the official install/update docs for the latest migration notes.

All features live on `main` — no branch juggling required.

## Features

| Feature | Description | Docs |
|---------|-------------|------|
| GPU & NPU Monitoring | Real-time DRM cycle counter + sysfs utilization in the bar | [docs/gpu-npu-monitoring.md](docs/gpu-npu-monitoring.md) |
| VPN Indicator | Bar icon with click-to-toggle, WireGuard/OpenVPN detection | [docs/vpn-indicator.md](docs/vpn-indicator.md) |
| GitHub Copilot | AI chat panel via `gh copilot` CLI | [docs/copilot-integration.md](docs/copilot-integration.md) |
| Home Assistant | HomeKit-style device control panel in the bar | [docs/homeassistant-integration.md](docs/homeassistant-integration.md) |
| US Date & World Clocks | MM/dd format, work week, timezone sidebar widget | [docs/us-clock-worldclocks.md](docs/us-clock-worldclocks.md) |
| MPRIS Active Player Fix | Prioritizes currently playing media source | [docs/mpris-active-player-fix.md](docs/mpris-active-player-fix.md) |
| WiFi Reconnect Fix | Fixes reconnect after password entry | [docs/wifi-reconnect-fix.md](docs/wifi-reconnect-fix.md) |

## Installation

### Fresh install

```bash
git clone https://github.com/tslove923/dots-hyprland.git
cd dots-hyprland
./setup install
```

### Apply custom Hyprland config (keybinds, env, execs)

```bash
./apply-custom.sh
```

Interactive TUI to select which custom Lua configs to generate for `~/.config/hypr/custom/`.

### Hyprland 0.55 note

- If your distro has not shipped Hyprland 0.55 yet, follow the upstream migration guidance before switching.
- The repo still supports the custom touch and drawer additions, but the Lua entry points and dispatcher API should match the current illogical-impulse version.

## Staying Updated

```bash
git remote add upstream https://github.com/end-4/dots-hyprland.git
git fetch upstream
git merge upstream/main
```

## Structure

```
dots/
  .config/
    hypr/           # Hyprland Lua configs (hyprland.lua + custom/)
    quickshell/ii/  # QuickShell QML modules and services
    illogical-impulse/  # Runtime config (config.json)
docs/               # Per-feature documentation
```

## Credits

- [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) — base configuration
- [Mission Center](https://gitlab.com/nicola-music-player/mission-center) — DRM monitoring inspiration

## License

Same as the original repository. See [LICENSE](LICENSE) for details.
