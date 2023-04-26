local team_util = require("models/team_util")


---@class EasyAPI : module
local M = {}


--#region Global data
---@type table<string, any>
local mod_data

---@class teams
---@type table<number, string>
local teams

---@class virtual_base_resources
---@type table<integer, table<string, integer>>
local virtual_base_resources

---@class virtual_base_resources_general_data
---@type table<string, table<string, any>>
local virtual_base_resources_general_data

---@class general_forces_data
---@type table<integer, table>
local general_forces_data

---@class general_players_data
---@type table<integer, table>
local general_players_data

---@class teams_base
---@field surface LuaSurface
---@field position table
---@type table<number, table>
local teams_base

---@class online_players_money
---@type table<number, number>
local online_players_money

---@class offline_players_money
---@type table<number, number>
local offline_players_money

---@class forces_money
---@type table<number, number>
local forces_money

--- {{game, name, address, mods = {name, version}}}
---@class server_list
---@type table<number, table<string, string|table>>
local server_list

---@type number
local void_force_index

---@type number
local void_surface_index
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
---@param	message string
---@param	caller LuaPlayer
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
	online_players_money[event.player_index] = nil
	offline_players_money[event.player_index] = nil
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

local function create_void_surface()
	local surface = game.get_surface("void")
	if surface then return surface end

	surface = game.create_surface("void", {width = 1, height = 1})
	surface.request_to_generate_chunks({0, 0}, 1)
	surface.force_generate_chunk_requests()
	surface.set_tiles({{name = "out-of-map", position = {0, 0}}})
	mod_data.void_surface_index = surface.index
	return surface
end

local function reset_balances()
	for player_index in pairs(online_players_money) do
		online_players_money[player_index] = start_player_money
	end
	for player_index in pairs(offline_players_money) do
		offline_players_money[player_index] = start_player_money
	end
	for force_index in pairs(forces_money) do
		forces_money[force_index] = start_force_money
	end
end

-- Perhaps, it should be changed to LuaPlayer
local function reset_player_balance(player_index)
	if game.get_player(player_index).connected then
		online_players_money[player_index] = start_player_money
	else
		offline_players_money[player_index] = start_player_money
	end
end

local function reset_offline_player_balance(player_index)
	offline_players_money[player_index] = start_player_money
end

local function reset_online_player_balance(player_index)
	online_players_money[player_index] = start_player_money
end

---@param force LuaForce
local function reset_force_balance(force)
	forces_money[force.index] = start_force_money
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

local function on_player_created(event)
	local player_index = event.player_index
	local player = game.get_player(player_index)
	if not (player and player.valid) then return end

	general_players_data[player_index] = {}
	online_players_money[player_index] = start_player_money

	if player.admin then
		local group = game.permissions.get_group("Admin")
		if group then
			group.add_player(player)
		end
	end
end

local function on_player_joined_game(event)
	local player_index = event.player_index
	local player = game.get_player(player_index)
	if not (player and player.valid) then return end

	local money = offline_players_money[player_index]
	if money then
		online_players_money[player_index] = money
		offline_players_money[player_index] = nil
	end

	local force = player.force
	if force.index == void_force_index then
		force = default_force_name
	end
end

local function on_player_left_game(event)
	local player_index = event.player_index
	local money = online_players_money[player_index]
	if money then
		offline_players_money[player_index] = money
		online_players_money[player_index] = nil
	end
end

local function on_player_changed_force(event)
	local player_index = event.player_index
	local player = game.get_player(player_index)
	if not (player and player.valid) then return end

	local prev_force = event.force
	local target_force = player.force
	if teams[target_force.index] then
		if teams[prev_force.index] then
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

local function on_player_demoted(event)
	local player = game.get_player(event.player_index)
	if not (player and player.valid) then return end

	if player.permission_group.name == "Admin" then
		local group = game.permissions.get_group(default_permission_group)
		if group then
			group.add_player(player)
		end
	end
end

local function on_player_promoted(event)
	local player = game.get_player(event.player_index)
	if not (player and player.valid) then return end

	local admin_group = game.permissions.get_group("Admin")
	if admin_group == nil then return end
	admin_group.add_player(player)
end

local function on_pre_player_removed(event)
	local player_index = event.player_index
	local force_index = game.get_player(player_index).force.index
	local player_money = online_players_money[player_index]
	-- send player money to force
	if forces_money[force_index] and player_money then
		forces_money[force_index] = forces_money[force_index] + player_money
	end
end

local function on_game_created_from_scenario()
	raise_event(custom_events.on_new_team, {force = game.forces.player})
	raise_event(custom_events.on_new_team, {force = game.forces.enemy})
	raise_event(custom_events.on_new_team, {force = game.forces.neutral})
end

local mod_settings = {
	["EAPI_default-permission-group"] = function(value) default_permission_group = value end, -- TODO: check the permission group
	["EAPI_start-player-money"] = function(value) start_player_money = value end,
	["EAPI_start-force-money"] = function(value) start_force_money = value end,
	["EAPI_default-force-name"] = function(value) default_force_name = value end,
	["EAPI_allow_create_team"] = function(value) allow_create_team = value end
}
local function on_runtime_mod_setting_changed(event)
	local setting_name = event.setting
	local f = mod_settings[setting_name]
	if f then f(settings.global[setting_name].value) end
end

local function on_forces_merging(event)
	local force = event.source
	if teams[force.index] then
		raise_event(custom_events.on_pre_deleted_team, {force = force})
	end
end

local function on_forces_merged(event)
	local source_index = event.source_index
	teams[source_index] = nil
	virtual_base_resources[source_index] = nil
end

local function on_force_created(event)
	local force = event.force
	if not (force and force.valid) then return end

	local force_index = force.index
	general_forces_data[force_index] = {}
	forces_money[force_index] = start_force_money
	virtual_base_resources[force_index] = {}
end

local function on_pre_deleted_team(event)
	local index = event.force.index
	teams_base[index] = nil
	forces_money[index] = nil
end

local function on_player_accepted_invite(event)
	local player = game.get_player(event.player_index)
	if not (player and player.valid) then return end

	player.force = event.force
end

--#endregion


--#region Commands

local function team_list_command(cmd)
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

local function create_new_team_command(cmd)
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
	if #player.force.players == 1 and not constant_forces[player.force.name] then
		local technologies = new_team.technologies
		for name, tech in pairs(player.force.technologies) do
			technologies[name].researched = tech.researched
		end
		game.merge_forces(player.force, new_team)
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

local function remove_team_command(cmd)
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

	online_players_money[target.index] = amount
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
	caller.print(target.name .. "'s balance: " .. amount)
end

local function deposit_money_command(cmd)
	local player_index = cmd.player_index
	local player = game.get_player(player_index)
	if online_players_money[player_index] == nil then
		player.print({"no-balance"})
		return
	end

	local force = player.force
	if forces_money[force.index] == nil then
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

	local result = online_players_money[player_index] - amount
	if result >= 0 then
		online_players_money[player_index] = result
		forces_money[force.index] = forces_money[force.index] + amount
		-- TODO: add localization
		player.print("Your balance: " .. result)
		player.print(force.name .. "'s balance: " .. forces_money[force.index])
	else
		player.print({"not-enough-money"}, {1, 1, 0})
	end
end

local function withdraw_money_command(cmd)
	local player_index = cmd.player_index
	local player = game.get_player(player_index)
	if online_players_money[player_index] == nil then
		player.print({"no-balance"})
		return
	end

	local force = player.force
	if forces_money[force.index] == nil then
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
	local result = forces_money[force_index] - amount
	if result >= 0 then
		forces_money[force_index] = result
		local caller_index = player.index
		online_players_money[caller_index] = online_players_money[caller_index] + amount
		local player_balance = online_players_money[caller_index]
		-- TODO: add localization
		player.print("Your balance: " .. player_balance)
		player.print(force.name .. "'s balance: " .. result)
	else
		player.print({"not-enough-money"}, {1, 1, 0})
	end
end

local function deposit_team_money_command(cmd)
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

	forces_money[target.index] = forces_money[target.index] + amount
	player.print(target.name .. "'s balance: " .. forces_money[target.index])
end

local function destroy_team_money_command(cmd)
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
	forces_money[target_index] = (forces_money[target_index] or 0) - amount
	-- TODO: add localization
	player.print(target.name .. "'s balance: " .. forces_money[target_index])
end

--TODO: improve
local function ring_command(cmd)
	local caller = game.get_player(cmd.player_index)
	local target_player = game.get_player(cmd.parameter)
	if not (target_player and target_player.valid) then return end
	if caller == target_player then return end

	target_player.play_sound{path = "utility/scenario_message"}
	caller.print{"EasyAPI.ring-sender", target_player.name}
	target_player.print{"EasyAPI.ring-target", caller.name}
end

local function pay_command(cmd)
	local args = {}
	for arg in string.gmatch(cmd.parameter, "%g+") do args[#args+1] = arg end

	local player = game.get_player(cmd.player_index)
	if online_players_money[player.index] == nil then
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
	elseif online_players_money[player.index] == nil then
		player.print("Target doesn't have balance")
		return
	else
		local result = online_players_money[player.index] - amount
		if result >= 0 then
			online_players_money[player.index] = result
			online_players_money[target.index] = online_players_money[target.index] + amount
			raise_event(custom_events.on_transfered_player_money, {receiver_index = target.index, payer_index = target.index})
			player.print("Your balance: " .. result)
		else
			player.print({"not-enough-money"}, {1, 1, 0})
		end
	end
end

local function balance_command(cmd)
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

	local balance = online_players_money[player.index]
	if balance then
		player.print("Your balance: " .. online_players_money[player.index])
	end
	local force_balance = forces_money[target.index]
	if force_balance then
		player.print(target.name .. "'s balance: " .. force_balance)
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
		caller.print("No balance for the force", {1, 0, 0})
	end
end

local function transfer_team_money_command(cmd)
	local args = {}
	for arg in string.gmatch(cmd.parameter, "%g+") do args[#args+1] = arg end

	local player = game.get_player(cmd.player_index)
	local force = player.force
	if forces_money[force.index] == nil then
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
		elseif forces_money[target.index] == nil then
			player.print("Target force doesn't have balance")
			return
		end

		local result = forces_money[force.index] - amount
		if result >= 0 then
			local target_index = target.index
			forces_money[force.index] = result
			forces_money[target_index] = forces_money[target_index] + amount
			raise_event(custom_events.on_transfered_force_money, {receiver = target, payer = force})
			player.print(force.name .. "'s balance: " .. result)
		else
			player.print({"not-enough-money"}, {1, 1, 0})
		end
	else--if #args == 1 then
		target = player.force
		local caller_index = player.index
		local result = online_players_money[caller_index] - amount
		if result >= 0 then
			local target_index = target.index
			online_players_money[caller_index] = result
			forces_money[target_index] = forces_money[target_index] + amount
			player.print("Your balance: " .. online_players_money[caller_index])
		else
			player.print({"not-enough-money"}, {1, 1, 0})
		end
	end
end

local function convert_money_command(cmd)
	local player_index = cmd.player_index
	local player = game.get_player(player_index)
	local force_index = player.force.index
	if forces_money[force_index] then
		convert_money(player, forces_money, force_index)
	elseif online_players_money[player_index] then
		convert_money(player, online_players_money, player_index)
	else
		-- TODO: add localization
		player.print("No balance")
	end
end

local function get_money_command(cmd)
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

	local current_forces_money = forces_money[force_index]
	if current_forces_money and current_forces_money > 0 then
		get_money(player, forces_money, force_index, amount)
		-- TODO: add localization
		player.print("Your balance: " .. forces_money[force_index])
		return
	end

	local current_player_money = online_players_money[player_index]
	if current_player_money and current_player_money > 0 then
		get_money(player, online_players_money, player_index, amount)
		-- TODO: add localization
		player.print(player_force.name .. "'s balance: " .. forces_money[force_index])
		return
	end

	-- TODO: add localization
	player.print("No balance")
end

--#endregion


--#region Pre-game stage

local function link_data()
	mod_data = global.EasyAPI
	teams = mod_data.teams
	online_players_money  = mod_data.online_players_money
	offline_players_money = mod_data.offline_players_money
	teams_base = mod_data.teams_base
	forces_money = mod_data.forces_money
	void_surface_index = mod_data.void_surface_index
	void_force_index = mod_data.void_force_index
	server_list = global.server_list
	virtual_base_resources = mod_data.virtual_base_resources
	virtual_base_resources_general_data = mod_data.virtual_base_resources_general_data
	general_forces_data  = mod_data.general_forces_data
	general_players_data = mod_data.general_players_data
end

local function update_global_data()
	global.server_list = global.server_list or {}
	global.EasyAPI = global.EasyAPI or {}
	mod_data = global.EasyAPI
	mod_data.teams = mod_data.teams or {}
	mod_data.online_players_money  = mod_data.online_players_money  or {}
	mod_data.offline_players_money = mod_data.offline_players_money or {}
	mod_data.forces_money = mod_data.forces_money or {}
	mod_data.teams_base = mod_data.teams_base or {}
	mod_data.virtual_base_resources = mod_data.virtual_base_resources or {}
	mod_data.virtual_base_resources_general_data = mod_data.virtual_base_resources_general_data or {}
	mod_data.general_forces_data  = mod_data.general_forces_data  or {}
	mod_data.general_players_data = mod_data.general_players_data or {}


	local forces = game.forces
	if forces.void == nil then
		mod_data.void_force_index = game.create_force("void").index
	end
	create_void_surface()

	link_data()

	local permissions = game.permissions
	local group = permissions.get_group("Admin")
	if group == nil then
		permissions.create_group("Admin")
	end

	if #teams == 0 then
		local player_force = forces.player
		teams[player_force.index] = "player"
		forces_money[player_force.index] = start_force_money
	end

	for _, force in pairs(game.forces) do
		if force.valid then
			local force_index = force.index
			general_forces_data = general_forces_data or {}
			virtual_base_resources[force_index] = virtual_base_resources[force_index] or {}
		end
	end

	for player_index, player in pairs(game.players) do
		if player.valid then
			general_players_data = general_players_data or {}
			if player.connected then
				if online_players_money[player_index] == nil then
					online_players_money[player_index] = start_player_money
				end
			else
				if offline_players_money[player_index] == nil then
					offline_players_money[player_index] = start_player_money
				end
			end
		end
	end

	-- Delete trash data
	for player_index in pairs(online_players_money) do
		if not game.get_player(player_index) then
			online_players_money[player_index] = nil
			offline_players_money[player_index] = nil
		end
	end
	for force_index in pairs(forces_money) do
		if not forces[force_index] then
			forces_money[force_index] = nil
		end
	end

	if forces_money[void_force_index] then
		forces_money[void_force_index] = nil
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
			if force.valid and forces_money[force.index] == nil then
				forces_money[force.index] = start_force_money
			end
		end
	end

	if mod_data.players_money then
		for player_index, money in pairs(mod_data.players_money) do
			local player = game.get_player(player_index)
			if player and player.valid then
				if player.connected then
					online_players_money[player_index] = online_players_money[player_index] or money
				else
					offline_players_money[player_index] = offline_players_money[player_index] or money
				end
			end
		end
		mod_data.players_money = nil
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
		return mod_data
	end,
	add_team = function(force)
		teams[force.index] = force.name
		raise_event(custom_events.on_new_team, {force = force})
	end,
	---@param force LuaForce
	---@param position table
	---@return boolean?
	change_team_base = function(force, surface, position)
		teams_base[force.index] = {surface = surface, position = position}
		raise_event(custom_events.on_new_team_base, {force = force, surface = surface, position = position})
	end,
	---@param force LuaForce
	remove_team_base = function(force)
		raise_event(custom_events.on_pre_deleted_team_base, {force = force})
		teams_base[force.index] = nil
	end,
	---@param force_index number
	---@return teams_base?
	get_team_base_by_index = function(force_index)
		return teams_base[force_index]
	end,
	---@param force_index number
	---@return boolean
	has_team_base_by_index = function(force_index)
		if teams_base[force_index] then
			return true
		end
		return false
	end,
	get_teams = function()
		return teams
	end,
	get_teams_count = function()
		return #teams
	end,
	set_teams = function(new_teams) -- TODO: check
		mod_data.teams = new_teams
	end,
	remove_team = function(index)
		local forces = game.forces
		for _index, name in pairs(teams) do
			if _index == index then
				raise_event(custom_events.on_pre_deleted_team, {force = forces[_index]})
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
		local forces = game.forces
		local data = {force = nil}
		for force_index in pairs(teams) do
			data.force = forces[force_index]
			raise_event(custom_events.on_pre_deleted_team, data)
		end
		mod_data.teams = {}
		teams = mod_data.teams
	end,
	-- get_locked_teams = function()
	-- 	return mod_data.locked_teams
	-- end,
	-- set_locked_teams = function(bool)
	-- 	mod_data.locked_teams = bool
	-- end,
	reset_balances = reset_balances,
	reset_player_balance = reset_player_balance,
	reset_offline_player_balance = reset_offline_player_balance,
	reset_online_player_balance = reset_online_player_balance,
	reset_force_balance = reset_force_balance,
	get_general_forces_data = function()
		return general_forces_data
	end,
	get_general_force_data = function(force_index)
		return general_forces_data[force_index]
	end,
	set_general_force_data = function(force_index, key, value)
		general_forces_data[force_index][key] = value
	end,
	get_general_players_data = function()
		return general_players_data
	end,
	get_general_player_data = function(force_index)
		return general_players_data[force_index]
	end,
	set_general_player_data = function(force_index, key, value)
		general_players_data[force_index][key] = value
	end,
	get_all_virtual_base_resources = function()
		return virtual_base_resources
	end,
	set_all_virtual_base_resources = function(data)
		mod_data.virtual_base_resources = data
		virtual_base_resources = data
	end,
	get_virtual_base_resources_by_force_index = function(force_index)
		return virtual_base_resources[force_index]
	end,
	get_virtual_base_resource_by_force_index = function(force_index, name)
		return virtual_base_resources[force_index][name]
	end,
	deposit_virtual_base_resource = function(force_index, name, amount)
		local force_resources = virtual_base_resources[force_index]
		force_resources[name] = force_resources[name] + amount
	end,
	set_virtual_base_resources_by_force_index = function(force_index, data)
		virtual_base_resources[force_index] = data
	end,
	set_virtual_base_resource_by_force_index = function(force_index, name, amount)
		virtual_base_resources[force_index][name] = amount
	end,
	get_virtual_base_resources_general_data = function()
		return virtual_base_resources_general_data
	end,
	get_virtual_base_resource_general_data = function(name)
		return virtual_base_resources_general_data[name]
	end,
	set_virtual_base_resource_general_data = function(name, key, value)
		virtual_base_resources_general_data[name] = virtual_base_resources_general_data[name] or {}
		virtual_base_resources_general_data[name][key] = value
	end,
	get_players_money = function()
		return online_players_money, offline_players_money
	end,
	get_offline_players_money = function()
		return offline_players_money
	end,
	set_offline_players_money = function(data)
		mod_data.offline_players_money = data
		offline_players_money = data
	end,
	get_online_players_money = function()
		return online_players_money
	end,
	set_online_players_money = function(data)
		mod_data.online_players_money = data
		online_players_money = data
	end,
	get_player_money_by_index = function(player_index)
		return online_players_money[player_index] or offline_players_money[player_index]
	end,
	get_online_player_money = function(player_index)
		return online_players_money[player_index]
	end,
	get_offline_player_money = function(player_index)
		return offline_players_money[player_index]
	end,
	get_forces_money = function()
		return forces_money
	end,
	set_forces_money = function(data)
		mod_data.forces_money = data
		forces_money = data
	end,
	get_force_money = function(force_index)
		return forces_money[force_index]
	end,
	set_player_money = function(player, amount)
		if player.connected then
			online_players_money[player.index] = amount
		else
			offline_players_money[player.index] = amount
		end
	end,
	set_online_player_money_by_index = function(player_index, amount)
		online_players_money[player_index] = amount
	end,
	set_offline_player_money_by_index = function(player_index, amount)
		offline_players_money[player_index] = amount
	end,
	set_force_money_by_index = function(force_index, amount)
		forces_money[force_index] = amount
	end,
	set_force_money = function(force, amount)
		forces_money[force.index] = amount
	end,
	deposit_force_money_by_index = function(force_index, amount)
		forces_money[force_index] = forces_money[force_index] + amount
	end,
	deposit_force_money = function(force, amount)
		local force_index = force.index
		forces_money[force_index] = forces_money[force_index] + amount
	end,
	deposit_player_money_by_index = function(player, amount)
		local player_index = player.index
		if player.connected then
			online_players_money[player_index] = online_players_money[player_index] + amount
		else
			offline_players_money[player_index] = offline_players_money[player_index] + amount
		end
	end,
	deposit_online_player_money_by_index = function(player_index, amount)
		online_players_money[player_index] = online_players_money[player_index] + amount
	end,
	deposit_offline_player_money_by_index = function(player_index, amount)
		offline_players_money[player_index] = offline_players_money[player_index] + amount
	end,
	get_void_force_index = function()
		return void_force_index
	end,
	get_void_surface_index = function()
		return void_surface_index
	end
})

remote.add_interface("EasyAPI_rcon", {
	get_data = function()
		print_to_rcon(game.table_to_json(mod_data))
	end,
	get_teams = function()
		print_to_rcon(game.table_to_json(teams))
	end,
	get_teams_count = function()
		print_to_rcon(#teams)
	end,
	find_team = function(index)
		for _index, name in pairs(teams) do
			if _index == index then
				print_to_rcon(name)
			end
		end
	end,
	get_all_virtual_base_resources = function()
		print_to_rcon(game.table_to_json(virtual_base_resources))
	end,
	get_offline_players_money = function()
		print_to_rcon(game.table_to_json(offline_players_money))
	end,
	get_online_players_money = function()
		print_to_rcon(game.table_to_json(online_players_money))
	end,
	get_player_money_by_index = function(player_index)
		print_to_rcon(online_players_money[player_index] or offline_players_money[player_index])
	end,
	get_online_player_money = function(player_index)
		print_to_rcon(online_players_money[player_index])
	end,
	get_offline_player_money = function(player_index)
		print_to_rcon(offline_players_money[player_index])
	end,
	get_forces_money = function()
		print_to_rcon(game.table_to_json(forces_money))
	end,
	get_force_money = function(force_index)
		print_to_rcon(forces_money[force_index])
	end,
	get_void_force_index = function()
		print_to_rcon(void_force_index)
	end,
	get_void_surface_index = function()
		print_to_rcon(void_surface_index)
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
		return server_list
	end,
	get_server_list_for_rcon = function()
		print_to_rcon(game.table_to_json(server_list))
	end,
	---@param game string # Factorio/Minecraft etc
	---@param server_name string
	---@param server_address? string # ip:port or server name
	---@param mods? table<string, string> # {name = name, version = version}
	add_server = function(game, server_name, server_address, mods)
		server_list[#server_list+1] = {
			game = game,
			name = server_name,
			address = server_address,
			mods = mods or {}
		}
	end,
	---@param server_name string
	remove_server_by_name = function(server_name)
		for i=1, #server_list do
			if server_list[i].name == server_name then
				tremove(server_list, i)
				return
			end
		end
	end,
	clear_server_list = function()
		global.server_list = {}
		server_list = global.server_list
	end,
})

--#endregion


M.events = {
	[defines.events.on_game_created_from_scenario] = on_game_created_from_scenario,
	[defines.events.on_runtime_mod_setting_changed] = on_runtime_mod_setting_changed,
	[defines.events.on_player_created] = on_player_created,
	[defines.events.on_player_joined_game] = on_player_joined_game,
	[defines.events.on_player_left_game] = on_player_left_game,
	[defines.events.on_player_changed_force] = on_player_changed_force,
	[defines.events.on_player_demoted] = on_player_demoted,
	[defines.events.on_player_promoted] = on_player_promoted,
	[defines.events.on_pre_player_removed] = on_pre_player_removed,
	[defines.events.on_player_removed] = clear_player_data,
	[defines.events.on_forces_merging] = on_forces_merging,
	[defines.events.on_forces_merged] = on_forces_merged,
	[defines.events.on_force_created] = on_force_created,
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
	destroy_team_money = destroy_team_money_command,
	transfer_team_money = transfer_team_money_command,
	convert_money = convert_money_command,
	get_money = get_money_command,
	pay = pay_command,
	ring = ring_command,
	balance = balance_command,
	team_balance = team_balance_command,
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
		local player = game.get_player(cmd.player_index)
		local character = player.character
		--TODO: add message
		if character == nil then return end

		local surface = player.surface
		local position = surface.find_non_colliding_position(
			character.name, player.position, 5, 1
		)
		if position then
			player.teleport(position, surface)
		else
			--TODO: change message
			player.print({"error.error-message-box-title"})
		end
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
