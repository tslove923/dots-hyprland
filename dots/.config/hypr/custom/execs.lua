-- Lua twin of custom/execs.conf touch additions for Hyprland 0.55+.
-- Loaded by require("custom.execs") from ~/.config/hypr/hyprland.lua.
--
-- NOTE: This file only contains the touch-related exec-once lines added on
-- archspectre. Other execs (nm-applet, etc.) belong in the upstream or
-- TUI-generated execs.lua. Merge as needed when you switch to Lua mode.

hl.on("hyprland.start", function()
  -- Hyprland plugin manager — loads plugins declared in hyprload.toml,
  -- including hyprgrass (touch gestures). -n = non-interactive.
  hl.exec_cmd("hyprpm reload -n")

  -- Auto-rotate screen based on accelerometer input. Toggleable via
  -- ~/.config/hypr/rotation-toggle (see toggle-rotation.sh keybind).
  hl.exec_cmd("~/.config/hypr/custom/scripts/rotate-screen.sh")

  -- nwg-drawer in --refresh mode for swipe-gesture triggers
  -- (SIGUSR2 / SIGRTMIN+3).
  hl.exec_cmd("nwg-drawer -r")
end)