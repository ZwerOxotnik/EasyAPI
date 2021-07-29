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
