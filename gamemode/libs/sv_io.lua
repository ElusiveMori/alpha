local log = alpha.logger("io")

local library = Library "io"
local prefix = "alpha/"

function library.read(filename)
	return file.Read(prefix .. filename)
end

function library.write(filename, str)
	file.Write(prefix .. filename, str)
end

function library.append(filename, str)
	file.Append(prefix .. filename, str)
end

function library.remove(filename)
	file.Delete(prefix .. filename)
end

function library:initialize()
	if (!file.Exists("alpha", "DATA")) then
		file.CreateDir("alpha")
	end
end