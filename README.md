# dots-hyprland — US Date Format & World Clocks

> **Branch**: `feature/us-clock-view-worldclocks`  
> **Based on**: [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)

QuickShell customizations for US-style date formatting, work week display in the top bar, and a world clocks widget in the sidebar.

## 🕐 Top Bar — US Date Format & Work Week

![Top bar with US date format and work week](/.github/assets/topbar-us-date.png)

Changes the top bar clock to show **US date format** (`MM/dd`) and the **ISO work week** number.

### Date format changes

**File**: `dots/.config/quickshell/ii/modules/common/Config.qml`

| Format | Default | Custom |
|--------|---------|--------|
| Top bar date | `ddd, dd/MM` | `ddd, MM/dd` |
| Short date | `dd/MM` | `MM/dd` |
| Date with year | `dd/MM/yyyy` | `MM/dd/yyyy` |

### Work week display

**Files**: `ClockWidget.qml`, `DateTime.qml`

Adds an ISO week number (e.g. `W10`) next to the date in the top bar. The `DateTime` service exposes a `workWeek` property computed from `Qt.formatDateTime`.

> **Note**: QuickShell persists user settings to `~/.config/illogical-impulse/config.json`.  
> Changes to `Config.qml` only set defaults — the JSON file overrides them.  
> To apply: update both the QML file and the `time` section in `config.json`.

## 🌍 Sidebar — World Clocks

![World clocks widget in sidebar](/.github/assets/world-clocks.png)

A new **World Clocks** panel in the right sidebar showing multiple time zones, sorted by UTC offset.

**Files**:
- `WorldClocks.qml` — New widget
- `SidebarRightContent.qml` — Wires widget into sidebar

### Configured time zones

| City | Time Zone |
|------|-----------|
| London, UK | Europe/London |
| Gdansk, PL | Europe/Warsaw |
| Bangalore, IN | Asia/Kolkata |
| Penang, MY | Asia/Kuala_Lumpur |
| Shanghai, CN | Asia/Shanghai |

Clocks display the city label, current time, UTC offset, and day difference relative to local time. Labels use a consistent `City, XX` format.

## 📦 Installation

```bash
# Sync QuickShell modules
for f in \
  modules/common/Config.qml \
  modules/ii/bar/ClockWidget.qml \
  modules/ii/sidebarRight/SidebarRightContent.qml \
  modules/ii/sidebarRight/WorldClocks.qml \
  services/DateTime.qml; do
  cp "dots/.config/quickshell/ii/$f" \
     "$HOME/.config/quickshell/ii/$f"
done

# Update persisted QuickShell settings
python3 -c "
import json, pathlib
p = pathlib.Path.home() / '.config/illogical-impulse/config.json'
d = json.loads(p.read_text())
d['time']['dateFormat'] = 'ddd, MM/dd'
d['time']['shortDateFormat'] = 'MM/dd'
d['time']['dateWithYearFormat'] = 'MM/dd/yyyy'
p.write_text(json.dumps(d, indent=2))
"

# Restart QuickShell to pick up changes
qs -c ii &
```

---

**Original Repository**: [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)  
**Customization by**: tslove923
