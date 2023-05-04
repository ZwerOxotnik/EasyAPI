--[[
	[WIP]
	Currently, I don't recommend to use it. It may change.
]]

---@class money_util : module
local M = {}


--#region constants
local call = remote.call
--#endregion


---@param player LuaPlayer
M.assign_default_permission_group = function(player)
	call("EasyAPI", "assign_default_permission_group", player)
end


return M
