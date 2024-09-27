---@class external_mod_configs_util
local configs_util = {}


---@return table<string, table<string, any>>
function configs_util.get_external_mod_configs()
	local external_mod_configs = {}
	for mod_name in pairs(script.active_mods) do
		local is_ok, data = pcall(require, string.format("__%s__/external_mod_configs", mod_name))
		if is_ok then
			external_mod_configs[mod_name] = data
		end
	end

	return external_mod_configs
end


---@param configs table<string, table<string, any>>
---@param name string
---@return boolean
function configs_util.does_exist_in_configs(configs, name)
	for _, config in pairs(configs) do
		if config[name] ~= nil then
			return true
		end
	end

	return false
end


---@param configs table<string, table<string, any>>
---@param name string
---@return any?
function configs_util.find_1st_value_in_configs(configs, name)
	for _, config in pairs(configs) do
		local value = config[name]
		if value ~= nil then
			return value
		end
	end
end


---@param configs table<string, table<string, any>>
---@param name string
---@return any?
function configs_util.find_1st_truthy_value_in_configs(configs, name)
	for _, config in pairs(configs) do
		local value = config[name]
		if value then
			return value
		end
	end
end


return configs_util
