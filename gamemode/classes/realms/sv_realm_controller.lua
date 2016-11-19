do return end

local class = Class("realm_controller")

class.index = class.index or {}

--[[ instance methods ]]

function class:constructor(id, depth)
	if (isstring(id) and isnumber(depth)) then
		if (class.index[id]) then
			return false
		end

		self.id = id
		self.depth = depth

		class.index[id] = self
	end
end

function class:get_realm(...)
	
end