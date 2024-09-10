--!strict
local process = require("@lune/process")
local task = require("@lune/task")

local executors = require("../libraries/exec_async.luau")
local execAsync = executors.Async
local exec = executors.Exec

local spawnDialog = require("../libraries/spawn_dialog.luau").Prompt

type WindowInfo = {
	WindowId: string,
	Name: string,
}

type WindowHelper = {
	CurrentWindows: { [string]: WindowInfo },
	GetWindow: (self: WindowHelper, pattern: string) -> WindowInfo?,
	ActivateWindow: (self: WindowHelper, window: string) -> (),
	MinimizeWindow: (self: WindowHelper, window: string) -> (),
	MoveWindow: (self: WindowHelper, window: string, delta: {x: number, y: number}) -> (),
	ResizeWindow: (self: WindowHelper, window: string, size: {x: number, y: number}) -> (),
	SnapWindow: (self: WindowHelper, window: string, side: "Left" | "Right") -> (),
}

local Windows = {
	CurrentWindows = {} :: { [string]:  WindowInfo },
	LastActiveWindows = {} :: { string },
	ActiveWindowId = "",
	GetWindow = function(self: WindowHelper, pattern: string): WindowInfo?
		for i, window in self.CurrentWindows do
			if window.Name:match(pattern) then
				return window
			end
		end
		return nil
	end,
	GetWindowName = function(self: WindowHelper, window_id: string): string?
		local result: string? = exec(`kdotool getwindowname {window_id}`)
		if result then
			return result
		end
		return nil
	end,
	ActivateWindow = function(self: WindowHelper, window: string)
		local window_id: string = ""
		if string.sub(window, 1, 1) == "{" then
			window_id = window
		else
			local get_id = self:GetWindow(window)
			if get_id then
				window_id = get_id.WindowId
			end
		end
		if window_id ~= "" then
			local success = exec(`kdotool windowactivate {window_id}`)
			return if success then true else nil
			-- print(reponse)
		end
		return nil
	end,
	MinimizeWindow = function(self: WindowHelper, window: string)
		local window_id: string = ""
		if string.sub(window, 1, 1) == "{" then
			window_id = window
		else
			local get_id = self:GetWindow(window)
			if get_id then
				window_id = get_id.WindowId
			end
		end
		if window_id ~= "" then
			local success = exec(`kdotool windowminimize {window_id}`)
			return if success then true else nil
		end
		return nil
	end,
	MaximizeWindow = function(self: WindowHelper, window: string)
		local window_id: string = ""
		if string.sub(window, 1, 1) == "{" then
			window_id = window
		else
			local get_id = self:GetWindow(window)
			if get_id then
				window_id = get_id.WindowId
			end
		end
		if window_id ~= "" then
			self:ResizeWindow(window, { x = 1920, y = 1080 })
			self:MoveWindow(window, { x = 0, y = 0 })
		end
		return nil
	end,
	SnapWindow = function(self: WindowHelper, window: string, side: "Left" | "Right")
		local window_id: string = ""
		if string.sub(window, 1, 1) == "{" then
			window_id = window
		else
			local get_id = self:GetWindow(window)
			if get_id then
				window_id = get_id.WindowId
			end
		end
		if window_id ~= "" then
			self:ResizeWindow(window_id, {
				x = 1920 // 2,
				y = 1080,
			})
			local width = 1920
			local height = 1080
			local x = if side == "Right" then width // 2 else 0
			local y = 0

			local success = exec(`kdotool windowmove {window_id} {x} {y}`)
			return if success then true else nil
		end
		return nil
	end,
	MoveWindow = function(self: WindowHelper, window: string, delta: {x: number, y: number})
		delta.x = delta.x // 1
		delta.y = delta.y // 1
		local window_id: string = ""
		if string.sub(window, 1, 1) == "{" then
			window_id = window
		else
			local get_id = self:GetWindow(window)
			if get_id then
				window_id = get_id.WindowId
			end
		end
		if window_id ~= "" then
			local success = exec(`kdotool windowmove --relative {window_id} {delta.x} {delta.y}`)
			if not success then
				-- print(delta)
				-- print(executors.ReadLastError())
			end
			return if success then true else nil
		end
		return nil
	end,
	ResizeWindow = function(self: WindowHelper, window: string, size: {x: number, y: number})
		local window_id: string = ""
		if string.sub(window, 1, 1) == "{" then
			window_id = window
		else
			local get_id = self:GetWindow(window)
			if get_id then
				window_id = get_id.WindowId
			end
		end
		if window_id ~= "" then
			local success = exec(`kdotool windowsize {window_id} {size.x} {size.y}`)
			if not success then
				-- print(delta)
				-- print(executors.ReadLastError())
			end
			return if success then true else nil
		end
		return nil
	end
}

local num_kwin_fails = 0


local function listen()
	task.spawn(function()
		while task.wait(0.35) do
			local windowids = execAsync(`kdotool search`):Await():split("\n")
			if #windowids == 0 then
				-- kwin broke
				break
			end
			for _, id in windowids do
				if #id > 0 then
					execAsync(`kdotool getwindowname {id}`):Then(function(window_name)
						if #window_name:gsub("%s", "") > 0 then
							if Windows.CurrentWindows[id] then
								Windows.CurrentWindows[id].Name = window_name:gsub("\n", "")
							elseif not window_name:match("plasma") and not window_name:match("Desktop @") then
								Windows.CurrentWindows[id] = {
									WindowId = id,
									Name = window_name:gsub("\n", ""),
								} :: WindowInfo
								table.insert(Windows.LastActiveWindows, 1, id) -- so there's more stuff to cycle thru
							end
						end
					end)
				end
			end


			local activewindowid: string? = exec(`kdotool getactivewindow`)
			if activewindowid then
				activewindowid = activewindowid:gsub("%s", "")
				if not Windows.CurrentWindows[activewindowid] then
					-- it's probably desktop or plasma or smth we don't want to switch to with gestures
					continue
				end

				local index = table.find(Windows.LastActiveWindows, activewindowid)
				if index and index ~= #Windows.LastActiveWindows then
					table.remove(Windows.LastActiveWindows, index)
					table.insert(Windows.LastActiveWindows, activewindowid)
				elseif index == nil then
					table.insert(Windows.LastActiveWindows, activewindowid)
				end

				Windows.ActiveWindowId = activewindowid

				if num_kwin_fails > 0 then
					num_kwin_fails = 0
				end
			else
				num_kwin_fails += 1
				if num_kwin_fails > 10 then -- kwin can fail with a panic but works again on subsequent iterations??? only if it's been failing multiple times in a row should be prompt restart of whole kwin
					break
				else
					continue
				end
			end
		end

		--- we'll only get here when the hacky way of executing KWin scripts breaks with the /Script error & requires a KWin restart.
		local result = spawnDialog {
			Title = "touchpaddy",
			Text = "Sorry, KWin crashed.. We need to run (kwin_wayland --replace) to restart KWin, but that might close VSCode/Firefox.",
			Buttons = {
				{
					ButtonText = "Okay, I've saved my work. Restart KWin",
					ButtonResponse = "restart"
				}, 
				{
					ButtonText = "Exit touchpaddy; I'll deal with KWin myself",
					ButtonResponse = "exit"
				}
			}
		} :: "restart" | "exit"
		
		if result == "restart" then
			exec("kwin_wayland --replace")
			listen()
		else
			process.exit()
		end

	end)
end

listen()

return Windows