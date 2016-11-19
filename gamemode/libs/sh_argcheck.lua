local argcheck = Library "argcheck"

argcheck:add_dependency "object"
argcheck:add_dependency "settings"

function argcheck:initialize()
	alpha.settings:set_default("arg_validation", true)

	if (alpha.settings.arg_validation) then
		function validate_type(arg, arg_type) 
			assert(type(arg) == arg_type, string.format("Invalid argument, %s expect but got %s", arg_type, type(arg)))
		end

		function validate_subtype(arg, arg_type)
			assert(arg.is_instance_of != nil, "Invalid argument, expect an object but got something else")
			assert(arg:is_instance_of(arg_type), "Invalid argument, object must be derived from " .. arg_type)
		end
	else
		function validate_type()
		end

		function validate_subtype()
		end
	end
end