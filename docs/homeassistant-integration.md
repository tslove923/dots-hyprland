# Home Assistant Integration

HomeKit-style Home Assistant panel in the QuickShell top bar for smart home control.

## Features

- **Bar icon**: `home` Material Symbol with optional device count badge
- **Grouped device panel**:
  - Cameras (top row, click for PiP live stream via `mpv`)
  - Security & Access (locks, covers)
  - Lighting (with brightness slider for dimmable devices)
  - Climate & Appliances (toggle switches)
- **Toggle actions**: Click to control lights, switches, locks, covers, climate
- **External config**: Keeps tokens and entity names outside the repo
- **Configurable polling**: Fetch interval set in config (default 15 minutes)
- **Settings UI**: Configure via QuickShell settings panel

## Files

| File | Description |
|------|-------------|
| `services/HomeAssistant.qml` | HA API service (new) |
| `modules/ii/bar/BarContent.qml` | Bar icon integration |
| `modules/ii/bar/home/HomeBar.qml` | Bar indicator component (new) |
| `modules/ii/bar/home/HomePopup.qml` | Device control popup (new) |
| `modules/settings/BarConfig.qml` | Settings panel integration (new) |
| `modules/settings/ServicesConfig.qml` | Service settings (new) |
| `modules/common/Config.qml` | homeAssistant config block |

All paths relative to `dots/.config/quickshell/ii/`.

## Configuration

### External config file (recommended)

Create `~/.config/illogical-impulse/homeassistant.json`:

```json
{
  "url": "https://your-home.ui.nabu.casa",
  "token": "YOUR_LONG_LIVED_ACCESS_TOKEN",
  "fetchInterval": 15,

  "cameras": ["camera.front_door"],
  "lights": ["light.living_room", "light.bedroom"],
  "locks": ["lock.front_door"],
  "covers": ["cover.garage"],
  "climate": ["climate.main"],
  "appliances": ["switch.coffee_maker"]
}
```

### Settings override

The external config path can be changed in:
- **Services → Home Assistant → External config path** in QuickShell settings

### Notes

- If `url` omits the scheme, `https://` is auto-added
- If `mpv` is installed, camera tiles open an always-on-top PiP window
- If external config is missing, QuickShell settings values are used as fallback

## Dependencies

- `mpv` (optional) — for camera PiP live streams
- Home Assistant instance with a long-lived access token
