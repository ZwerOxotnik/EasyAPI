require("defines")
require("models/BetterCommands/control"):create_settings() -- Adds switchable commands

data:extend({
	{
		type = "string-setting",
		name = "EAPI_who-decides-diplomacy",
		setting_type = "runtime-global",
		default_value = "all_players",
		allowed_values = {"all_players", "team_leader"}
	},
	{type = "double-setting", name = "EAPI_start-player-money", setting_type = "runtime-global", default_value = 500},
	{type = "double-setting", name = "EAPI_start-force-money", setting_type = "runtime-global", default_value = 1000},
	{type = "string-setting", name = "EAPI_default-permission-group", setting_type = "runtime-global", default_value = "Default"},
	{type = "string-setting", name = "EAPI_default-force-name", setting_type = "runtime-global", default_value = "player"},
	{type = "bool-setting", name = "EAPI_enable-money-printer", setting_type = "startup", default_value = false}
})
