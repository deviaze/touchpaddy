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

local function shellExec(cmd: string, forward_stdio: boolean?): { ok: true, out: string} | { ok: false, err: string }
	local response = process.exec(cmd, nil, { shell = true, stdio = if forward_stdio then "forward" else nil })
	if response.ok then
		return {
			ok = true,
			out = response.stdout,
		}
	else
		return {
			ok = false,
			err = response.stderr,
		}
	end
end

local function shellAsync(cmd: string, options: {timeout: number?}?): AsyncHandle
	local handle = process.create(cmd, nil, { shell = true })
	local AsyncHandle = {
		start = os.clock(),
		cmd = cmd,
	}
	type AsyncHandle = typeof(AsyncHandle)

	type AsyncResult = {
		ok: true,
		out: string,
	} | {
		ok: false,
		err: string | "timeout",
		Retry: (self: AsyncResult) -> AsyncHandle,
	}

	function AsyncHandle.with(self: AsyncHandle, callback: (self: AsyncHandle, result: AsyncResult) -> ())
		task.spawn(function()
			task.delay(if options and options.timeout then options.timeout else 1, function()
				handle.kill()
			end)
			local stdout = handle.stdout:readToEnd()
			local stderr = handle.stderr:readToEnd()
			if #stdout > #stderr then
				callback(AsyncHandle, { 
					ok = true, 
					out = stdout 
				})
			else
				callback(AsyncHandle, {
					ok = false,
					err = stderr,
					Retry = function(self: AsyncResult)
						return shellAsync(cmd, nil, { timeout = if options and options.timeout then options.timeout else 1 })
					end
				})
			end
		end)
	end

	function AsyncHandle.connect(self: AsyncHandle, callback: (output: string?) -> ())
		local thread = task.spawn(function()
			while true do
				local new_text = handle.stdout:read()
			end
		end)
		return {
			Disconnect = function(self: AsyncHandle)
				task.cancel(thread)
			end
		}
	end

	function AsyncHandle.await(self: AsyncHandle)
		local result = handle.stdout:readToEnd()
		if result then
			return {
				ok = true,
				out = result,
			}
		else
			return {
				ok = false,
				err = ""
			}
		end
	end
	return AsyncHandle
end

return {
	async = execAsync,
	shell = shellExec,
	shellAsync = shellAsync,
	stderrs = current_exceptions,
}