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

if settings.startup["enable-money-printer"].value then
	require("prototypes.money-printer")
end
