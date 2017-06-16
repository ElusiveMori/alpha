AddCSLuaFile()

local function new_preprocess_parse_exception(message, cause)
	return new_exception(message, "preprocess_parse", cause)
end

local function new_preprocess_compile_exception(path, cause)
	return new_exception(("error compiling preprocessor script of file %s"):format(path), "preprocessor_exception", cause)
end

local function new_preprocess_execute_exception(path, cause)
	return new_exception(("error running preprocessor script of file %s"):format(path), "preprocessor_exception", cause)
end

local function new_postprocess_compile_exception(path, cause)
	return new_exception(("error compiling postprocessed file %s"):format(path), "preprocessor_exception", cause)
end

local function new_postprocess_execute_exception(path, cause)
	return new_exception(("error running postprocessed file %s"):format(path), "preprocessor_exception", cause)
end

alpha.preprocess = alpha.preprocess or {}
local preprocess = alpha.preprocess

preprocess.directives = preprocess.directives or {}
local directives = preprocess.directives

local context_stack = {}
function preprocess.push_context()
	local context = {
		FILE = FILE,
		PATH = PATH,
		FILESHORT = FILESHORT,
		RESULT = RESULT,
	}

	table.insert(context_stack, context)
end

function preprocess.pop_context()
	local context = table.remove(context_stack)

	for k, v in pairs(context) do
		_G[k] = v
	end
end

function preprocess.reset_result()
	RESULT = ""
end

function preprocess.write_enabled(line)
	RESULT = RESULT .. line
end

function preprocess.write_disabled(line)
	RESULT = RESULT .. string.gsub("\n", "\n//")
end

preprocess.write = preprocess.write_enabled
preprocess.condition_stack = {}

function preprocess.inject(lines)
	preprocess.write(lines:gsub("\n", " "))
end

function preprocess.check_stack()
	for _, condition in pairs(preprocess.condition_stack) do
		if (condition == false) then
			return false
		end
	end

	return true
end

function preprocess.update_write()
	if (preprocess.check_stack()) then
		preprocess.write = preprocess.write_enabled
	else
		preprocess.write = preprocess.write_disabled
	end
end

function preprocess.default_arg_parse(str)
	local args = {}

	for arg in str:gmatch("[^%s]+") do
		table.insert(args, arg)
	end

	return table.concat(args, ",")
end

function preprocess.vararg_arg_parse(str)
	local args = {}

	for arg in str:gmatch("[^%s]+") do
		table.insert(args, arg)
	end

	return unpack(args)
end

function preprocess.parse_directive_args(directive, str)
	if (directives[directive]) then
		if (directives[directive].parse) then
			return directives[directive].parse(str)
		else
			return preprocess.default_arg_parse(str)
		end
	else
		throw(new_preprocess_parse_exception(("no such directive: %s"):format(directive)))
	end
end

function preprocess.execute_directive(directive, ...)
	if (directives[directive]) then
		directives[directive].execute(...)
	else
		throw(new_preprocess_parse_exception(("no such directive: %s"):format(directive)))
	end
end

function preprocess.add_directive(name, execute_func, parse_func)
	directives[name] = {execute = execute_func, parse = parse_func}
end

-- default directives

preprocess.add_directive("if",
	function(condition)
		table.insert(preprocess.condition_stack, bool)
		preprocess.update_write()
	end)

preprocess.add_directive("else",
	function()
		table.insert(preprocess.condition_stack, !table.remove(preprocess.condition_stack))
		preprocess.update_write()
	end)

preprocess.add_directive("endif",
	function()
		table.remove(preprocess.condition_stack)
		preprocess.update_write()
	end)

function preprocess.parse(source)
	return try(function()
		source = source:gsub("\r", "")

		local current_pos = 1
		local current_static_chunk = ""
		local chunks = {}

		local function peek(n)
			n = n or 0
			return source:sub(current_pos + n, current_pos + n)
		end

		local function get(n)
			n = n or 0
			local c = source:sub(current_pos, current_pos + n)
			current_pos = current_pos + n + 1
			return c
		end

		local function append(str)
			current_static_chunk = current_static_chunk .. str
		end

		local function consume(str)
			if (source:sub(current_pos, current_pos + #str - 1) == str) then
				current_pos = current_pos + #str
				append(str)
				return true
			else
				return
			end
		end

		local function eof()
			return (peek() == "")
		end

		local function append_until(str)
			while (!eof() and !consume(str)) do
				append(get())
			end
		end

		local function try_multiline_string()
			if (consume("[")) then
				-- count equals signs
				local equals_count = 0
				while (consume("=")) do
					equals_count = equals_count + 1
				end

				-- if equals signs are followed by another bracket, then we have a string start
				if (consume("[")) then
					multiline_started = true

					-- the end will have this form
					local delimeter = "]" .. ("="):rep(equals_count) .. "]"
					-- look for the end
					while (!eof() and !consume(delimeter)) do
						append(get())
					end

					return true
				else
					return false
				end
			else
				return false
			end
		end

		local function commit_chunk(content, type)
			table.insert(chunks, {type = type, content = content})
		end

		local function commit_static()
			commit_chunk(current_static_chunk, "static")
			current_static_chunk = ""
		end

		local function commit_directive(directive)
			commit_chunk(directive, "directive")
		end

		local function commit_expression(expression)
			commit_chunk(expression, "expression")
		end

		local function is_line_start()
			local i = current_pos - 1

			while (source[i] == " " or source[i] == "\t") do
				i = i - 1
			end

			if (i <= 0 or source[i] == "\n") then
				return true
			else
				return false
			end
		end

		local function try_comments()
			if (consume("--")) then
				if (!try_multiline_string) then
					append_until("\n")
				end

				return true
			elseif (consume("/*")) then
				append_until("*/")

				return true
			elseif (consume("//")) then
				append_until("\n")

				return true
			end

			return false
		end

		local function try_literals()
			if (consume("\"")) then
				append_until("\"")

				return true
			elseif (consume("'")) then
				append_until("'")

				return true
			elseif (peek() == "[") then
				try_multiline_string()

				return true
			end

			return false
		end

		local function try_directives()
			if (peek() == "$" and peek(1) == "(") then
				local expr = ""
				commit_static()
				get(1)

				while (!eof() and peek() != ")") do
					expr = expr .. get()
				end

				if (eof()) then
					throw(new_exception("unexpected dynamic expression end", "preprocess_exception"))
				end

				get()
				commit_expression(expr)

				return true
			elseif (peek() == "#" and is_line_start()) then
				commit_static()
				get()

				local directive = ""

				while (!eof() and peek() != "\n") do
					directive = directive .. get()
				end

				commit_directive(directive)
				append("//#" .. directive)

				return true
			end

			return false
		end

		while (!eof()) do
			if (!try_comments()) then
				if (!try_literals()) then
					if (!try_directives()) then
						append(get())
					end
				end
			end
		end

		if (current_static_chunk != "") then
			commit_static()
		end

		local preprocessor_source = ""

		local function process_chunk_static(chunk)
			preprocessor_source = preprocessor_source .. ("preprocess.write [====[\n%s]====]\n"):format(chunk.content)
		end

		local function process_chunk_directive(chunk)
			for directive, body in pairs(directives) do
				if (chunk.content:sub(1, #directive) == directive) then
					local args = chunk.content:sub(#directive + 1, #(chunk.content))

					if (#args > 0) then
						preprocessor_source = preprocessor_source .. ("preprocess.execute_directive(\"%s\", preprocess.parse_directive_args ([[%s]], [[%s]]))\n"):format(directive, directive, args)
						return
					else
						preprocessor_source = preprocessor_source .. ("preprocess.execute_directive(\"%s\")\n"):format(directive)
						return
					end
				end
			end

			preprocessor_source = preprocessor_source .. ("%s\n"):format(chunk.content)
		end

		local function process_chunk_expression(chunk)
			preprocessor_source = preprocessor_source .. ("preprocess.write (%s)\n"):format(chunk.content)
		end

		for _, chunk in pairs(chunks) do
			if (chunk.type == "static") then
				process_chunk_static(chunk)
			elseif (chunk.type == "directive") then
				process_chunk_directive(chunk)
			elseif (chunk.type == "expression") then
				process_chunk_expression(chunk)
			end
		end

		return preprocessor_source
	end).catch(function(exception)
		if (exception.id == "preprocess_parse_exception") then
			-- rethrow
			throw(exception)
		else
			throw(new_preprocess_parse_exception("error while parsing", exception))
		end
	end)
end

function alpha.include_preprocess(path)
	local source = file.Read(path, "LUA")

	if (source) then
		local parts = string.Explode("/", path)
		local noext = string.Explode(".", parts[#parts])[1]
		local nopref = noext:sub(4, #noext)
		parts[#parts] = nil

		local preprocessor_source = ([[
			local preprocess = alpha.preprocess
			FILE = "%s"
			PATH = "%s"
			FILESHORT = "%s"
			RESULT = ""
		]]):gsub("\t", ""):gsub("\n", " "):format(noext, path, nopref)

		preprocessor_source = preprocessor_source .. preprocess.parse(source)

		file.CreateDir("alpha-debug-preprocess/" .. table.concat(parts, "/"))
		file.Write("alpha-debug-preprocess/" .. path .. ".txt", preprocessor_source)

		local preprocessor = CompileString(preprocessor_source, path, false)
		local result

		if (isfunction(preprocessor)) then
			try(function()
				preprocess.push_context()
				preprocessor()
				result = RESULT
			end).anyway(function()
				preprocess.pop_context()
			end).catch(function(exception)
				if (exception.id == "preprocessor_exception") then
					throw(exception)
				end

				throw(new_preprocess_execute_exception(path, exception))
			end)

			file.CreateDir("alpha-debug-postprocess/" .. table.concat(parts, "/"))
			file.Write("alpha-debug-postprocess/" .. path .. ".txt", result)

			local postprocessor = CompileString(result, path, false)

			if (isfunction(postprocessor)) then
				try(postprocessor).catch(function(exception)
					throw(new_include_exception(("error including file %s"):format(path), exception))
				end)
			else
				throw(new_postprocess_compile_exception(path, new_lua_exception(postprocessor)))
			end
		else
			throw(new_preprocess_compile_exception(path, new_lua_exception(preprocessor)))
		end
	end
end
