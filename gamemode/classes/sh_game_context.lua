local log = alpha.logger("class/game_context")
local class = Class("game_context")

local initialize_list

if (SERVER) then
	initialize_list = {
		"think_starter", "whitelist_filter", "debug_info"
	}
else
	initialize_list = {
		"debug_info"
	}
end

function class:constructor()
	for _, element in ipairs(initialize_list) do
		log:debug("initializing " .. element)
		self[element] = C[element]:create()
	end
end

function class:destructor()
	for _, element in ipairs(table.Reverse(initialize_list)) do
		log:debug("tearing down " .. element)
		self[element]:delete()
	end
end