AddCSLuaFile()

local function collect_trace(level)
	level = level or 1
	local trace = {}
	local offset = 1
	local info = debug.getinfo(level + offset)

	while (info != nil) do
		if (info.what != "C" and !info.short_src:find("sh_exception")) then
			table.insert(trace, info)
		end

		level = level + 1
		info = debug.getinfo(level + offset)
	end

	return trace
end

function try(try_func)
	local t = {}

	t.catch = function(catch_func)
		local exception
		local trace

		local success, arg1, arg2, arg3, arg4 = xpcall(try_func, function(err)
			exception = err
			trace = collect_trace(1)
		end)

		if (!istable(exception)) then
			exception = new_exception(exception, "lua_error")
		end

		exception.trace = trace

		if (t.anyway_func) then
			t.anyway_func()
		end

		if (!success) then
			catch_func(exception)
		else
			return arg1, arg2, arg3, arg4
		end
	end

	-- this is called after main code, regardless of whether it threw an exception or not, but before the catch block
	-- this code should not throw exceptions, unless you want to obscure the original exception
	t.anyway = function(anyway_func)
		t.anyway_func = anyway_func

		return t
	end

	return t
end

local function get_trace_hash(trace)
	return util.CRC(tostring(trace.short_src) .. tostring(trace.currentline))
end

-- should rewrite this at some point to use a reversed stack trace (opposite of java)
function alpha.format_trace(trace, common_frames)
	local formatted = ""
	local max_line_length = 1

	for k, v in ipairs(trace) do
		local line = ("\n  >>%2i: @%s:%i"):format(k, v.short_src, v.currentline):gsub("gamemodes/", "")
		if (common_frames[get_trace_hash(v)]) then
			local all_common_after = true

			for i=k+1, #trace do
				if (!common_frames[get_trace_hash(trace[i])]) then
					all_common_after = false
					break
				end
			end

			if (all_common_after) then
				formatted = formatted .. ("\n... %i common frames omitted"):format(#trace - k + 1)
				break
			else
				formatted = formatted .. line
			end
		else
			common_frames[get_trace_hash(v)] = true
			formatted = formatted .. line
		end
	end

	return formatted
end

local exception_meta = {
	id = "runtime",
	message = "Generic runtime error",
	trace = {}
}

function exception_meta:__tostring()
	return alpha.stringify_exception(self, {})
end

exception_meta.__index = exception_meta

function new_exception(message, id, cause)
	local exception = {
		id = id,
		message = tostring(message):gsub("\n", ""),
		cause = cause
	}

	setmetatable(exception, exception_meta)

	return exception
end

function new_lua_exception(message)
	return new_exception(message, "lua")
end

function throw(exception, level)
	level = level or 1

	if (getmetatable(exception) != exception_meta) then
		exception = new_exception(tostring(exception))
	end

	error(exception, level + 1)
end

function alpha.stringify_exception(exception, common_frames)
	local result = ("%s%s"):format(exception.message, alpha.format_trace(exception.trace, common_frames))

	if (exception.cause) then
		result = result .. "\nCaused by: " .. alpha.stringify_exception(exception.cause, common_frames)
	end

	return result
end

function alpha.print_exception(message, exception)
	MsgC(Color(255, 0, 0), "[alpha-error] ", Color(255, 117, 117), message)

	local trace = tostring(exception) --:gsub("\n", "\n  ")

	for k, v in ipairs(string.Explode("\n", trace)) do
		MsgC(Color(255, 117, 117), v, "\n")
	end
end