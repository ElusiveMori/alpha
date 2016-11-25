#LIBRARY io
local prefix = "alpha/"

function io.read(filename)
	return file.Read(prefix .. filename)
end

function io.write(filename, str)
	file.Write(prefix .. filename, str)
end

function io.append(filename, str)
	file.Append(prefix .. filename, str)
end

function io.remove(filename)
	file.Delete(prefix .. filename)
end

function io:initialize()
	if (!file.Exists("alpha", "DATA")) then
		file.CreateDir("alpha")
	end
end