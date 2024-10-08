-- Contains settings as data for other mods (see https://mods.factorio.com/mod/EasyAPI)
---@type table<string, any>
return {
	--[[
	   Template: (see names for events in https://github.com/ZwerOxotnik/EasyAPI/blob/main/events.lua)
	   is_ event_name _event_active = true,
	   (use case: simplification as setting for activating events in other mods)
	]]---
	-- Example:
	-- Actives events for https://mods.factorio.com/mod/reclaiming_system
	-- is_on_pre_entity_changed_force_event_active = true,
	-- is_on_entity_changed_force_event_active     = true,
}
