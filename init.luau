#!lunestream run
--!strict
-- thank you for using my luau gesture bindings :) may hina bless u
local process = require("@lune/process")
local environment = require("@workspace/environment")
local shell = require("@libraries/exec_async").shell

local lune = (function() -- determine name of lune install
	local lune_version_result = shell("lune --version")
	local lune_major_version = if lune_version_result.ok
		then tonumber(lune_version_result.out:match("lune [%d]+[%.]([%d]+)[%.][%d]+")) -- gets x from "lune 0.x.8"
		else nil
	local has_lunestream = if shell("lunestream --help").ok then true else false
	local has_lune_process_stream = if shell("lune-process-stream --help").ok then true else false

	if lune_major_version and lune_major_version >= 9 then
		-- process.exec / process.spawn should come out in lune version >= 0.9.0
		return "lune"
	elseif has_lunestream then
		return "lunestream"
	elseif has_lune_process_stream then
		return "lune-process-stream"
	else
		error("error parsing lune version; is a version of lune/lunestream/lune-process-stream installed and added to PATH?")
	end
end)()

if #process.args > 0 then
	if process.args[1] == "debug" then
		return require("./src/main.luau")
	elseif process.args[1] == "help" then
		local color = require("@lune/stdio").color
		print(`touchpaddy: libinput touchpad gestures\n Usage:\n  <lunestream | lune> run path_to_touchpaddy {color("cyan")}-- run as daemon (background){color("reset")}\n  <lunestream | lune> run path_to_touchpaddy debug {color("cyan")}-- run in current terminal{color("reset")}`)
		print(`if you need kill the touchpaddy background process (on linux), use {color("red")}pkill {lune}{color("reset")}`)
	else
		error("invalid args provided")
	end
else
	local screen_result = shell(`screen -dmS "touchpaddy" {lune} run ./src/main.luau`)
	local stdio = require("@lune/stdio")
	print(`{stdio.color("green")}Launched touchpaddy as a background process!{stdio.color("reset")}\nIf something goes wrong, kill it with {stdio.color("red")}pkill {lune}{stdio.color("reset")}`)
end

return  "" :: any --require("./src/main.luau")