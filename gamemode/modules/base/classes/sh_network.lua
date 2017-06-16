#class network

--[[ shared definitions ]]

class.network_instances = class.network_instances or {}
class.network           = {}
class.delta_mode        = DELTA_NONE
class.hash_lookup       = {}

local recursive_copy    = alpha.util.recursive_copy
local recursive_inherit = alpha.util.recursive_inherit
local get_delta         = alpha.util.get_delta
local merge_delta       = alpha.util.merge_delta
local net_write_table   = alpha.util.net_write_table
local net_read_table    = alpha.util.net_read_table

function class:get_hash()
	return self.hash
end

function class:get_from_hash(hash)
	return class.hash_lookup[hash]
end

function class:get_network_id()
	if (self:is_instance()) then
		return self.network_id or -1
	end
end

function class:post_register()
	for child in iter_children(self) do
		child.hash = tonumber(util.CRC(child:get_class_id()))
		class.hash_lookup[child.hash] = child
	end
end

function class:get_network_instance(network_id)
	local instance = class.network_instances[network_id]

	if (IsValid(instance)) then
		return instance
	end
end

--[[ serverside definitions ]]

if (SERVER) then
	class.network_counter = class.network_counter or 1

	function class:constructor()
		self:assign_network_id()
		self.network = {}

		-- possible values for players in this table
		-- nil - not up to date at all (requires full update)
		-- 1 - has the last version that has been sent
		-- 2 - has the actual version (completely sync with server)
		self.up_to_date = {}
		self:hook_add("PlayerInitialSpawn", class.on_client_initial_spawn)
		self:hook_add("PlayerDisconnect", class.on_client_disconnect)

		class.network_instances[self.network_id] = self
	end

	function class:post_constructor()
		if (self.delta_mode > 0) then
			self.last_send = {}
		end

		-- call update here to allow autonetworking
		-- classes to propagate
		self:update()
	end

	function class:destructor()
		net.Start("network_object_remove")
			net.WriteUInt(self:get_network_id(), 32)
		net.Broadcast()
	end

	function class:get_new_network_id()
		class.network_counter = class.network_counter + 1

		return class.network_counter - 1
	end

	function class:assign_network_id()
		if (self:is_instance()) then
			self.network_id = class:get_new_network_id()
		end
	end

	local function send_delta_pp(instance, targets)
		for _, client in pairs(targets) do
			if (instance.up_to_date[client] == 2) then
				continue
			end

			local delta = get_delta(instance.last_send[client], instance.network)
			instance.last_send[client] = recursive_copy(instance.network)

			net.Start("network_object_update_delta")
				net.WriteUInt(instance:get_network_id(), 32)
				net.WriteUInt(instance:get_hash(), 32)
				net_write_table(delta)
			net.Send(client)

			instance.up_to_date[client] = 2
		end
	end

	local function send_delta_normal_full(instance, targets)
		for _, client in pairs(targets) do
			if (instance.up_to_date[client] != 2) then
				net.Start("network_object_update_full")
					net.WriteUInt(instance:get_network_id(), 32)
					net.WriteUInt(instance:get_hash(), 32)
					net.WriteTable(instance.network)
				net.Send(client)

				instance.up_to_date[client] = 2
			end
		end
	end

	local function send_delta_normal_partial(instance, targets)
		local delta

		for _, client in pairs(targets) do
			if (!instance.up_to_date[client]) then
				net.Start("network_object_update_full")
					net.WriteUInt(instance:get_network_id(), 32)
					net.WriteUInt(instance:get_hash(), 32)
					net.WriteTable(instance.network)
				net.Send(client)

				instance.up_to_date[client] = 2
			elseif (instance.up_to_date[client] == 1) then
				if (!delta) then
					delta = get_delta(instance.last_send, instance.network)
					instance.last_send = recursive_copy(instance.network)
				end

				net.Start("network_object_update_delta")
					net.WriteUInt(instance:get_network_id(), 32)
					net.WriteUInt(instance:get_hash(), 32)
					net_write_table(delta)
				net.Send(client)

				instance.up_to_date[client] = 2
			end
		end
	end

	local function send_delta_none(instance, targets)
		for _, client in pairs(targets) do
			if (instance.up_to_date[client]) then
				continue
			end

			net.Start("network_object_update_full")
				net.WriteUInt(instance:get_network_id(), 32)
				net.WriteUInt(instance:get_hash(), 32)
				net.WriteTable(instance.network)
			net.Send(client)

			instance.up_to_date[client] = 2
		end
	end

	function class:send(targets, is_full)
		if (self:is_instance()) then
			if (!targets) then
				targets = player.GetAll()
			elseif (!istable(targets)) then
				targets = {targets}
			end

			if (self.delta_mode == DELTA_PP) then
				send_delta_pp(self, targets)
			elseif (self.delta_mode == DELTA_NORMAL) then
				if (is_full) then
					send_delta_normal_full(self, targets)
				else
					send_delta_normal_partial(self, targets)
				end
			else
				send_delta_none(self, targets)
			end
		end
	end

	-- this should be called each time there have
	-- been changes to the network data
	-- otherwise there might be incorrect delta
	-- messages sent to players resulting in
	-- clients having wrong data
	function class:update()
		if (self.delta_mode == DELTA_NONE) then
			for client, state in pairs(self.up_to_date) do
				self.up_to_date[client] = nil
			end
		elseif (self.delta_mode == DELTA_NORMAL) then
			for client, state in pairs(self.up_to_date) do
				if (state == 2) then
					self.up_to_date[client] = 1
				elseif (state == 1) then
					self.up_to_date[client] = nil
				end
			end
		else
			for client, state in pairs(self.up_to_date) do
				if (state == 2) then
					self.up_to_date[client] = nil
				end
			end
		end

		self:on_update()
	end

	function class:send_message(clients, message_id, data)
		if (self:is_instance()) then
			if (!istable(clients)) then
				clients = {clients}
			end

			net.Start("network_object_message")
				net.WriteUInt(self:get_network_id())
				net.WriteString(message_id)
				net.WriteTable(data)
			net.Send(clients)
		end
	end

	function class:on_update()
	end

	function class:on_receive_message(client, message_id, data)
	end

	function class:on_client_initial_spawn(client)
		if (self.delta_mode == DELTA_PP) then
			self.last_send[client] = {}
		end
	end

	function class:on_client_disconnect(client)
		if (self.delta_mode == DELTA_PP) then
			self.last_send[client] = nil
			self.up_to_date[client] = nil
		end
	end
end

--[[ clientside definitions ]]

if (CLIENT) then
	function class:constructor(network_id)
		if (network_id and network_id > 0) then
			self.network_id = network_id
			self.network = {}

			class.network_instances[self.network_id] = self
		else
			return false
		end
	end

	function class:send_message(message_id, data)
		if (self:is_instance()) then
			net.Start("network_object_message")
				net.WriteUInt(self:get_network_id())
				net.WriteString(message_id)
				net.WriteTable(data)
			net.SendToServer()
		end
	end

	function class:get_hash()
		return self.hash
	end

	function class:get_network_id()
		if (self:is_instance()) then
			return self.network_id or -1
		end
	end

	function class:on_receive_message(message_id, data)
	end

	function class:on_update(data)
	end
end

if (SERVER) then
	util.AddNetworkString("network_object_message")
	util.AddNetworkString("network_object_update_full")
	util.AddNetworkString("network_object_update_delta")
	util.AddNetworkString("network_object_remove")

	net.Receive("network_object_message", function(len, client)
		local network_id = net.ReadUInt(32) or -1
		local instance = class:get_network_instance(network_id)

		if (instance) then
			local message_id = net.ReadString() or ""
			local data = net.ReadTable() or {}

			instance:on_network_message(client, message_id, data)
		end
	end)
end

if (CLIENT) then
	net.Receive("network_object_message", function(len)
		local network_id = net.ReadUInt(32) or -1
		local instance = class:get_network_instance(network_id)

		if (instance) then
			local message_id = net.ReadString() or ""
			local data = net.ReadTable() or {}

			instance:on_network_message(message_id, data)
		end
	end)

	net.Receive("network_object_update_delta", function(len)
		local network_id = net.ReadUInt(32) or -1
		local hash = net.ReadUInt(32) or 0
		local instance = class:get_network_instance(network_id)

		if (!IsValid(instance)) then
			local class = class:get_from_hash(hash)

			if (class) then
				instance = class:create(network_id)
			end

			if (!instance) then
				return
			end
		end

		merge_delta(instance.network, net_read_table())
		instance:on_update()
	end)

	net.Receive("network_object_update_full", function(len)
		local network_id = net.ReadUInt(32) or -1
		local hash = net.ReadUInt(32) or 0
		local instance = class:get_network_instance(network_id)

		if (!IsValid(instance)) then
			local class = class:get_from_hash(hash)

			if (class) then
				instance = class:create(network_id)
			end

			if (!instance) then
				return
			end
		end

		instance.network = net.ReadTable()
		instance:on_update()
	end)

	net.Receive("network_object_remove", function(len)
		local network_id = net.ReadUInt(32) or ""
		local instance = class:get_network_instance(network_id)

		if (IsValid(instance)) then
			instance:delete()
		end
	end)
end
