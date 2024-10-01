local process = require("@lune/process")
local task = require("@lune/task")

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
		retry: (self: AsyncResult) -> AsyncHandle,
	}

	function AsyncHandle.spawn(self: AsyncHandle, callback: (result: AsyncResult, handle: AsyncHandle) -> ())
		task.spawn(function()
			task.delay(if options and options.timeout then options.timeout else 1, function()
				pcall(function() -- we don't have a sensible way of determining whether process has completed or not; handle.status() yields so that's not what we want
					handle.kill()
				end)
			end)
			local stdout = handle.stdout:readToEnd()
			local stderr = handle.stderr:readToEnd()
			if #stdout > #stderr then
				callback({ 
					ok = true, 
					out = stdout 
				}, AsyncHandle)
			else
				callback({
					ok = false,
					err = stderr,
					retry = function(self: AsyncResult)
						return shellAsync(cmd, nil, { timeout = if options and options.timeout then options.timeout else 1 })
					end
				}, AsyncHandle)
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
		local result: string = handle.stdout:readToEnd()
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
	shell = shellExec,
	shellAsync = shellAsync,
}