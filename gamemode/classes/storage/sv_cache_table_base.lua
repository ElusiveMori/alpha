local log = alpha.logger("class/cache_table_base")
local class = Class("cache_table_base")

function class:constructor()
end

--[[
	sets what type of records this cache will produce and accept
	must be derived from cache_record_base
--]]
function class:set_record_class(record_class)
end

--[[
	indicates that a transaction should begin
	the underlying storage method does not guarantee to use this information whatsoever
	this should put off writing any information until :commit() is called
--]]
function class:begin()
end

--[[
	indicates that a transaction should end
--]]
function class:commit()
end