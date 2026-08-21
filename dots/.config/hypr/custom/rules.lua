-- Custom rules for Lua-mode Hyprland.
-- This file is loaded from ~/.config/hypr/hyprland.lua when present.
-- Keep private app-specific rules here (for example, internal tools).

-- Example patterns:
-- hl.window_rule({ match = { class = "^(my-app)$" }, float = true })
-- hl.window_rule({ match = { class = "^(my-app)$" }, workspace = "special:special" })
-- hl.window_rule({ match = { title = "^(My Dialog)$" }, center = true })
-- hl.window_rule({ match = { title = "^(My Dialog)$" }, size = { "(monitor_w*0.50)", "(monitor_h*0.60)" } })

-- Fullscreen screensaver (Super+Shift+O). Upstream omarchy/default/hypr/apps/system.lua
-- sets these; the fork dropped them. Without fullscreen the terminal maps at 80x24,
-- which also stalls wait_for_terminal_resize inside omarchy-screensaver for up to 2s.
hl.window_rule({ match = { class = "org.omarchy.screensaver" }, fullscreen = true })
hl.window_rule({ match = { class = "org.omarchy.screensaver" }, float = true })
hl.window_rule({ match = { class = "org.omarchy.screensaver" }, animation = "slide" })
