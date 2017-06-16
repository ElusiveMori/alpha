#module base.argcheck

alpha.preprocess.add_directive("check",
	function(text)
		if (DEBUG) then
			alpha.preprocess.inject(([[validate_type(%s)]]):format(text))
		end
	end)

alpha.preprocess.add_directive("checksub",
	function(text)
		if (DEBUG) then
			alpha.preprocess.inject(([[validate_subtype(%s)]]):format(text))
		end
	end)

function validate_type(arg, ...)
	local acceptable_types = {...}

	local match = false
	for _, arg_type in pairs(acceptable_types) do
		if (type(arg) == arg_type) then
			match = true
			break
		end
	end

	if (!match) then
		error(string.format("Invalid argument, (%s) expected but got %s", table.concat(acceptable_types, ", "), type(arg)))
	end
end

function validate_subtype(arg, arg_type)
	assert(arg.is_instance_of != nil, "Invalid argument, expected an object but got something else")
	assert(arg:is_instance_of(arg_type), "Invalid argument, object must be derived from " .. arg_type)
end
