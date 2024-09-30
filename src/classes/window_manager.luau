--!strict
local task = require("@lune/task")

local process = require("@lune/process")
local fs = require("@lune/fs")

local execs = require("@libraries/exec_async")

local environment = require("@workspace/environment")
local shell = execs.shell
local shellAsync = execs.shellAsync

type WindowInfo = {
	Id: string,
	Name: string?,
	ClassName: string?,
	LastAccessTime: number,
}

local WindowManager = {
	TrackedWindows = {} :: { [string]: WindowInfo },
	LastActiveWindows = {} :: { string },
	ActiveWindowId = "",
}

type WindowManager = typeof(WindowManager)

function WindowManager.GetWindow(self: WindowManager, pattern: string): WindowInfo?
	for id, window_info in WindowManager.TrackedWindows do
		if
			window_info.Id == pattern
			or window_info.Name and window_info.Name == pattern
			or window_info.ClassName and window_info.ClassName == pattern
		then
			return window_info :: WindowInfo
		elseif
			window_info.Name and window_info.Name:match(pattern)
			or window_info.ClassName and (window_info.ClassName :: string):match(pattern)
		then
			return window_info :: WindowInfo
		end
	end
	return nil
end

local function getWindowInfo(window_id)
	local window_info = WindowManager.TrackedWindows[window_id]
	if not window_id then
		error(`window w/ provided window_id does not exist. id: {window_id}`)
	end
	return window_info
end

local PlatformType = environment.PlatformType

function WindowManager.ActivateWindow(self: WindowManager, window_id: string)
	if PlatformType.OS == "Linux" then
		if PlatformType.DesktopEnvironment == "KDE" then
			local result = shell(`kdotool windowactivate {window_id}`)
			if result.ok then
				return true
			end
		end
	else
		error("notimplementedexception")
	end
	return false
end

function WindowManager.MinimizeWindow(self: WindowManager, window_id: string)
	if PlatformType.OS == "Linux" then
		if PlatformType.DesktopEnvironment == "KDE" then
			local result = shell(`kdotool windowminimize {window_id}`)
			return if result.ok then true else false
		end
	end

	return false
end

function WindowManager.MaximizeWindow(self: WindowManager, window_id: string)
	if PlatformType.OS == "Linux" then
		if PlatformType.DesktopEnvironment == "KDE" then
			local result = shell(`xrandr | grep '*'`)
			if result.ok then
				local x, y = result.out:match("^[%s]*([%w]+)x([%w]+)%s") -- output in format "  1920x1080  60.00* ...."
				if x == nil or y == nil then
					error("error getting screen resolution with xrandr")
				end

				local screen_resolution = {
					x = tonumber(x),
					y = tonumber(y),
				}

				if screen_resolution.x and screen_resolution.y then
					local resized_success =
						self:ResizeWindow(window_id, { x = screen_resolution.x, y = screen_resolution.y })
					local moved_success = self:MoveWindow(window_id, { x = 0, y = 0 })

					if resized_success and moved_success then
						return true
					end
				end
			end
		end
	end

	return false
end

function WindowManager.MoveWindow(self: WindowManager, window_id: string, delta: { x: number, y: number })
	delta.x = delta.x // 1
	delta.y = delta.y // 1

	if PlatformType.OS == "Linux" then
		if PlatformType.DesktopEnvironment == "KDE" then
			local result = shell(`kdotool windowmove --relative {window_id} {delta.x} {delta.y}`)
			if result.ok then
				return true
			end
		end
	end

	return false
end

function WindowManager.ResizeWindow(self: WindowManager, window_id: string, size: { x: number, y: number })
	if PlatformType.OS == "Linux" then
		if PlatformType.DesktopEnvironment == "KDE" then
			local result = shell(`kdotool windowsize {window_id} {size.x} {size.y}`)
			if result.ok then
				return true
			end
		end
	end

	return false
end

function WindowManager.SnapWindow(self: WindowManager, window_id: string, side: "Left" | "Right")
	if PlatformType.OS == "Linux" then
		if PlatformType.DesktopEnvironment == "KDE" then
			-- get screen resolution
			local result = shell(`xrandr | grep '*'`) -- whomever names linux commands needs to stop tbh
			if result.ok then
				local x, y = result.out:match("^[%s]*([%w]+)x([%w]+)%s") -- matching output in format "  1920x1080  60.00* ...."
				if x == nil or y == nil then
					error("error getting screen resolution with xrandr")
				end

				local screen_resolution = {
					x = tonumber(x),
					y = tonumber(y),
				}

				if screen_resolution.x and screen_resolution.y then
					local resized_success =
						self:ResizeWindow(window_id, { x = screen_resolution.x, y = screen_resolution.y })
					local moved_success = self:MoveWindow(window_id, { x = 0, y = 0 })
					if resized_success and moved_success then
						return true
					end
				else
					error(`xrandr screenresolution not a number? xrandr output: {result.out}`)
				end
			end
		end
	end

	return false
end

function WindowManager.ShowTaskView()
	if PlatformType.OS == "Linux" then
		if PlatformType.DesktopEnvironment == "KDE" then
			shell("xdotool Ctrl+F9")
		end
	end
end

function WindowManager.Listen(self: WindowManager)
	if PlatformType.OS == "Linux" then
		if PlatformType.DesktopEnvironment == "KDE" then
			--[[
				KDE's KWin window manager interactive console can sometimes fail due to the hacky way we have to pass KWin scripts w/ kdotool:
					> kdotool converts cli commands into javascript KWin scripts at runtime
					> passes them to DBus pretending to be wmconsole
					> KWin executes window actions.
					* a bad script execution, race condition, or some other issue (idek tbh) can cause the wm interactive console to crash
				When this happens, our window management cli utility for KDE, kdotool, emits a rust panic (code: 101)
				Sometimes kdotool panics when KWin is recoverable, so we can just 'continue' and hope/assume kdotool won't panic
				on the next iteration, but if we've gotten multiple failures in a row, we can assume KWin is legitimately crashed 
				and we need to run a command to restart the KWin window manager:
					`kwin_wayland --replace` -- (yes you run it on x11 and wayland and KWin wmconsole can break on both iirc)
				Unfortunately that command *can* suddenly crash/close firefox and vscode on Wayland, so we need to alert the user
				to save their tabs/work before allowing us to restart the window manager
			]]
			local kwin_fail_count = 0

			local listener_thread = task.spawn(function()
				while task.wait(0.25) do
					local window_id_result = shellAsync("kdotool search"):await().out :: string?
					if window_id_result then
						if #window_id_result == 0 then
							-- kwin broke?
							kwin_fail_count += 1
							if kwin_fail_count > 10 then
								break
							end
						else
							local window_ids = window_id_result:split("\n")
						end
					end
				end
			end)
		end
	end
end

-- WindowManager:Listen()

return WindowManager
