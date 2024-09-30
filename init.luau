#!lunestream run
-- thank you for using my luau gesture bindings :) may hina bless u
local process = require("@lune/process")
local environment = require("@workspace/environment")
local shell = require("@libraries/exec_async").shell

local lune_version = "lunestream"
local lune_version_result = shell("lune --version")
if lune_version_result.ok then
	local second_version_digit = lune_version_result.out:match("lune [%d]+[%.]([%d]+)[%.][%d]+")
	local major_version = tonumber(second_version_digit)
	-- process.exec/create should come out in lune 0.9.0+
	if major_version and major_version >= 9 then
		lune_version = "lune"
	end
end
if not shell('lunestream --help').ok then
	lune_version = "lune-process-stream"
end

if #process.args > 0 then
	if process.args[1] == "debug" then
		return require("./src/main.luau")
	elseif process.args[1] == "help" then
		local color = require("@lune/stdio").color
		print(`touchpaddy: libinput touchpad gestures\n Usage:\n  <lunestream | lune> run path_to_touchpaddy {color("cyan")}-- run as daemon (background){color("reset")}\n  <lunestream | lune> run path_to_touchpaddy debug {color("cyan")}-- run in current terminal{color("reset")}`)
		print(`if you need kill the touchpaddy background process (on linux), use {color("red")}pkill lunestream{color("reset")} (or substitute with the name of your lune executable; {color("red")}pkill lune{color("reset")}, {color("red")}pkill lune-process-stream{color("reset")}, etc.)`)
	else
		error("invalid args provided")
	end
else
	local screen_result = shell(`screen -dmS "touchpaddy" {lune_version} run ./src/main.luau`)
end


return  "" --require("./src/main.luau")