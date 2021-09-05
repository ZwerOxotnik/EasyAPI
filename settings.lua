require("defines")
require("models/BetterCommands/control"):create_settings() -- Adds switchable commands

data:extend({
	{
		type = "string-setting",
		name = "who-decides-diplomacy",
		setting_type = "runtime-global",
		default_value = "all_players",
		allowed_values = {"all_players", "team_leader"}
	},
	{type = "double-setting", name = "start-player-money", setting_type = "runtime-global", default_value = 500},
	{type = "double-setting", name = "start-force-money", setting_type = "runtime-global", default_value = 1000},
	{type = "string-setting", name = "default-permission-group", setting_type = "runtime-global", default_value = "Default"},
	{type = "string-setting", name = "default-force-name", setting_type = "runtime-global", default_value = "player"},
	{type = "bool-setting", name = "enable-money-printer", setting_type = "startup", default_value = false}
})
