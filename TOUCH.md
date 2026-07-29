# Touch support

Modular touch/gesture config merged from archspectre. Lives in
`dots/.config/hypr/custom/` so it's preserved across illogical-impulse updates.

## Files added

### Hyprlang (`.conf`) — active today

- `custom/touch.conf` — hyprgrass plugin block (gestures, edge swipes, OSK toggle, long-press)
- `custom/scripts/rotate-screen.sh` — auto-rotate via `monitor-sensor`
- `custom/scripts/toggle-rotation.sh` — toggles `~/.config/hypr/rotation-toggle`

### Lua twins — activate when you switch to `hyprland.lua`

- `custom/touch.lua` — `hl.config({plugin={hyprgrass={...}}})` + `hl.plugin.hyprgrass.bind/gesture` calls + touch keybinds
- `custom/execs.lua` — `hl.on("hyprland.start", ...)` for hyprpm/rotate-screen/nwg-drawer
- `custom/general.lua` — `hl.config({xwayland={...}})`
- `custom/env.lua` — `hl.env("EDITOR", "vim")`

## Files modified

- `hyprland.conf` — sources `custom/touch.conf` between `general.conf` and `keybinds.conf`, wrapped in `# hyprlang noerror true` so machines without hyprgrass don't crash
- `custom/keybinds.conf` — `##! Touchscreen & Rotation` section appended (Super+R, Super+Z, XF86PowerOff, Super+H, Super+U)
- `custom/execs.conf` — `hyprpm reload -n`, `rotate-screen.sh`, `nwg-drawer -r`
- `custom/general.conf` — `xwayland { force_zero_scaling, use_nearest_neighbor }`
- `custom/env.conf` — `EDITOR=vim` uncommented

## Enabling on a new machine

```bash
# 1. Install hyprgrass plugin
hyprpm add https://github.com/horriblename/hyprgrass
hyprpm enable hyprgrass

# 2. Install runtime deps
yay -S wvkbd nwg-drawer monitor-sensor

# 3. Reboot or restart Hyprland so hyprpm reload -n picks up hyprgrass
```

## Disabling on machines without a touchscreen

Nothing to do — `custom/touch.conf` is wrapped in `# hyprlang noerror true`,
so if the hyprgrass plugin isn't loaded the gestures block silently no-ops.
To fully remove: delete `custom/touch.conf` and the matching `source=` line
in `hyprland.conf`. Same for `custom/touch.lua` on the Lua side.

## Switching to Lua mode (Hyprland 0.55+)

When `~/.config/hypr/hyprland.lua` exists, Hyprland stops reading
`hyprland.conf` entirely — `.conf` files are dead from that point on.

The repo now ships a full Lua migration pulled from the upstream
`fix/hypridle-lua-dispatch` branch:

- `hyprland.lua` — entry point; `is_file_exists`-guards each `require("custom.X")`
- `hyprland/lib/init.lua` — helpers (`is_file_exists`, `workspace_in_group`)
- `hyprland/services/` — `create_custom_config.lua` bootstraps missing custom files
- `hyprland/{env,execs,general,rules,colors,keybinds,variables}.lua` — upstream twins
- `hyprland/shellOverrides/main.lua` — shell overrides
- `custom/touch.lua` — hyprgrass + gesture binds + touch keybinds (this repo's addition)

The entry point already does `require("custom.touch")` when `custom/touch.lua`
exists — no edit needed. `custom/touch.lua` uses native `hl.dsp.global(...)`
for quickshell dispatchers, `hl.dsp.window.move({workspace=..., follow=false})`
for `movetoworkspacesilent special:minimized`, and `hl.dsp.window.drag()` /
`hl.dsp.window.resize()` for long-press mouse binds. `overview:toggle`,
`dpms off`, and `movetoworkspacesilent e-1` still go through `hl.dsp.exec_cmd`
as a fallback (no native wrapper found in `hyprland/lib/init.lua`).

To activate on a machine: copy/symlink the `hyprland.lua` + `hyprland/*.lua`
files into `~/.config/hypr/` (alongside the existing `.conf` files is fine —
Hyprland prefers `.lua`). Restart Hyprland.

## Notes

- `$qsConfig = ii` is set upstream in `hyprland/variables.conf` — no action needed.
- The `exec = hyprctl dispatch submap global` / `submap = global` lines from
  archspectre's old `hyprland.conf` aren't needed in the new format — the
  repo's keybinds work without them.
- `monitors.conf` (home monitor layout) and the `$TIME12` hyprlock tweak
  are machine-specific and not committed here.
- `.conf` format is deprecated in Hyprland 0.55+ but supported for 1–2 more
  releases. After that, Lua becomes the only option — the twins above are
  the migration path.