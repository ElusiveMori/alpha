AddCSLuaFile()

alpha = alpha or {}
alpha.folder_name = "alpha"

include("sh_exception.lua")
include("sh_preprocess.lua")

try(function()
	function alpha.include(path)
		try(function()
			if (!file.Exists(path, "LUA")) then
				throw(new_exception(("no such file %s"):format(path), "include_exception"))
			end

			local filename = string.Explode('/', path)
			local prefix = filename[#filename]:sub(1, 3)

			if (SERVER) then
				if (prefix == "sh_" or prefix == "cl_") then
					AddCSLuaFile(path)
				end

				if (prefix == "sv_" or prefix == "sh_") then
					alpha.include_preprocess(path)
				end
			else
				if (prefix == "sh_" or prefix == "cl_") then
					alpha.include_preprocess(path)
				end
			end
		end).catch(function(exception)
			throw(new_exception(("error including file %s"):format(path), "include_exception", exception))
		end)
	end

	function alpha.include_directory(path)
		for _, filename in pairs(file.Find(path .. "/*.lua", "LUA")) do
			alpha.include(path .. "/" .. filename)
		end
	end

	function alpha.include_directory_recursive(path)
		local files, directories = file.Find(path .. "/*", "LUA")

		for _, filename in pairs(files) do
			alpha.include(path .. "/" .. filename)
		end

		for _, directory in pairs(directories) do
			alpha.include_directory_recursive(path .. "/" .. directory)
		end
	end

	alpha.include_directory(alpha.folder_name .. "/gamemode/preload")

	try(function()
		alpha.include(alpha.folder_name .. "/gamemode/init/sh_bootstrap.lua")
	end).catch(function(exception)
		throw(new_exception("bootstrap failed", "init_exception", exception))
	end)
end).catch(function(exception)
	alpha.print_exception("init failed with exception: ", exception)
end)
