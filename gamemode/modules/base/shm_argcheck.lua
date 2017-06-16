#module base.argcheck

alpha.preprocess.add_directive("check",
	function(a, b, c)
		print(a, b, c)
	end)

-- function argcheck:initialize()
-- 	function validate_type(arg, ...)
-- 		#if DEBUG then
-- 			local acceptable_types = {...}
--
-- 			local match = false
-- 			for _, arg_type in pairs(acceptable_types) do
-- 				if (type(arg) == arg_type) then
-- 					match = true
-- 					break
-- 				end
-- 			end
--
-- 			if (!match) then
-- 				error(string.format("Invalid argument, (%s) expected but got %s", table.concat(acceptable_types, ", "), type(arg)))
-- 			end
-- 		#end
-- 	end
--
-- 	function validate_subtype(arg, arg_type)
-- 		#if DEBUG then
-- 			assert(arg.is_instance_of != nil, "Invalid argument, expect an object but got something else")
-- 			assert(arg:is_instance_of(arg_type), "Invalid argument, object must be derived from " .. arg_type)
-- 		#end
-- 	end
-- end
