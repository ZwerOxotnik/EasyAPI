--[[
	[WIP]
	Currently, I don't recommend to use it. It may change.
]]

---@class money_util : module
local M = {}


-- Events
local on_updated_force_balance_event
local on_updated_player_balance_event
local on_transfered_player_money_event
local on_transfered_force_money_event


---@type table<string, integer>
M.custom_events = {}


M.have_force_enough_money = function(force, amount)
	local balance = remote.call("EasyAPI", "get_force_money", force.index)
	if balance and balance >= amount then
		return true
	else
		return false
	end
end

M.have_player_enough_money = function(player, amount)
	local balance = remote.call("EasyAPI", "get_player_money", player.index)
	if balance and balance >= amount then
		return true
	else
		return false
	end
end

M.set_force_balance = function(force, amount)
	remote.call("EasyAPI", "set_force_money", force, amount)
end

M.set_player_balance = function(player, amount)
	remote.call("EasyAPI", "set_player_money", player.index, amount)
end

M.deposit_force = function(force, amount)
	local balance = remote.call("EasyAPI", "get_force_money", force.index) + amount
	remote.call("EasyAPI", "set_force_money", force, balance)
end

M.deposit_player = function(player, amount)
	local balance = remote.call("EasyAPI", "get_player_money", player.index) + amount
	remote.call("EasyAPI", "set_player_money", player.index, balance)
end

M.withdraw_force = function(force, amount)
	local balance = remote.call("EasyAPI", "get_force_money", force.index) - amount
	remote.call("EasyAPI", "set_force_money", force, balance)
end

M.withdraw_player = function(player, amount)
	local balance = remote.call("EasyAPI", "get_player_money", player.index) - amount
	remote.call("EasyAPI", "set_player_money", player.index, balance)
end

M.get_force_balance = function(force)
	return remote.call("EasyAPI", "get_force_money", force.index)
end

M.get_player_balance = function(player)
	return remote.call("EasyAPI", "get_player_money", player.index)
end

M.reset_player_balance = function(player_index)
	remote.call("EasyAPI", "reset_player_balance", player_index)
end

M.reset_force_balance = function(force)
	remote.call("EasyAPI", "reset_player_balance", force)
end


M.on_load = function()
	on_updated_force_balance_event = remote.call("EasyAPI", "get_event_name", "on_updated_force_balance")
	on_updated_player_balance_event = remote.call("EasyAPI", "get_event_name", "on_updated_player_balance")
	on_transfered_player_money_event = remote.call("EasyAPI", "get_event_name", "on_transfered_player_money")
	on_transfered_force_money_event = remote.call("EasyAPI", "get_event_name", "on_transfered_force_money")

	M.custom_events = {
		on_updated_force_balance = on_updated_force_balance_event,
		on_updated_player_balance = on_updated_player_balance_event,
		on_transfered_player_money = on_transfered_player_money_event,
		on_transfered_force_money = on_transfered_force_money_event
	}
end


return M
