local process = require("@lune/process")
local task = require("@lune/task")

local current_exceptions = {}

local function execAsync(cmd: string)
	local result: string?
	local handle: process.ChildProcess?
	task.spawn(function()
		handle = process.create(cmd, nil, { shell = true })
		result = handle.stdout:readToEnd()
	end)
	return {
		Then = function(self: any, callback: (result: string) -> ())
			task.spawn(function()
				while result == nil do
					task.wait()
				end
				if result ~= nil then
					callback(result)
				end
			end)
		end,
		Await = function(self: any, timeout: number?): string
			local start_time = os.clock()
			while result == nil do
				task.wait()
				if timeout and os.clock() - start_time > timeout then
					break
				end
			end
			if result then
				return result
			else
				error(`process returned nil or broke somehow {cmd}`)
			end
		end,
	}
end

local function exec(cmd: string, forward: boolean?)
	local result = process.exec(cmd, nil, { shell = true, stdio = if forward then "forward" else nil })
	local stdout, stderr = result.stdout, result.stderr
	if result.code == 101 then -- rust panic
		return nil
	elseif not result.ok then
		table.insert(current_exceptions, stderr)
		return nil
	else
		return stdout
	end
end

return {
	Async = execAsync,
	Exec = exec,
	ReadLastError = function()
		if #current_exceptions > 0 then
			local last_error = current_exceptions[#current_exceptions]
			return last_error
		else
			return nil
		end
	end,
	stderrs = current_exceptions,
}