local team_util = require("models/team_util")

---@class EasyAPI : module
local M = {}


--#region Global data
local mod_data
local teams
local players_money
local forces_money
--#endregion


--#region Values from settings
local start_player_money = settings.global["start-player-money"].value
local start_force_money = settings.global["start-force-money"].value
local who_decides_diplomacy = settings.global["who-decides-diplomacy"].value
local default_permission_group = settings.global["default-permission-group"].value
local default_force_name = settings.global["default-force-name"].value
--#endregion


--#region Constants
local custom_events = require("events")
local constant_forces = {neutral = true, player = true, enemy = true}
local RED_COLOR = {1,0,0}
local YELLOW_COLOR = {1,1,0}
local MAX_TEAM_NAME_LENGTH = 32
local on_updated_force_balance_event = custom_events.on_updated_force_balance
--#endregion


--#region Util

---@param s string
local function trim(s)
	return s:match'^%s*(.*%S)' or ''
end

-- Sends message to a player or server
local function print_to_caller(message, caller)
	if caller then
		if caller.valid then
			caller.print(message)
		end
	else
		print(message) -- this message for server
	end
end

local function clear_player_data(event)
	players_money[event.player_index] = nil
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
  surface.set_tiles({{name = "out-of-map", position = {1,1}}})
  return surface
end

local function reset_balances()
	for player_index, _ in pairs(players_money) do
		players_money[player_index] = start_player_money
	end
	for force_index, _ in pairs(forces_money) do
		forces_money[force_index] = start_force_money
	end
end

local function reset_player_balance(player_index)
	players_money[player_index] = start_player_money
end

---@param force LuaForce
local function reset_force_balance(force)
	forces_money[force.index] = start_force_money
end

---@param player LuaPLayer
---@param data table #players_money|forces_money
---@param index number
local function convert_money(player, data, index)
	local count = player.get_item_count("coin")
	if count > 0 then
		player.remove_item{name = "coin", count = count}
	end
	local entity = player.selected
	if entity and entity.valid and entity.force == player.force and entity.operable then
		if get_distance(player.position, entity.position) <= 10 then
			local count_in_entity = entity.get_item_count("coin")
			if count_in_entity > 0 then
				count = entity.remove_item({name = "coin", count = count_in_entity}) + count
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

--#endregion


--#region Functions of events

local function on_player_created(event)
	local player_index = event.player_index
	local player = game.get_player(player_index)
	if player.admin then
		game.permissions.get_group("Admin").add_player(player)
	end
	players_money[player_index] = start_player_money
	script.raise_event(custom_events.on_updated_player_balance, {player_index = player_index, balance = start_player_money})
end

local function on_player_changed_force(event)
	local target_force = game.get_player(event.player_index).force
	if teams[target_force.index] then
		script.raise_event(custom_events.on_player_joined_team, {force = target_force})
	end
end

local function on_player_promoted(event)
	game.permissions.get_group("Admin").add_player(game.get_player(event.player_index))
end

local function on_pre_player_removed(event)
	local player_index = event.player_index
	local force_index = game.get_player(player_index).force.index
	local player_money = players_money[player_index]
	-- send player money to force
	if forces_money[force_index] and player_money then
		forces_money[force_index] = forces_money[force_index] + player_money
	end
end

local function on_player_demoted(event)
	local player = game.get_player(event.player_index)
	if player.permission_group.name == "Admin" then
		game.permissions.get_group(default_permission_group).add_player(player)
	end
end

local function on_game_created_from_scenario(event)
	script.raise_event(custom_events.on_new_team, {force = game.forces.player})
end

local function on_runtime_mod_setting_changed(event)
	if event.setting_type ~= "runtime-global" then return end

	if event.setting == "who-decides-diplomacy" then
		who_decides_diplomacy = settings.global[event.setting].value
	elseif event.setting == "default-permission-group" then
		default_permission_group = settings.global[event.setting].value
		-- TODO: check the permission group
	elseif event.setting == "start-player-money" then
		start_player_money = settings.global[event.setting].value
	elseif event.setting == "start-force-money" then
		start_force_money = settings.global[event.setting].value
	elseif event.setting == "default-force-name" then
		default_force_name = settings.global[event.setting].value
	end
end

local function on_forces_merging(event)
	local force = event.source
	if teams[force.index] then
		script.raise_event(custom_events.on_pre_deleted_team, {force = force})
	end
end

local function on_forces_merged(event)
	teams[event.source_index] = nil
end

local function on_new_team(event)
	forces_money[event.force.index] = start_force_money
end

local function on_pre_deleted_team(event)
	forces_money[event.force.index] = nil
end

local function on_player_accepted_invite(event)
	game.get_player(event.player_index).force = event.force
end

--#endregion


--#region Commands

local function team_list_command(cmd)
	if cmd.player_index == 0 then
		for name, _ in pairs(game.forces) do
			print(name)
		end
		return
	end

	local caller = game.get_player(cmd.player_index)

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
		return table.concat(data)
	end

	local ally_forces = {}
	local neutral_forces = {}
	local enemy_forces = {}

	local caller_force = caller.force
	for _, force in pairs(game.forces) do
		if force ~= caller_force then
			if caller_force.get_friend(force) then
				ally_forces[#ally_forces+1] = force
			elseif caller_force.get_cease_fire(force) then
				neutral_forces[#neutral_forces+1] = force
			else
				enemy_forces[#enemy_forces+1] = force
			end
		end
	end

	caller.print({"", "[font=default-large-bold][color=#FFFFFF]", {"gui-map-editor-title.force-editor"}, {"colon"}, " for \"" .. caller.force.name .. "\"[/color][/font]"})
	if #enemy_forces > 0 then
		caller.print({"", "  [font=default-large-bold][color=#880000]Enemies[/color][/font]", {"colon"}, ' ', get_forces(enemy_forces)})
	end
	if #neutral_forces > 0 then
		caller.print({"", "  [font=default-large-bold]Neutrals[/font]", {"colon"}, ' ', get_forces(neutral_forces)})
	end
	if #ally_forces > 0 then
		caller.print({"", "  [font=default-large-bold][color=green]Allies[/color][/font]", {"colon"}, ' ', get_forces(ally_forces)})
	end
end

local function show_team_command(cmd)
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

local function kick_teammate_command(cmd)
	local caller = game.get_player(cmd.player_index)
	local target_player = game.get_player(cmd.parameter)
	local force = game.forces[default_force_name] or game.forces.player
	if caller.admin then
		game.print(cmd.parameter .. " was kicked from \"" .. target_player.force.name .. "\" team by " .. caller.name)
		target_player.force = force
		script.raise_event(custom_events.on_player_kicked_from_team, {player_index = target_player.index, kicker = caller.index})
	elseif caller.force == target_player.force then
		if caller.force.players[1] == caller then
			game.print(cmd.parameter .. " was kicked from \"" .. target_player.force.name .. "\" team by " .. caller.name)
			target_player.force = force
			script.raise_event(custom_events.on_player_kicked_from_team, {player_index = target_player.index, kicker = caller.index})
		else
			caller.print("You don't have permissions to kick players")
		end
	else
		caller.print("You can't kick a player from another force")
	end
end

local function create_new_team_command(cmd)
	local caller = game.get_player(cmd.player_index)

	if #cmd.parameter > (MAX_TEAM_NAME_LENGTH + 2) then
		caller.print({"too-long-team-name"}, RED_COLOR)
		return
	end
	local team_name = trim(cmd.parameter)

	local new_team = team_util.create_team(team_name, caller)
	if new_team == nil then return end

	-- TODO: improve
	if #caller.force.players == 1 and not constant_forces[caller.force.name] then
		local technologies = new_team.technologies
		for name, tech in pairs(caller.force.technologies) do
			technologies[name].researched = tech.researched
		end
		game.merge_forces(caller.force, new_team)
	else
		local prev_force = caller.force
		caller.force = new_team
		local technologies = new_team.technologies
		for name, tech in pairs(prev_force.technologies) do
			technologies[name].researched = tech.researched
		end
	end
end

local function remove_team_command(cmd)
	local caller = game.get_player(cmd.player_index)
	local target_force = game.forces[cmd.parameter]
	if #target_force.players ~= 0 then
		caller.print("The team isn't empty. There are still players in it")
		return
	elseif constant_forces[target_force.name] then
		caller.print({"gui-map-editor-force-editor.cant-delete-built-in-force"})
		return
	end

	game.merge_forces(target_force, game.forces.player)
end

-- TODO: improve
local function friendly_fire_command(cmd)
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

local function set_money_command(cmd)
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

	players_money[target.index] = amount
	script.raise_event(custom_events.on_updated_player_balance, {player_index = target.index, balance = amount})
	caller.print(target.name .. "'s balance: " .. amount)
end

local function set_team_money_command(cmd)
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

	forces_money[target.index] = amount
	script.raise_event(on_updated_force_balance_event, {force = target, balance = amount})
	caller.print(target.name .. "'s balance: " .. amount)
end

local function deposit_money_command(cmd)
	local args = {}
	for arg in string.gmatch(cmd.parameter, "%g+") do args[#args+1] = arg end
	local player_index = cmd.player_index
	local caller = game.get_player(player_index)
	if players_money[player_index] == nil then
		caller.print("You does't have balance")
		return
	end

	local force = caller.force
	if forces_money[force.index] == nil then
		caller.print("Your force doesn't have balance")
		return
	end

	local amount = tonumber(args[1])
	if amount == nil or amount <= 0 then
		caller.print({"EasyAPI-commands.deposit-money"})
		return
	end

	local result = players_money[caller.index] - amount
	if result > 0 then
		players_money[caller.index] = result
		script.raise_event(custom_events.on_updated_player_balance, {player_index = caller.index, balance = result})
		forces_money[force.index] = forces_money[force.index] + amount
		local force_balance = forces_money[force.index]
		script.raise_event(on_updated_force_balance_event, {force = force, balance = force_balance})
		caller.print("Your balance: " .. result)
		caller.print(force.name .. "'s balance: " .. force_balance)
	else
		caller.print("Not enough money", YELLOW_COLOR)
	end
end

local function withdraw_money_command(cmd)
	local args = {}
	for arg in string.gmatch(cmd.parameter, "%g+") do args[#args+1] = arg end

	local player_index = cmd.player_index
	local caller = game.get_player(player_index)
	if players_money[player_index] == nil then
		caller.print("You does't have balance")
		return
	end

	local force = caller.force
	if forces_money[force.index] == nil then
		caller.print("Your force doesn't have balance")
		return
	end

	local amount = tonumber(args[1])
	if amount == nil or amount <= 0 then
		caller.print({"EasyAPI-commands.withdraw-money"})
		return
	end

	local force_index = force.index
	local result = forces_money[force_index] - amount
	if result > 0 then
		forces_money[force_index] = result
		script.raise_event(on_updated_force_balance_event, {force = force, balance = result})
		local caller_index = caller.index
		players_money[caller_index] = players_money[caller_index] + amount
		local player_balance = players_money[caller_index]
		script.raise_event(custom_events.on_updated_player_balance, {player_index = caller_index, balance = player_balance})
		caller.print("Your balance: " .. player_balance)
		caller.print(force.name .. "'s balance: " .. result)
	else
		caller.print("Not enough money", YELLOW_COLOR)
	end
end

local function deposit_team_money_command(cmd)
	local args = {}
	for arg in string.gmatch(cmd.parameter, "%g+") do args[#args+1] = arg end
	local caller = game.get_player(cmd.player_index)

	local amount = tonumber(args[2] or args[1])
	if amount == nil or amount <= 0 then
		caller.print({"EasyAPI-commands.deposit-team-money"})
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

	forces_money[target.index] = forces_money[target.index] + amount
	script.raise_event(on_updated_force_balance_event, {force = target, balance = forces_money[target.index]})
	caller.print(target.name .. "'s balance: " .. forces_money[target.index])
end

local function withdraw_team_money_command(cmd)
	local args = {}
	for arg in string.gmatch(cmd.parameter, "%g+") do args[#args+1] = arg end
	local caller = game.get_player(cmd.player_index)

	local amount = tonumber(args[2] or args[1])
	if amount == nil or amount <= 0 then
		caller.print({"EasyAPI-commands.withdraw-team-money"})
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

	forces_money[target.index] = forces_money[target.index] - amount
	script.raise_event(on_updated_force_balance_event, {force = target, balance = forces_money[target.index]})
	caller.print(target.name .. "'s balance: " .. forces_money[target.index])
end

local function pay_command(cmd)
	local args = {}
	for arg in string.gmatch(cmd.parameter, "%g+") do args[#args+1] = arg end

	local caller = game.get_player(cmd.player_index)
	if players_money[caller.index] == nil then
		caller.print("You don't have balance")
		return
	elseif #args < 2 then
		caller.print({"EasyAPI-commands.pay"})
		return
	end

	local amount = tonumber(args[2])
	if amount == nil or amount < 0 then
		caller.print({"EasyAPI-commands.pay"})
		return
	end

	local target = game.get_player(args[1])
	if not (target and target.valid) then
		caller.print({"player-doesnt-exist", args[1]})
		return
	elseif target == caller then
		caller.print("You can't pay yourself")
		return
	elseif players_money[caller.index] == nil then
		caller.print("Target doesn't have balance")
		return
	else
		local result = players_money[caller.index] - amount
		if result > 0 then
			players_money[caller.index] = result
			script.raise_event(custom_events.on_updated_player_balance, {target = caller, balance = result})
			players_money[target.index] = players_money[target.index] + amount
			local target_balance = players_money[target.index]
			script.raise_event(custom_events.on_updated_player_balance, {target = target, balance = target_balance})
			script.raise_event(custom_events.on_transfered_player_money, {receiver_index = target.index, payer_index = target.index})
			caller.print("Your balance: " .. result)
		else
			caller.print("Not enough money", YELLOW_COLOR)
		end
	end
end

local function balance_command(cmd)
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
			target = game.get_player(parameter)
			if not (target and target.valid) then
				caller.print({"player-doesnt-exist", parameter})
				return
			end
		end
	end

	local balance = players_money[caller.index]
	if balance then
		caller.print("Your balance: " .. players_money[caller.index])
	end
	local force_balance = forces_money[target.index]
	if force_balance then
		caller.print(target.name .. "'s balance: " .. force_balance)
	end
end

local function team_balance_command(cmd)
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
	if forces_money[force.index] then
		caller.print(target.name .. "'s balance: " .. forces_money[force.index])
	else
		caller.print("No balance for the force", RED_COLOR)
	end
end

local function transfer_team_money_command(cmd)
	local args = {}
	for arg in string.gmatch(cmd.parameter, "%g+") do args[#args+1] = arg end

	local caller = game.get_player(cmd.player_index)
	local force = caller.force
	if forces_money[force.index] == nil then
		caller.print("Your force doesn't have balance")
		return
	end

	local amount = tonumber(args[2] or args[1])
	if amount == nil or amount <= 0 then
		caller.print({"EasyAPI-commands.transfer-team-money"})
		return
	end

	local target
	if #args == 2 then
		target = game.forces[args[1]]
		if not (target and target.valid) then
			caller.print({"force-doesnt-exist", args[1]})
			return
		elseif target == caller.force then
			caller.print("You can't transfer money to your own team", RED_COLOR)
			return
		elseif forces_money[target.index] == nil then
			caller.print("Target force doesn't have balance")
			return
		end

		local result = forces_money[force.index] - amount
		if result > 0 then
			local target_index = target.index
			forces_money[force.index] = result
			script.raise_event(on_updated_force_balance_event, {force = force, balance = result})
			forces_money[target_index] = forces_money[target_index] + amount
			script.raise_event(on_updated_force_balance_event, {force = target, balance = forces_money[target_index]})
			script.raise_event(custom_events.on_transfered_force_money, {receiver = target, payer = force})
			caller.print(force.name .. "'s balance: " .. result)
		else
			caller.print("Not enough money", YELLOW_COLOR)
		end
	else--if #args == 1 then
		target = caller.force
		local caller_index = caller.index
		local result = players_money[caller_index] - amount
		if result > 0 then
			local target_index = target.index
			players_money[caller_index] = result
			script.raise_event(custom_events.on_updated_player_balance, {player_index = caller_index, balance = result})
			forces_money[target_index] = forces_money[target_index] + amount
			script.raise_event(on_updated_force_balance_event, {force = target, balance = forces_money[target_index]})
			caller.print("Your balance: " .. players_money[caller_index])
		else
			caller.print("Not enough money", YELLOW_COLOR)
		end
	end
end

local function convert_money_command(cmd)
	local player_index = cmd.player_index
	local player = game.get_player(player_index)
	local force_index = player.force.index
	if forces_money[force_index] then
		convert_money(player, forces_money, force_index)
	elseif players_money[player_index] then
		convert_money(player, forces_money, player_index)
	else
		player.print("No balance")
	end
end

--#endregion


--#region Pre-game stage

local function link_data()
	mod_data = global.EasyAPI
	teams = mod_data.teams
	players_money = mod_data.players_money
	forces_money = mod_data.forces_money
end

local function update_global_data()
	global.EasyAPI = global.EasyAPI or {}
	mod_data = global.EasyAPI
	mod_data.teams = mod_data.teams or {}
	mod_data.players_money = mod_data.players_money or {}
	mod_data.forces_money = mod_data.forces_money or {}

	link_data()

	local permissions = game.permissions
	local group = permissions.get_group("Admin")
	if group == nil then
		permissions.create_group("Admin")
	end

	if #teams == 0 then
		local player_force = game.forces.player
		teams[player_force.index] = "player"
		forces_money[player_force.index] = start_force_money
	end

	for player_index, _ in pairs(game.players) do
		if players_money[player_index] == nil then
			players_money[player_index] = start_player_money
		end
	end

	-- Delete trash data
	for player_index, _ in pairs(players_money) do
		if not game.get_player(player_index) then
			players_money[player_index] = nil
		end
	end
	for force_index, _ in pairs(forces_money) do
		if not game.forces[force_index] then
			forces_money[force_index] = nil
		end
	end
end


M.on_init = update_global_data
M.on_configuration_changed = update_global_data
M.on_load = link_data


remote.add_interface("EasyAPI", {
	get_event_name = function(name)
		return custom_events[name]
	end,
	get_events = function()
		return custom_events
	end,
	get_data = function()
		return mod_data
	end,
	add_team = function(force)
		teams[force.index] = force.name
		script.raise_event(custom_events.on_new_team, {force = force})
	end,
	get_teams = function()
		return teams
	end,
	set_teams = function(new_teams) -- TODO: check
		mod_data.teams = new_teams
	end,
	remove_team = function(index)
		for _index, name in pairs(teams) do
			if _index == index then
				local force = game.forces[name]
				script.raise_event(custom_events.on_pre_deleted_team, {force = force})
				teams[_index] = nil
				return name
			end
		end

		return 0 -- not found
	end,
	find_team = function(index)
		for _index, name in pairs(teams) do
			if _index == index then
				return name
			end
		end

		return 0 -- not found
	end,
	delete_teams = function()
		for _, name in pairs(teams) do
			local force = game.forces[name]
			script.raise_event(custom_events.on_pre_deleted_team, {force = force})
		end
		mod_data.teams = nil
	end,
	-- get_locked_teams = function()
	-- 	return mod_data.locked_teams
	-- end,
	-- set_locked_teams = function(bool)
	-- 	mod_data.locked_teams = bool
	-- end,
	reset_balances = reset_balances,
	reset_player_balance = reset_player_balance,
	reset_force_balance = reset_force_balance,
	get_players_money = function()
		return players_money
	end,
	get_player_money = function(player_index)
		return players_money[player_index]
	end,
	get_forces_money = function()
		return forces_money
	end,
	get_force_money = function(force_index)
		return forces_money[force_index]
	end,
	set_player_money = function(player_index, amount)
		players_money[player_index] = amount
		script.raise_event(custom_events.on_updated_player_balance, {player_index = player_index, balance = amount})
	end,
	set_force_money_by_index = function(force_index, amount)
		forces_money[force_index] = amount or 0
	end,
	set_force_money = function(force, amount)
		forces_money[force.index] = amount
		script.raise_event(on_updated_force_balance_event, {force = force, balance = amount})
	end,
	deposit_force_money = function(force, amount)
		local force_index = force.index
		local new_amount = (forces_money[force_index] or 0) + (amount or 0)
		forces_money[force_index] = new_amount
		script.raise_event(on_updated_force_balance_event, {force = force, balance = new_amount})
	end
})

--#endregion


M.events = {
	[defines.events.on_game_created_from_scenario] = on_game_created_from_scenario,
	[defines.events.on_runtime_mod_setting_changed] = on_runtime_mod_setting_changed,
	[defines.events.on_player_created] = function(event)
		pcall(on_player_created, event)
	end,
	[defines.events.on_player_changed_force] = function(event)
		pcall(on_player_changed_force, event)
	end,
	[defines.events.on_player_demoted] = function(event)
		pcall(on_player_demoted, event)
	end,
	[defines.events.on_player_promoted] = function(event)
		pcall(on_player_promoted, event)
	end,
	[defines.events.on_pre_player_removed] = on_pre_player_removed,
	[defines.events.on_player_removed] = clear_player_data,
	[defines.events.on_forces_merging] = on_forces_merging,
	[defines.events.on_forces_merged] = on_forces_merged,
	[custom_events.on_new_team] = on_new_team,
	[custom_events.on_pre_deleted_team] = on_pre_deleted_team,
	[custom_events.on_round_start] = reset_balances,
	[custom_events.on_player_accepted_invite] = on_player_accepted_invite
}

M.commands = {
	create_team = create_new_team_command,
	remove_team = remove_team_command,
	team_list = team_list_command,
	show_team = show_team_command,
	kick_teammate = kick_teammate_command,
	friendly_fire = friendly_fire_command,
	set_money = set_money_command,
	set_team_money = set_team_money_command,
	deposit_money = deposit_money_command,
	withdraw_money = withdraw_money_command,
	deposit_team_money = deposit_team_money_command,
	withdraw_team_money = withdraw_team_money_command,
	transfer_team_money = transfer_team_money_command,
	convert_money = convert_money_command,
	pay = pay_command,
	balance = balance_command,
	team_balance = team_balance_command
}


return M
