--[[
	[WIP]
	Currently, I don't recommend to use it. It may change.
]]

---@class diplomacy_util : module
local M = {}


--#region constants
local call = remote.call
--#endregion


do
	---@class DIPLOMACY_TYPES
	local DIPLOMACY_TYPES = {
		ALLY_TYPE = 1,
		NEUTRAL_TYPE = 2,
		ENEMY_TYPE = 3
	}
end
local ALLY_TYPE = 1
local NEUTRAL_TYPE = 2
local ENEMY_TYPE = 3


-- Events
local on_ally_event
local on_neutral_event
local on_enemy_event


---@type table<string, integer>
M.custom_events = {}


---@param force ForceIdentification
---@param other_force ForceIdentification|string
---@return string #ally|neutral|enemy
local function get_stance_diplomacy(force, other_force)
	if force.get_friend(other_force) then
		return "ally"
	elseif force.get_cease_fire(other_force) then
		return "neutral"
	else
		return "enemy"
	end
end
M.get_stance_diplomacy = get_stance_diplomacy

---@param force ForceIdentification
---@param other_force ForceIdentification|string
---@return DIPLOMACY_TYPES
M.get_stance_diplomacy_type = function(force, other_force)
	if force.get_friend(other_force) then
		return ALLY_TYPE
	elseif force.get_cease_fire(other_force) then
		return NEUTRAL_TYPE
	else
		return ENEMY_TYPE
	end
end

---@param type DIPLOMACY_TYPES
---@return string #ally|neutral|enemy
M.get_stance_name_diplomacy_by_type = function(type)
	if type == ALLY_TYPE then
		return "ally"
	elseif type == NEUTRAL_TYPE then
		return "neutral"
	else
		return "enemy"
	end
end

---@param force ForceIdentification
---@param other_force ForceIdentification
---@param player_index number
M.declare_war = function(force, other_force, player_index)
	local prev_relationship = get_stance_diplomacy(force, other_force)
	force.set_friend(other_force, true)
	force.set_cease_fire(other_force, true)
	other_force.set_friend(force, true)
	other_force.set_cease_fire(force, true)
	script.raise_event(on_ally_event, {source = force, destination = other_force, player_index = player_index, prev_relationship = prev_relationship})
end

---@param force ForceIdentification
---@param other_force ForceIdentification
---@param player_index number
M.declare_neutrality = function(force, other_force, player_index)
	local prev_relationship = get_stance_diplomacy(force, other_force)
	force.set_friend(other_force, false)
	force.set_cease_fire(other_force, true)
	other_force.set_friend(force, false)
	other_force.set_cease_fire(force, true)
	script.raise_event(on_neutral_event, {source = force, destination = other_force, player_index = player_index, prev_relationship = prev_relationship})
end

---@param force ForceIdentification
---@param other_force ForceIdentification
---@param player_index number
M.declare_peace = function(force, other_force, player_index)
	local prev_relationship = get_stance_diplomacy(force, other_force)
	force.set_friend(other_force, false)
	force.set_cease_fire(other_force, false)
	other_force.set_friend(force, false)
	other_force.set_cease_fire(force, false)
	script.raise_event(on_enemy_event, {source = force, destination = other_force, player_index = player_index, prev_relationship = prev_relationship})
end


M.on_load = function()
	on_ally_event = call("EasyAPI", "get_event_name", "on_ally")
	on_neutral_event = call("EasyAPI", "get_event_name", "on_neutral")
	on_enemy_event = call("EasyAPI", "get_event_name", "on_enemy")

	M.custom_events = {
		on_ally = on_ally_event,
		on_neutral = on_neutral_event,
		on_enemy = on_enemy_event
	}
end


return M
