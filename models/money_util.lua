--[[
	[WIP]
	Currently, I don't recommend to use it. It may change.
]]

---@class money_util : module
local M = {}

--#region constants
local call = remote.call
--#endregion


-- Events
local on_transfered_player_money_event
local on_transfered_force_money_event


---@type table<string, integer>
M.custom_events = {}


---@param force ForceIdentification
---@param amount number
---@return boolean
M.have_force_enough_money = function(force, amount)
	local balance = call("EasyAPI", "get_force_money", force.index)
	if balance and balance >= amount then
		return true
	else
		return false
	end
end

---@param player PlayerIdentification
---@param amount number
---@return boolean
M.have_player_enough_money = function(player, amount)
	local balance = call("EasyAPI", "get_player_money", player.index)
	if balance and balance >= amount then
		return true
	else
		return false
	end
end

---@param force ForceIdentification
---@param amount number
M.set_force_balance = function(force, amount)
	call("EasyAPI", "set_force_money", force, amount)
end

---@param player PlayerIdentification
---@param amount number
M.set_player_balance = function(player, amount)
	call("EasyAPI", "set_player_money", player.index, amount)
end

---@param force ForceIdentification
---@param amount number
M.deposit_force = function(force, amount)
	call("EasyAPI", "deposit_force_money", force, amount)
end

---@param player PlayerIdentification
---@param amount number
M.deposit_player = function(player, amount)
	call("EasyAPI", "deposit_player_money", player, amount)
end

---@param force ForceIdentification
---@param amount number
M.withdraw_force = function(force, amount)
	local balance = call("EasyAPI", "get_force_money", force.index) - amount
	call("EasyAPI", "set_force_money", force, balance)
end

---@param player PlayerIdentification
---@param amount number
M.withdraw_player = function(player, amount)
	local balance = call("EasyAPI", "get_player_money", player.index) - amount
	call("EasyAPI", "set_player_money", player.index, balance)
end

---@param force ForceIdentification
---@return number
M.get_force_balance = function(force)
	return call("EasyAPI", "get_force_money", force.index)
end

---@param player PlayerIdentification
---@return number
M.get_player_balance = function(player)
	return call("EasyAPI", "get_player_money", player.index)
end

---@param player_index number
M.reset_player_balance = function(player_index)
	call("EasyAPI", "reset_player_balance", player_index)
end

---@param force ForceIdentification
M.reset_force_balance = function(force)
	call("EasyAPI", "reset_player_balance", force)
end

local function get_data()
	on_transfered_player_money_event = call("EasyAPI", "get_event_name", "on_transfered_player_money")
	on_transfered_force_money_event = call("EasyAPI", "get_event_name", "on_transfered_force_money")

	M.custom_events = {
		on_transfered_player_money = on_transfered_player_money_event,
		on_transfered_force_money = on_transfered_force_money_event
	}
end


M.on_load = get_data
M.on_init = get_data


return M
