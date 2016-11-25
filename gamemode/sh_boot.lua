alpha = alpha or {}
alpha.folder_name = "alpha"
alpha.debug       = true

#DEBUG = true

function alpha.include(path)
	local filename = string.Explode('/', path)
	local prefix = filename[#filename]:sub(1, 3)

	if (SERVER) then
		if (prefix == "sh_" or prefix == "cl_") then
			AddCSLuaFile(path)
		end

		if (prefix == "sv_" or prefix == "sh_") then
			include_preprocess(path)
		end
	elseif (prefix == "sh_" or prefix == "cl_") then
		include_preprocess(path)
	end
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
	
#INJECT_LOGGER

if (SERVER) then
	require("mysqloo")
end

if (SERVER and !mysqloo) then
	log:warn("MySQLOO not detected - aborting!")
	return
end

-- This is just for padding
for i=1, 3 do
	log:info((". "):rep(i))
end

log:info("initialize starting...")
local start_time = SysTime()

if (alpha.loaded) then
	log:info("reload detected - unloading libraries...")
	hook.Call("AlphaReload")
	log:info("libraries unloaded.")
else
	alpha.loaded = true
end

log:info("loading libraries...")
alpha.include(alpha.folder_name .. "/gamemode/sh_library.lua")
log:info("libraries loaded.")

hook.Call("PostInitialize")
log:info("initialize finished.")
log:info(Format("init took %f seconds.", SysTime() - start_time))