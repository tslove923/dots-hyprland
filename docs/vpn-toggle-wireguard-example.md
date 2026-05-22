# VPN Toggle Script (WireGuard Example)

This repo includes a portable VPN toggle flow for Hyprland keybinds and the QuickShell VPN indicator.

## Included Files

| File | Purpose |
|------|---------|
| `dots/.config/hypr/custom/scripts/vpn_toggle.sh` | Wrapper script used by keybinds; dispatches to a user-provided script |
| `dots/.config/hypr/custom/scripts/vpn-toggle.sh.example` | Example user script that toggles a WireGuard connection |

## How It Works

1. Keybinds call `~/.config/hypr/custom/scripts/vpn_toggle.sh`.
2. The wrapper tries these scripts in order:
   - `~/.config/hypr/custom/scripts/vpn-toggle.sh`
   - `~/.config/illogical-impulse/scripts/vpn-toggle.sh`
   - `~/Documents/vpn-toggle.sh`
3. The first matching script is executed.

This keeps the repo generic while still allowing local customization.

## Install the Example Script

Copy the example to the first lookup path so it is used automatically:

```bash
cp ~/.config/hypr/custom/scripts/vpn-toggle.sh.example ~/.config/hypr/custom/scripts/vpn-toggle.sh
chmod +x ~/.config/hypr/custom/scripts/vpn-toggle.sh
```

## WireGuard Connection Name

The example script accepts an optional connection name argument and defaults to `wg0`:

```bash
~/.config/hypr/custom/scripts/vpn-toggle.sh my-wg-connection
```

If your WireGuard profile name is not `wg0`, edit the keybind command or set your local script default.

## Toggle Logic

The example script uses this order:

1. `nmcli` toggle if a WireGuard profile with that name exists in NetworkManager.
2. `wg-quick` toggle as fallback.

It sends desktop notifications for connected/disconnected states.

## QuickShell VPN Indicator Integration

If you want click-to-toggle in the status bar, set `vpn.toggleScript` in your config:

```json
{
  "vpn": {
    "toggleScript": "~/.config/hypr/custom/scripts/vpn_toggle.sh"
  }
}
```

Config file:

- `~/.config/illogical-impulse/config.json`

## Notes

- The `wg-quick` fallback may require sudo privileges.
- For passwordless keybind toggling, configure sudoers carefully for the required `wg-quick` commands.
