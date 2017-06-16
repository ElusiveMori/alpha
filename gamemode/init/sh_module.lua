--[[
	Modules specify their dependencies with the #using directive. When the preprocessor encounters
	that directive, it will check if said module is loaded or not, and if it isn't - it will load it.
	This will continue recursively until all transitive dependencies are satisfied, and then the
	preprocessor continues as usual with the parsing.

	The modules are specified with a Java-like package syntax, e.g.
	#using package.subpackage.module
	This string is called it's qualifier

	The index of all modules is built in the following manner:
	All files and directoris in the "modules" directory are scanned. Loose files are only included if they have
	a "shm", "svm" or "clm" prefix, 'm' standing for "module". If an entire package is specified, then it
	acts as an aggregator of all submodules inside it - requiring all of them. If there is a "sh_init.lua",
	"cl_init.lua" or "sv_init.lua" file inside, then it will be ran after all submodules have been initialized.
	All other files are not added to the index, and have to be included manually by modules using other facilities.
	The module name is built from the path and filename.

	For example, considering the following directory structure:
	base\
		shm_a.lua
		shm_b.lua
		shm_c.lua
		sh_init.lua

	When "#using base.a" is used, only "shm_a.lua" will be included, and any dependencies it specifies.
	When "#using base" is used, all files inside the base directory are included, with dependencies properly resolved,
	and "sh_init.lua" included last.
--]]
#log

alpha.module = alpha.module or {}
local module = alpha.module

module.modules = module.modules or {}
module.meta    = module.meta or {}
module.index   = module.index or {}

local modules     = module.modules
local index       = module.index
local module_meta = module.meta

module_meta.__index = module_meta

function module_meta:hook_add(name, func)
	hook.Add(name, self.__name, func)
end

function module_meta:hook_remove(name)
	hook.Remove(name, self.__name)
end

function module.get(name)
	if (modules[name]) then
		return modules[name]
	else
		local module = {__name = name}
		modules[name] = module
		alpha[name] = module

		setmetatable(module, module_meta)

		return module
	end
end

function module.scan()
	local file_queue = {}
	local directory_queue = {alpha.directory_name .. "/gamemode/modules/"}

	while (#directory_queue > 0) do
		local current_dir = table.remove(directory_queue)

		local files, directories = file.Find(current_dir .. "*", "LUA")

		for _, filename in pairs(files) do
			table.insert(file_queue, current_dir .. filename)
		end

		for _, directory in pairs(directories) do
			table.insert(directory_queue, current_dir .. directory .. "/")
		end
	end

	for _, filename in pairs(file_queue) do
		local path, prefix, name = alpha.parse_lua_filename(filename)

		if (path) then
			if (prefix == "shm" or prefix == "svm" or prefix == "clm") then
				for i=1, 3 do
					table.remove(path, 1)
				end

				index[table.concat(path, ".") .. "." .. name] = {
					loaded = false,
					full_path = filename
				}
			end
		end
	end
end

--[[ includes a module using it's qualifier ]]
function module.include(name)
	local index_entry = index[name]
	if (index_entry) then
		if (!index_entry.loaded) then
			alpha.include(index_entry.full_path)
			index_entry.loaded = true
			log:info("included module " .. name)
		end
	else
		throw(new_include_exception(("no module with qualifier %s"):format(name)))
	end
end

function module.include_all()
	for qualifier, _ in pairs(index) do
		module.include(qualifier)
	end
end

alpha.preprocess.add_directive("using",
	function(name)
		module.include(name)
	end)

alpha.preprocess.add_directive("module",
	function(name)
		local split = string.Explode(".", name)
		alpha.preprocess.inject(([[local %s = alpha.module.get("%s")]]):format(split[#split], split[#split]))
	end)

module.scan()
module.include_all()
