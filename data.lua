EasyAPI = {
	all_coins = {[data.raw.item.coin] = true},
	coin_conversions = {
		["coin"] = 1
	}
}

data:extend({
	{
    type = "item-group",
    name = "money",
    order = "z",
    icon = "__base__/graphics/icons/coin.png",
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

---@param count integer
---@param coin_path string
EasyAPI.add_new_coin = function(count, coin_path)
	local data = {
		type = "item",
		name = "coinX" .. count,
		icon = coin_path,
		icon_size = 64, icon_mipmaps = 4,
		subgroup = "coins",
		order = "coinX50",
		stack_size = 100000 / count,
		localised_name = {'', {"item-name.coin"}, "X" .. count}
	}
	EasyAPI.coin_conversions[data.name] = count
	EasyAPI.all_coins[data] = true

	lazyAPI.add_prototype(data)
end
EasyAPI._add_new_coin = EasyAPI.add_new_coin


EasyAPI.add_new_coin(50, "__EasyAPI__/graphics/coinX50.png")
EasyAPI.add_new_coin(2500, "__EasyAPI__/graphics/coinX2500.png")
