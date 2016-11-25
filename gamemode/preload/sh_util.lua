alpha.util = alpha.util

NIL_TOKEN = NIL_TOKEN or {}

local recursive_inherit, recursive_copy, get_delta, merge_delta, net_write_table, net_read_table, get_players_in_pvs
local istable = istable
local pairs = pairs
local table = table
local NIL_TOKEN = NIL_TOKEN

recursive_inherit = function(target, source)
	for k, v in pairs(source) do
		if (istable(target[k]) and istable(v)) then
			recursive_inherit(target[k], v)
		elseif (target[k] == nil) then
			target[k] = v
		end
	end
end

recursive_copy = function(source, passed_list)
	local result = {}
	passed_list = passed_list or {}

	for k, v in pairs(source) do
		if (istable(v) and !passed_list[v]) then
			if (v == NIL_TOKEN) then
				result[k] = NIL_TOKEN
			else
				passed_list[v] = v
				result[k] = recursive_copy(v, passed_list)
			end
		else
			result[k] = v
		end
	end

	return result
end

get_delta = function(base, compare)
	local total_diff = {}

	for k, v in pairs(base) do
		if (compare[k] == nil) then
			total_diff[k] = NIL_TOKEN
		else
			if (istable(compare[k]) and istable(v)) then
				local diff = get_delta(v, compare[k])

				if (table.Count(diff) > 0) then
					total_diff[k] = diff
				end
			else
				if (istable(compare[k])) then
					total_diff[k] = recursive_copy(compare[k])
				else
					total_diff = compare[k]
				end
			end
		end
	end

	for k, v in pairs(compare) do
		if (!base[k] and !total_diff[k]) then
			if (istable(v)) then
				total_diff[k] = alpha.util.recursive_copy(v)
			else
				total_diff[k] = v
			end
		end
	end

	return total_diff
end

merge_delta = function(target, delta)
	for k, v in pairs(delta) do
		if (!target[k]) then
			target[k] = v
		elseif (v == NIL_TOKEN) then
			target[k] = nil
		elseif (istable(target[k]) and istable(v)) then
			merge_delta(target[k], v)
		else
			target[k] = v
		end
	end
end

local function write_type(t)
	if (t == NIL_TOKEN) then
		net.WriteType(nil)
	elseif (istable(t)) then
		net.WriteUInt(TYPE_TABLE, 8)
		net_write_table(t)
	else
		net.WriteType(t)
	end
end

local function read_type(t)
	t = t or net.ReadUInt(8)

	if (t == TYPE_TABLE) then
		return net_read_table()
	else
		return net.ReadType(t)
	end
end

net_write_table = function(data)
	for k, v in pairs(data) do
		write_type(k)
		write_type(v)
	end

	net.WriteType(nil)
end

net_read_table = function()
	local t = {}

	while (true) do
		local k = read_type()

		if (k == nil) then
			return t
		end

		local v = read_type()

		if (v == nil) then
			t[k] = NIL_TOKEN
		else
			t[k] = v
		end
	end

	return t
end

local function lookup_table(t)
	local new = {}

	for k, v in pairs(t) do
		new[v] = k
	end

	return new
end

local function get_players_in_pvs(any)
	local t = {}

	for k, v in pairs(ents.FindInPVS(any)) do
		if (v:IsPlayer()) then
			table.insert(t, v)
		end
	end

	return t
end

alpha.util = {
	recursive_copy = recursive_copy,
	recursive_inherit = recursive_inherit,
	get_delta = get_delta,
	merge_delta = merge_delta,
	net_write_table = net_write_table,
	net_read_table = net_read_table,
	get_players_in_pvs = get_players_in_pvs,
	lookup_table = lookup_table,
}

--[[
	local recursive_copy = alpha.util.recursive_copy,
	local recursive_inherit = alpha.util.recursive_inherit
	local get_delta = alpha.util.get_delta
	local merge_delta = alpha.util.merge_delta
	local net_write_table = alpha.util.net_write_table
	local net_read_table = alpha.util.net_read_table
]]