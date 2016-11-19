local class = Class("entity")

class.transmit_mode    = TRANSMIT_PVS
class.delta_mode       = DELTA_NONE
class.check_interval   = 0.1
class.check_next       = 0

class:derive_from("network")

local get_players_in_pvs = alpha.util.get_players_in_pvs

--[[ serverside definitions ]]

if (SERVER) then
	function class:constructor()
		self.entity = ents.Create("alpha_entity")

		if (!IsValid(self.entity)) then
			return false
		end

		self:hook_add("Tick", class.on_tick)

		self.network.entity_id = self.entity:EntIndex()
		self.entity.instance = self
		self.entity:SetNetworkID(self:get_network_id())
		self.entity:Spawn()
	end

	function class:destructor()
		if (IsValid(self.entity)) then
			self.entity:Remove()
		end
	end

	function class:get_entity()
		if (self:is_instance()) then
			return self.entity
		end
	end

	function class:is_valid()
		return (!self:is_instance()) or IsValid(self.entity)
	end

	function class:ent_use(entity) end

	function class:ent_update_transmit_state(entity)
		return self.transmit_mode
	end

	function class:on_tick()
	--[[
		if (class.check_next < CurTime()) then
			for _, client in pairs(player.GetAll()) do
				for _, entity in pairs(ents.FindInPVS(client:GetPos())) do
					if (entity:GetClass() == "alpha_entity") then
						local instance = entity.instance

						if (IsValid(instance) and instance.transmit_mode == TRANSMIT_PVS) then
							instance:send(client)
						end
					end
				end
			end

			class.check_next = CurTime() + class.check_interval
		end
	--]]
		if (self.transmit_mode == TRANSMIT_PVS) then
			for _, client in pairs(player.GetAll()) do
				if (client:TestPVS(self.entity)) then
					self:send(client)
				end
			end
		end
	end

	function class:on_update()
		if (self.transmit_mode == TRANSMIT_PVS) then
			self:send(get_players_in_pvs(self.entity))
		elseif (self.transmit_mode == TRANSMIT_ALWAYS) then
			self:send(player.GetAll())
		end
	end
end

--[[ clientside definitions ]]

if (CLIENT) then
	function class:get_entity()
		if (self:is_instance()) then
			return Entity(self.network.entity_id)
		end
	end

	function class:ent_draw(entity)
		entity:DrawModel()
	end
end

--[[ shared definitions ]]

function class:ent_initialize            (entity) end
function class:ent_think                 (entity) end
function class:ent_remove                (entity) end
function class:ent_calc_absolute_position(entity, pos, ang) return pos, ang end
function class:ent_setup_data_tables     (entity) end
function class:ent_physics_collide       (entity) end

