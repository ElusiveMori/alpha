do return end

local class = Class("realm")

class.index = class.index or {}

--[[ instance methods ]]

function class:constructor()
	self.entities = {}
	self.clients  = {}

	class.index[self] = self
end

function class:add_entity(entity)
	if (!self:is_instance()) then
		return
	end

	if (entity.realm != self) then
		if (entity.realm) then
			local old_realm = entity.realm

			entity.realm.entities[entity] = nil

			if (entity:IsPlayer()) then
				entity.realm.clients[entity] = nil
			end
		end

		entity.realm = self
		self.entities[entity] = entity

		if (entity:IsPlayer()) then
			self.clients[entity] = entity
		end

		-- make entity (in-)visible to realm citizens
		for _, realm in pairs(class.index) do
			if (realm != self) then
				for _, client in pairs(realm.clients) do
					if (IsValid(client)) then
						entity:SetPreventTransmit(client, true)
					else
						realm.clients[client] = nil
					end
				end
			else
				for _, client in pairs(realm.clients) do
					if (IsValid(client)) then
						entity:SetPreventTransmit(client, false)
					else
						realm.clients[client] = nil
					end
				end
			end
		end

		-- make realm citizens (in-)visible to client (if this entity is a client)
		if (entity:IsPlayer()) then
			for _, realm in pairs(class.index) do
				if (realm != self) then
					for _, citizen in pairs(realm.entities) do
						if (IsValid(citizen)) then
							citizen:SetPreventTransmit(entity, true)
						else
							realm.entities[citizen] = nil
						end
					end
				else
					for _, citizen in pairs(realm.entities) do
						if (IsValid(citizen)) then
							citizen:SetPreventTransmit(entity, false)
						else
							realm.entities[citizen] = nil
						end
					end
				end
			end
		end

		-- enable collisions for entity
		entity.old_custom_collision = entity:GetCustomCollisionCheck()
		entity:SetCustomCollisionCheck(true)
	end
end

function class:remove_entity(entity)
	if (!self:is_instance()) then
		return
	end

	if (entity.realm == self.realm) then
		entity.realm = nil
		self.entities[entity] = nil

		-- make entity visible to all realm citizens
		for _, realm in pairs(class.index) do
			for _, client in pairs(realm.clients) do
				if (client:IsValid()) then
					entity:SetPreventTransmit(client, false)
				else
					realm.clients[client] = nil
				end
			end
		end

		-- make all realm citizens visible to this client
		if (entity:IsPlayer()) then
			self.clients[entity] = nil
		
			for _, realm in pairs(class.index) do
				for _, citizen in pairs(realm.entities) do
					if (IsValid(citizen)) then
						citizen:SetPreventTransmit(entity, false)
					else
						realm.entities[citizen] = nil
					end
				end
			end
		end

		entity:SetCustomCollisionCheck(entity.old_custom_collision)
		entity.old_custom_collision = nil
	end
end

--[[ static methods ]]

--[[ class hooks ]]

function class:post_register()
	class:hook_add("ShouldCollide", class.should_collide)
	class:hook_add("EntityTakeDamage", class.entity_take_damage)
	class:hook_add("PlayerUse", class.player_use)
	class:hook_add("CanPlayerEnterVehicle", class.can_player_enter_vehicle)
	class:hook_add("EntityEmitSound", class.entity_emit_sound)

	class:hook_add("PlayerInitialSpawn", class.player_initial_spawn)

	if (alpha.debug) then
		concommand.Add("joinrealm", function(client, cmd, args)
			local realm = class:get_realm(args[1])

			if (realm) then
				realm:add_entity(client)
				client:ChatPrint("you joined realm " .. args[1])
			end
		end)

		concommand.Add("setrealm", function(client, cmd, args)
			local realm = class:get_realm(args[1])

			if (realm) then
				local entity = client:GetEyeTrace().Entity
				if (IsValid(entity)) then
					realm:add_entity(entity)
					client:ChatPrint("you added this entity to " .. args[1])
				end
			end
		end)

		concommand.Add("spawnmodel", function(client, cmd, args)
			//models/Combine_Helicopter/helicopter_bomb01.mdl
			local prop = ents.Create("prop_physics")
			prop:SetModel("models/Combine_Helicopter/helicopter_bomb01.mdl")
			prop:SetPos(client:GetEyeTrace().HitPos + Vector(0, 0, 48))
			prop:Spawn()
			class:get_realm(args[1] or "overworld"):add_entity(prop)
		end)

		concommand.Add("exitrealm", function(client, cmd, args)
			class:get_realm(client.realm_id):remove_entity(client)
		end)
	end
end

local function can_entities_interact(e1, e2)
	if (e1.realm and e2.realm) then
		return e1.realm == e2.realm
	else
		return true
	end
end

function class:should_collide(entity1, entity2)
	if (!can_entities_interact(entity1, entity2)) then
		return false
	end
end

function class:entity_take_damage(entity, damage_info)
	local attacker = damage_info:GetAttacker()
	local inflictor = damage_info:GetInflictor()

	if (!can_entities_interact(entity, attacker)) then
		return true
	end

	if (!can_entities_interact(entity, inflictor)) then
		return true
	end
end

function class:player_use(client, entity)
	if (!can_entities_interact(client, entity)) then
		return false
	end
end

function class:can_player_enter_vehicle(client, vehicle)
	if (!can_entities_interact(client, vehicle)) then
		return false
	end
end

function class:entity_emit_sound(data)

end

util.AddNetworkString("realm_sound")

function class:player_initial_spawn(client)
	class:get_realm("overworld"):add_entity(client)
end
