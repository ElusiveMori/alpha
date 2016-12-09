#logger

alpha.library = alpha.library or {}
local library = alpha.library

library.libraries = library.libraries or {}
library.meta      = library.meta or {}

local init_order = {}
local libraries = library.libraries
local library_meta = library.meta

library_meta.__index = library_meta

function library_meta:initialize()
end

function library_meta:shutdown()
end

function library_meta:hook_add(name, func)
	hook.Add(name, self.__name, func)
end

function library_meta:hook_remove(name)
	hook.Remove(name, self.__name)
end

function library_meta:add_dependency(name)
	self.__dependencies[name] = name
end

function library.get(name)
	if (libraries[name]) then
		return libraries[name]
	else
		local lib = {__name = name, __dependencies = {}, __dependants = {}}
		libraries[name] = lib
		alpha[name] = lib

		setmetatable(lib, library_meta)

		return lib
	end
end

_G.Library = library.get

-- init order is resolved with Kahn's algorithm
-- https://en.wikipedia.org/wiki/Topological_sorting#Kahn.27s_algorithm
alpha.include_directory(alpha.folder_name .. "/gamemode/libs")

for name, lib in pairs(libraries) do
	for _, dependency in pairs(lib.__dependencies) do
		if (!libraries[dependency]) then
			error(Format("dependency [%s] of library [%s] is missing", name, dependency))
		end

		libraries[dependency].__dependants[name] = name
	end
end

-- libraries which don't have any dependants
local leafs = {}

for name, lib in pairs(libraries) do
	if (!next(lib.__dependants)) then -- passes if table is empty
		table.insert(leafs, name)
	end
end

local sorted = {}

while (#leafs > 0) do
	local name = table.remove(leafs)
	local lib = libraries[name]

	table.insert(sorted, name)

	for _, dependency in pairs(lib.__dependencies) do
		lib.__dependencies[dependency] = nil
		libraries[dependency].__dependants[name] = nil

		if (!next(libraries[dependency].__dependants)) then
			table.insert(leafs, dependency)
		end
	end
end

for name, library in pairs(libraries) do
	if (next(library.__dependencies)) then
		local _, s = next(library.__dependencies)
		error(Format("cyclic dependency detected, no init will occur (%s, %s)", name, s))
	end
end

local init_order = table.Reverse(sorted)

log:debug("library init order: " .. table.concat(init_order, ","))

for _, name in ipairs(init_order) do
	log:debug(Format("initializing library \"%s\"", name))
	libraries[name]:initialize()
end

local function shutdown()
	for _, name in ipairs(table.Reverse(init_order)) do
		log:info(Format("shutting down library \"%s\"", name))
		libraries[name]:shutdown()
	end
end

hook.Add("ShutDown", "alpha_LibraryShutdown", function()
	log:info("shutting down...")
	shutdown()
end)
hook.Add("AlphaReload", "alpha_LibraryReload", shutdown)