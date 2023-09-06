--[[ Uses https://github.com/ZwerOxotnik/factorio-BetterCommands
Returns tables of commands without functions as command "settings". All parameters are optional!
	Contains:
		name :: string: The name of your /command. (default: key of the table)
		description :: string or LocalisedString: The description of your command. (default: nil)
		is_allowed_empty_args :: boolean: Ignores empty parameters in commands, otherwise stops the command. (default: true)
		input_type :: string: Filter for parameters by type of input. (default: nil)
			possible variants:
				"player" - Stops execution if can't find a player by parameter
				"team" - Stops execution if can't find a team (force) by parameter
		allow_for_server :: boolean: Allow execution of a command from a server (default: false)
		only_for_admin :: boolean: The command can be executed only by admins (default: false)
		is_added_by_default :: boolean: Default value for switchable commands (default: true)
		allow_for_players :: string[]: Allows to use the command for players with specified names (default: nil)
		max_input_length :: uint # Max amount of characters for command (default: 500)
		is_logged :: boolean # Logs the command into .log file (default: false)
		alternative_names :: string[] # Alternative names for the command (all commands should be added) (default: nil)
]]--
---@type table<string, table>
return {
	create_team = {name = "create-team", is_allowed_empty_args = false, description = {"gui-map-editor-force-editor.no-force-name-given"}},
	remove_team = {name = "remove-team", input_type = "team", only_for_admin = true},
	team_list = {name = "team-list", allow_for_server = true},
	show_team = {name = "show-team", allow_for_server = true},
	ring = {is_allowed_empty_args = false, input_type = "player"},
	kick_teammate = {name = "kick-teammate", is_allowed_empty_args = false, input_type = "player"},
	friendly_fire = {name = "friendly-fire", is_allowed_empty_args = false, only_for_admin = true},
	set_money = {name = "set-money", is_allowed_empty_args = false, only_for_admin = true},
	deposit_money  = {name = "deposit-money", is_allowed_empty_args = false},
	withdraw_money = {name = "withdraw-money", is_allowed_empty_args = false},
	set_team_money = {name = "set-team-money", is_allowed_empty_args = false, only_for_admin = true},
	deposit_team_money  = {name = "deposit-team-money", is_allowed_empty_args = false, only_for_admin = true},
	destroy_team_money  = {name = "destroy-team-money", is_allowed_empty_args = false, only_for_admin = true},
	transfer_team_money = {name = "transfer-team-money", is_allowed_empty_args = false},
	bring = {is_allowed_empty_args = false, only_for_admin = true, input_type = "player"},
	["goto"] = {only_for_admin = true},
	convert_money = {name = "convert-money"},
	get_money = {name = "get-money", is_allowed_empty_args = false},
	pay = {is_allowed_empty_args = false},
	team_balance = {name = "team-balance"},
	uncloak  = {only_for_admin = true, is_added_by_default = false},
	fix_bugs = {name = "fix-bugs", allow_for_server = true, only_for_admin = true, is_allowed_empty_args = true},
	sync     = {allow_for_server = true, only_for_admin = true, is_allowed_empty_args = true},
	cloak    = {only_for_admin = true, is_added_by_default = false},
	balance  = {},
	kill = {name = "killme", is_added_by_default = false},
	hp = {is_allowed_empty_args = false, only_for_admin = true, is_added_by_default = false},
	["play-sound"] = {is_allowed_empty_args = false, only_for_admin = true, is_added_by_default = false},
	unstuck = {is_allowed_empty_args = true},
}
