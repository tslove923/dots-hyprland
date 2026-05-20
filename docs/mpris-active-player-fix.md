# MPRIS Active Player Fix

Fixes media player selection so the currently playing source takes priority over paused/stopped players.

## Problem

The default `MprisController` could select a paused player (e.g. Spotify) while another source (browser media) was actively playing. This caused the media widget to show stale info.

## Fix

Prioritizes players by playback state: Playing > Paused > Stopped. Browser media players (Chromium, Firefox) are now properly detected and ranked.

## Files

| File | Description |
|------|-------------|
| `modules/ii/bar/Media.qml` | Active player display logic |
| `modules/ii/mediaControls/MediaControls.qml` | Player selection priority |
| `services/MprisController.qml` | Core player ranking algorithm |

All paths relative to `dots/.config/quickshell/ii/`.

## Details

The fix adds an `activePlayer` property that:
1. Monitors all MPRIS2 players on D-Bus
2. Ranks by playback state (Playing > Paused > Stopped)
3. Prefers browser players when multiple are in the same state
4. Updates immediately when playback state changes (no polling delay)
