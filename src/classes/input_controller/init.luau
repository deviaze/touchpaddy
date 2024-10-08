--!strict
local execs = require("@libraries/exec_async")
local envionment = require("@workspace/environment")
local shell = execs.shell
local shellAsync = execs.shellAsync

local Input = {}

export type InputController = typeof(Input)

local PlatformType = envionment.PlatformType

local LinuxKeys = require("linux_keys")

Input.Keys = {
	Win = if PlatformType.OS == "Windows" then "Win" else "Super_L",
	Meta = "Super_L",
	Super = "Super_L",
	Ctrl = "Control_L",
	Backspace = if PlatformType.OS == "Linux" then "BackSpace" else "Backspace",
	Esc = "Escape",
	Shift = if PlatformType.OS == "Linux" then "Shift_L" else "Shift",
	Alt = if PlatformType.OS == "Linux" then "Alt_L" else "Alt",
	PageUp = if PlatformType.OS == "Linux" then "Page_Up" else "PageUp",
}

--- Accepts string key combinations w/ plus + (ex. "Ctrl+C") and keys after another w/ comma ,
function Input.SendKeys(self: InputController, keycodes: string)
	if not keycodes or #keycodes == 0 or typeof(keycodes) == "table" then
		if typeof(keycodes) == "table" then
			print(`Input: attempt to pass table to Input:SendKeys; string expected`)
		elseif #keycodes == 0 then
			print('Input: attempt to pass "" to Input:SendKeys; string expected')
		elseif not keycodes then
			print('Input: attempt to pass nil | false into Input:SendKeys; string expected')
		end
		print(`Traceback: {debug.traceback(nil, 3)}`)
		return false
	end

	if PlatformType.OS == "Linux" then
		local key_downs_and_ups = LinuxKeys.parse(keycodes)
		if key_downs_and_ups then
			local result = shell(`ydotool key {key_downs_and_ups}`)
			if result.ok then
				return true
			end
		end
		return false
	end
	return false
end

function Input.SendPaste(self: InputController, text: string)
	
end

return Input