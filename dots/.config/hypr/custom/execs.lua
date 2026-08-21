-- Custom exec-once additions, loaded on top of hyprland/execs.lua.
-- hyprland/execs.lua already starts: geoclue, qs (bar), wallpaper, keyring,
-- hypridle, dbus-update-activation-environment, easyeffects, wl-paste
-- cliphist, and setcursor. Only put NEW autostarts here, otherwise things
-- (e.g. the quickshell bar) get started twice.

hl.on("hyprland.start", function ()
    -- Auto-rotate screen based on accelerometer input. Toggleable via
    -- ~/.config/hypr/rotation-toggle (see toggle-rotation.sh keybind).
    hl.exec_cmd("$HOME/.config/hypr/custom/scripts/rotate-screen.sh")
end)
