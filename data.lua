data:extend({{
	type = "recipe-category",
	name = "money"
}})

if settings.startup["enable-money-printer"].value then
	require("prototypes.money-printer")
end
