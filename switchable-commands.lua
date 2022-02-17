-- Recommended to know about https://lua-api.factorio.com/latest/LuaCommandProcessor.html#LuaCommandProcessor.add_command

--[[
Returns tables of commands without functions as command "settings". All parameters are optional!
  Contains:
    name :: string: The name of your /command. (default: key of the table)
    description :: string or LocalisedString: The description of your command.
    is_allowed_empty_args :: boolean: Ignores empty parameters in commands, otherwise stops the command. (default: true)
    input_type :: string: filter for parameters by type of input. (default: nil)
      possible variants:
        "player" - Stops execution if can't find a player by parameter
        "team" - Stops execution if can't find a team (force) by parameter
    allow_for_server :: boolean: Allow execution of a command from a server (default: false)
    only_for_admin :: boolean: The command can be executed only by admins (default: false)
		default_value :: boolean: default value for settings (default: false)
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
	deposit_money = {name = "deposit-money", is_allowed_empty_args = false},
	withdraw_money = {name = "withdraw-money", is_allowed_empty_args = false},
	set_team_money = {name = "set-team-money", is_allowed_empty_args = false, only_for_admin = true},
	deposit_team_money = {name = "deposit-team-money", is_allowed_empty_args = false, only_for_admin = true},
	withdraw_team_money = {name = "withdraw-team-money", is_allowed_empty_args = false, only_for_admin = true},
	transfer_team_money = {name = "transfer-team-money", is_allowed_empty_args = false},
	bring = {is_allowed_empty_args = false, only_for_admin = true, input_type = "player"},
	convert_money = {name = "convert-money"},
	pay = {is_allowed_empty_args = false},
	balance = {},
	team_balance = {name = "team-balance"}
}
