EasyAPI = {
	all_coins = {[data.raw.item.coin] = true},
	coin_conversions = {
		["coin"] = 1
	},
	valuable_coin_list = {
		{prot = data.raw.item.coin, value = 1}
	}
}

data:extend({
	{
		type = "item-group",
		name = "money",
		order = "z",
		icon = "__base__/graphics/icons/coin.png",
		hidden = settings.startup["EAPI_disable_money_item_group"].value,
		icon_size = 64, icon_mipmaps = 4,
	}, {
		type = "item-subgroup",
		name = "coins",
		group = "money",
		order = "a"
	}, {
		type = "recipe-category",
		name = "money"
	}
})


data.raw.item.coin.subgroup = "coins"
data.raw.item.coin.order = "coin"
data.raw.item.coin.flags = nil


---@param subgroup string # "coin-for-item" by default
---@param required_count integer # 1 by default
---@param required_item_name string
---@param result_item_name string? # "coin" by default
---@param result_count integer # 1 by default
---@param bottom_icon table?
---@param top_icon table?
EasyAPI.create_coin_conversion_recipe = function(subgroup, required_count, required_item_name, result_item_name, result_count, bottom_icon, top_icon)
	required_count = required_count or 1
	result_item_name = result_item_name or "coin"
	subgroup = subgroup or "coin-for-item"

	if data.raw["item-subgroup"][subgroup] == nil then
		lazyAPI.add_prototype({
			type = "item-subgroup",
			name = subgroup,
			group = "money",
			order = "a"
		})
	end

	local prototype = {
		type = "recipe",
		name = required_item_name .. "-" .. result_item_name .. "-" .. required_count,
		subgroup = subgroup,
		category = "money",
		enabled = true,
		ingredients = {{type="item", name=required_item_name, amount=required_count}},
		energy_required = required_count,
		order = result_item_name .. "-" .. required_count,
		results = {{type="item", name=result_item_name, amount=result_count}},
	}
	if bottom_icon or top_icon then
		if bottom_icon and top_icon then
			bottom_icon = table.deepcopy(bottom_icon)
			top_icon = table.deepcopy(top_icon)
			top_icon.scale = top_icon.scale or 0.35
			prototype.icons = {bottom_icon, top_icon}
		else
			local icon = table.deepcopy(bottom_icon or top_icon)
			prototype.icons = {icon}
		end
	end

	lazyAPI.add_prototype(prototype)
end
EasyAPI._create_coin_conversion_recipe = EasyAPI.create_coin_conversion_recipe


---@param count integer
---@param coin_path string
EasyAPI.add_new_coin = function(count, coin_path)
	local prototype = {
		type = "item",
		name = "coinX" .. count,
		icon = coin_path,
		icon_size = 64, icon_mipmaps = 4,
		subgroup = "coins",
		order = "coinX50",
		stack_size = 100000 / count,
		localised_name = {'', {"item-name.coin"}, "X" .. count}
	}
	EasyAPI.coin_conversions[prototype.name] = count
	EasyAPI.all_coins[prototype] = true

	lazyAPI.add_prototype(prototype)

	local valuable_coin_list = EasyAPI.valuable_coin_list
	local is_in_valuable_coin_list = false
	for i, t in ipairs(valuable_coin_list) do
		if count < t.value then
			is_in_valuable_coin_list = true
			table.insert(valuable_coin_list, i, {prot = prototype, value = count})
			break
		end
	end
	if is_in_valuable_coin_list == false then
		valuable_coin_list[#valuable_coin_list+1] = {prot = prototype, value = count}
	end

	local bottom_icon = {
		icon = "__base__/graphics/icons/coin.png",
		icon_size = 64
	}
	local top_icon = {
		icon = coin_path,
		icon_size = 64,
		scale = 0.35
	}
	EasyAPI.create_coin_conversion_recipe("coin-for_coin", 1, prototype.name, "coin", count, bottom_icon, top_icon)
end
EasyAPI._add_new_coin = EasyAPI.add_new_coin


EasyAPI.add_new_coin(50,   "__EasyAPI__/graphics/coinX50.png")
EasyAPI.add_new_coin(2500, "__EasyAPI__/graphics/coinX2500.png")
