local team_util = require("models/team_util")
permissions_util = require("models/permissions_util")
player_util = require("__zk-lib__/static-libs/lualibs/control_stage/player-util")


---@class EasyAPI : module
local M = {}


--#region Global data
---@type table<string, any>
local _mod_data

---@class teams
---@type table<uint, string>
local _teams

---@class virtual_base_resources
---@type table<integer, table<string, integer>>
local _virtual_base_resources

---@class virtual_base_resources_general_data
---@type table<string, table<string, any>>
local _virtual_base_resources_general_data

---@class general_forces_data
---@field permission_group LuaPermissionGroup?
---@type table<uint, table>
local _general_forces_data

---@class general_players_data
---@field permission_group LuaPermissionGroup?
---@type table<uint, table>
local _general_players_data

---@class teams_base
---@field surface LuaSurface
---@field position table

---@type table<uint, teams_base>
local _teams_base

---@class online_players_money
---@type table<uint, number>
local _online_players_money

---@class offline_players_money
---@type table<uint, number>
local _offline_players_money

---@class forces_money
---@type table<uint, number>
local _forces_money

--- {{game, name, address, mods = {name, version}}}
---@class server_list
---@type table<number, table<string, string|table>>
local _server_list

---@type uint
local _void_force_index

---@type uint
local _void_surface_index
--#endregion


--#region Values from settings
---@type number
local start_player_money = settings.global["EAPI_start-player-money"].value

---@type number
local start_force_money = settings.global["EAPI_start-force-money"].value

---@type string
local default_permission_group = settings.global["EAPI_default-permission-group"].value

---@type string
local default_force_name = settings.global["EAPI_default-force-name"].value

---@type boolean
local allow_create_team = settings.global["EAPI_allow_create_team"].value
--#endregion


--#region Constants
local custom_events = require("events")
local raise_event = script.raise_event
local constant_forces = {neutral = true, player = true, enemy = true}
local print_to_rcon = rcon.print
local tremove = table.remove
local tconcat = table.concat
--#endregion


--#region Util

---@param s string
local function trim(s)
	return s:match'^%s*(.*%S)' or ''
end

-- Sends message to a player or server
---@param message string
---@param caller LuaPlayer
local function print_to_caller(message, caller)
	if caller then
		if caller.valid then
			caller.print(message)
		end
	else
		print(message) -- this message for server
	end
end

M.assign_default_permission_group = function(player)
	if settings.global["EAPI_permissions_per_player"].value then
		local general_player_data = _general_players_data[player.index]
		general_player_data.permission_group.add_player(player)
	elseif settings.global["EAPI_permissions_per_force"].value then
		_general_forces_data[player.force.index].permission_group.add_player(player)
	elseif settings.global["EAPI_add_admins_to_admin_permission_group"].value then
		if player.admin then
			_mod_data.admin_group.add_player(player)
		end
	end
end

M.on_player_removed = function(event)
	local player_index= event.player_index
	_online_players_money[player_index] = nil
	_offline_players_money[player_index] = nil
	_general_players_data[player_index] = nil
end

local function get_distance(start, stop)
	local xdiff = start.x - stop.x
	local ydiff = start.y - stop.y
	return (xdiff * xdiff + ydiff * ydiff)^0.5
end

local function create_lobby_surface()
	local surface = game.get_surface("Lobby")
	if surface then return surface end

	surface = game.create_surface("Lobby", {width = 1, height = 1})
	surface.request_to_generate_chunks({0, 0}, 1)
	surface.force_generate_chunk_requests()
	surface.set_tiles({{name = "out-of-map", position = {0, 0}}})
	return surface
end


---@param force LuaForce
function remove_team_base(force)
	local force_index = force.index
	local team_base_data = _teams_base[force_index]
	if team_base_data == nil then return end
	raise_event(custom_events.on_pre_deleted_team_base, {force = force, surface = team_base_data.surface, position = team_base_data.position})
	_teams_base[force_index] = nil
end


function create_void_surface()
	local surface = game.get_surface("void")
	if surface then return surface end

	surface = game.create_surface("void", {width = 1, height = 1})
	surface.request_to_generate_chunks({0, 0}, 1)
	surface.force_generate_chunk_requests()
	surface.set_tiles({{name = "out-of-map", position = {0, 0}}})
	_mod_data.void_surface_index = surface.index
	return surface
end

M.reset_balances = function()
	for player_index in pairs(_online_players_money) do
		_online_players_money[player_index] = start_player_money
	end
	for player_index in pairs(_offline_players_money) do
		_offline_players_money[player_index] = start_player_money
	end
	for force_index in pairs(_forces_money) do
		_forces_money[force_index] = start_force_money
	end
end

---@param player LuaPlayer
---@param data online_players_money|forces_money
---@param index integer
local function convert_money(player, data, index)
	local count
	local get_item_count = function(item_name)

		local _count = player.get_item_count(item_name)
		if _count > 0 then
			player.remove_item{name = item_name, count = _count}
		end
		return _count
	end
	count = get_item_count("coin") + get_item_count("coinX50") * 50 + get_item_count("coinX2500") * 2500

	local entity = player.selected
	if entity and entity.valid and entity.force == player.force and entity.operable then
		if get_distance(player.position, entity.position) <= 10 then
			local count_in_entity = entity.get_item_count("coin")
			if count_in_entity > 0 then
				count = count + entity.remove_item({name = "coin", count = count_in_entity})
			end
			count_in_entity = entity.get_item_count("coinX50")
			if count_in_entity > 0 then
				count = count + entity.remove_item({name = "coinX50", count = count_in_entity}) * 50
			end
			count_in_entity = entity.get_item_count("coinX2500")
			if count_in_entity > 0 then
				count = count + entity.remove_item({name = "coinX2500", count = count_in_entity}) * 50
			end
		end
	end

	if count > 0 then
		data[index] = data[index] + count
		player.print("Added: " .. count)
	else
		player.print("Nothing found")
	end
end

---@param player LuaPlayer
---@param data online_players_money|forces_money
---@param index integer
---@param amount integer
local function get_money(player, data, index, amount)
	local current_balance = data[index]
	if amount > current_balance then
		amount = current_balance
	end

	-- TODO: improve
	local stack_data = {name = "coin", count = amount}
	if player.can_insert(stack_data) then
		player.insert(stack_data)
		data[index] = current_balance - amount
	end
end

--#endregion


--#region Functions of events


---@param event on_player_created
M.on_player_created = function(event)
	local player_index = event.player_index
	local player = game.get_player(player_index)
	if not (player and player.valid) then return end

	_mod_data.persistent_players_data[player.name] = _mod_data.persistent_players_data[player.name] or {}
	_general_players_data[player_index] = {}
	_online_players_money[player_index] = start_player_money

	if settings.global["EAPI_permissions_per_player"].value then
		local group = game.permissions.create_group(player.name)
		_general_players_data[player_index].permission_group = group
	end
	M.assign_default_permission_group(player)
end


---@param event on_player_joined_game
M.on_player_joined_game = function(event)
	local player_index = event.player_index
	local player = game.get_player(player_index)
	if not (player and player.valid) then return end

	local money = _offline_players_money[player_index]
	if money then
		_online_players_money[player_index] = money
		_offline_players_money[player_index] = nil
	end

	local force = player.force
	if force.index == _void_force_index then
		force = default_force_name
	end
end


---@param event on_player_left_game
M.on_player_left_game = function(event)
	local player_index = event.player_index
	local money = _online_players_money[player_index]
	if money then
		_offline_players_money[player_index] = money
		_online_players_money[player_index] = nil
	end
end


---@param event on_player_changed_force
M.on_player_changed_force = function(event)
	local player_index = event.player_index
	local player = game.get_player(player_index)
	if not (player and player.valid) then return end

	if settings.global["EAPI_permissions_per_force"].value and
	   settings.global["EAPI_permissions_per_player"].value == false
	then
		_general_forces_data[player.force.index].permission_group.add_player(player)
	end

	local prev_force = event.force
	local target_force = player.force
	if _teams[target_force.index] then
		if _teams[prev_force.index] then
			prev_force.print({"EasyAPI.player-switched-team", player.name, target_force.name})
		end
		target_force.print({"EasyAPI.player-joined-team", player.name})

		raise_event(
			custom_events.on_player_joined_team,
			{
				player_index = player_index,
				force = target_force,
				prev_force = prev_force
			}
		)
	else
		prev_force.print({"EasyAPI.player-left-team", player.name})
	end
end


---@param event on_player_demoted
M.on_player_demoted = function(event)
	local player = game.get_player(event.player_index)
	if not (player and player.valid) then return end

	if _mod_data.admin_group == player.permission_group then
		M.assign_default_permission_group(player)
	end
end


---@param event on_player_promoted
M.on_player_promoted = function(event)
	local player = game.get_player(event.player_index)
	if not (player and player.valid) then return end

	if settings.global["EAPI_permissions_per_player"].value or
	   settings.global["EAPI_permissions_per_force"].value or
	   settings.global["EAPI_add_admins_to_admin_permission_group"].value == false then
	   return
	end

	_mod_data.admin_group.add_player(player)
end


---@param event on_pre_player_removed
M.on_pre_player_removed = function(event)
	local player_index = event.player_index
	local player = game.get_player(player_index)
	local force_index = player.force.index
	local player_money = _online_players_money[player_index]
	-- send player money to force
	if _forces_money[force_index] and player_money then
		_forces_money[force_index] = _forces_money[force_index] + player_money
	end

	local persistent_player_data = _mod_data.persistent_players_data[player.name]
	if persistent_player_data then
		if next(persistent_player_data) == nil then
			_mod_data.persistent_players_data[player.name] = nil
		end
	end
end


---@param event on_game_created_from_scenario
M.on_game_created_from_scenario = function(event)
	if settings.global["EAPI_start-evolution"] then
		game.forces.enemy.evolution_factor = settings.global["EAPI_start-evolution"].value
	end

	raise_event(custom_events.on_new_team, {force = game.forces.player})
	raise_event(custom_events.on_new_team, {force = game.forces.enemy})
	raise_event(custom_events.on_new_team, {force = game.forces.neutral})
end


local mod_settings = {
	["EAPI_default-permission-group"] = function(value) default_permission_group = value end, -- TODO: check the permission group
	["EAPI_start-player-money"] = function(value) start_player_money = value end,
	["EAPI_start-force-money"] = function(value) start_force_money = value end,
	["EAPI_default-force-name"] = function(value) default_force_name = value end,
	["EAPI_allow_create_team"] = function(value) allow_create_team = value end,
	["EAPI_permissions_per_force"]  = function(value)
		local is_permissions_per_force = false
		if settings.global["EAPI_permissions_per_force"].value then
			is_permissions_per_force = true
		end
		local is_permissions_per_player = false
		if settings.global["EAPI_permissions_per_player"].value then
			is_permissions_per_player = true
		end

		for _, force in pairs(game.forces) do
			if force.valid then
				local force_index = force.index
				local general_force_data = _general_forces_data[force_index]
				_general_forces_data[force_index] = _general_forces_data[force_index] or {}
				if is_permissions_per_force then
					if general_force_data.permission_group == nil then
						local force_group = game.permissions.create_group(force.name)
						general_force_data.permission_group = force_group
						if is_permissions_per_player == false then
							for _, player in pairs(force.players) do
								if player.valid then
									force_group.add_player(player)
								end
							end
						end
					end
				elseif general_force_data.permission_group then
					local force_permission_group = general_force_data.permission_group
					for _, player in pairs(force.players) do
						if player.valid and player.permission_group == force_permission_group then
							M.assign_default_permission_group(player)
						end
					end
				end
			end
		end
	end,
	["EAPI_permissions_per_player"] = function(value)
		for _, player in pairs(game.players) do
			if player.valid then
				local general_player_data = _general_players_data[player.index]
				local permission_group = general_player_data.permission_group
				if permission_group == nil then
					permission_group = game.permissions.create_group(player.name)
					general_player_data.permission_group = permission_group
				end
				if value then
					permission_group.add_player(player)
				else
					M.assign_default_permission_group(player)
				end
			end
		end
	end,
	["EAPI_add_admins_to_admin_permission_group"] = function()
		for _, player in pairs(game.players) do
			if player.valid and player.admin then
				if _mod_data.admin_group == player.permission_group then
					M.assign_default_permission_group(player)
				else
					if settings.global["EAPI_permissions_per_player"].value or
						settings.global["EAPI_permissions_per_force"].value or
						settings.global["EAPI_add_admins_to_admin_permission_group"].value == false then
						return
					end

					_mod_data.admin_group.add_player(player)
				end
			end
		end
	end,
}
---@param event on_runtime_mod_setting_changed
M.on_runtime_mod_setting_changed = function(event)
	local setting_name = event.setting
	local f = mod_settings[setting_name]
	if f then f(settings.global[setting_name].value) end
end


---@param event on_forces_merging
M.on_forces_merging = function(event)
	local force = event.source
	if _teams[force.index] then
		raise_event(custom_events.on_pre_deleted_team, {force = force})
	end
end


---@param event on_forces_merged
M.on_forces_merged = function(event)
	local source_index = event.source_index
	_teams[source_index] = nil
	_mod_data.not_deletable_teams[source_index] = nil
	_virtual_base_resources[source_index] = nil
	_general_forces_data[source_index] = nil
end


---@param event on_force_created
M.on_force_created = function(event)
	local force = event.force
	if not (force and force.valid) then return end

	local force_index = force.index
	_general_forces_data[force_index] = {}
	_forces_money[force_index] = start_force_money
	_virtual_base_resources[force_index] = {}
	if settings.global["EAPI_permissions_per_force"].value == false then
		return
	end

	local force_group = game.permissions.create_group(force.name)
	_general_forces_data[force_index].permission_group = force_group
	if settings.global["EAPI_permissions_per_player"].value == false then
		for _, player in pairs(force.players) do
			if player.valid then
				force_group.add_player(player)
			end
		end
	end
end


---@param event on_pre_surface_deleted
M.on_pre_surface_deleted = function(event)
	local surface = game.get_surface(event.surface_index)
	local forces = game.forces
	for force_index, team_data in pairs(_teams_base) do
		if team_data.surface == surface then
			local force = forces[force_index]
			if force and force.valid then
				remove_team_base(force)
			end
		end
	end
end


M.on_pre_deleted_team = function(event)
	local force = event.force
	remove_team_base(force)

	local index = force.index
	_teams_base[index]   = nil
	_forces_money[index] = nil
end


M.on_player_accepted_invite = function(event)
	local player = game.get_player(event.player_index)
	if not (player and player.valid) then return end

	player.force = event.force
end

--#endregion


--#region Commands

M.team_list_command = function(cmd)
	if cmd.player_index == 0 then
		for name, force in pairs(game.forces) do
			print("name: " .. name .. ", index: " .. force.index)
		end
		return
	end

	local player = game.get_player(cmd.player_index)

	local function get_forces(forces)
		local data = {}
		for _, force in pairs(forces) do
			if #force.players > 0 then
				data[#data+1] = force.name
				data[#data+1] = '('
				data[#data+1] = #force.connected_players
				data[#data+1] = '/'
				data[#data+1] = #force.players
				data[#data+1] = ') '
			else
				data[#data+1] = force.name
				data[#data+1] = ' '
			end
		end
		return tconcat(data)
	end

	local ally_forces = {}
	local neutral_forces = {}
	local enemy_forces = {}

	local player_force = player.force
	for _, force in pairs(game.forces) do
		if force ~= player_force then
			if player_force.get_friend(force) then
				ally_forces[#ally_forces+1] = force
			elseif player_force.get_cease_fire(force) then
				neutral_forces[#neutral_forces+1] = force
			else
				enemy_forces[#enemy_forces+1] = force
			end
		end
	end

	player.print({"", "[font=default-large-bold][color=#FFFFFF]", {"gui-map-editor-title.force-editor"}, {"colon"}, " for \"" .. player.force.name .. "\"[/color][/font]"})
	if #enemy_forces > 0 then
		player.print({"", "  [font=default-large-bold][color=#880000]Enemies[/color][/font]", {"colon"}, ' ', get_forces(enemy_forces)})
	end
	if #neutral_forces > 0 then
		player.print({"", "  [font=default-large-bold]Neutrals[/font]", {"colon"}, ' ', get_forces(neutral_forces)})
	end
	if #ally_forces > 0 then
		player.print({"", "  [font=default-large-bold][color=green]Allies[/color][/font]", {"colon"}, ' ', get_forces(ally_forces)})
	end
end

M.show_team_command = function(cmd)
	local caller = game.get_player(cmd.player_index)
	if cmd.parameter == nil then
		if cmd.player_index == 0 then return end
		cmd.parameter = caller.force.name
	elseif #cmd.parameter > 52 then
		print_to_caller({"too-long-team-name"}, caller)
		return
	else
		cmd.parameter = trim(cmd.parameter)
	end

	local target_force = game.forces[cmd.parameter]
	if target_force == nil then
		print_to_caller({"force-doesnt-exist", cmd.parameter}, caller)
		return
	end

	-- TODO: optimize
	local function get_players(force)
		local list = ""
		local count = 0
		for _, player in pairs(force.connected_players) do
			list = ' ' .. list .. player.name
			count = count + 1
			if count > 40 then
				return list .. "+" .. tostring(#force.players - 40)
			end
		end
		for _, player in pairs(force.players) do
			if player.connected == false then
				list = ' ' .. list .. player.name
				count = count + 1
				if count > 40 then
					return list .. "+" .. tostring(#force.players - 40)
				end
			end
		end
		return list
	end

	print_to_caller({"", {"gui-browse-games.games-headers-players"}, {"colon"}, get_players(target_force)}, caller)
end

M.kick_teammate_command = function(cmd)
	local caller = game.get_player(cmd.player_index)
	local target_player = game.get_player(cmd.parameter)
	local force = game.forces[default_force_name] or game.forces.player
	if caller.admin then
		game.print(cmd.parameter .. " was kicked from \"" .. target_player.force.name .. "\" team by " .. caller.name)
		target_player.force = force
		raise_event(custom_events.on_player_kicked_from_team, {player_index = target_player.index, kicker = caller.index})
	elseif caller.force == target_player.force then
		if caller.force.players[1] == caller then
			game.print(cmd.parameter .. " was kicked from \"" .. target_player.force.name .. "\" team by " .. caller.name)
			target_player.force = force
			raise_event(custom_events.on_player_kicked_from_team, {player_index = target_player.index, kicker = caller.index})
		else
			caller.print("You don't have permissions to kick players")
		end
	else
		caller.print("You can't kick a player from another force")
	end
end

M.create_new_team_command = function(cmd)
	local player = game.get_player(cmd.player_index)

	if not allow_create_team then
		player.print("Creation of teams is disabled by setting")
		return
	end

	local team_name = trim(cmd.parameter)
	if #cmd.parameter > 32 then -- 32 is max team name
		player.print({"too-long-team-name"}, {1, 0, 0})
		return
	end

	local new_team = team_util.create_team(team_name, player)
	if new_team == nil then return end

	-- TODO: improve
	local force = player.force
	if #force.players == 1 and not constant_forces[force.name] then
		local technologies = new_team.technologies
		for name, tech in pairs(force.technologies) do
			technologies[name].researched = tech.researched
		end

		if _teams[force.index] and not _mod_data.not_deletable_teams[force.index] then
			game.merge_forces(force, new_team)
		end
	else
		local prev_force = player.force
		player.force = new_team
		local technologies = new_team.technologies
		for name, tech in pairs(prev_force.technologies) do
			technologies[name].researched = tech.researched
		end
	end

	player.print({"EasyAPI.new_team"})
end

M.remove_team_command = function(cmd)
	local admin = game.get_player(cmd.player_index)
	local target_force = game.forces[cmd.parameter]
	if #target_force.players ~= 0 then
		admin.print({"not-empty-team"})
		return
	elseif constant_forces[target_force.name] then
		admin.print({"gui-map-editor-force-editor.cant-delete-built-in-force"})
		return
	end

	game.merge_forces(target_force, game.forces.player)
end

-- TODO: improve
M.friendly_fire_command = function(cmd)
	local friendly_fire_state

	-- TODO: add localization here
	if cmd.parameter == "true" then
		friendly_fire_state = true
		game.print("Friendly fire is enabled")
	elseif cmd.parameter == "false" then
		friendly_fire_state = false
		game.print("Friendly fire is disabled")
	else
		local caller = game.get_player(cmd.player_index)
		caller.print("Parameter must be true or false")
		return
	end

	for _, force in pairs(game.forces) do
		force.friendly_fire = friendly_fire_state
	end
end

M.set_money_command = function(cmd)
	local args = {}
	for arg in string.gmatch(cmd.parameter, "%g+") do args[#args+1] = arg end
	local caller = game.get_player(cmd.player_index)

	local amount = tonumber(args[2] or args[1])
	if amount == nil then
		caller.print({"EasyAPI-commands.set-money"})
		return
	end

	local target
	if #args == 2 then
		target = game.get_player(args[1])
		if not (target and target.valid) then
			caller.print({"player-doesnt-exist", args[1]})
			return
		end
	else
		target = caller
	end

	_online_players_money[target.index] = amount
	caller.print(target.name .. "'s balance: " .. amount)
end

M.set_team_money_command = function(cmd)
	local args = {}
	for arg in string.gmatch(cmd.parameter, "%g+") do args[#args+1] = arg end
	local caller = game.get_player(cmd.player_index)

	local amount = tonumber(args[2] or args[1])
	if amount == nil then
		caller.print({"EasyAPI-commands.set-team-money"})
		return
	end

	local target
	if #args == 2 then
		target = game.forces[args[1]]
		if not (target and target.valid) then
			caller.print({"force-doesnt-exist", args[1]})
			return
		end
	else
		target = caller.force
	end

	_forces_money[target.index] = amount
	caller.print(target.name .. "'s balance: " .. amount)
end

M.deposit_money_command = function(cmd)
	local player_index = cmd.player_index
	local player = game.get_player(player_index)
	if _online_players_money[player_index] == nil then
		player.print({"no-balance"})
		return
	end

	local force = player.force
	if _forces_money[force.index] == nil then
		player.print({"no-team-balance"})
		return
	end

	local args = {}
	for arg in string.gmatch(cmd.parameter, "%g+") do args[#args+1] = arg end

	local amount = tonumber(args[1])
	if amount == nil or amount <= 0 then
		player.print({"EasyAPI-commands.deposit-money"})
		return
	end

	local result = _online_players_money[player_index] - amount
	if result >= 0 then
		_online_players_money[player_index] = result
		_forces_money[force.index] = _forces_money[force.index] + amount
		-- TODO: add localization
		player.print("Your balance: " .. result)
		player.print(force.name .. "'s balance: " .. _forces_money[force.index])
	else
		player.print({"not-enough-money"}, {1, 1, 0})
	end
end

M.withdraw_money_command = function(cmd)
	local player_index = cmd.player_index
	local player = game.get_player(player_index)
	if _online_players_money[player_index] == nil then
		player.print({"no-balance"})
		return
	end

	local force = player.force
	if _forces_money[force.index] == nil then
		player.print({"no-team-balance"})
		return
	end

	local args = {}
	for arg in string.gmatch(cmd.parameter, "%g+") do args[#args+1] = arg end

	local amount = tonumber(args[1])
	if amount == nil or amount <= 0 then
		player.print({"EasyAPI-commands.withdraw-money"})
		return
	end

	local force_index = force.index
	local result = _forces_money[force_index] - amount
	if result >= 0 then
		_forces_money[force_index] = result
		local caller_index = player.index
		_online_players_money[caller_index] = _online_players_money[caller_index] + amount
		local player_balance = _online_players_money[caller_index]
		-- TODO: add localization
		player.print("Your balance: " .. player_balance)
		player.print(force.name .. "'s balance: " .. result)
	else
		player.print({"not-enough-money"}, {1, 1, 0})
	end
end

M.deposit_team_money_command = function(cmd)
	local args = {}
	for arg in string.gmatch(cmd.parameter, "%g+") do args[#args+1] = arg end
	local player = game.get_player(cmd.player_index)

	local amount = tonumber(args[2] or args[1])
	if amount == nil or amount <= 0 then
		player.print({"EasyAPI-commands.deposit-team-money"})
		return
	end

	local target
	if #args == 2 then
		target = game.forces[args[1]]
		if not (target and target.valid) then
			player.print({"force-doesnt-exist", args[1]})
			return
		end
	else
		target = player.force
	end

	_forces_money[target.index] = _forces_money[target.index] + amount
	player.print(target.name .. "'s balance: " .. _forces_money[target.index])
end

M.destroy_team_money_command = function(cmd)
	local args = {}
	for arg in string.gmatch(cmd.parameter, "%g+") do args[#args+1] = arg end
	local player = game.get_player(cmd.player_index)

	local amount = tonumber(args[2] or args[1])
	if amount == nil or amount <= 0 then
		player.print({"EasyAPI-commands.destroy-team-money"})
		return
	end

	local target
	if #args == 2 then
		target = game.forces[args[1]]
		if not (target and target.valid) then
			player.print({"force-doesnt-exist", args[1]})
			return
		end
	else
		target = player.force
	end

	local target_index = target.index
	_forces_money[target_index] = (_forces_money[target_index] or 0) - amount
	-- TODO: add localization
	player.print(target.name .. "'s balance: " .. _forces_money[target_index])
end

--TODO: improve
M.ring_command = function(cmd)
	local caller = game.get_player(cmd.player_index)
	local target_player = game.get_player(cmd.parameter)
	if not (target_player and target_player.valid) then return end
	if caller == target_player then return end

	target_player.play_sound{path = "utility/scenario_message"}
	caller.print{"EasyAPI.ring-sender", target_player.name}
	target_player.print{"EasyAPI.ring-target", caller.name}
end

M.pay_command = function(cmd)
	local args = {}
	for arg in string.gmatch(cmd.parameter, "%g+") do args[#args+1] = arg end

	local player = game.get_player(cmd.player_index)
	if _online_players_money[player.index] == nil then
		player.print({"no-balance"})
		return
	elseif #args < 2 then
		player.print({"EasyAPI-commands.pay"})
		return
	end

	local amount = tonumber(args[2])
	if amount == nil or amount < 0 then
		player.print({"EasyAPI-commands.pay"})
		return
	end

	local target = game.get_player(args[1])
	if not (target and target.valid) then
		player.print({"player-doesnt-exist", args[1]})
		return
	elseif target == player then
		player.print("You can't pay yourself")
		return
	elseif _online_players_money[player.index] == nil then
		player.print("Target doesn't have balance")
		return
	else
		local result = _online_players_money[player.index] - amount
		if result >= 0 then
			_online_players_money[player.index] = result
			_online_players_money[target.index] = _online_players_money[target.index] + amount
			raise_event(custom_events.on_transfered_player_money, {receiver_index = target.index, payer_index = target.index})
			player.print("Your balance: " .. result)
		else
			player.print({"not-enough-money"}, {1, 1, 0})
		end
	end
end

M.balance_command = function(cmd)
	local player = game.get_player(cmd.player_index)
	local parameter = cmd.parameter
	local target
	if parameter == nil then
		target = player.force
	else
		parameter = trim(parameter)
		if parameter == '' then
			target = player.force
		else
			target = game.get_player(parameter)
			if not (target and target.valid) then
				player.print({"player-doesnt-exist", parameter})
				return
			end
		end
	end

	local balance = _online_players_money[player.index]
	if balance then
		player.print("Your balance: " .. _online_players_money[player.index])
	end
	local force_balance = _forces_money[target.index]
	if force_balance then
		player.print(target.name .. "'s balance: " .. force_balance)
	end
end

M.team_balance_command = function(cmd)
	local caller = game.get_player(cmd.player_index)
	local parameter = cmd.parameter
	local target
	if parameter == nil then
		target = caller.force
	else
		parameter = trim(parameter)
		if parameter == '' then
			target = caller.force
		else
			target = game.forces[parameter]
			if not (target and target.valid) then
				caller.print({"force-doesnt-exist", parameter})
				return
			end
		end
	end

	local force = target
	if _forces_money[force.index] then
		caller.print(target.name .. "'s balance: " .. _forces_money[force.index])
	else
		caller.print("No balance for the force", {1, 0, 0})
	end
end

M.transfer_team_money_command = function(cmd)
	local args = {}
	for arg in string.gmatch(cmd.parameter, "%g+") do args[#args+1] = arg end

	local player = game.get_player(cmd.player_index)
	local force = player.force
	if _forces_money[force.index] == nil then
		player.print({"no-team-balance"})
		return
	end

	local amount = tonumber(args[2] or args[1])
	if amount == nil or amount <= 0 then
		player.print({"EasyAPI-commands.transfer-team-money"})
		return
	end

	local target
	if #args == 2 then
		target = game.forces[args[1]]
		if not (target and target.valid) then
			player.print({"force-doesnt-exist", args[1]})
			return
		elseif target == player.force then
			player.print("You can't transfer money to your own team", {1, 0, 0})
			return
		elseif _forces_money[target.index] == nil then
			player.print("Target force doesn't have balance")
			return
		end

		local result = _forces_money[force.index] - amount
		if result >= 0 then
			local target_index = target.index
			_forces_money[force.index] = result
			_forces_money[target_index] = _forces_money[target_index] + amount
			raise_event(custom_events.on_transfered_force_money, {receiver = target, payer = force})
			player.print(force.name .. "'s balance: " .. result)
		else
			player.print({"not-enough-money"}, {1, 1, 0})
		end
	else--if #args == 1 then
		target = player.force
		local caller_index = player.index
		local result = _online_players_money[caller_index] - amount
		if result >= 0 then
			local target_index = target.index
			_online_players_money[caller_index] = result
			_forces_money[target_index] = _forces_money[target_index] + amount
			player.print("Your balance: " .. _online_players_money[caller_index])
		else
			player.print({"not-enough-money"}, {1, 1, 0})
		end
	end
end

M.convert_money_command = function(cmd)
	local player_index = cmd.player_index
	local player = game.get_player(player_index)
	local force_index = player.force.index
	if _forces_money[force_index] then
		convert_money(player, _forces_money, force_index)
	elseif _online_players_money[player_index] then
		convert_money(player, _online_players_money, player_index)
	else
		-- TODO: add localization
		player.print("No balance")
	end
end

M.get_money_command = function(cmd)
	local player_index = cmd.player_index
	local player = game.get_player(player_index)
	local player_force = player.force
	local force_index = player_force.index


	local amount = tonumber(trim(cmd.parameter))
	if amount == nil then
		-- TODO: change
		player.print("NaN")
	elseif amount <= 0 then
		-- TODO: change
		player.print("Invalid number")
	end
	---@cast amount integer

	local current_forces_money = _forces_money[force_index]
	if current_forces_money and current_forces_money > 0 then
		get_money(player, _forces_money, force_index, amount)
		-- TODO: add localization
		player.print("Your balance: " .. _forces_money[force_index])
		return
	end

	local current_player_money = _online_players_money[player_index]
	if current_player_money and current_player_money > 0 then
		get_money(player, _online_players_money, player_index, amount)
		-- TODO: add localization
		player.print(player_force.name .. "'s balance: " .. _forces_money[force_index])
		return
	end

	-- TODO: add localization
	player.print("No balance")
end

--#endregion


--#region Pre-game stage

local function link_data()
	_mod_data = global.EasyAPI
	_teams = _mod_data.teams
	_online_players_money  = _mod_data.online_players_money
	_offline_players_money = _mod_data.offline_players_money
	_teams_base = _mod_data.teams_base
	_forces_money = _mod_data.forces_money
	_void_surface_index = _mod_data.void_surface_index
	_void_force_index = _mod_data.void_force_index
	_server_list = global.server_list
	_virtual_base_resources = _mod_data.virtual_base_resources
	_virtual_base_resources_general_data = _mod_data.virtual_base_resources_general_data
	_general_forces_data  = _mod_data.general_forces_data
	_general_players_data = _mod_data.general_players_data
end

local function update_global_data()
	global.server_list = global.server_list or {}
	global.EasyAPI = global.EasyAPI or {}
	_mod_data = global.EasyAPI
	_mod_data.teams = _mod_data.teams or {}
	_mod_data.online_players_money  = _mod_data.online_players_money  or {}
	_mod_data.offline_players_money = _mod_data.offline_players_money or {}
	---@type table<uint, true>
	_mod_data.not_deletable_teams   = _mod_data.not_deletable_teams   or {}
	_mod_data.forces_money = _mod_data.forces_money or {}
	_mod_data.teams_base = _mod_data.teams_base or {}
	_mod_data.virtual_base_resources = _mod_data.virtual_base_resources or {}
	_mod_data.virtual_base_resources_general_data = _mod_data.virtual_base_resources_general_data or {}
	_mod_data.general_forces_data  = _mod_data.general_forces_data  or {}
	_mod_data.general_players_data = _mod_data.general_players_data or {}
	---@type table<string, table>
	_mod_data.persistent_players_data = _mod_data.persistent_players_data or {}


	local forces = game.forces
	if forces.void == nil then
		_mod_data.void_force_index = game.create_force("void").index
	end
	create_void_surface()

	link_data()

	local permissions = game.permissions
	_mod_data.admin_group = permissions.get_group("Admin") or permissions.create_group("Admin")

	if #_teams == 0 then
		local player_force = forces.player
		_teams[player_force.index] = "player"
		_forces_money[player_force.index] = start_force_money
	end

	local is_permissions_per_force = false
	if settings.global["EAPI_permissions_per_force"].value then
		is_permissions_per_force = true
	end
	local is_permissions_per_player = false
	if settings.global["EAPI_permissions_per_player"].value then
		is_permissions_per_player = true
	end

	for _, force in pairs(game.forces) do
		if force.valid then
			local force_index = force.index
			_virtual_base_resources[force_index] = _virtual_base_resources[force_index] or {}
			_general_forces_data[force_index] = _general_forces_data[force_index] or {}
			local general_force_data = _general_forces_data[force_index]
			if is_permissions_per_force then
				if general_force_data.permission_group == nil then
					local force_group = game.permissions.create_group(force.name)
					general_force_data.permission_group = force_group
					if is_permissions_per_player == false then
						for _, player in pairs(force.players) do
							if player.valid then
								force_group.add_player(player)
							end
						end
					end
				end
			end
		end
	end

	-- TODO: add and use events
	for player_index, data in pairs(_general_players_data) do
		local player = game.get_player(player_index)
		if not (player and player.valid) then
			local permission_group = data.permission_group
			if permission_group then
				permission_group.destroy()
			end
		end
	end

	for player_index, player in pairs(game.players) do
		if player.valid then
			_mod_data.persistent_players_data[player.name] = _mod_data.persistent_players_data[player.name] or {}
			_general_players_data[player_index] = _general_players_data[player_index] or {}
			if player.connected then
				if _online_players_money[player_index] == nil then
					_online_players_money[player_index] = start_player_money
				end
			else
				if _offline_players_money[player_index] == nil then
					_offline_players_money[player_index] = start_player_money
				end
			end
		end
	end

	-- Delete trash data
	for player_index in pairs(_online_players_money) do
		if not game.get_player(player_index) then
			_online_players_money[player_index] = nil
			_offline_players_money[player_index] = nil
		end
	end
	for force_index in pairs(_forces_money) do
		if not forces[force_index] then
			_forces_money[force_index] = nil
		end
	end

	if _forces_money[_void_force_index] then
		_forces_money[_void_force_index] = nil
	end
end


M.on_init = update_global_data
M.on_configuration_changed = function(event)
	update_global_data()

	local mod_changes = event.mod_changes["EasyAPI"]
	if not (mod_changes and mod_changes.old_version) then return end

	local version = tonumber(string.gmatch(mod_changes.old_version, "%d+.%d+")())
	if version < 0.5 then
		for _, force in pairs(game.forces) do
			if force.valid and _forces_money[force.index] == nil then
				_forces_money[force.index] = start_force_money
			end
		end
	end

	if _mod_data.players_money then
		for player_index, money in pairs(_mod_data.players_money) do
			local player = game.get_player(player_index)
			if player and player.valid then
				if player.connected then
					_online_players_money[player_index] = _online_players_money[player_index] or money
				else
					_offline_players_money[player_index] = _offline_players_money[player_index] or money
				end
			end
		end
		_mod_data.players_money = nil
	end
end
M.on_load = link_data

--#endregion


--#region Remote interfaces

remote.add_interface("EasyAPI", {
	get_event_name = function(name)
		return custom_events[name]
	end,
	get_events = function()
		return custom_events
	end,
	get_data = function()
		return _mod_data
	end,
	change_setting = function(type, name, value)
		settings[type][name] = {value = value}
	end,
	assign_default_permission_group = M.assign_default_permission_group,
	---@param force LuaForce
	---@param is_not_deletable true?
	add_team = function(force, is_not_deletable)
		_teams[force.index] = force.name
		if is_not_deletable then
			_mod_data.not_deletable_teams[force.index] = true
		end
		raise_event(custom_events.on_new_team, {force = force})
	end,
	---@param force_index integer
	---@return boolean?
	is_team_deletable = function(force_index)
		if _teams[force_index] then return end
		return not _mod_data.not_deletable_teams[force_index]
	end,
	---@param force LuaForce
	---@param surface LuaSurface
	---@param position MapPosition
	change_team_base = function(force, surface, position)
		_teams_base[force.index] = {surface = surface, position = position}
		raise_event(custom_events.on_new_team_base, {force = force, surface = surface, position = position})
	end,
	remove_team_base = remove_team_base,
	---@param force_index number
	---@return teams_base?
	get_team_base_by_index = function(force_index)
		return _teams_base[force_index]
	end,
	---@param force_index number
	---@return boolean
	has_team_base_by_index = function(force_index)
		return (_teams_base[force_index] ~= nil)
	end,
	get_teams = function()
		return _teams
	end,
	get_teams_count = function()
		return #_teams
	end,
	set_teams = function(new_teams) -- TODO: check
		_mod_data.teams = new_teams
	end,
	remove_team = function(force_index, is_forced)
		local force = game.forces[force_index]
		if not (force and force.valid) then return end

		local team_name = _teams[force_index]
		if not team_name then return 0 end -- not found
		if not is_forced and _mod_data.not_deletable_teams[force_index] then return end

		if not is_forced and force_index == 1 or force_index == 2 or force_index == 3
			or (_void_force_index and force_index == _void_force_index)
		then
			remove_team_base(force)
			return
		end

		raise_event(custom_events.on_pre_deleted_team,
			{force = force}
		)
		_teams[force_index] = nil
		_mod_data.not_deletable_teams[force_index] = nil
		return team_name
	end,
	find_team = function(index)
		for _index, name in pairs(_teams) do
			if _index == index then
				return name
			end
		end

		return 0 -- not found
	end,
	delete_teams = function()
		local forces = game.forces
		local data = {force = nil}
		for force_index in pairs(_teams) do
			data.force = forces[force_index]
			raise_event(custom_events.on_pre_deleted_team, data)
		end
		_mod_data.teams = {}
		_teams = _mod_data.teams
	end,
	-- get_locked_teams = function()
	-- 	return mod_data.locked_teams
	-- end,
	-- set_locked_teams = function(bool)
	-- 	mod_data.locked_teams = bool
	-- end,
	reset_balances = M.reset_balances,
	-- Perhaps, it should be changed to LuaPlayer
	reset_player_balance = function(player_index)
		if game.get_player(player_index).connected then
			_online_players_money[player_index] = start_player_money
		else
			_offline_players_money[player_index] = start_player_money
		end
	end,
	reset_offline_player_balance = function(player_index)
		_offline_players_money[player_index] = start_player_money
	end,
	reset_online_player_balance = function(player_index)
		_online_players_money[player_index] = start_player_money
	end,
	reset_force_balance = function(force)
		_forces_money[force.index] = start_force_money
	end,
	get_general_forces_data = function()
		return _general_forces_data
	end,
	get_general_force_data = function(force_index)
		return _general_forces_data[force_index]
	end,
	set_general_force_data = function(force_index, key, value)
		_general_forces_data[force_index][key] = value
	end,
	get_general_players_data = function()
		return _general_players_data
	end,
	get_general_player_data = function(force_index)
		return _general_players_data[force_index]
	end,
	set_general_player_data = function(force_index, key, value)
		_general_players_data[force_index][key] = value
	end,
	get_persistent_players_data = function()
		return _mod_data.persistent_players_data
	end,
	get_persistent_player_data = function(nickname)
		return _mod_data.persistent_players_data[nickname]
	end,
	set_persistent_player_data = function(nickname, key, value)
		_mod_data.persistent_players_data[nickname][key] = value
	end,
	get_all_virtual_base_resources = function()
		return _virtual_base_resources
	end,
	set_all_virtual_base_resources = function(data)
		_mod_data.virtual_base_resources = data
		_virtual_base_resources = data
	end,
	get_virtual_base_resources_by_force_index = function(force_index)
		return _virtual_base_resources[force_index]
	end,
	get_virtual_base_resource_by_force_index = function(force_index, name)
		return _virtual_base_resources[force_index][name]
	end,
	deposit_virtual_base_resource = function(force_index, name, amount)
		local force_resources = _virtual_base_resources[force_index]
		force_resources[name] = force_resources[name] + amount
	end,
	set_virtual_base_resources_by_force_index = function(force_index, data)
		_virtual_base_resources[force_index] = data
	end,
	set_virtual_base_resource_by_force_index = function(force_index, name, amount)
		_virtual_base_resources[force_index][name] = amount
	end,
	get_virtual_base_resources_general_data = function()
		return _virtual_base_resources_general_data
	end,
	get_virtual_base_resource_general_data = function(name)
		return _virtual_base_resources_general_data[name]
	end,
	set_virtual_base_resource_general_data = function(name, key, value)
		_virtual_base_resources_general_data[name] = _virtual_base_resources_general_data[name] or {}
		_virtual_base_resources_general_data[name][key] = value
	end,
	get_players_money = function()
		return _online_players_money, _offline_players_money
	end,
	get_offline_players_money = function()
		return _offline_players_money
	end,
	set_offline_players_money = function(data)
		_mod_data.offline_players_money = data
		_offline_players_money = data
	end,
	get_online_players_money = function()
		return _online_players_money
	end,
	set_online_players_money = function(data)
		_mod_data.online_players_money = data
		_online_players_money = data
	end,
	get_player_money_by_index = function(player_index)
		return _online_players_money[player_index] or _offline_players_money[player_index]
	end,
	get_online_player_money = function(player_index)
		return _online_players_money[player_index]
	end,
	get_offline_player_money = function(player_index)
		return _offline_players_money[player_index]
	end,
	get_forces_money = function()
		return _forces_money
	end,
	set_forces_money = function(data)
		_mod_data.forces_money = data
		_forces_money = data
	end,
	get_force_money = function(force_index)
		return _forces_money[force_index]
	end,
	set_player_money = function(player, amount)
		if player.connected then
			_online_players_money[player.index] = amount
		else
			_offline_players_money[player.index] = amount
		end
	end,
	set_online_player_money_by_index = function(player_index, amount)
		_online_players_money[player_index] = amount
	end,
	set_offline_player_money_by_index = function(player_index, amount)
		_offline_players_money[player_index] = amount
	end,
	set_force_money_by_index = function(force_index, amount)
		_forces_money[force_index] = amount
	end,
	set_force_money = function(force, amount)
		_forces_money[force.index] = amount
	end,
	deposit_force_money_by_index = function(force_index, amount)
		_forces_money[force_index] = _forces_money[force_index] + amount
	end,
	deposit_force_money = function(force, amount)
		local force_index = force.index
		_forces_money[force_index] = _forces_money[force_index] + amount
	end,
	deposit_player_money_by_index = function(player, amount)
		local player_index = player.index
		if player.connected then
			_online_players_money[player_index] = _online_players_money[player_index] + amount
		else
			_offline_players_money[player_index] = _offline_players_money[player_index] + amount
		end
	end,
	deposit_online_player_money_by_index = function(player_index, amount)
		_online_players_money[player_index] = _online_players_money[player_index] + amount
	end,
	deposit_offline_player_money_by_index = function(player_index, amount)
		_offline_players_money[player_index] = _offline_players_money[player_index] + amount
	end,
	get_void_force_index = function()
		return _void_force_index
	end,
	get_void_surface_index = function()
		return _void_surface_index
	end
})

remote.add_interface("EasyAPI_rcon", {
	get_data = function()
		print_to_rcon(game.table_to_json(_mod_data))
	end,
	get_teams = function()
		print_to_rcon(game.table_to_json(_teams))
	end,
	get_teams_count = function()
		print_to_rcon(#_teams)
	end,
	find_team = function(index)
		for _index, name in pairs(_teams) do
			if _index == index then
				print_to_rcon(name)
			end
		end
	end,
	get_all_virtual_base_resources = function()
		print_to_rcon(game.table_to_json(_virtual_base_resources))
	end,
	get_offline_players_money = function()
		print_to_rcon(game.table_to_json(_offline_players_money))
	end,
	get_online_players_money = function()
		print_to_rcon(game.table_to_json(_online_players_money))
	end,
	get_player_money_by_index = function(player_index)
		print_to_rcon(_online_players_money[player_index] or _offline_players_money[player_index])
	end,
	get_online_player_money = function(player_index)
		print_to_rcon(_online_players_money[player_index])
	end,
	get_offline_player_money = function(player_index)
		print_to_rcon(_offline_players_money[player_index])
	end,
	get_forces_money = function()
		print_to_rcon(game.table_to_json(_forces_money))
	end,
	get_force_money = function(force_index)
		print_to_rcon(_forces_money[force_index])
	end,
	get_void_force_index = function()
		print_to_rcon(_void_force_index)
	end,
	get_void_surface_index = function()
		print_to_rcon(_void_surface_index)
	end
})

remote.add_interface("BridgeAPI", {
	---@param name? string
	set_server_name = function(name)
		global.server_name = name
	end,
	---@return string?
	get_server_name = function()
		return global.server_name
	end,
	get_server_name_for_rcon = function()
		print_to_rcon(global.server_name)
	end,
	---@return server_list
	get_server_list = function()
		return _server_list
	end,
	get_server_list_for_rcon = function()
		print_to_rcon(game.table_to_json(_server_list))
	end,
	---@param game string # Factorio/Minecraft etc
	---@param server_name string
	---@param server_address? string # ip:port or server name
	---@param mods? table<string, string> # {name = name, version = version}
	add_server = function(game, server_name, server_address, mods)
		_server_list[#_server_list+1] = {
			game = game,
			name = server_name,
			address = server_address,
			mods = mods or {}
		}
	end,
	---@param server_name string
	remove_server_by_name = function(server_name)
		for i=1, #_server_list do
			if _server_list[i].name == server_name then
				tremove(_server_list, i)
				return
			end
		end
	end,
	clear_server_list = function()
		global.server_list = {}
		_server_list = global.server_list
	end,
})

--#endregion


M.events = {
	[defines.events.on_game_created_from_scenario] = M.on_game_created_from_scenario,
	[defines.events.on_runtime_mod_setting_changed] = M.on_runtime_mod_setting_changed,
	[defines.events.on_player_created] = M.on_player_created,
	[defines.events.on_player_joined_game] = M.on_player_joined_game,
	[defines.events.on_player_left_game] = M.on_player_left_game,
	[defines.events.on_player_changed_force] = M.on_player_changed_force,
	[defines.events.on_player_demoted] = M.on_player_demoted,
	[defines.events.on_player_promoted] = M.on_player_promoted,
	[defines.events.on_pre_player_removed] = M.on_pre_player_removed,
	[defines.events.on_player_removed] = M.on_player_removed,
	[defines.events.on_forces_merging] = M.on_forces_merging,
	[defines.events.on_forces_merged] = M.on_forces_merged,
	[defines.events.on_force_created] = M.on_force_created,
	[defines.events.on_pre_surface_deleted] = M.on_pre_surface_deleted,
	[custom_events.on_pre_deleted_team] = M.on_pre_deleted_team,
	[custom_events.on_round_start] = M.reset_balances,
	[custom_events.on_player_accepted_invite] = M.on_player_accepted_invite
}

M.commands = {
	create_team = M.create_new_team_command,
	remove_team = M.remove_team_command,
	team_list = M.team_list_command,
	show_team = M.show_team_command,
	kick_teammate = M.kick_teammate_command,
	friendly_fire = M.friendly_fire_command,
	set_money = M.set_money_command,
	set_team_money = M.set_team_money_command,
	deposit_money = M.deposit_money_command,
	withdraw_money = M.withdraw_money_command,
	deposit_team_money = M.deposit_team_money_command,
	destroy_team_money = M.destroy_team_money_command,
	transfer_team_money = M.transfer_team_money_command,
	convert_money = M.convert_money_command,
	get_money = M.get_money_command,
	pay = M.pay_command,
	ring = M.ring_command,
	balance = M.balance_command,
	team_balance = M.team_balance_command,
	bring = function(cmd)
		local player = game.get_player(cmd.player_index)
		local target = game.get_player(cmd.parameter)
		if not (target and target.valid) then
			player.print({"player-doesnt-exist", cmd.parameter})
			return
		elseif player == target then
			player.print({"error.error-message-box-title"})
			return
		end

		local surface = player.surface
		local character = target.character
		if character == nil then
			target.teleport(player.position, surface)
			return
		end

		local position = surface.find_non_colliding_position(
			character.name, player.position, 50, 1
		)
		if position then
			target.teleport(position, surface)
		else
			player.print({"error.error-message-box-title"})
		end
	end,
	["goto"] = function(cmd)
		local player = game.get_player(cmd.player_index)
		local parameter = cmd.parameter
		local target
		if parameter == nil then
			target = player.selected
		else
			target = game.get_player(parameter)
		end

		if not (target and target.valid) then
			if parameter == nil then
				--TODO: change message
				player.print({"error.error-message-box-title"})
				return
			end

			local x, y
			local args = {}
			for arg in string.gmatch(parameter, "%g+") do args[#args+1] = arg end
			if #args == 1 then
				x = string.gsub(parameter, ".*%[gps=(%-?%d+).*", "%1")
				y = string.gsub(parameter, ".*%[gps=.+,(%-?%d+).*", "%1")
				x = tonumber(x)
				y = tonumber(y)
			elseif #args == 2 then
				x = tonumber(args[1])
				y = tonumber(args[2])
			end

			if x == nil or y == nil then
				player.print({"player-doesnt-exist", parameter})
				return
			end
			player.teleport({x, y}, player.surface)
			return
		elseif player == target then
			--TODO: change message
			player.print({"error.error-message-box-title"})
			return
		end

		local surface = target.surface
		local character = player.character
		if character == nil then
			player.teleport(target.position, surface)
			return
		end

		local position = surface.find_non_colliding_position(
			character.name, target.position, 50, 1
		)
		if position then
			player.teleport(position, surface)
		else
			--TODO: change message
			player.print({"error.error-message-box-title"})
		end
	end,
	["unstuck"] = function(cmd)
		local player   = game.get_player(cmd.player_index)
		local surface  = player.surface
		local position = player.position
		player_util.teleport_safely(player, surface, position)
	end,
	["cloak"] = function(cmd)
		local player = game.get_player(cmd.player_index)
		local parameter = cmd.parameter
		if parameter == nil then
			player.show_on_map = false
			return
		end

		local target = game.get_player(parameter)
		if not (target and target.valid) then
			player.print({"player-doesnt-exist", parameter})
			return
		end

		target.show_on_map = false
	end,
	["uncloak"] = function(cmd)
		local player = game.get_player(cmd.player_index)
		local parameter = cmd.parameter
		if parameter == nil then
			player.show_on_map = true
			return
		end

		local target = game.get_player(parameter)
		if not (target and target.valid) then
			player.print({"player-doesnt-exist", parameter})
			return
		end

		target.show_on_map = true
	end,
	fix_bugs = function(cmd)
		raise_event(custom_events.on_fix_bugs, {})
		local player, player_name
		if cmd.player_index ~= 0 then
			player = game.get_player(cmd.player_index)
			if player and player.valid then
				player_name = player.name
			end
		end

		local message = string.format("Mods tried to fix bugs, request by \"%s\"", player_name or "server")
		log(message)
		if player and player.valid then
			player.print(message)
		end
	end,
	sync = function(cmd)
		raise_event(custom_events.on_sync, {})
		raise_event(custom_events.on_fix_bugs, {})
		local player_index = cmd.player_index
		local message
		if player_index == 0 then
			message = "Server forced to sync data"
		else
			local admin = game.get_player(cmd.player_index)
			local admin_name
			if admin and admin.valid then
				admin_name = admin.name
			end
			message = string.format("Admin \"%s\" forced to sync data", admin_name or "?")
		end
		log(message)
		game.print(message)
	end,
	kill = function(cmd)
		local player = game.get_player(cmd.player_index)
		local character = player.character
		if character then
			character.die()
		end
	end,
	hp = function(cmd)
		local player = game.get_player(cmd.player_index)
		local target = player.selected
		if not (target and target.valid) then
			player.print({"error.error-message-box-title"})
			return
		end

		local health = tonumber(cmd.parameter)
		if health == nil then
			--TODO: change message
			player.print({"error.error-message-box-title"})
			return
		end

		target.health = health
	end,
	["play-sound"] = function(cmd)
		local player = game.get_player(cmd.player_index)
		local sound_path = cmd.parameter
		if game.is_valid_sound_pat(sound_path) then
			game.play_sound{path = sound_path}
		else
			--TODO: change message
			player.print({"error.error-message-box-title"})
			return
		end
	end,
}


return M
