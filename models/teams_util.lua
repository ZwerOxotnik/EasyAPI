--[[
	[WIP]
	Currently, I don't recommend to use it. It may change.
]]

---@class teams_util : module
local M = {}


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


---@return LuaForce|nil
M.create_team = function(name)
	if name > 52 then
		log({"too-long-team-name"})
		return
	end

	-- for compability with other mods/scenarios and forces count max = 64 (https://lua-api.factorio.com/1.1.30/LuaGameScript.html#LuaGameScript.create_force)
	if #game.forces >= 60 then log({"teams.too_many"}) return end
	if game.forces[name] then
		log({"gui-map-editor-force-editor.new-force-name-already-used", name})
		return
	end
	if name:find(" ") then
		log("Whitespaces aren't allowed for teams")
		return
	end

	local new_team = game.create_force(name)
	remote.call("EasyAPI", "add_team", new_team)
	return new_team
end

M.add_team = function(force)
	remote.call("EasyAPI", "add_team", force)
end

M.remove_team = function(force)
	remote.call("EasyAPI", "remove_team", force.index)
end


M.on_load = function()
	on_team_lost_event = remote.call("EasyAPI", "get_event_name", "on_team_lost")
	on_team_won_event = remote.call("EasyAPI", "get_event_name", "on_team_won")
	on_player_joined_team_event = remote.call("EasyAPI", "get_event_name", "on_player_joined_team")
	on_new_team_event = remote.call("EasyAPI", "get_event_name", "on_new_team")
	on_pre_deleted_team_event = remote.call("EasyAPI", "get_event_name", "on_pre_deleted_team")
	on_team_invited_event = remote.call("EasyAPI", "get_event_name", "on_team_invited")
	on_player_accepted_invite_event = remote.call("EasyAPI", "get_event_name", "on_player_accepted_invite")

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


return M
