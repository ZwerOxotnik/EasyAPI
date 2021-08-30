local function create_recipe(count)
	data:extend({{
			type = "recipe",
			name = "copper-coin-" .. count,
			subgroup = "coins",
			category = "money",
			enabled = true,
			ingredients = {{"copper-plate", count}},
			energy_required = count,
			order = "coin-" .. count,
			result = "coin",
			result_count = count
	}})
end

create_recipe(100)
create_recipe(1000)
create_recipe(5000)


local money_printer = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-1"])
money_printer.name = "money-printer"
money_printer.minable = {mining_time = 0.2, result = money_printer.name}
money_printer.fast_replaceable_group = nil
money_printer.energy_usage = "750kW"
money_printer.allowed_effects = nil
money_printer.next_upgrade = nil
money_printer.crafting_speed = 1
money_printer.base_productivity = 0
money_printer.crafting_categories = {"money"}
local money_printer_recipe = table.deepcopy(data.raw.recipe["assembling-machine-1"])
money_printer_recipe.name = money_printer.name
money_printer_recipe.result = money_printer.name
money_printer_recipe.enabled = true
data:extend({
	money_printer_recipe,
	money_printer, {
		type = "item",
		name = money_printer.name,
		icon = "__base__/graphics/icons/assembling-machine-1.png",
		icon_size = 64, icon_mipmaps = 4,
		subgroup = "coins",
		order = "a[" .. money_printer.name .. "]",
		place_result = money_printer.name,
		stack_size = 50
	}
})
