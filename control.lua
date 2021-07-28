require("defines")
local event_handler = require("event_handler")


---@type table<string, module>
local modules = {}
modules.better_commands = require("models/BetterCommands/control")
modules.EasyAPI = require("models.EasyAPI")

modules.better_commands:handle_custom_commands(modules.EasyAPI) -- adds commands

event_handler.add_libraries(modules)
