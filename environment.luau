--!strict
-- this is a top-level state container, not really a .env equivalent!!
local process = require("@lune/process")

local execs = require("@libraries/exec_async.luau")
local gui = require("@libraries/gui")

local shell = execs.shell
local shellAsync = execs.shellAsync

local Environment = {}

local has_valid_lune_lunestream_version = if (process :: any).create then true else false
if not has_valid_lune_lunestream_version then
	local stdio = require("@lune/stdio")
	local color = stdio.color
	local b, r = color("blue"), color("reset")
	error(`{color("yellow")}touchpaddy requires lune-process-stream,\n or (if it's the future!), any version of Lune with process.create and process.exec (0.9.0+?){r}\n\n\z
	To install lunestream:\n\z
	{b}1{r}. clone {color("cyan")}https://github.com/0x5eal/lune-process-stream{r}\n\z
	{b}2{r}. build the repo with {color("green")}cargo b --release{r}\n\z
	{b}3{r}. rename the resulting binary {color("green")}"lunestream"{r}\n\z
	{b}4{r}. add lunestream to your PATH\n\z
	`)
end

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
			local dependencies: {[string]: {string}} = {
				yad = {"KDE", "yad: show guis", "https://github.com/v1cont/yad"},
				screen = {"touchpaddy", "screen: allows us to run in background/daemonize", "please install screen via package manager"},
				kdotool = {"KDE", "kdotool: lets us move, open/close, and tab through windows", "https://github.com/jinliu/kdotool"},
			}

			if Environment.PlatformType.SessionType == "X11" then
				dependencies.xdotool = {"X11", "xdotool: allows us to send keystrokes to control windows", "https://github.com/jordansissel/xdotool"}
			elseif Environment.PlatformType.SessionType == "Wayland" then
				dependencies.ydotool = {"Wayland", "ydotool: wayland alternative to xdotool! if issues, pls switch to X11", "https://github.com/ReimuNotMoe/ydotool"}
			end
			
			local dependencies_failed: { { string } } = {}
			for command, dependency_info in dependencies do 
				local success = shell(command .. " --help").ok
				if not success then
					table.insert(dependencies_failed, dependency_info)
				end
			end

			if #dependencies_failed > 0 then
				if table.find(dependencies_failed, dependencies.yad) then
					for _, dependency in dependencies_failed do
						print("Missing dependency: " .. table.concat(dependency, " | "))
					end
					process.exit(1)
				else
					local columns = { "For", "Dependency", "Link (double click to copy)" } :: { string }
					gui.prompt({
						Title = "touchpaddy - dependencies not found",
						Text = "We need the following programs !!\nPlease install them (package manager or PATH is ok!) and relaunch touchpaddy:",
						List = {
							ListType = "None",
							Columns = columns,
							Entries = dependencies_failed,
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
					process.exit(1)
				end
			end

			if Environment.PlatformType.OS == "Linux" then
				shellAsync("ydotoold")
				print("running ydotoold")
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
