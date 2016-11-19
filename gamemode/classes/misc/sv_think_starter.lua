--[[
	Necessary to make sure the think hook is running before first players join
--]]

local class = Class("think_starter")

function class:constructor()
	self:hook_add("InitPostEntity", self.init_post_entity)
end

function class:destructor()
	self:hook_remove("InitPostEntity")
end

function class:init_post_entity()
	RunConsoleCommand("bot")

	timer.Simple(0, function()
		for _, bot in pairs(player.GetBots()) do
			bot:Kick()
		end
	end)
end