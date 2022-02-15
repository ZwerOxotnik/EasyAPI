--[[
	This file is a special for servers to make scripts work on your server only.
	* Rewrite global functions like: on_player_joined_game etc
	Example: /c on_player_joined_game = function(e) log(serpent.line(e)) end
	* Remove unnecessary stuff
	* Do not interact with game etc, otherwise players will desync
	* Use it with cautious
	(It's more useful for headless servers and simpler with scripts)
]]


local M = {}


--#region Global variables
on_tick = function() end
on_player_joined_game = function() end
on_player_left_game = function() end
on_player_created = function() end
on_player_kicked = function() end
on_player_unbanned = function() end
on_player_banned = function() end
on_pre_build = function() end
on_built_entity = function() end
on_player_used_capsule = function() end
on_player_selected_area = function() end
on_player_rotated_entity = function() end
on_player_main_inventory_changed = function() end
on_player_mined_entity = function() end
on_pre_player_mined_item = function() end
on_player_mined_item = function() end
on_player_muted = function() end
on_player_pipette = function() end
on_player_placed_equipment = function() end
on_player_promoted = function() end
on_player_demoted = function() end
on_player_removed = function() end
on_pre_player_died = function() end
on_player_died = function() end
on_player_respawned = function() end
on_player_cheat_mode_disabled = function() end
on_player_cheat_mode_enabled = function() end
on_player_changed_force = function() end
on_player_changed_position = function() end
on_player_changed_surface = function() end
on_player_deconstructed_area = function() end
on_gui_checked_state_changed = function() end
on_gui_click = function() end
on_gui_closed = function() end
on_gui_confirmed = function() end
on_gui_elem_changed = function() end
on_gui_opened = function() end
on_gui_selected_tab_changed = function() end
on_gui_selection_state_changed = function() end
on_gui_switch_state_changed = function() end
on_gui_text_changed = function() end
on_gui_value_changed = function() end
on_lua_shortcut = function() end
on_entity_renamed = function() end
on_market_item_purchased = function() end
--#endregion


-- https://lua-api.factorio.com/latest/
M.events = {
	[defines.events.on_tick] = function(e)
		on_tick(e)
	end,
	[defines.events.on_player_joined_game] = function(e)
		on_player_joined_game(e)
	end,
	[defines.events.on_player_left_game] = function(e)
		on_player_left_game(e)
	end,
	[defines.events.on_player_created] = function(e)
		on_player_created(e)
	end,
	[defines.events.on_player_kicked] = function(e)
		on_player_kicked(e)
	end,
	[defines.events.on_player_unbanned] = function(e)
		on_player_unbanned(e)
	end,
	[defines.events.on_player_banned] = function(e)
		on_player_banned(e)
	end,
	[defines.events.on_pre_build] = function(e)
		on_pre_build(e)
	end,
	[defines.events.on_built_entity] = function(e)
		on_built_entity(e)
	end,
	[defines.events.on_player_used_capsule] = function(e)
		on_player_used_capsule(e)
	end,
	[defines.events.on_player_selected_area] = function(e)
		on_player_selected_area(e)
	end,
	[defines.events.on_player_rotated_entity] = function(e)
		on_player_rotated_entity(e)
	end,
	[defines.events.on_player_main_inventory_changed] = function(e)
		on_player_main_inventory_changed(e)
	end,
	[defines.events.on_player_mined_entity] = function(e)
		on_player_mined_entity(e)
	end,
	[defines.events.on_pre_player_mined_item] = function(e)
		on_pre_player_mined_item(e)
	end,
	[defines.events.on_player_mined_item] = function(e)
		on_player_mined_item(e)
	end,
	[defines.events.on_player_muted] = function(e)
		on_player_muted(e)
	end,
	[defines.events.on_player_pipette] = function(e)
		on_player_pipette(e)
	end,
	[defines.events.on_player_placed_equipment] = function(e)
		on_player_placed_equipment(e)
	end,
	[defines.events.on_player_promoted] = function(e)
		on_player_promoted(e)
	end,
	[defines.events.on_player_demoted] = function(e)
		on_player_demoted(e)
	end,
	[defines.events.on_player_removed] = function(e)
		on_player_removed(e)
	end,
	[defines.events.on_pre_player_died] = function(e)
		on_pre_player_died(e)
	end,
	[defines.events.on_player_died] = function(e)
		on_player_died(e)
	end,
	[defines.events.on_player_respawned] = function(e)
		on_player_respawned(e)
	end,
	[defines.events.on_player_cheat_mode_disabled] = function(e)
		on_player_cheat_mode_disabled(e)
	end,
	[defines.events.on_player_cheat_mode_enabled] = function(e)
		on_player_cheat_mode_enabled(e)
	end,
	[defines.events.on_player_changed_force] = function(e)
		on_player_changed_force(e)
	end,
	[defines.events.on_player_changed_position] = function(e)
		on_player_changed_position(e)
	end,
	[defines.events.on_player_changed_surface] = function(e)
		on_player_changed_surface(e)
	end,
	[defines.events.on_player_deconstructed_area] = function(e)
		on_player_deconstructed_area(e)
	end,
	[defines.events.on_gui_checked_state_changed] = function(e)
		on_gui_checked_state_changed(e)
	end,
	[defines.events.on_gui_click] = function(e)
		on_gui_click(e)
	end,
	[defines.events.on_gui_closed] = function(e)
		on_gui_closed(e)
	end,
	[defines.events.on_gui_confirmed] = function(e)
		on_gui_confirmed(e)
	end,
	[defines.events.on_gui_elem_changed] = function(e)
		on_gui_elem_changed(e)
	end,
	[defines.events.on_gui_opened] = function(e)
		on_gui_opened(e)
	end,
	[defines.events.on_gui_selected_tab_changed] = function(e)
		on_gui_selected_tab_changed(e)
	end,
	[defines.events.on_gui_selection_state_changed] = function(e)
		on_gui_selection_state_changed(e)
	end,
	[defines.events.on_gui_switch_state_changed] = function(e)
		on_gui_switch_state_changed(e)
	end,
	[defines.events.on_gui_text_changed] = function(e)
		on_gui_text_changed(e)
	end,
	[defines.events.on_gui_value_changed] = function(e)
		on_gui_value_changed(e)
	end,
	[defines.events.on_lua_shortcut] = function(e)
		on_lua_shortcut(e)
	end,
	[defines.events.on_entity_renamed] = function(e)
		on_entity_renamed(e)
	end,
	[defines.events.on_market_item_purchased] = function(e)
		on_market_item_purchased(e)
	end,
}

return M
