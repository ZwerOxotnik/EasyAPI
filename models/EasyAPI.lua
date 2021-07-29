---@class EasyAPI : module
local M = {}


--#region Global data
local teams
local mod_data
--#endregion


local who_decides_diplomacy = settings.global["who-decides-diplomacy"].value


--#region Constants
local custom_events = require("events")
local constant_forces = {neutral = true, player = true, enemy = true}
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
	local player_index = event.player_index
end

--#endregion


--#region Functions of events

local function on_player_created(event)
	local player = game.get_player(event.player_index)
	if player.admin then
		game.permissions.get_group("admins").add_player(player)
	end
end

local function on_player_changed_force(event)
	local target_force = game.get_player(event.player_index).force
	if teams[target_force.index] then
		script.raise_event(custom_events.on_player_joined_team, {force = target_force})
	end
end

local function on_runtime_mod_setting_changed(event)
	if event.setting_type ~= "runtime-global" then return end

	if event.setting == "who_decides_diplomacy" then
		who_decides_diplomacy = settings.global[event.setting].value
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
	if caller.admin then
		game.print(cmd.parameter .. " was kicked from \"" .. target_player.force.name .. "\" team by " .. caller.name)
		target_player.force = game.forces["player"]
		script.raise_event(custom_events.on_player_kicked_from_team, {player_index = target_player.index, kicker = caller.index})
	elseif caller.force == target_player.force then
		if caller.force.players[1] == caller then
			game.print(cmd.parameter .. " was kicked from \"" .. target_player.force.name .. "\" team by " .. caller.name)
			target_player.force = game.forces["player"]
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

	if #cmd.parameter > 52 then
		caller.print({"too-long-team-name"}, cmd.player_index)
		return
	end
	local team_name = trim(cmd.parameter)

	-- for compability with other mods/scenarios and forces count max = 64 (https://lua-api.factorio.com/1.1.30/LuaGameScript.html#LuaGameScript.create_force)
	if #game.forces >= 60 then caller.print({"teams.too_many"}) return end
	if game.forces[team_name] then
		caller.print({"gui-map-editor-force-editor.new-force-name-already-used", team_name})
		return
	end

	local new_team = game.create_force(team_name)
	teams[new_team.index] = team_name
	script.raise_event(custom_events.on_new_team, {force = new_team})
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

	game.merge_forces(target_force, game.forces["player"])
end

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

--#endregion


--#region Pre-game stage

local function link_data()
	mod_data = global.EasyAPI
	teams = global.EasyAPI.teams
end

local function update_global_data()
	global.EasyAPI = global.EasyAPI or {}
	global.EasyAPI.teams = global.EasyAPI.teams or {}

	link_data()

	local group = game.permissions.get_group("admins")
	if group == nil then
		game.permissions.create_group("admins")
	end

	if teams == nil then
		local player_force = game.forces.player
		teams[player_force.index] = "player"
	end

	-- for i, _ in pairs(game.players) do
	-- 	if diplomacy.players[i] == nil then
	-- 		diplomacy.players[i] = {}
	-- 	end
	-- end
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
})

--#endregion


M.events = {
	[defines.events.on_runtime_mod_setting_changed] = on_runtime_mod_setting_changed,
	[defines.events.on_player_created] = function(event)
		pcall(on_player_created, event)
	end,
	[defines.events.on_player_changed_force] = function(event)
		pcall(on_player_changed_force, event)
	end,
	[defines.events.on_player_removed] = clear_player_data,
	[defines.events.on_forces_merging] = on_forces_merging,
	[defines.events.on_forces_merged] = on_forces_merged
}

M.commands = {
	create_team = create_new_team_command,
	remove_team = remove_team_command,
	team_list = team_list_command,
	show_team = show_team_command,
	kick_teammate = kick_teammate_command,
	friendly_fire = friendly_fire_command
}


return M
