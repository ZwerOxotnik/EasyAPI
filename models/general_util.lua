--[[
	[WIP]
	Currently, I don't recommend to use it. It may change.
]]

---@class general_util : module
local M = {}

--#region constants
local call = remote.call
--#endregion


-- Events
local on_reload_scenario_event
local on_new_character_event
local on_player_on_admin_surface_event
local on_player_on_scenario_surface_event
local on_player_on_lobby_surface_event
local on_toggle_event


---@type table<string, integer>
M.custom_events = {}


---@return table<string, integer>
M.get_events = function()
	return call("EasyAPI", "get_events")
end

---@return table<string, table>
M.get_data = function()
	return call("EasyAPI", "get_data")
end


M.on_load = function()
	on_reload_scenario_event = call("EasyAPI", "get_event_name", "on_reload_scenario")
	on_new_character_event = call("EasyAPI", "get_event_name", "on_new_character")
	on_player_on_admin_surface_event = call("EasyAPI", "get_event_name", "on_player_on_admin_surface")
	on_player_on_scenario_surface_event = call("EasyAPI", "get_event_name", "on_player_on_scenario_surface")
	on_player_on_lobby_surface_event = call("EasyAPI", "get_event_name", "on_player_on_lobby_surface")
	on_toggle_event = call("EasyAPI", "get_event_name", "on_toggle")

	M.custom_events = {
		on_reload_scenario = on_reload_scenario_event,
		on_new_character = on_new_character_event,
		on_player_on_admin_surface = on_player_on_admin_surface_event,
		on_player_on_scenario_surface = on_player_on_scenario_surface_event,
		on_player_on_lobby_surface = on_player_on_lobby_surface_event,
		on_toggle = on_toggle_event
	}
end


return M
