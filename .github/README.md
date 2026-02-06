# dots-hyprland - GPU & NPU Monitoring Feature

> **Branch**: `feature/gpu-npu-monitoring`  
> **Based on**: [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)

## 🎮 GPU & NPU Usage Monitoring

This branch adds real-time GPU and NPU usage indicators for Intel Lunar Lake SoCs (and other Intel GPUs) to the Quickshell status bar, similar to existing CPU, memory, and swap monitors.

### Screenshot

![GPU & NPU Monitoring](images/gpu-npu-monitoring.png)

### Features

- **GPU Monitoring**: Real-time usage tracking via DRM cycle counters
  - Works with Intel Xe driver (Lunar Lake Arc Graphics)
  - Supports render, video, and compute engines
  - Material Symbols icon: `stadia_controller`
- **NPU Monitoring**: Intel NPU power state detection
  - Shows Active/Suspended status
  - Material Symbols icon: `neurology`
- **Multiple UI Components**: Indicators in bar, vertical bar, popup tooltip, and full overlay
- **Configurable thresholds**: Warning colors at 90% usage (customizable)
- **Always-show option**: Keep indicators visible even at 0% usage

### Files Added/Modified

### Files Modified

| File | Changes |
|------|---------|
| `services/ResourceUsage.qml` | Added GPU/NPU monitoring logic with DRM fdinfo parsing |
| `modules/ii/bar/Resources.qml` | Added GPU/NPU indicators to horizontal bar |
| `modules/ii/verticalBar/Resources.qml` | Added GPU/NPU indicators to vertical bar |
| `modules/ii/bar/ResourcesPopup.qml` | Added GPU/NPU info to hover tooltip |
| `modules/ii/overlay/resources/Resources.qml` | Added GPU/NPU tabs with usage graphs |
| `modules/common/Config.qml` | Added configuration options (thresholds, always-show) |

### Dependencies

**Arch Linux**:
```bash
sudo pacman -S intel-gpu-tools  # Optional, for intel_gpu_top fallback
```

**Other distributions**:
- Fedora/RHEL: `sudo dnf install intel-gpu-tools`
- Ubuntu/Debian: `sudo apt install intel-gpu-tools`
- Gentoo: `emerge x11-apps/intel-gpu-tools`

### Installation

**Method 1: From this fork**
```bash
# Clone this feature branch
git clone -b feature/gpu-npu-monitoring https://github.com/tslove923/dots-hyprland.git
cd dots-hyprland

# Run the installer
./setup
```

**Method 2: Manual installation**
```bash
# Copy modified files to your config
cp dots/.config/quickshell/ii/services/ResourceUsage.qml \
   ~/.config/quickshell/ii/services/

cp dots/.config/quickshell/ii/modules/ii/bar/Resources.qml \
   ~/.config/quickshell/ii/modules/ii/bar/

cp dots/.config/quickshell/ii/modules/ii/verticalBar/Resources.qml \
   ~/.config/quickshell/ii/modules/ii/verticalBar/

cp dots/.config/quickshell/ii/modules/ii/bar/ResourcesPopup.qml \
   ~/.config/quickshell/ii/modules/ii/bar/

cp dots/.config/quickshell/ii/modules/ii/overlay/resources/Resources.qml \
   ~/.config/quickshell/ii/modules/ii/overlay/resources/

cp dots/.config/quickshell/ii/modules/common/Config.qml \
   ~/.config/quickshell/ii/modules/common/

# Reload Quickshell
qs -r
```

### Configuration

Edit `~/.config/illogical-impulse/config.json`:

```json
{
  "alwaysShowGpu": true,
  "gpuWarningThreshold": 90,
  "alwaysShowNpu": true,
  "npuWarningThreshold": 90
}
```

### How It Works

**GPU Monitoring**:
1. Reads DRM file descriptors from `/proc/*/fdinfo/*`
2. Parses cycle counters: `drm-cycles-rcs` (render), `drm-cycles-vcs` (video), `drm-cycles-ccs` (compute)
3. Calculates usage: `(active_cycles_delta / total_cycles_delta) * 100`
4. Averages across all active engines
5. Works with Intel Xe driver (Lunar Lake) and i915

**NPU Monitoring**:
1. Reads power state from `/sys/class/accel/accel0/device/power/runtime_status`
2. Returns 100% (Active) or 0% (Suspended)
3. Future: Could integrate with Intel NPU driver for detailed metrics

### Troubleshooting

**GPU shows 0% constantly**:
- Check kernel driver: `lspci -k | grep -A 3 VGA`
- Verify fdinfo exists: `ls /proc/*/fdinfo/* | head`
- Test manually: `cat /proc/$(pgrep -n qs)/fdinfo/* | grep drm-cycles`

**NPU not detected**:
- Check device exists: `ls /sys/class/accel/`
- Verify NPU driver loaded: `lsmod | grep intel_vpu`
- Check dmesg: `dmesg | grep -i npu`

**Permission errors**:
- `/proc/*/fdinfo/` requires process ownership (Quickshell reads its own)
- `/sys/class/accel/` should be world-readable

### Development Workflow

```bash
# Make changes in dev repo
cd ~/projects/dots-hyprland-dev
# Edit files...

# Sync to live config
bash scripts/sync_and_test.sh gpu-npu

# Test changes
qs -r
```

### Credits

- **Mission Center**: Inspired the DRM cycle counter monitoring approach
- **end-4/dots-hyprland**: Base configuration
- **Intel**: Xe driver and DRM subsystem documentation

### License

Same as base dots-hyprland repository (see [LICENSE](../LICENSE))

---

**Original Repository**: [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)  
**Customization by**: tslove923
