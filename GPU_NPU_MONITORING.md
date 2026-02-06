# GPU and NPU Monitoring for Intel Lunar Lake

This configuration adds GPU and NPU usage indicators to the resource monitors in the dots-hyprland setup.

## Requirements

### For GPU Monitoring

Install the `intel-gpu-tools` package from the Arch Linux official repos:

```bash
sudo pacman -S intel-gpu-tools
```

This provides the `intel_gpu_top` tool which monitors Intel GPU usage in real-time.

### For NPU Monitoring

NPU monitoring is built-in using the sysfs interface at `/sys/class/accel/accel0/`. No additional packages are required.

The NPU driver (`intel_vpu`) should be automatically loaded by the kernel for Lunar Lake systems.

## Features Added

### 1. **Bar Resources** (Horizontal and Vertical)
- GPU indicator with gamepad icon (🎮 `stadia_controller`)
- NPU indicator with brain/neurology icon (🧠 `neurology`)
- Both indicators show usage percentage with color-coded warnings

### 2. **Resource Popup Tooltip**
- GPU load percentage when hovering over resources
- NPU status (Active/Suspended) based on power state

### 3. **Overlay Resources Widget**
- GPU and NPU tabs with historical usage graphs
- Dynamic visibility - tabs only appear when hardware is detected

## Configuration

Edit `~/.config/quickshell/ii/config.json` to customize:

```json
{
  "bar": {
    "resources": {
      "alwaysShowGpu": false,      // Show GPU indicator even when media is playing
      "alwaysShowNpu": false,      // Show NPU indicator even when media is playing
      "gpuWarningThreshold": 90,   // Warning color above this percentage
      "npuWarningThreshold": 90    // Warning color above this percentage
    }
  }
}
```

## How It Works

### GPU Monitoring
- Uses `intel_gpu_top -J -s 100` to get JSON output of GPU usage
- Averages usage across all GPU engines (Render, Video, etc.)
- Updates every 3 seconds (configurable via `updateInterval`)

### NPU Monitoring
- Reads `/sys/class/accel/accel0/device/power/runtime_status`
- Reports "Active" (100%) when NPU is running tasks
- Reports "Suspended" (0%) when NPU is idle/powered down
- Note: This is a simplified metric based on power state. More sophisticated NPU monitoring tools may become available as the platform matures.

## Verification

Check if GPU monitoring is working:
```bash
intel_gpu_top -s 1000
```

Check if NPU is detected:
```bash
lspci | grep -i NPU
ls -la /sys/class/accel/accel0/
```

## Troubleshooting

**GPU shows 0% usage:**
- Ensure `intel-gpu-tools` is installed: `pacman -Qs intel-gpu-tools`
- Test manually: `intel_gpu_top`
- Check GPU device: `ls /dev/dri/`

**NPU not detected:**
- Verify NPU device exists: `lspci | grep NPU`
- Check kernel module: `lsmod | grep intel_vpu`
- Verify sysfs path: `cat /sys/class/accel/accel0/device/power/runtime_status`

**High CPU usage from monitoring:**
- GPU monitoring uses `intel_gpu_top` which has minimal overhead
- Adjust `updateInterval` in config: `resources: { updateInterval: 5000 }` for 5 seconds

## Icons Used

- **GPU**: `stadia_controller` (Material Symbols)
- **NPU**: `neurology` (Material Symbols)

You can customize these icons in the respective QML files if preferred.
