local process = require("@lune/process")

export type DialogOptions = {
	Title: string?,
	Text: string?,
	Buttons: {
		{
			ButtonText: string,
			ButtonResponse: string,
		}
	}?
}

local function spawnDialog(options: DialogOptions)
	local spawn_command = [[yad]]
	if options.Title then
		spawn_command ..= ` --title="{options.Title}" `
	end
	if options.Text then
		spawn_command ..= ` --text="{options.Text}" `
	end
	if options.Buttons then
		for _, button in options.Buttons do
			spawn_command ..= ` --button="{button.ButtonText}":"echo {button.ButtonResponse}"`
		end
	end

	local dialog_handler = process.create("yad " .. spawn_command, nil, { shell = true, stdio = "forward" })
	local button_response: string? = dialog_handler.stdout:read(10)
	if button_response then
		button_response = button_response:gsub("%s", "")
	end
	dialog_handler.kill()

	return button_response
end

return {
	Prompt = spawnDialog,
}
