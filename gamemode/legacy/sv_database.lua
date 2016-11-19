-- WIP, archived

do return end

local class = Class("database")

local function dummy()
end

---[[
class.settings = {
	host = "127.0.0.1",
	username = "alpha",
	password = "HKkpUBF7RlfytnkYoUIV",
	database = "alpha_dev",
	port = 3306,
}
--]]

--[[
class.settings = {
	host = "127.0.0.1",
	username = "root",
	password = "",
	database = "alpha_dev",
	port = 3306,
}
--]]

class.query_templates = {
	get_player_profile = {
		template = [[
			SELECT *
			FROM players
			WHERE steamid=?
		]],
		args = {"string"},
		callback = true,
	},
	prepare_player_profile = {
		template = [[
			INSERT INTO players(steamid,name,group,data,playtime,firstentry)
			VALUES(?,?,?,?,?,?)
			ON DUPLICATE KEY UPDATE steamid=steamid
		]],
		args = {"string", "string", "string", "string", "number", "number"},
		callback = false,
	}
	update_player_profile = {
		template = [[
			UPDATE players
			SET
				name=?,
				group=?,
				data=?,
				playtime=?
			WHERE
				steamid=?
		]],
		args = {"string", "string", "string", "number", "string"},
		callback = false,
	},
	get_player_characters = {
		template = [[
			SELECT t1.characterid, t1.class, t1.quickname, t1.data, t1.location
			FROM characters AS t1
			INNER JOIN players_characters AS t2 ON t1.characterid=t2.characterid
			WHERE t2.steamid=?
		]],
		args = {"string"},
		callback = true,

	},
	get_character = [[
		SELECT *
		FROM characters
		WHERE characterid=?
	]],
	update_character = [[
		UPDATE characters
		SET
			class=?,
			quickname=?,
			data=?,
			location=?,
		WHERE
			characterid=?
	]],
	create_character = [[
		INSERT INTO characters(class,quickname,data,location)
		VALUES(?,?,?,?)
	]],
	get_active_bans = [[
		SELECT date, duration, reason, by
		FROM active_bans
		WHERE steamid=? AND date+duration>?
	]],
	archive_expired_bans = [[
		INSERT INTO archived_bans(steamid,date,duration,reason,by,liftmethod,liftby)
			SELECT steamid,date,duration,reason,by,"expire",0
			FROM active_bans
			WHERE date+duration<?
	]],
	cleanup_expired_bans = [[
		DELETE FROM active_bans
		WHERE date+duration<?
	]],
	archive_ban = [[
		INSERT INTO archived_bans(steamid,date,duration,reason,by,liftmethod,liftby)
			SELECT steamid,date,duration,reason,by,"manual",?
			FROM active_bans
			WHERE steamid=?
	]],
	remove_ban = [[
		DELETE FROM active_bans
		WHERE steamid=?
	]]
}

local q = {
	template = "",
	argtypes = {"string", "number", "number", "number"},
	callback = false,
}

class.prepared_queries = class.prepared_queries or {}

function class:constructor()
	return false
end

function class:connect()
	if (!self.active) then
		local settings = self.settings
		local database = mysqloo.connect(settings.host,
		                                 settings.username,
		                                 settings.password,
		                                 settings.database,
		                                 settings.port)

		function database:onConnectionFailed(err)
			alpha.warning("connection to mysql server has failed with error:")
			alpha.warning(err)
		end

		alpha.print("connecting to mysql server...")
		alpha.print(Format("host: %s:%s", settings.host, settings.port))
		alpha.print(Format("username: %s", settings.username))
		alpha.print(Format("database: %s", settings.database))
		database:connect()
		database:wait()

		local status = database:status()

		if (status == mysqloo.DATABASE_CONNECTED) then
			alpha.print("successfully established mysql connection")
			alpha.print("server info: " .. database:serverInfo())
			alpha.print("host info: " .. database:hostInfo())
			self.active = true
			self.db = database
		end
	end
end

function class:post_initialize()
	self:connect()
end

function class:get_query(id, callback)
	if (self.active) then
		if (self.query_templates[id]) then
			local query = self.db:prepare(self.query_templates[id])

			function query:onSuccess(data)
				callback(data)
			end

			function query:onError(err)
				alpha.warning(Format("query %s has failed with error:"), id)
				alpha.warning(err)
			end

			return query
		else
			alpha.warning("invalid query template")
		end
	else
		alpha.warning(Format("trying to get query %s, but database is inactive", id))
	end
end

function class:get_player_profile(steamid64, callback)
	local query = self:get_query("get_player_profile", callback)

	if (query) then
		query:setString(1, steamid64)

		query:start()
	end
end
	
function class:prepare_player_profile(steamid64, name, group, data, playtime, firstentry)
	local query = self:get_query("prepare_player_profile", dummy)

	if (query) then
		query:setString(1, steamid64)
		query:setString(2, name)
		query:setString(3, group)
		query:setString(4, data)
		query:setNumber(5, playtime)
		query:setNumber(6, firstentry)

		query:start()
	end
end

function class:update_player_profile(steamid64, name, group, data, playtime)
	local query = self:get_query("update_player_profile", dummy)

	if (query) then
		query:setString(1, steamid64)
		query:setString(2, name)
		query:setString(3, group)
		query:setString(4, data)
		query:setNumber(5, playtime)

		query:start()
	end
end

function class:get_player_characters(steamid64, callback)
	local query = self:get_query("get_player_characters", callback)

	if (query) then
		query:setString(1, steamid64)

		query:start()
	end
end

function class:get_character(characterid, callback)
	local query = self:get_query("get_characater", callback)

	if (query) then
		query:setNumber(1, characterid)

		query:start()
	end
end

function class:update_character(characterid, class, quickname, data, location)
	local query = self:get_query("update_character", dummy)

	if (query) then
		query:setNumber(1, characterid)
		query:setString(2, class)
		query:setString(3, quickname)
		query:setString(4, data)
		query:setString(5, location)
	end
end


class:hook_add("PostInitialize", class.post_initialize)
