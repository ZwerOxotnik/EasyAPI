--[[
	[WIP]
	Currently, I don't recommend to use it. Mostly, it doesn't work yet or even messy.
]]

return {
	-- Rounds
	on_round_start = script.generate_event_name(),
	on_round_end   = script.generate_event_name(), -- {source: string}

	-- Teams
	on_team_lost = script.generate_event_name(), -- {force}
	on_team_won = script.generate_event_name(), -- {force}
	on_player_joined_team = script.generate_event_name(), -- {player_index, force, prev_force}
	on_new_team = script.generate_event_name(), -- {force}
	on_pre_deleted_team = script.generate_event_name(), -- {force}
	on_new_team_base = script.generate_event_name(), -- {force, surface, position}
	on_pre_deleted_team_base = script.generate_event_name(), -- {force, surface, position}
	on_player_invited_in_team = script.generate_event_name(), -- {inviter_index, target_index, force}
	on_player_sent_join_request_in_team = script.generate_event_name(), -- {player_index, force}
	on_player_accepted_invite = script.generate_event_name(), -- {player_index, force}
	-- Called when a force surrenders.
	--	Contains:
	--		force :: LuaForce: The force to be surrender
	--		destination :: LuaForce (optional): The force to reassign entities to.
	on_pre_surrender = script.generate_event_name(),

	-- Called when someone/something was kicked from a team.
	--	Contains:
	--		player_index :: uint: The kicked player.
	-- 		force :: LuaForce: previous force
	--		kicker :: uint or nil: A player/server/script who kicked the player. (TODO: improve)
	on_player_kicked_from_team = script.generate_event_name(),

	-- Money
	on_transfered_player_money = script.generate_event_name(), -- {receiver_index = player.index, payer_index = player.index}
	on_transfered_force_money = script.generate_event_name(), -- {receiver = force, payer = force}

	-- Spawn (no use yet)
	on_new_global_spawn = script.generate_event_name(), -- {position, id = spawn_id}
	on_new_player_spawn = script.generate_event_name(), -- {position, id = spawn_id}
	on_new_force_spawn = script.generate_event_name(),  -- {position, id = spawn_id}
	on_deleted_global_spawn = script.generate_event_name(), -- {position, id = spawn_id}
	on_deleted_player_spawn = script.generate_event_name(), -- {position, id = spawn_id}
	on_deleted_force_spawn = script.generate_event_name(),  -- {position, id = spawn_id}

	-- Diplomacy
	-- Called when someone/something changed a diplomacy relationship to ally/neutral/enemy.
	--	Contains:
	--		source :: LuaForce: The force that changed current diplomacy relationship.
	--		destination :: LuaForce: The force which have to accept new diplomacy relationship.
	--		player_index :: uint (optional): The player who cause the changing.
	--		prev_relationship :: string: Previous relationship between forces.
	on_ally = script.generate_event_name(),
	on_neutral = script.generate_event_name(),
	on_enemy = script.generate_event_name(),

	-- Chat
	-- (Propably, it'll be changed)
	--  Called when a player successfully send a message.
	--	Contains:
	--		player_index :: uint: The index of the player who did the change.
	--		message :: string: The chat message.
	--		chat_name :: string: name of chat.
	on_send_message = script.generate_event_name(),

	-- Called when a player successfully poke another player.
	--	Contains:
	--		sender_index :: uint: The index of the player who did the poke.
	--		target_index :: uint: The index of the player who receive the poke.
	on_poke = script.generate_event_name(),

	-- General
	on_mod_load = script.generate_event_name(), -- {mod_name} -- TODO: check and add
	on_reload_scenario = script.generate_event_name(),
	on_new_character = script.generate_event_name(), -- {player_index}
	on_player_on_admin_surface = script.generate_event_name(), -- {player_index}
	on_player_on_scenario_surface = script.generate_event_name(), -- {player_index}
	on_player_on_lobby_surface = script.generate_event_name(), -- {player_index}
	on_fix_bugs = script.generate_event_name(), -- empty table
	on_sync = script.generate_event_name(), -- empty table

	--  Called before an entity will change a force.
	--	Contains:
	--		entity :: LuaEntity: The entity that will get new force.
	--		next_force :: LuaForce: New force for the entity.
	on_pre_entity_changed_force = script.generate_event_name(),

	--  Called when an entity changed a force.
	--	Contains:
	--		entity :: LuaEntity: The entity that changed force.
	--		prev_force :: LuaForce: The previous owner of the entity
	on_entity_changed_force = script.generate_event_name(),

	-- Called when switched a mod
	--	Contains:
	--		mod_name :: string
	--		state :: boolean
	on_toggle = script.generate_event_name(),
}
