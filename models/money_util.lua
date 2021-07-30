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

end

M.have_player_enough_money = function(player, amount)

end

M.set_force_balance = function(force, amount)

end

M.set_player_balance = function(player, amount)

end

M.deposit_force = function(force, amount)

end

M.deposit_player = function(player, amount)

end

M.withdraw_force = function(force, amount)

end

M.withdraw_player = function(player, amount)

end

M.get_force_balance = function(force)

end

M.get_player_balance = function(player)

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
