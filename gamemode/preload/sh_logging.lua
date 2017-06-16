local logger_meta = {}

logger_meta.__index = logger_meta

local function vararg_stringify(...)
	local args = {...}
	local str = ""

	for k, v in pairs(args) do
		local t = type(v)

		if (t == "Entity") then
			args[k] = (IsValid(v) and v:GetClass() or "NULL")
		elseif (t == "Player") then
			args[k] = (IsValid(v) and v:GetName() or "NULL")
		elseif (t == "Vector" or t == "Angle") then
			args[k] = Format("(%s, %s, %s)", v[1], v[2], v[3])
		elseif (t != "table") then
			args[k] = tostring(v)
		end
	end

	return unpack(args)
end

--[[
	Expected prefixes:
		info, warn, debug, error
--]]

local prefix_padding_length = 5

local sv_color = Color(145, 219, 231)
local cl_color = Color(231, 219, 116)

local function internal_print(self, prefix, ...)
	local args = {...}
	local time = os.date("%d/%m %H:%M:%S", os.time())


	table.insert(args, 1, Color(162, 195, 173))
	table.insert(args, 1, Format("[%s | %s | alpha - %s] ", time, prefix .. (" "):rep(prefix_padding_length - #prefix), self.tag))
	table.insert(args, 1, Color(59, 165, 93))

	if (CLIENT) then
		table.insert(args, 1, "CL | ")
		table.insert(args, 1, cl_color)
	else
		table.insert(args, 1, "SV | ")
		table.insert(args, 1, sv_color)
	end

	table.insert(args, "\n")

	MsgC(vararg_stringify(unpack(args)))
end

function logger_meta:info(...)
	internal_print(self, "info", ...)
end

function logger_meta:warn(...)
	internal_print(self, "warn", ...)
end

function logger_meta:debug(...)
	internal_print(self, "debug", ...)
end

function logger_meta:error(...)
	internal_print(self, "error", ...)
end

function alpha.logger(tag)
	local t = {}

	setmetatable(t, logger_meta)
	t.tag = tag

	return t
end

alpha.preprocess.add_directive("log",
	function(name)
		alpha.preprocess.inject(([[local log = alpha.logger("%s")]]):format(name or FILESHORT))
	end)
