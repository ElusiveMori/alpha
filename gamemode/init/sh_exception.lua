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
	return {
		catch = function(catch_func)
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

			if (!success) then
				catch_func(exception)
			else
				return arg1, arg2, arg3, arg4
			end
		end
	}
end

function alpha.format_trace(trace)
	local formatted = ""
	local max_line_length = 1

	for k, v in ipairs(trace) do
		formatted = formatted .. ("\n>>%2i: @%s:%i"):format(k, v.short_src, v.currentline):gsub("gamemodes/", "")
	end

	return formatted
end

local exception_meta = {
	id = "runtime",
	message = "Generic runtime error",
	trace = {}
}

function exception_meta:__tostring()
	local result = ("%s%s"):format(self.message, alpha.format_trace(self.trace))

	if (self.cause) then
		result = result .. "\nCaused by: " .. tostring(self.cause)
	end

	return result
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

function alpha.print_exception(message, exception)
	MsgC(Color(255, 0, 0), "[alpha-error] ", Color(255, 117, 117), message)

	local trace = tostring(exception):gsub("\n", "\n  ")

	for k, v in ipairs(string.Explode("\n", trace)) do
		MsgC(Color(255, 117, 117), v, "\n")
	end
end