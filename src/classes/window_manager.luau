--!strict
local task = require("@lune/task")

local process = require("@lune/process")
local fs = require("@lune/fs")

local environment = require("@workspace/environment")
local Input = require("@classes/input_controller")

local execs = require("@libraries/exec_async")
local shell = execs.shell
local shellAsync = execs.shellAsync

local gui = require("@libraries/gui")

type WindowInfo = {
	Id: string,
	Name: string?,
	ClassName: string?,
	LastAccessTime: number,
}

local WindowManager = {
	TrackedWindows = {} :: { [string]: WindowInfo },
	LastActiveWindows = {} :: { string },
	ActiveWindowId = "" :: string,
}

local PlatformType = environment.PlatformType

type WindowManager = typeof(WindowManager)

function WindowManager.GetActiveWindow(self: WindowManager): string?
	if PlatformType.OS == "Linux" then
		if PlatformType.DesktopEnvironment == "KDE" then
			local result = shell("kdotool getactivewindow")
			if result.ok then
				local window_id: string? = result.out:match("({[%w%-]+})")
				if window_id then
					return window_id
				end
			end
		end
	end
	return nil
end

function WindowManager.SwitchWindow(self: WindowManager, direction: "Left" | "Right")
	if PlatformType.OS == "Linux" then
		Input:SendKeys(
			if direction == "Left" then "Alt+Shift+Tab" else "Alt+Tab"
		)
	end
	return nil
end

function WindowManager.GetWindowInfo(self: WindowManager, pattern: string): WindowInfo?
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
	if PlatformType.OS == "Linux" then
		if PlatformType.DesktopEnvironment == "KDE" then
			local result = {
				Id = pattern,
			} :: WindowInfo
			local window_name_result = shellAsync(`kdotool getwindowname {pattern}`):await()
			if window_name_result.ok then
				result.Name = window_name_result.out:gsub("\n", "")
			else
				print(window_name_result)
			end
			local class_name_result = shellAsync(`kdotool getwindowclassname {pattern}`):await()
			if class_name_result.ok then
				result.ClassName = class_name_result.out:gsub("\n", "")
			end
			result.LastAccessTime = os.clock()
			WindowManager.TrackedWindows[pattern] = result
			return result
		end
	end
	return nil
end

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
			local result = shellAsync(`kdotool windowminimize {window_id}`):await()
			return if result.ok then true else false
		end
	end

	return false
end

function WindowManager.GetScreenResolution(self: WindowManager) -- unsure how this interacts w/ multimonitor setups atm
	if PlatformType.OS == "Linux" then
		local result = shell("xrandr | grep '*'") -- whomever names linux commands needs to stop tbh
		if result.ok then
			local x, y = result.out:match("^[%s]*([%w]+)x([%w]+)%s") -- output in format "  1920x1080  60.00* ...."
			if tonumber(x) and tonumber(y) then
				return {
					x = tonumber(x) :: number,
					y = tonumber(y) :: number,
				}
			end
		end
		error("error parsing screen resolution with xrandr")
	end
	error("error getting screen resolution")
end

function WindowManager.MaximizeWindow(self: WindowManager, window_id: string)
	if PlatformType.OS == "Linux" then
		if PlatformType.DesktopEnvironment == "KDE" then
			Input:SendKeys("Ctrl+PageUp")
		end
	end

	return false
end

function WindowManager.MoveWindow(self: WindowManager, window_id: string, position: { x: number, y: number })
	if PlatformType.OS == "Linux" then
		if PlatformType.DesktopEnvironment == "KDE" then
			local command = "kdotool windowmove " .. window_id
			if position.x <= 1 or position.y <= 1 then
				position.x *= 100; position.x //= 1
				position.y *= 100; position.y //= 1
				
				-- kdotool's rust code can handle percentages and strips the trailing %
				command ..= ` {position.x}% {position.y}%`
			else
				position.x //= 1 -- round to integers
				position.y //= 1

				-- and it also handles regular pixels if you don't give it a %
				command ..= ` {position.x} {position.y}`
			end
			local result = shell(command)
			if result.ok then
				return true
			else
				print(`issue moving window {window_id}: {result.err}`)
			end
		end
	end
	return false
end

function WindowManager.MoveWindowRelative(self: WindowManager, window_id: string, delta: { x: number, y: number })
	delta.x = delta.x // 1
	delta.y = delta.y // 1

	if PlatformType.OS == "Linux" then
		if PlatformType.DesktopEnvironment == "KDE" then
			local result = shell(`kdotool windowmove --relative {window_id} {delta.x} {delta.y}`)
			if result.ok then
				return true
			else
				print("issue moving window: " .. result.err)
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
			else
				print("issue resizing window:" .. result.err )
			end
		end
	end

	return false
end

function WindowManager.SnapWindow(self: WindowManager, window_id: string, side: "Left" | "Right")
	if PlatformType.OS == "Linux" then
		if PlatformType.DesktopEnvironment == "KDE" then
			Input:SendKeys("Meta+" .. side)
			return true
		end
	end

	return false
end

local task_view_shown = false

function WindowManager.ShowTaskView(self: WindowManager)
	if PlatformType.OS == "Linux" then
		if PlatformType.DesktopEnvironment == "KDE" then
			Input:SendKeys("Ctrl+F9")
		end
	elseif PlatformType.OS == "Windows" then
		Input:SendKeys("Win+Tab")
	end
	task_view_shown = true
end

function WindowManager.HideTaskView(self: WindowManager)
	Input:SendKeys("Esc")
	task_view_shown = false
end

WindowManager.Events = {}

local helper_fns = {}

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
					`kwin_wayland --replace` -- (yes.. you can run it on both x11 and wayland .. and KWin wmconsole can break on both iirc)
				Unfortunately that command *can* suddenly crash/close firefox and vscode on Wayland, so we need to alert the user
				to save their tabs/work before allowing us to restart the window manager
			]]
			local kwin_fail_count = 0

			local listener_thread = task.spawn(function()
				while task.wait(0.25) do
					-- search all currently open windows, add missing ones to TrackedWindows
					local search_result = shell("kdotool search")
					local kwin_success = if search_result.ok and #search_result.out > 0 then true else false
					if kwin_success then
						kwin_fail_count = 0
					else
						kwin_fail_count += 1
						if kwin_fail_count > 10 then
							helper_fns.kwin_broke()
							break
						else
							-- kdotool might fail/panic/return nothing on one iteration and be fine the next
							continue
						end
					end

					local window_ids: { string } = if search_result.ok then search_result.out:split("\n") else {}
					for _, window_id in window_ids do
						local tracked_window_info = WindowManager.TrackedWindows[window_id]
						if not tracked_window_info then
							WindowManager.TrackedWindows[window_id] = {
								Id = window_id,
								LastAccessTime = os.clock(),
							} :: WindowInfo
							tracked_window_info = WindowManager.TrackedWindows[window_id]
							shellAsync(`kdotool getwindowname {window_id}`):spawn(function(result)
								if result.ok and tracked_window_info then
									tracked_window_info.Name = result.out:gsub("\n", "")
								end
							end)
							shellAsync(`kdotool getwindowclassname {window_id}`):spawn(function(result)
								if result.ok and tracked_window_info then
									tracked_window_info.ClassName = result.out:gsub("\n", "")
								end
							end)
						end
						
					end

					-- Update ActiveWindowId
					local active_window_id: string? = WindowManager:GetActiveWindow()
					if active_window_id and WindowManager.ActiveWindowId ~= active_window_id then
						if task_view_shown then
							task_view_shown = false
						end
						WindowManager.ActiveWindowId = active_window_id
					elseif active_window_id then
						local tracked_active_window = WindowManager.TrackedWindows[active_window_id]
						if tracked_active_window then
							tracked_active_window.LastAccessTime = os.clock()
						end
					end
				end
			end)
		end
	end
end

function helper_fns.kwin_broke()
	local gui_result = gui.prompt {
		Title = "touchpaddy - kwin crash",
		Text = "Apologies, it seems KWin crashed.\nWe need to restart KWin (kwin_wayland --replace), but if you're on Wayland, restarting KWin might close Firefox, Code OSS/VSCode, other Wayland-dependent programs.",
		Buttons = {
			{
				ButtonText = "Okay, I've saved my work. Restart KWin",
				ButtonResponse = "restart",
			}, 
			{
				ButtonText = "Exit touchpaddy. I'll deal with KWin myself",
				ButtonResponse = "exit"
			}
		}
	} :: "restart" | "exit"
	if gui_result == "restart" then
		shell("kwin_wayland --replace")
	else
		process.exit(0)
	end
end

-- WindowManager:Listen()

return WindowManager
