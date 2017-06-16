#module base.object
#using base.argcheck
#log

object.classes = object.classes or {}
object.meta    = object.meta or {}

local classes   = object.classes
local base_meta = object.meta

local next = next
local pairs = pairs
local setmetatable = setmetatable
local table = table
local hook = hook

base_meta.__index = base_meta
base_meta.data = {}

local function dummy() end

--[[ loop utilities ]]
 function iter_parents(class)
	local base = class.__all_parents

	local k, v = next(base)

	return function()
		local rv = v
		k, v = next(base, k)

		return rv
	end
end

function iter_children(class)
	local child = class.__all_children

	local k, v = next(child)

	return function()
		local rv = v
		k, v = next(child, k)

		return rv
	end
end

local iter_parents = iter_parents
local iter_children = iter_children

local recursive_copy = alpha.util.recursive_copy
local recursive_inherit = alpha.util.recursive_inherit

--[[
	 	metatable of base class
		basic functions and events
--]]

function base_meta:is_instance()
	return self.__index != self
end

function base_meta:get_class_id()
	return self.__class_id
end

function base_meta:get_class()
	return self.__index
end

function base_meta:delete()
	object.delete(self)
end

function base_meta:create(...)
	return object.create(self, ...)
end

function base_meta:derive_from(...)
	local args = {...}

	if (#args > 4) then
		log:error("more than 4 parents not supported")
		return
	end

	table.CopyFromTo(args, self.__parents)
end

function base_meta:is_instance_of(class_id)
	return self.__superclass_lookup[class_id] != nil
end

function base_meta:is_valid()
	return true
end

function base_meta:to_string()
	if (self:is_instance()) then
		return Format("[inst: %s]", self:get_class_id())
	else
		return Format("[class: %s]", self:get_class_id())
	end
end

function base_meta:hook_add(name, func)
	hook.Add(name, self, func)
end

function base_meta:hook_remove(name)
	hook.Remove(name, self)
end

function base_meta:base_call(id, func, ...)
	self.__parents[id][func](self, ...)
end

base_meta.constructor      = dummy
base_meta.post_constructor = dummy
base_meta.destructor       = dummy
base_meta.post_register    = dummy

function base_meta:construct_base(t, ...)
	for _, parent in pairs(self.__parents) do
		t = object.supercreate(parent, t, ...)

		if (!t) then
			return false
		end
	end

	return t or {data = {}}
end

base_meta.IsValid = function(t) return t:is_valid() end
base_meta.__tostring = function(t) return t:to_string() end

--[[ end of base_meta ]]

function object.new_class(id)
	local t = classes[id] or {}
	classes[id] = t

	local class_meta = {__index = base_meta}

	setmetatable(t, class_meta)

	-- internal fields

	t.__class_meta        = class_meta -- class metatable
	t.__parents           = {}  -- direct bases (defined by class)
	t.__class_id          = id  -- class id
	t.__index             = t   -- itself
	t.__all_parents       = {t} -- all class parents (including itself)
	t.__superclass_lookup = {[id] = t}
	t.__all_children      = {t} -- all class children (including itself)
	t.__tostring          = base_meta.__tostring

	-- default methods

	t.constructor      = function() end
	t.destructor       = function() end
	t.post_constructor = function() end

	-- default fields

	t.data = rawget(t, "data") or {}   -- copied onto all class instances

	log:debug("registered new class ", id)

	return t
end

_G.Class = {
	__call = function(self, ...) return object.new_class(...) end,
	__index = classes
}

_G.C = _G.Class

setmetatable(_G.Class, _G.Class)

function object.supercreate(class, t, ...)
	t = class:construct_base(t, ...)

	setmetatable(t, class)
	recursive_inherit(t.data, recursive_copy(class.data))

	-- if constructor returns false, it means that the construction failed
	if (t:constructor(...) == false) then
		return false
	end

	return t
end

function object.create(class, ...)
	class = (istable(class) and class.__index or isstring(class) and classes[class])

	if (IsValid(class)) then
		local success, t = pcall(object.supercreate, class, nil, ...)

		if (!success) then
			log:error("failed to create object of class [" .. class.__class_id .. "] due to error: " .. t)
			return false
		else
			if (t) then
				for parent in iter_parents(class) do
					parent.post_constructor(t)
				end

				return t
			else
				return false
			end
		end
	end
end

local function object_delete_internal(class, instance)
	if (!class) then
		class = instance.__index
	end

	setmetatable(instance, class)
	local success, msg = pcall(class.destructor, instance)

	if (!success) then
		log:error("destructor of class [" .. class.__class_id .. "] failed with error: " .. msg)
	end

	for k, parent in pairs(class.__parents) do
		object_delete_internal(parent, instance)
	end
end

function object.delete(instance)
	if (IsValid(instance)) then
		if (instance:is_instance()) then
			object_delete_internal(nil, instance)

			setmetatable(instance, nil)

			for k, v in pairs(instance) do
				instance[k] = nil
			end
		end
	end
end

object:hook_add("PostInitialize", function()
	for id, class in pairs(classes) do
		if (class.__parents) then
			for i, base in pairs(class.__parents) do
				if (!IsValid(classes[base])) then
					log:error("missing base [", base, "] in class [", id, "]")
				else
					class.__parents[i] = classes[base]
				end
			end
		end

		local base = class.__parents
		local class_meta = class.__class_meta

		if (#base == 1) then
			class_meta.__index = function(t, k) return base[1][k] end
		elseif (#base == 2) then
			class_meta.__index = function(t, k) return base[1][k] or base[2][k] end
		elseif (#base == 3) then
			class_meta.__index = function(t, k) return base[1][k] or base[2][k] or base[3][k] end
		elseif (#base == 4) then
			class_meta.__index = function(t, k) return base[1][k] or base[2][k] or base[3][k] or base[4][k] end
		end
	end

	for id, class in pairs(classes) do
		local queue = {}

		for k, v in pairs(class.__parents) do
			table.insert(queue, v)
		end

		while (#queue > 0) do
			local base = table.remove(queue, 1)

			for k, v in pairs(base.__parents) do
				table.insert(queue, v)
			end

			table.insert(class.__all_parents, base)
			table.insert(base.__all_children, class)
			class.__superclass_lookup[base.__class_id] = base
		end

		class.__all_parents = table.Reverse(class.__all_parents)
	end

	local sorted_parent_count = {}

	for id, class in pairs(classes) do
		table.insert(sorted_parent_count, class)
	end

	table.sort(sorted_parent_count, function(a, b)
		return #a.__all_parents > #b.__all_parents
	end)

	for _, class in pairs(sorted_parent_count) do
		for _, child in pairs(class.__parents) do
			recursive_inherit(child.data, class.data)
		end

		class:post_register()
	end

	hook.Call("PostObjectInitialize")
end)
