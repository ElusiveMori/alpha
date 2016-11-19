AddCSLuaFile()

ENT.Type = "anim"

if (CLIENT) then
	function ENT:Draw()
		if (IsValid(self.instance)) then
			self.instance:ent_draw(self)
		end
	end
end

if (SERVER) then
	function ENT:Use(...)
		if (IsValid(self.instance)) then
			self.instance:ent_use(self, ...)
		end
	end

	function ENT:UpdateTransmitState()
		if (IsValid(self.instance)) then
			return self.instance:ent_update_transmit_state(self)
		end

		return TRANSMIT_NEVER
	end

	function ENT:OnRemove()
		if (IsValid(self.instance)) then
			self.instance:ent_remove(self)
			self.instance:delete()
		end
	end
end

function ENT:Initialize()
	if (CLIENT) then
		local instance = C.network:get_network_instance(self:GetNetworkID())

		if (IsValid(instance)) then
			self.instance = instance
		end
	end

	if (IsValid(self.instance)) then
		self.instance:ent_initialize(self)
	end
end

function ENT:Think()
	if (!IsValid(self.instance)) then
		local instance = C.network:get_network_instance(self:GetNetworkID())

		if (IsValid(instance)) then
			self.instance = instance
		end
	else
		self.instance:ent_think(self)
	end
end

function ENT:CalcAbsolutePosition(...)
	if (IsValid(self.instance)) then
		return self.instance:ent_calc_absolute_position(self, ...)
	end
end

function ENT:SetupDataTables()
	self:NetworkVar("Int", 31, "NetworkID")

	if (IsValid(self.instance)) then
		self.instance:ent_setup_data_tables(self)
	end
end

function ENT:PhysicsCollide(...)
	if (IsValid(self.instance)) then
		self.instance:ent_physics_collide(self, ...)
	end
end