--!strict
-- this is a top-level state container, not really a .env equivalent!!
local process = require("@lune/process")

local execs = require("@libraries/exec_async.luau")
local gui = require("@libraries/gui")

local shell = execs.shell

local Environment = {}

type PlatformType = {
	OS: "Windows" | "Linux" | "MacOS",
	DesktopEnvironment: "Windows" | "KDE" | "GNOME" | "Other",
	SessionType: "X11" | "Wayland" | "Other",
}

Environment.PlatformType = {} :: PlatformType

if process.os == "linux" then
	local xdg_desktop_result = shell("echo $XDG_CURRENT_DESKTOP")
	local xdg_session_result = shell("echo $XDG_SESSION_TYPE")

	if xdg_desktop_result.ok and xdg_session_result.ok then
		Environment.PlatformType = {
			OS = "Linux",
			DesktopEnvironment = if xdg_desktop_result.out:match("KDE")
				then "KDE"
				elseif xdg_desktop_result.out:match("GNOME") then "GNOME"
				else "Other",
			SessionType = if xdg_session_result.out:match("x11")
				then "X11"
				elseif xdg_session_result.out:match("wayland") then "Wayland"
				else "Other",
		} :: any

		if Environment.PlatformType.DesktopEnvironment == "KDE" then
			-- assert we have the right deps installed
			local kdotool_ok = if shell("kdotool --help").ok then true else false
			local session_type = Environment.PlatformType.SessionType
			local xydotool_ok: boolean = if session_type == "X11"
				then shell("xdotool --help").ok
				elseif session_type == "Wayland" then shell("ydotool --help").ok
				else false

			if not kdotool_ok or not xydotool_ok then
				local columns = { "For", "Dependency", "Link (double click to copy)" } :: { string }
				local entries: { { string } } = {}
				if not kdotool_ok then
					table.insert(entries, {
						"KDE",
						"kdotool: lets us move and open/close and tab through your windows",
						"https://github.com/jinliu/kdotool",
					})
				end
				if not xydotool_ok then
					local entry = if Environment.PlatformType.SessionType == "X11"
						then {
							"X11",
							"xdotool: allows us to send kwin shortcuts by directly sending keystrokes",
							"https://github.com/jordansissel/xdotool",
						}
						elseif Environment.PlatformType.SessionType == "Wayland" then {
							"Wayland",
							"ydotool: allows us to send kwin shortcuts\n -- A Little More Annoying And Not As Reliable As xdotool! -- consider switching to X11 if needed",
							"https://github.com/ReimuNotMoe/ydotool",
						}
						else nil

					if entry then
						table.insert(entries, entry)
					end
				end

				if #entries > 0 then
					gui.prompt({
						Title = "touchpaddy - dependencies not found",
						Text = "We need the following programs !!\nPlease install them (package manager or PATH is ok!) and relaunch touchpaddy:",
						List = {
							ListType = "None",
							Columns = columns,
							Entries = entries,
							Options = {
								Editable = true,
								EditableColumns = { 3 },
							},
						},
						Buttons = {
							{
								ButtonText = "Ok fine",
								ButtonResponse = "",
							},
						},
						Size = {
							Width = 1260,
							Height = 200,
						},
					})
				end
				process.exit(1)
			end
		end
	end
elseif process.os == "windows" then
	Environment.PlatformType = {
		OS = "Windows",
		DesktopEnvironment = "Windows",
		SessionType = "Other",
	}
else
	error("Your operating system is not currently supported. Apologies!!")
end

Environment.WindowManagerHeartbeat = 0.15

return Environment
