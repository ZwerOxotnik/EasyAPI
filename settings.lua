require("defines")
require("models/BetterCommands/control"):create_settings() -- Adds switchable commands

local runtime_settings = {
	{
		type = "string-setting",
		name = "EAPI_who-decides-diplomacy",
		default_value = "all_players",
		allowed_values = {"all_players", "team_leader"}
	},
	{type = "int-setting",    name = "EAPI_max_teams", default_value = 40, minimal_value = 0, maximal_value = 55},
	{type = "int-setting",    name = "EAPI_start-player-money", default_value = 500},
	{type = "int-setting",    name = "EAPI_start-force-money", default_value = 1000},
	{type = "string-setting", name = "EAPI_default-permission-group", default_value = "Default"},
	{type = "string-setting", name = "EAPI_default-force-name", default_value = "player"},
	{type = "bool-setting",   name = "EAPI_allow_create_team", default_value = true},
	{type = "bool-setting",   name = "EAPI_permissions_per_force",  default_value = false},
	{type = "bool-setting",   name = "EAPI_permissions_per_player", default_value = false},
	{type = "bool-setting",   name = "EAPI_add_admins_to_admin_permission_group", default_value = true},
}
for _, data in pairs(runtime_settings) do
	data.setting_type = "runtime-global"
end
data:extend(runtime_settings)
