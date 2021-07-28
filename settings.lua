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
})
