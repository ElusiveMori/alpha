local log = alpha.logger("settings")

local library = Library "settings"

library:add_dependency "io"

local function save_settings()
	log:info("saving settings...")
	local output = {}

	for k, v in pairs(library) do
		if (isstring(k)) then
			if (k:sub(1, 2) != "__") then
				output[k] = v
			end
		end
	end

	alpha.io.write("settings.dat", util.TableToJSON(output, true))
	hook.Call("AlphaSettingsSaved")
end

local function load_settings()
	log:info("loading settings...")
	table.Merge(alpha.settings, util.JSONToTable(alpha.io.read("settings.dat") or "") or {})
	hook.Call("AlphaSettingsLoaded")
end

function library:initialize()
	load_settings()
	save_settings()
end

function library:shutdown()
	save_settings()
end

local defaults = {}

function library:set_default(entry, default)
	if (self[entry] == nil) then
		self[entry] = (istable(default) and table.Copy(default)) or default
	end

	defaults[entry] = default
end

concommand.Add("alpha_reloadsettings", function(client)
	if (!IsValid(client)) then
		load_settings()
		save_settings()
	end
end)

concommand.Add("alpha_clearsettings", function(client, cmd, args)
	if (!IsValid(client)) then
		if (!args[1]) then
			for k, v in pairs(defaults) do
				log:info(Format("defaulting setting \"%s\"", k))
				library[k] = (istable(v) and table.Copy(v)) or v
			end
		else
			local setting = args[1]
			if (defaults[setting]) then
				local default = defaults[setting]
				log:info(Format("defaulting setting \"%s\"", setting))
				library[setting] = (istable(default) and table.Copy(default)) or default
			else
				log:warn("no default for this setting")
			end
		end

		save_settings()
		load_settings()
	end
end)