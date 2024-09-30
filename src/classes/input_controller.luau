--!strict
local execs = require("@libraries/exec_async")
local envionment = require("@workspace/environment")
local shell = execs.shell
local shellAsync = execs.shellAsync

local Input = {}

export type InputController = typeof(Input)

local PlatformType = envionment.PlatformType

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

function Input.SendKeys(self: InputController, keystrokes: {string})
	if PlatformType.OS == "Linux" then
		if PlatformType.SessionType == "X11" then
			local parsed_keys = ""
			for index, key in keystrokes do
				if Input.Keys[key] then
					key = Input.Keys[key]
				end
				parsed_keys ..= key .. if index < #keystrokes then "+" else ""
			end
			local result = shellAsync(`xdotool key {parsed_keys}`):await()
			if result.ok then
				return true
			end
		end
	end
	return false
end

function Input.SendPaste(self: InputController, text: string)
	
end

return Input