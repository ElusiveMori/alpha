#log

if (SERVER) then
	--require("mysqloo")
end

if (SERVER and !mysqloo) then
	--log:warn("MySQLOO not detected - aborting!")
	--return
end

-- This is just for padding
for i=1, 3 do
	log:info((". "):rep(i))
end

log:info("initialize starting...")
local start_time = SysTime()

if (alpha.loaded) then
	log:info("reload detected - unloading modules...")
	hook.Call("AlphaReload")
	log:info("modules unloaded.")
else
	alpha.loaded = true
end

log:info("loading modules...")
alpha.include("sh_module.lua")
log:info("modules loaded.")

hook.Call("PostInitialize")
log:info("initialize finished.")
log:info(Format("init took %f seconds.", SysTime() - start_time))