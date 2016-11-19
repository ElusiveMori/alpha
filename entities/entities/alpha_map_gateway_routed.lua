AddCSLuaFile()

ENT.Type = "anim"

-- dummy entity for use in maps
-- replaced by alpha_entity with class "realm_gateway_routed"
-- neccessary keyvalues:
-- gateway_id           - string
-- target_gateway(0-99) - string
-- source_realm(0-99)   - string
-- target_realm(0-99)   - string

function ENT:KeyValue(key, value)
	self.kv = self.kv or {}
	self.kv[key] = value

//	return false
end

if (SERVER) then
	hook.Add("InitPostEntity", "SetupGateways", function()
		for _, entity in pairs(ents.FindByClass("alpha_map_gateway_routed")) do
			local gateway_id = entity.kv.gateway_id
			if (gateway_id) then
				local gateway = C.realm_gateway_routed:create(gateway_id)

				if (IsValid(gateway)) then
					entity.gateway = gateway
					gateway:set_pos(entity:GetPos())
					gateway:set_ang(entity:GetAngles())
				end
			end
		end

		for _, entity in pairs(ents.FindByClass("alpha_map_gateway")) do
			if (entity.gateway) then
				local routes = {}

				for i=0, 99 do
					local s = tostring(i)

					local target_gateway = entity.kv["target_gateway" .. s]
					local source_realm   = entity.kv["source_realm"   .. s]
					local target_realm   = entity.kv["target_realm"   .. s]

					if (target_gateway and source_realm and target_realm) then
						print("setting route (" .. source_realm .. ", " .. entity.kv.gateway_id .. ") -> (" .. target_realm .. ", " .. target_gateway .. ")")
						routes[source_realm] = {target_realm, target_gateway}
					end
				end

				entity.gateway:load_routes(routes)
			end

			entity:Remove()
		end
	end)
end