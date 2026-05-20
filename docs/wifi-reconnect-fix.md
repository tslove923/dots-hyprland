# WiFi Reconnect Fix

Fixes a bug where WiFi failed to reconnect after entering a new password.

## Problem

In `Network.qml`, after the user enters a WiFi password:
1. `wifiConnectTarget` was nulled immediately
2. `changePasswordProc` could not re-execute `nmcli connect` because the target was gone
3. Result: password saved but connection never re-attempted

## Fix

5-line change in `services/Network.qml`:
- Defer nulling `wifiConnectTarget` until after the connection attempt completes
- Call `.exec()` on `connectProc` instead of toggling `.running`
- Guard against null reference on retry path

## File

| File | Description |
|------|-------------|
| `services/Network.qml` | WiFi connection and password handling |

Path relative to `dots/.config/quickshell/ii/`.

## Status

This is a bug fix against upstream (end-4/dots-hyprland). The issue still exists in upstream as of the Lua migration.
