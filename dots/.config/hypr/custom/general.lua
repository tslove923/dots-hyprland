-- Lua twin of custom/general.conf touch additions for Hyprland 0.55+.
-- Loaded by require("custom.general") from ~/.config/hypr/hyprland.lua.
--
-- Only contains the xwayland block added on archspectre. Merge with the
-- upstream general.lua when you switch to Lua mode.

hl.config({
  xwayland = {
    force_zero_scaling = true,
    use_nearest_neighbor = true,
  },
})