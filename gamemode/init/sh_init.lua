AddCSLuaFile()

alpha = alpha or {}
alpha.directory_name = "alpha"

include("sh_exception.lua")
include("sh_preprocess.lua")

function new_include_exception(message, cause)
	return new_exception(message, "include_exception", cause)
end

try(function()
	local current_include_dir = alpha.directory_name .. "/gamemode/init/"

	-- accessor func for current_include_dir
	function alpha.pwd(path)
		if (pwd) then
			current_include_dir = path
		else
			return current_include_dir
		end
	end

	--[[
		This function separates a part into several components, such as
		file prefix, list of directories leading to it, and the name.
		For example:
		some/path/to/sh_test.lua -> {"some", "path", "to"}, "sh", "test"
	]]
	function alpha.parse_lua_filename(path)
		-- must end with .lua
		if (path:find(".lua$")) then
			-- just in case, normalize slashes
			path = path:gsub("\\", '/')
			local parts = string.Explode('/', path)
			local filename = parts[#parts]
			table.remove(parts)
			local prefix, name = filename:match("^([%w]+)_([%w_]+)%.lua")
			return parts, prefix, name
		end
	end

	function alpha.check_dir(path)
		if (file.IsDir(alpha.pwd() .. path, "LUA")) then
			return alpha.pwd() .. path
		elseif (file.IsDir(path, "LUA")) then
			return path
		end
	end

	function alpha.check_path(path)
		if (file.Exists(alpha.pwd() .. path, "LUA")) then
			return alpha.pwd() .. path
		elseif (file.Exists(path, "LUA")) then
			return path
		end
	end

	local function should_include_cl(prefix)
		return prefix == "sh" or
					prefix == "shm" or
					prefix == "cl" or
					prefix == "clm"
	end

	local function should_include_sv(prefix)
		return prefix == "sh" or
				 	prefix == "shm" or
					prefix == "sv" or
					prefix == "svm"
	end

	function alpha.include(path)
		local old_include_dir = alpha.pwd()
		local original_path = path

		try(function()
			-- check relative path first
			path = alpha.check_path(path)

			if (!path) then
				throw(new_include_exception(("no such file %s"):format(original_path)))
			end

			local trail, prefix = alpha.parse_lua_filename(path)
			alpha.pwd(table.concat(trail, '/') .. '/')

			if (SERVER) then
				if (should_include_cl(prefix)) then
					AddCSLuaFile(path)
				end

				if (should_include_sv(prefix)) then
					alpha.include_preprocess(path)
				end
			else
				if (should_include_cl(prefix)) then
					alpha.include_preprocess(path)
				end
			end
		end).anyway(function()
			alpha.pwd(old_include_dir)
		end).catch(function(exception)
			if (exception.id == "include_exception") then
				throw(exception)
			else
				throw(new_include_exception(("error including file %s"):format(original_path), exception))
			end
		end)
	end

	function alpha.include_directory(path)
		local original_path = path
		path = alpha.check_dir(path)

		if (!path) then
			throw(new_include_exception(("no such directory %s"):format(original_path)))
		end

		for _, filename in pairs(file.Find(path .. "/*.lua", "LUA")) do
			alpha.include(path .. "/" .. filename)
		end
	end

	function alpha.include_directory_recursive(path)
		local original_path = path
		path = alpha.check_dir(path)

		if (!path) then
			throw(new_include_exception(("no such directory %s"):format(original_path)))
		end

		local files, directories = file.Find(path .. "/*", "LUA")

		for _, filename in pairs(files) do
			alpha.include(path .. "/" .. filename)
		end

		for _, directory in pairs(directories) do
			alpha.include_directory_recursive(path .. "/" .. directory)
		end
	end

	alpha.include_directory(alpha.directory_name .. "/gamemode/preload")

	try(function()
		alpha.include("sh_bootstrap.lua")
	end).catch(function(exception)
		throw(new_exception("bootstrap failed", "init_exception", exception))
	end)
end).catch(function(exception)
	alpha.print_exception("init failed with exception: ", exception)
end)
