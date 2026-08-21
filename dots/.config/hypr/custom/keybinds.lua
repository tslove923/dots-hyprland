-- Custom keybinds for Lua-mode Hyprland.
-- Repo is the source of truth; synced to ~/.config/hypr/custom/keybinds.lua.
-- Note: ./apply-custom.sh regenerates this file and drops hand-added binds below.

local scripts = HOME .. "/.config/hypr/custom/scripts"

-- Services
hl.bind("SUPER + ALT + I", hl.dsp.exec_cmd(scripts .. "/toggle_caffeine.sh"),
	{ description = "Services: Toggle suspend inhibit (caffeine)" })
hl.bind("SUPER + ALT + D", hl.dsp.exec_cmd(scripts .. "/toggle_docker.sh"),
	{ description = "Services: Toggle Docker" })
hl.bind("SUPER + ALT + B", hl.dsp.exec_cmd("alacritty -e bluetui"),
	{ description = "Services: Bluetooth TUI" })
hl.bind("SUPER + ALT + V", hl.dsp.exec_cmd(scripts .. "/vpn_toggle.sh"),
	{ description = "Services: Toggle VPN" })

-- Apps: Omarchy-style remaps (unbind upstream defaults first)
hl.unbind("SUPER + W") -- upstream default is browser
hl.unbind("SUPER + B") -- upstream default is left sidebar toggle
hl.bind("SUPER + W", hl.dsp.window.close(), { description = "Window: Close" })
hl.bind("SUPER + B", hl.dsp.exec_cmd(browser), { description = "App: Browser" })
hl.bind("SUPER + ALT + C", hl.dsp.exec_cmd(codeEditor), { description = "App: Code editor" })

-- Window focus: Alt-Tab switches to the previously focused window (cross-workspace)
hl.bind("ALT + Tab", function()
	local wins = hl.get_windows()
	table.sort(wins, function(a, b) return a.focus_history_id < b.focus_history_id end)
	if #wins >= 2 then
		hl.dispatch(hl.dsp.focus({ window = wins[2] }))
	end
end, { description = "Window: Focus previous (Alt-Tab)" })

-- Workspace Management
for i = 1, 10 do
	local key = i % 10
	hl.unbind("SUPER + SHIFT + " .. key)
	hl.bind("SUPER + SHIFT + " .. key, function()
		hl.dispatch(hl.dsp.window.move({ workspace = workspace_in_group(i), follow = true }))
	end, { description = "Window: Send to workspace " .. i .. " and follow" })
end

hl.bind("SUPER + ALT + Right", hl.dsp.focus({ workspace = "r+1" }),
	{ description = "Workspace: Next" })
hl.bind("SUPER + ALT + Left", hl.dsp.focus({ workspace = "r-1" }),
	{ description = "Workspace: Previous" })

-- Screensaver
hl.bind("SUPER + SHIFT + O", hl.dsp.exec_cmd("~/.local/bin/omarchy-launch-screensaver"),
	{ description = "Session: Screensaver" })
