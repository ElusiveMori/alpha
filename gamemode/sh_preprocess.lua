AddCSLuaFile()

RESULT = ""

local function write_enabled(line)
	RESULT = RESULT .. line
end

local function write_disabled(line)
	RESULT = RESULT .. string.gsub("[^\n]*", "")
end

WRITE = write_enabled

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
		WRITE = write_enabled
	else
		WRITE = write_disabled
	end
end

local directives

function EXEC_DIRECTIVE(directive, ...)
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
		WRITE(expr:gsub("\n", " "))
	end,
	INJECT_LOGGER = function(name)
		EXEC_DIRECTIVE("INJECT", ([[local log = alpha.logger("%s") ]]):format(prefix or FILESHORT))
	end,
	LIBRARY = function(name)
		name = name or FILESHORT

		if (!name) then
			return
		end

		EXEC_DIRECTIVE("INJECT_LOGGER", "library/" .. name)
		EXEC_DIRECTIVE("INJECT", ([[local library = Library("%s") local %s = library]]):format(name, name))
	end,
	DEPEND = function(...)
		local dependencies = {...}

		for _, dependency in pairs(dependencies) do
			EXEC_DIRECTIVE("INJECT", ([[library:add_dependency("%s") ]]):format(dependency))
		end
	end
}

local function preprocess(str, filename)
	local parts = string.Explode("/", filename)
	local noext = string.Explode(".", parts[#parts])[1]
	local nopref = noext:sub(4, #noext)
	parts[#parts] = nil

	local chunk = {
		"RESULT = ''",
		string.format("FILE = [[%s]]", noext),
		string.format("FILEPATH = [[%s]]", filename),
		string.format("FILESHORT = [[%s]]", nopref)
	}

	str = str:gsub("\r", "")

	for _, line in pairs(string.Explode("\n", str)) do
		local directive = line:match("^%s*#(.*)$")

		if (directive) then
			local directive_statement, directive_args = directive:match("([^%s]+)%s*(.*)")

			if (directives[directive_statement]) then
				if (#directive_args > 0) then
					local split_args = {}

					for arg in directive_args:gmatch("[^%s]+") do
						table.insert(split_args, ("[[%s]]"):format(arg))
					end

					table.insert(chunk, ("EXEC_DIRECTIVE([[%s]], %s) "):format(
						directive_statement,
						table.concat(split_args, ", ")))
				else
					table.insert(chunk, ("EXEC_DIRECTIVE([[%s]]) "):format(directive_statement))
				end
			else
				table.insert(chunk, ("%s "):format(directive))
			end

			table.insert(chunk, ("WRITE [====[\n--%s]====]\n"):format(line .. "\n"))
		else
			local last = 1

			for text, expr, index in string.gmatch(line, "(.-)$(%b())()") do 
				last = index

				if text != "" then
					table.insert(chunk, string.format("WRITE [====[\n%s]====]", text))
				end

				table.insert(chunk, string.format("WRITE (tostring(%s))", expr))
			end

			table.insert(chunk, string.format("WRITE [====[\n%s]====]\n", string.sub(line, last) .. "\n"))
		end
	end

	--if (DEBUG) then
		local debug_chunk = table.Copy(chunk)

		for k, line in pairs(debug_chunk) do
			debug_chunk[k] = filter_newlines(line)
		end

		file.CreateDir("alpha-debug-preprocess/" .. table.concat(parts, "/"))
		file.Write("alpha-debug-preprocess/" .. filename .. ".txt", table.concat(debug_chunk, "\n"))
	--end

	CompileString(table.concat(chunk, " "), filename)()

	--if (DEBUG) then
		file.CreateDir("alpha-debug-postprocess/" .. table.concat(parts, "/"))
		file.Write("alpha-debug-postprocess/" .. filename .. ".txt", RESULT)
	--end
end

function include_preprocess(path)
	local content = file.Read(path, "LUA")

	if (content) then
		local success, result = pcall(preprocess, content, path)

		if (!success) then
			error(string.format("preprocess error in file %s: %s", path, result))
		else
			return CompileString(RESULT, path)()
		end
	end
end