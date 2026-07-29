-- Lua twin of touch.conf for Hyprland 0.55+ Lua config mode.
-- Loaded by require("custom.touch") from ~/.config/hypr/hyprland.lua
-- when the entry point's `is_file_exists` guard sees this file.
--
-- Requires:
--   - hyprgrass plugin (install via `hyprpm add https://github.com/horriblename/hyprgrass`)
--   - quickshell globals: sidebarRightToggle, sidebarLeftToggle, oskToggle
--
-- API verified against origin/fix/hypridle-lua-dispatch upstream Lua migration:
--   hl.dsp.global("quickshell:X") replaces hyprctl dispatch global quickshell:X
--   hl.dsp.window.move({workspace="special:S", follow=false}) replaces
--     movetoworkspacesilent special:S
--   hl.dsp.window.drag() / hl.dsp.window.resize() for mouse binds
-- Dispatchers without a native wrapper (overview:toggle, dpms, e-1 workspace)
-- still use hl.dsp.exec_cmd("hyprctl dispatch ...") as a safe fallback.

hl.config({
  plugin = {
    hyprgrass = {
      sensitivity = 4.0,
      long_press_delay = 400,
      resize_on_border_long_press = true,
      edge_margin = 10,
    },
  },
  gestures = {
    workspace_swipe_touch = true,
    workspace_swipe_cancel_ratio = 0.15,
  },
})

-- Edge swipes
hl.plugin.hyprgrass.bind {
  pattern = {kind = "edge", origin = "r", direction = "l"},
  action = hl.dsp.global("quickshell:sidebarRightToggle"),
}

hl.plugin.hyprgrass.bind {
  pattern = {kind = "edge", origin = "l", direction = "l"},
  action = hl.dsp.global("quickshell:sidebarRightToggle"),
}

hl.plugin.hyprgrass.bind {
  pattern = {kind = "edge", origin = "l", direction = "r"},
  action = hl.dsp.global("quickshell:sidebarLeftToggle"),
}

hl.plugin.hyprgrass.bind {
  pattern = {kind = "edge", origin = "l", direction = "d"},
  action = hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ -4%"),
}

hl.plugin.hyprgrass.bind {
  pattern = {kind = "edge", origin = "u", direction = "d"},
  action = hl.dsp.exec_cmd("pkill -SIGUSR2 nwg-drawer"),
}

hl.plugin.hyprgrass.bind {
  pattern = {kind = "edge", origin = "u", direction = "u"},
  action = hl.dsp.exec_cmd("pkill -SIGRTMIN+3 nwg-drawer"),
}

hl.plugin.hyprgrass.bind {
  pattern = {kind = "edge", origin = "d", direction = "u"},
  action = hl.dsp.global("quickshell:oskToggle"),
}

-- Multi-finger swipes
hl.plugin.hyprgrass.gesture {
  pattern = {kind = "swipe", fingers = 4, direction = "down"},
  action = "close",
}

hl.plugin.hyprgrass.bind {
  pattern = {kind = "swipe", fingers = 3, direction = "up"},
  action = hl.dsp.exec_cmd("hyprctl dispatch overview:toggle"),
}

-- Long-press window manipulation (mouse binds)
hl.plugin.hyprgrass.bind {
  pattern = {kind = "longpress", fingers = 2},
  action = hl.dsp.window.drag(),
  mouse = true,
}

hl.plugin.hyprgrass.bind {
  pattern = {kind = "longpress", fingers = 3},
  action = hl.dsp.window.resize(),
  mouse = true,
}

-- Touch-related keybinds (mirrors custom/keybinds.conf touch section)
hl.bind("SUPER + R",
  hl.dsp.exec_cmd("~/.config/hypr/custom/scripts/toggle-rotation.sh"))

hl.bind("SUPER + Z",
  hl.dsp.exec_cmd("bash -c 'voxd --trigger-record'"))

hl.bind("XF86PowerOff",
  hl.dsp.exec_cmd("hyprctl dispatch dpms off"),
  { locked = true })

hl.bind("SUPER + H",
  hl.dsp.window.move({ workspace = "special:minimized", follow = false }))

hl.bind("SUPER + U",
  hl.dsp.exec_cmd("hyprctl dispatch movetoworkspacesilent e-1"))