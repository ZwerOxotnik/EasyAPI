--[[
	[WIP]
	Currently, I don't recommend to use it. It may change.
]]

---@class teams_util : module
local M = {}


--#region constants
local call = remote.call
local RED_COLOR = {1, 0, 0}
--#endregion


-- Events
local on_team_lost_event
local on_team_won_event
local on_player_joined_team_event
local on_new_team_event
local on_pre_deleted_team_event
local on_team_invited_event
local on_player_accepted_invite_event


---@type table<string, integer>
M.custom_events = {}


-- Doesn't check team name length
---@param name string
---@return boolean
local function is_team_name_valid(name)
	local result = string.match(name, "[A-z][A-z0-9_-]+")
	if result then
		return (#name == #result)
	else
		return false
	end
end
M.is_team_name_valid = is_team_name_valid


---@param name string
---@param caller ForceIdentification|PlayerIdentification|LuaGame
---@return ForceIdentification?
M.create_team = function(name, caller)
	if #name > 32 then
		caller.print({"too-long-team-name"}, RED_COLOR)
		return
	end

	-- for compability with other mods/scenarios and forces count max = 64 (https://lua-api.factorio.com/1.1.38/LuaGameScript.html#LuaGameScript.create_force)
	if #game.forces >= 60 then
		caller.print({"teams.too_many"})
		return
	end
	local teams_count = call("EasyAPI", "get_teams_count")
	if teams_count >= settings.global["EAPI_max_teams"].value then
		caller.print("Too many teams by setting")
		return
	end
	if game.forces[name] then
		caller.print({"gui-map-editor-force-editor.new-force-name-already-used", name})
		return
	end
	if is_team_name_valid(name) == false then
		caller.print("The name contains invalid symbols", RED_COLOR)
		return
	end

	local new_team = game.create_force(name)
	call("EasyAPI", "add_team", new_team)
	return new_team
end

---@param force ForceIdentification
M.add_team = function(force)
	call("EasyAPI", "add_team", force)
end

---@param force ForceIdentification
M.remove_team = function(force)
	call("EasyAPI", "remove_team", force.index)
end


local function get_data()
	on_team_lost_event = call("EasyAPI", "get_event_name", "on_team_lost")
	on_team_won_event = call("EasyAPI", "get_event_name", "on_team_won")
	on_player_joined_team_event = call("EasyAPI", "get_event_name", "on_player_joined_team")
	on_new_team_event = call("EasyAPI", "get_event_name", "on_new_team")
	on_pre_deleted_team_event = call("EasyAPI", "get_event_name", "on_pre_deleted_team")
	on_team_invited_event = call("EasyAPI", "get_event_name", "on_team_invited")
	on_player_accepted_invite_event = call("EasyAPI", "get_event_name", "on_player_accepted_invite")

	M.custom_events = {
		on_team_lost = on_team_lost_event,
		on_team_won = on_team_won_event,
		on_player_joined_team = on_player_joined_team_event,
		on_new_team = on_new_team_event,
		on_pre_deleted_team = on_pre_deleted_team_event,
		on_team_invited = on_team_invited_event,
		on_player_accepted_invite = on_player_accepted_invite_event
	}
end


M.on_load = get_data
M.on_init = get_data


return M
