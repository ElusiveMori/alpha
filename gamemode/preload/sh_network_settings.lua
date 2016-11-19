--[[
net_maxfilesize 64              // Max file size for downloading
net_maxcleartime 0              // Magic
net_splitrate 32                // Magic
net_splitpacket_maxrate 1048576 // 1MB/Sec (1048576)
rate 1048576                    // 1MB/Sec (1048576)
sv_timeout 30                   // 30 seconds
sv_max_connects_sec 1           // Disallow reconnect exploit
sv_maxrate 1048576              // Clamp rate
sv_minrate 1048576              // Clamp rate
sv_maxcmdrate 100               // Clamp cl_cmdrate
sv_mincmdrate 100               // Clamp cl_cmdrate
sv_maxupdaterate 100            // Clamp cl_updaterate
sv_minupdaterate 100            // Clamp cl_updaterate
sv_client_cmdrate_difference 0  // Clamp cmdrate between min/max
--]]

-- useful variables
-- sv_usermessage_maxsize - max umsg size per tick
-- lua_networkvar_bytespertick

local cmdrate   = 66
local rate      = 1048576
local splitrate = 32

local vars = {
	net_maxcleartime             = 0,
	net_splitrate                = splitrate,
	net_splitpacket_maxrate      = rate,
	sv_maxrate                   = rate,
	sv_minrate                   = rate,
	sv_maxcmdrate                = cmdrate,
	sv_mincmdrate                = cmdrate,
	sv_maxupdaterate             = cmdrate,
	sv_minupdaterate             = cmdrate,
	sv_client_cmdrate_difference = 0,
	host_limitlocal              = 1,
	net_usesocketsforloopback    = 1,
}

local cl_vars = {
	net_maxcleartime             = 0,
	net_splitrate                = splitrate,
	net_splitpacket_maxrate      = rate,
	rate                         = rate,
	host_limitlocal              = 1,
	net_usesocketsforloopback    = 1,
	cl_updaterate                = cmdrate,
	cl_cmdrate                   = cmdrate,
}

if (SERVER) then
	for k, v in pairs(vars) do
		RunConsoleCommand(k, v)
	end
end

if (CLIENT) then
	for k, v in pairs(cl_vars) do
		RunConsoleCommand(k, v)
	end
end