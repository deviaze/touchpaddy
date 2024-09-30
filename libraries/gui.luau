--!strict
local process = require("@lune/process")

export type DialogOptions = {
	Title: string?,
	Text: string?,
	Buttons: {
		{
			ButtonText: string,
			ButtonResponse: string,
		}
	}?,
	List: {
		ListType: "Checklist" | "Tree" | "Radiolist" | "None" ?,
		Columns: { string },
		Entries: { { string } },
		Options: {
			Editable: boolean?,
			EditableColumns: { number }?,
			DoubleClickAction: string?,
		}?,
	}?,
	Size: {
		Width: number,
		Height: number,
	}?,
}

local function prompt(options: DialogOptions)
	local spawn_command = ""
	if options.Title then
		spawn_command ..= ` --title="{options.Title}" `
	end
	if options.Text then
		spawn_command ..= ` --text="{options.Text}" `
	end

	if options.Size then
		spawn_command ..= ` --width={options.Size.Width} --height={options.Size.Height}`
	end

	if options.List then
		local list_info = options.List
		spawn_command ..= ` --list {
			if list_info.ListType == "Checklist" then
				"--checklist"
			elseif list_info.ListType == "Tree" then
				"--tree"
			elseif list_info.ListType == "Radiolist" then
				"--radiolist"
			else "--multiple"
		}`

		local list_options = list_info.Options
		if list_options then
			if list_options.Editable then
				spawn_command ..= " --editable"
			end
			if list_options.EditableColumns then
				local cols = table.concat(list_options.EditableColumns, ",")
				spawn_command ..= ` --editable-cols="{cols}"`
			end
			if list_options.DoubleClickAction then
				spawn_command ..= ` --dclick-action={list_options.DoubleClickAction}`
			end
		end

		local column_count = 0
		for _, column_name in list_info.Columns do 
			spawn_command ..= ` --column="{column_name}"`
			column_count += 1
		end
		for index, entry in list_info.Entries do
			if #entry ~= column_count then
				error(`yad gui wrapper: entry {index} provided with invalid column count.\n Got {#entry} columns, expected {column_count} `)
			else
				for column_index, column_text in entry do
					entry[column_index] = `"{column_text}"`
				end
				spawn_command ..= ` {table.concat(entry, " ")} `
			end
		end
	end

	if options.Buttons then
		for _, button in options.Buttons do
			spawn_command ..= ` --button="{button.ButtonText}":"echo {button.ButtonResponse}"`
		end
	end

	local handler = process.create("yad " .. spawn_command, nil, { shell = true, stdio = "forward" })
	local button_response: string? = handler.stdout:read(200)
	if button_response then
		button_response = button_response:gsub("%s", "")
	end
	if handler.status().ok then
		handler.kill()
	end

	return button_response
end

return {
	prompt = prompt,
}