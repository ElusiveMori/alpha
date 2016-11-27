AddCSLuaFile()

RESULT = ""

local function write_enabled(line)
	RESULT = RESULT .. line
end

local function write_disabled(line)
	RESULT = RESULT .. string.gsub("\n", "\n//")
end

__WRITE = write_enabled

local function filter_newlines(str)
	local result = ""

	for i=1, #str do
		if (str[i] != "\n") then
			result = result .. str[i]
		end
	end

	return result
end

local eval_stack = {}

local function check_stack()
	for _, v in pairs(eval_stack) do
		if (v == false) then
			return false
		end
	end

	return true
end

local function update_write()
	if (check_stack()) then
		__WRITE = write_enabled
	else
		__WRITE = write_disabled
	end
end

local directives

function __EXEC_DIRECTIVE(directive, ...)
	directives[directive](...)
end

directives = {
	IF = function(bool)
		table.insert(eval_stack, bool)

		update_write()
	end,
	ELSE = function()
		table.insert(eval_stack, !table.remove(eval_stack))

		update_write()
	end,
	ENDIF = function()
		table.remove(eval_stack)

		update_write()
	end,
	INJECT = function(expr)
		__WRITE(expr:gsub("\n", " "))
	end,
	INJECT_LOGGER = function(name)
		__EXEC_DIRECTIVE("INJECT", ([[local log = alpha.logger("%s") ]]):format(prefix or FILESHORT))
	end,
	LIBRARY = function(name)
		name = name or FILESHORT

		if (!name) then
			return
		end

		__EXEC_DIRECTIVE("INJECT_LOGGER", "library/" .. name)
		__EXEC_DIRECTIVE("INJECT", ([[local library = Library("%s") local %s = library ]]):format(name, name))
	end,
	DEPEND = function(...)
		local dependencies = {...}

		for _, dependency in pairs(dependencies) do
			__EXEC_DIRECTIVE("INJECT", ([[library:add_dependency("%s") ]]):format(dependency))
		end
	end
}

local function parse(str)
	str = str:gsub("\r", "")

	local current_pos = 1
	local current_static = ""
	local chunks = {}

	local function peek(n)
		n = n or 0
		return str:sub(current_pos + n, current_pos + n)
	end

	local function get(n)
		n = n or 0
		local c = str:sub(current_pos, current_pos + n)
		current_pos = current_pos + n + 1
		return c
	end

	local function append(what)
		current_static = current_static .. what
	end

	local function consume(what)
		if (str:sub(current_pos, current_pos + #what - 1) == what) then
			current_pos = current_pos + #what
			append(what)
			return true
		else
			return
		end
	end

	local function eof()
		return peek() == ""
	end

	local function append_until(seq)
		while (!eof() and !consume(seq)) do
			append(get())
		end
	end

	local function try_multiline_string()
		if (consume("[")) then
			-- count equals signs
			local equals = 0
			while (consume("=")) do
				equals = equals + 1
			end

			-- if equals are followed by another bracket, then we have a string start
			if (consume("[")) then
				multiline_started = true

				-- the end will have this form
				local delimeter = "]" .. ("="):rep(equals) .. "]"
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
		commit_chunk(current_static, "static")
		current_static = ""
	end

	local function commit_directive(directive)
		commit_chunk(directive, "directive")
	end

	local function commit_expression(expression)
		commit_chunk(expression, "expression")
	end

	local function is_line_start()
		local i = current_pos - 1

		while (str[i] == " " or str[i] == "\t") do
			i = i - 1
		end

		if (i <= 0 or str[i] == "\n") then
			return true
		else
			return false
		end
	end

	local function try_comments()
		if (consume("--")) then
			local multiline = try_multiline_string()

			if (!multiline) then
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
				error("unexpected dynamic expression end")
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

	if (current_static != "") then
		commit_static()
	end

	local final = ""

	local function process_chunk_static(chunk)
		final = final .. ("__WRITE [====[\n%s]====]\n"):format(chunk.content)
	end

	local function process_chunk_directive(chunk)
		local directive_statement, directive_args = chunk.content:match("([^%s]+)%s*(.*)")

		if (directives[directive_statement]) then
			if (#directive_args > 0) then
				local split_args = {}

				for arg in directive_args:gmatch("[^%s]+") do
					table.insert(split_args, ("[[%s]]"):format(arg))
				end

				final = final .. ("__EXEC_DIRECTIVE(\"%s\", %s)\n"):format(directive_statement, table.concat(split_args, ", "))
			else
				final = final .. ("__EXEC_DIRECTIVE(\"%s\")\n"):format(chunk.content)
			end
		else
			final = final .. ("%s\n"):format(chunk.content)
		end
	end

	local function process_chunk_expression(chunk)
		final = final .. ("__WRITE (%s)\n"):format(chunk.content)
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

	return final
end

function include_preprocess(path)
	local content = file.Read(path, "LUA")

	if (content) then
		local parts = string.Explode("/", path)
		local noext = string.Explode(".", parts[#parts])[1]
		local nopref = noext:sub(4, #noext)
		parts[#parts] = nil

		local preprocessor_source = ([[
			RESULT = ""
			FILE = "%s"
			FILEPATH = "%s"
			FILESHORT = "%s"
		]]):gsub("\t", ""):gsub("\n", " "):format(noext, filename, nopref)

		local preprocessor_source = preprocessor_source .. parse(content)

		file.CreateDir("alpha-debug-preprocess/" .. table.concat(parts, "/"))
		file.Write("alpha-debug-preprocess/" .. path .. ".txt", preprocessor_source)

		RunString(preprocessor_source, "preprocessing: " .. path)

		file.CreateDir("alpha-debug-postprocess/" .. table.concat(parts, "/"))
		file.Write("alpha-debug-postprocess/" .. path .. ".txt", RESULT)

		RunString(RESULT, path)
	end
end