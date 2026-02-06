# AI Assistant Wake Word Detector - Build Instructions

## Quick Start

```bash
cd ~/projects/dots-hyprland-dev/ai-assistant/wake-word

# Build and install
make install

# Enable and start service
make enable
make start

# Check status
make status
make logs
```

## Build System

This package uses the same build pattern as voxd-npu:

### Cached Virtual Environment
- **First build**: ~2-3 minutes (downloads and installs all dependencies)
- **Subsequent builds**: ~5-10 seconds (reuses cached venv)
- **Cache key**: `_dep_hash` in PKGBUILD (change when dependencies update)

### Cache Location
```
.cached_venv_v1_ov2025.4.1_oww0.6.0/
```

### Build Targets

```bash
make build        # Build package (fast with cache)
make install      # Build + install with pacman
make clean        # Remove build artifacts (keeps cache)
make clean-all    # Remove everything (forces full rebuild)
```

## Installation

### Manual Build
```bash
makepkg -sfi
# -s: sync dependencies
# -f: force rebuild
# -i: install after build
```

### From Package
```bash
makepkg -sf
sudo pacman -U ai-assistant-wake-word-npu-*.pkg.tar.zst
```

## Service Management

```bash
# Enable at boot
systemctl --user enable ai-assistant-wake-word

# Start service
systemctl --user start ai-assistant-wake-word

# Check status
systemctl --user status ai-assistant-wake-word

# View logs
journalctl --user -u ai-assistant-wake-word -f

# Stop service
systemctl --user stop ai-assistant-wake-word
```

## Configuration

Edit `/etc/ai-assistant/wake-word.conf`:

```bash
# Device selection
DEVICE=NPU        # NPU, GPU, or CPU

# Sensitivity
THRESHOLD=0.5     # 0.0-1.0 (lower = more sensitive)

# Wake words
WAKE_WORDS=hey_assistant
```

Restart service after changes:
```bash
make restart
```

## Cache Management

### When to Invalidate Cache

Update `_dep_hash` in PKGBUILD when you:
- Upgrade OpenVINO version
- Upgrade openwakeword version
- Add/remove Python dependencies
- Change dependency versions

Example:
```bash
# Old: _dep_hash="v1_ov2025.4.1_oww0.6.0"
# New: _dep_hash="v2_ov2025.5.0_oww0.7.0"
```

### Manual Cache Control

```bash
# Keep cache (fast rebuilds)
make build

# Force full rebuild
make clean-all
make build
```

## Uninstall

```bash
make uninstall

# Or manually
systemctl --user stop ai-assistant-wake-word
systemctl --user disable ai-assistant-wake-word
sudo pacman -R ai-assistant-wake-word-npu
```

## Troubleshooting

### Cache Issues
```bash
# Remove cache and rebuild
make clean-all
make install
```

### Permission Issues
```bash
# Ensure scripts are executable
chmod +x wake_word_detector_npu.py build.sh
```

### Service Not Starting
```bash
# Check logs
journalctl --user -u ai-assistant-wake-word -n 50

# Test manually
ai-assistant-wake-word
```

### Microphone Not Found
```bash
# List audio devices
arecord -l

# Test recording
arecord -d 5 test.wav && aplay test.wav
```

## Performance

### Expected Build Times

| Scenario | Time | Notes |
|----------|------|-------|
| First build | 2-3 min | Downloads all deps |
| Cached rebuild | 5-10 sec | Reuses venv |
| Code-only change | 3-5 sec | Only copies scripts |

### Runtime Performance

| Metric | Value |
|--------|-------|
| Latency (NPU) | 20-30ms |
| Latency (CPU) | 80ms |
| CPU usage (NPU) | <2% |
| CPU usage (CPU) | 5-10% |
| Memory | ~100MB |

## Development Workflow

```bash
# Edit code
vim wake_word_detector_npu.py

# Quick test without install
./wake_word_detector_npu.py

# Rebuild and install
make install

# Restart service
make restart

# Check logs
make logs
```

## Comparison with voxd-npu

Both packages use the same build pattern:

| Feature | voxd-npu | wake-word-npu |
|---------|----------|---------------|
| Venv location | `/opt/voxd-npu/venv` | `/opt/ai-assistant-wake-word/venv` |
| Wrapper | `/usr/local/bin/voxd` | `/usr/local/bin/ai-assistant-wake-word` |
| Cache key | Build-specific | Dependency hash |
| OpenVINO | ✅ 2025.4.1 | ✅ 2025.4.1 |
| Fast rebuild | ✅ Cached venv | ✅ Cached venv |
