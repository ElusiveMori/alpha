local log = alpha.logger("class/whitelist_filter")
local class = Class("whitelist_filter")

alpha.settings:set_default("whitelist", {
	enabled = true,
	players = {
		"76561198013465945"
	}
})

function class:pull_settings()
	self.enabled = alpha.settings.whitelist.enabled
	self.whitelist = alpha.util.lookup_table(alpha.settings.whitelist.players)
end

function class:constructor()
	self:pull_settings()

	self:hook_add("AlphaSettingsLoaded", self.pull_settings)
	self:hook_add("CheckPassword", self.on_check_password)
end

function class:destructor()
	self:hook_remove("AlphaSettingsLoaded")
	self:hook_remove("CheckPassword")
end

function class:on_check_password(steamid64, ip, sv_password, cl_password, name)
	cl_password = (isstring(cl_password) and cl_password) or ""

	if (steamid64 and ip and name) then
		if (self.whitelist[steamid64]) then
			log:info(Format("accepting player %s [%s::%s] due to whitelist", name, ip, steamid64))
			return true
		elseif (self.enabled) then
			log:info(Format("rejecting player %s [%s::%s] due to whitelist", name, ip, steamid64))
			return false, "You are not in the whitelist."
		elseif (#sv_password > 0) then
			log:info(Format("rejecting player %s [%s::%s] due to password", name, ip, steamid64))
			return cl_password == sv_password, "Wrong password."
		end
	else
		return false, "Fuck you."
	end
end