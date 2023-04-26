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

-- TODO: refactor
data:extend({
	{
		type = "item",
		name = "coinX50",
		icon = "__EasyAPI__/graphics/coinX50.png",
		icon_size = 64, icon_mipmaps = 4,
		subgroup = "coins",
		order = "coinX50",
		stack_size = 100000 / 50,
		localised_name = {'', {"item-name.coin"}, "X50"}
	},
	{
		type = "item",
		name = "coinX2500",
		icon = "__EasyAPI__/graphics/coinX2500.png",
		icon_size = 64, icon_mipmaps = 4,
		subgroup = "coins",
		order = "coinX2500",
		stack_size = 100000 / 2500,
		localised_name = {'', {"item-name.coin"}, "X2500"}
	}
})
data.raw.item.coin.subgroup = "coins"
data.raw.item.coin.order = "coin"
data.raw.item.coin.flags = nil
