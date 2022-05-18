
--[[
Biter Trails control script © 2022 by asher_sky is licensed under Attribution-NonCommercial-ShareAlike 4.0 International. See LICENSE.txt for additional information
--]]

local table = require("__flib__.table")
local math = require("__flib__.math")

--- @class biter_data
--- @field biter LuaEntity
--- @field position MapPosition
--- @field counter number
--- @field visible_check_timer number

--- @class mod_global
--- @field biters table<number, biter_data>
--- @field sleeping_biters table<number, biter_data>
--- @field settings table
--- @field from_key any
--- @field player_forces table

--- @class EventData
--- @field player_index number
--- @field force LuaForce
--- @field entity LuaEntity

local mod_settings -- needs to be re-initialized in on_load

local speeds = {
  veryslow = 0.010,
  slow = 0.025,
  default = 0.050,
  fast = 0.100,
  veryfast = 0.200,
}

local palette = {
  light = {amplitude = 15, center = 240},           -- light
  pastel = {amplitude = 55, center = 200},          -- pastel <3
  default = {amplitude = 127.5, center = 127.5},    -- default (nyan)
  vibrant = {amplitude = 50, center = 100},         -- muted
  deep = {amplitude = 25, center = 50},             -- dark
}

local balance_to_ticks = {
  ['super-pretty'] = 1,
  ['pretty'] = 2,
  ['balanced'] = 3,
  ['performance'] = 4
}

local sin = math.sin
local pi_0 = 0 * math.pi / 3
local pi_2 = 2 * math.pi / 3
local pi_4 = 4 * math.pi / 3

local function make_rainbow(event_tick, unit_number, frequency, palette_choice)
  -- local frequency = speeds[settings["biter-trails-speed"]]
  -- local modifier = unit_number + event_tick
  local freq_mod = frequency * (unit_number + event_tick)
  local amplitude = palette_choice.amplitude
  local center = palette_choice.center
  return {
    r = sin(freq_mod+pi_0)*amplitude+center,
    g = sin(freq_mod+pi_2)*amplitude+center,
    b = sin(freq_mod+pi_4)*amplitude+center,
    a = 255,
  }
end

--- Add a biter to the biters table.
local function add_biter(biter)
  global.data.biters[biter.unit_number] = {
    biter = biter,
    position = biter.position,
    counter = 1,
    visible_check_timer = 1
  }
end

local function make_trails(event_tick)
  local sprite = mod_settings["biter-trails-color"]
  local light = mod_settings["biter-trails-glow"]

  if not (sprite or light) then
    local ids = rendering.get_all_ids("asher_sky_testing")
    if #ids > 0 then
      for _, id in pairs(ids) do
        rendering.destroy(id)
      end
      local global = global.data
      local biters = global.biters
      for _, data in pairs(biters) do
        data.light_id = nil
        data.sprite_id = nil
      end
    end
    return
  end

  local length = mod_settings["biter-trails-length"]
  local scale = mod_settings["biter-trails-scale"]
  local trail_mode = mod_settings["biter-trails-color-type"]
  -- local trail_mode = "rainbow"
  -- local passengers_only = settings["biter-trails-passengers-only"]
  local frequency = speeds[mod_settings["biter-trails-speed"]]
  local palette_choice = palette[mod_settings["biter-trails-palette"]]
  -- local tiptoe_mode = settings["biter-trails-tiptoe-mode"]

  local global = global.data
  local biters = global.biters
  local sleeping_biters = global.sleeping_biters
  local forces = global.player_forces
  local group_colors = global.group_colors


  for group_number, data in pairs(group_colors) do
    if not data.group and data.group.valid then
      group_colors[group_number] = nil
    else
      group_colors[group_number].color = make_rainbow(event_tick, group_number, frequency, palette_choice)
    end
  end

  local num = table_size(sleeping_biters) * 0.008
  global.from_key = table.for_n_of(sleeping_biters, global.from_key, num, function(data)
    if data.biter.valid then
      local biter = data.biter
      local unit_number = biter.unit_number
      local last_position = data.position
      local current_position = biter.position
      local same_position = last_position and (last_position.x == current_position.x) and (last_position.y == current_position.y)

      if not same_position then
        local chunk_is_visible = false
        for _, force in pairs(forces) do
            chunk_is_visible = force.is_chunk_visible(biter.surface, {current_position.x / 32, current_position.y / 32})
        end
        if chunk_is_visible then
          biters[unit_number] = sleeping_biters[unit_number]
          return nil, true
        end
      end
    else
      return nil, true
    end
  end)

  if trail_mode == "rainbow" then
    for unit_number, data in pairs(biters) do
      local biter = data.biter
      if not biter.valid then
        biters[unit_number] = nil
      else
        if data.sprite_id then
          rendering.destroy(data.sprite_id)
          data.sprite_id = nil
        end
        if data.light_id then
          rendering.destroy(data.light_id)
          data.light_id = nil
        end
        local last_position = data.position
        local current_position = biter.position
        data.position = current_position

        local same_position = last_position and (last_position.x == current_position.x) and (last_position.y == current_position.y)
        local chunk_is_hidden = false
        if data.visible_check_timer > 678 then
          for _, force in pairs(forces) do
            chunk_is_hidden = not force.is_chunk_visible(biter.surface, {current_position.x / 32, current_position.y / 32})
          end
          data.visible_check_timer = 1
        else
          data.visible_check_timer = data.visible_check_timer + 1
        end

        if (not same_position) and (not chunk_is_hidden) then

          local color = {}
          if biter.unit_group then
            local group_number = biter.unit_group.group_number
            if group_colors[group_number] then
              color = group_colors[group_number].color
            else
              color = make_rainbow(event_tick, group_number, frequency, palette_choice)
              group_colors[group_number] = {
                group = biter.unit_group,
                color = color
              }
            end
          else
            color = make_rainbow(event_tick, unit_number, frequency, palette_choice)
          end

          local surface = biter.surface
          if sprite then
            rendering.draw_sprite{
              sprite = "biter-trail",
              target = current_position,
              -- target = biter,
              surface = surface,
              x_scale = scale,
              y_scale = scale,
              render_layer = "radius-visualization",
              time_to_live = length,
              tint = color,
            }

            -- surface.create_particle{
            --   name = "rocket-silo-metal-particle-big",
            --   position = biter.position,
            --   movement = {0,0},
            --   height = 0.9,
            --   vertical_speed = 0.03,
            --   frame_speed = 1
            -- }
            --
            -- surface.create_trivial_smoke{
            --   name = "smoke-building",
            --   position = biter.position
            -- }
          end

          if light then
            rendering.draw_light{
              sprite = "biter-trail",
              target = current_position,
              -- target = biter,
              surface = surface,
              intensity = .175,
              scale = scale * 1.75,
              render_layer = "light-effect",
              time_to_live = length,
              color = color,
            }
          end
          -- game.print("[gps="..biter.position.x..","..biter.position.y.."]")

        else
          if data.counter > 333 then
            data.counter = 1
            sleeping_biters[unit_number] = data
            biters[unit_number] = nil
          else
            data.counter = data.counter + 1
          end
        end
      end
    end
  else
    local num = table_size(biters) / 4
    -- length = 10 * mod_settings["biter-trails-balance"]
    global.from_key_2 = table.for_n_of(biters, global.from_key_2, num, function(data)
      if data.biter.valid then
        local biter = data.biter
        local unit_number = biter.unit_number
        local last_position = data.position
        local current_position = biter.position
        local same_position = last_position and (last_position.x == current_position.x) and (last_position.y == current_position.y)
        data.position = current_position

        local chunk_is_hidden = false
        if data.visible_check_timer > 678 then
          for _, force in pairs(forces) do
            chunk_is_hidden = not force.is_chunk_visible(biter.surface, {current_position.x / 32, current_position.y / 32})
          end
          data.visible_check_timer = 1
        else
          data.visible_check_timer = data.visible_check_timer + 1
        end
        if (not same_position) and (not chunk_is_hidden) then
          local color = {}

          if biter.unit_group then
            local group_number = biter.unit_group.group_number
            if group_colors[group_number] then
              color = group_colors[group_number].color
            else
              color = make_rainbow(event_tick, group_number, frequency, palette_choice)
              group_colors[group_number] = {
                group = biter.unit_group,
                color = color
              }
            end
          else
            color = make_rainbow(event_tick, unit_number, frequency, palette_choice)
          end

          local surface = biter.surface
          if sprite then
            if data.sprite_id then
              rendering.set_color(data.sprite_id, color)
            else
              data.sprite_id = rendering.draw_sprite{
                sprite = "biter-trail",
                -- target = current_position,
                target = biter,
                surface = surface,
                x_scale = scale * 2,
                y_scale = scale * 2,
                render_layer = "radius-visualization",
                -- time_to_live = length,
                tint = color,
              }
            end
          end

          if light then
            if data.light_id then
              rendering.set_color(data.light_id, color)
            else
              data.light_id = rendering.draw_light{
                sprite = "biter-trail",
                -- target = current_position,
                target = biter,
                surface = surface,
                intensity = 1.5,
                scale = scale * 1.75 * 2,
                render_layer = "light-effect",
                -- time_to_live = length,
                color = color,
              }
            end
          end
          -- game.print("[gps="..biter.position.x..","..biter.position.y.."]")

        else
          -- if data.counter > 60
          -- game.print("same position: [gps="..biter.position.x..","..biter.position.y.."]")
          if data.counter > 123 then
            data.counter = 1
            sleeping_biters[unit_number] = data
            biters[unit_number] = nil
            if data.sprite_id then
              rendering.destroy(data.sprite_id)
              data.sprite_id = nil
            end
            if data.light_id then
              rendering.destroy(data.light_id)
              data.light_id = nil
            end
          else
            data.counter = data.counter + 1
          end
        end
      else
        return nil, true
      end
    end)
  end
  -- game.print("[color=blue]active biters: "..table_size(global.biters)..", sleeping biters: "..math.round(table_size(global.sleeping_biters))..", checked: "..num.."[/color]")
end

local function update_render_sizes()
  -- if global.data and global.data.biters then
  --   for _, data in pairs(global.data.biters) do
  --     if data.sprite_id and rendering.is_valid(data.sprite_id) then
  --       rendering.set_x_scale(data.sprite_id, mod_settings["biter-trails-scale"] * 2)
  --       rendering.set_y_scale(data.sprite_id, mod_settings["biter-trails-scale"] * 2)
  --     end
  --     if data.light_id and rendering.is_valid(data.light_id) then
  --       rendering.set_scale(data.light_id, mod_settings["biter-trails-scale"] * 2)
  --     end
  --   end
  -- end
  local ids = rendering.get_all_ids("asher_sky_testing")
  for _, id in pairs(ids) do
    local type = rendering.get_type(id)
    if type == "light" then
      rendering.set_scale(id, mod_settings["biter-trails-scale"] * 2)
    elseif type == "sprite" then
      rendering.set_x_scale(id, mod_settings["biter-trails-scale"] * 2)
      rendering.set_y_scale(id, mod_settings["biter-trails-scale"] * 2)
    end
  end
end

local function initialize_settings()
  local settings = settings.global
  global.data.settings = {}
  global.data.settings["biter-trails-color"] = settings["biter-trails-color"].value
  global.data.settings["biter-trails-glow"] = settings["biter-trails-glow"].value
  global.data.settings["biter-trails-length"] = tonumber(settings["biter-trails-length"].value)
  global.data.settings["biter-trails-scale"] = tonumber(settings["biter-trails-scale"].value)
  global.data.settings["biter-trails-color-type"] = settings["biter-trails-color-type"].value
  global.data.settings["biter-trails-speed"] = settings["biter-trails-speed"].value
  global.data.settings["biter-trails-palette"] = settings["biter-trails-palette"].value
  global.data.settings["biter-trails-balance"] = balance_to_ticks[settings["biter-trails-balance"].value]
  mod_settings = global.data.settings
  update_render_sizes()
end

--- Get all biters on all surface and add them to sleeping_biters table.
--- @return biter_data
local function get_all_biters()
  local sleeping_biters = {} --- @type biter_data

  for _, surface in pairs(game.surfaces) do
    for _, biter in pairs(surface.find_entities_filtered{type={"unit"}, force={"enemy"}}) do
      sleeping_biters[biter.unit_number] = {
        biter = biter,
        position = biter.position,
        counter = 1,
        visible_check_timer = 1
      }
    end
  end
  return sleeping_biters
end

--- @return table<number, LuaForce>
local function get_forces_with_players()
  local forces = {} --- @type table<number, LuaForce>
  for _, force in pairs(game.forces) do
    if #force.connected_players > 0 then
      forces[force.index] = force
    end
  end
  return forces
end

--- TODO Does this fire for players changed on force merge/removal?
script.on_event(defines.events.on_player_changed_force, function(event)
  local forces = global.data.player_forces
  local force = game.get_player(event.player_index).force
  local old_force = event.force

  forces[force.index] = force
  if #old_force.connected_players < 1 then
    forces[old_force.index] = nil
  end
end)

script.on_event(defines.events.on_player_joined_game, function(event)
  local forces = global.data.player_forces
  local force = game.get_player(event.player_index).force
  forces[force.index] = force
end)

script.on_event(defines.events.on_player_left_game, function(event)
  local forces = global.data.player_forces
  local force = game.get_player(event.player_index).force
  if #force.connected_players == 0 then
    forces[force.index] = nil
  end
end)

script.on_load(function()
  mod_settings = global.data.settings
end)

script.on_event(defines.events.on_entity_spawned, function(event)
  if event.entity then
    add_biter(event.entity)
  end
end)

script.on_event(defines.events.on_unit_group_finished_gathering, function(event)
  if event.group.command then
    local group = event.group
    local command = group.command.type
    if command == defines.command.attack
    or command == defines.command.go_to_location
    or command == defines.command.attack_area then
      local forces = global.data.player_forces
      local chunk_is_visible = false
      for _, force in pairs(forces) do
        chunk_is_visible = force.is_chunk_visible(group.surface, {group.position.x / 32, group.position.y / 32})
      end
      if chunk_is_visible then
        for _, biter in pairs(event.group.members) do
          add_biter(biter)
        end
      end
    end
  end
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function()
  initialize_settings()
end)

script.on_configuration_changed(function()
  initialize_settings()
  global.data.sleeping_biters = get_all_biters() -- Does this need to be done every change?
  global.data.forces = get_forces_with_players()
  global.data.group_colors = global.data.group_colors or {}
end)

script.on_init(function()
  global.data = {}
  initialize_settings()
  global.data.biters = {} --- @type biter_data
  global.data.sleeping_biters = get_all_biters()
  global.data.player_forces = get_forces_with_players()
  global.data.group_colors = {}
end)

script.on_event(defines.events.on_tick, function(event)
  if (event.tick % mod_settings["biter-trails-balance"]) == 0 then
    make_trails(event.tick) -- change make trails to use mod_settings upvalue, and change paramater to event_tick directly
  end
end)
--
-- --[[
-- Spider Trails control script © 2022 by asher_sky is licensed under Attribution-NonCommercial-ShareAlike 4.0 International. See LICENSE.txt for additional information
-- --]]
--
-- local table = require("__flib__.table")
-- local math = require("__flib__.math")
--
-- local speeds = {
--   veryslow = 0.010,
--   slow = 0.025,
--   default = 0.050,
--   fast = 0.100,
--   veryfast = 0.200,
-- }
--
-- local palette = {
--   light = {amplitude = 15, center = 240},           -- light
--   pastel = {amplitude = 55, center = 200},          -- pastel <3
--   default = {amplitude = 127.5, center = 127.5},    -- default (nyan)
--   vibrant = {amplitude = 50, center = 100},         -- muted
--   deep = {amplitude = 25, center = 50},             -- dark
-- }
--
-- local sin = math.sin
-- local pi_0 = 0 * math.pi / 3
-- local pi_2 = 2 * math.pi / 3
-- local pi_4 = 4 * math.pi / 3
--
-- function make_rainbow(event_tick, unit_number, frequency, palette_choice)
--   -- local frequency = speeds[settings["biter-trails-speed"]]
--   -- local modifier = unit_number + event_tick
--   local freq_mod = frequency * (unit_number + event_tick)
--   local amplitude = palette_choice.amplitude
--   local center = palette_choice.center
--   return {
--     r = sin(freq_mod+pi_0)*amplitude+center,
--     g = sin(freq_mod+pi_2)*amplitude+center,
--     b = sin(freq_mod+pi_4)*amplitude+center,
--     a = 255,
--   }
-- end
--
-- -- local function initialize_settings()
-- --   if not global.data.settings then
-- --     global.data.settings = {}
-- --   end
-- --   local settings = settings.global
-- --   global.data.settings = {}
-- --   global.data.settings["biter-trails-color"] = settings["biter-trails-color"].value
-- --   global.data.settings["biter-trails-glow"] = settings["biter-trails-glow"].value
-- --   global.data.settings["biter-trails-length"] = settings["biter-trails-length"].value
-- --   global.data.settings["biter-trails-scale"] = settings["biter-trails-scale"].value
-- --   global.data.settings["biter-trails-color-type"] = settings["biter-trails-color-type"].value
-- --   global.data.settings["biter-trails-speed"] = settings["biter-trails-speed"].value
-- --   global.data.settings["biter-trails-palette"] = settings["biter-trails-palette"].value
-- --   global.data.settings["biter-trails-balance"] = settings["biter-trails-balance"].value
-- -- end
--
-- local function get_all_biters()
--   if not global.data.biters then
--     global.data.biters = {}
--   end
--   if not global.data.sleeping_biters then
--     global.data.sleeping_biters = {}
--   end
--   for each, surface in pairs(game.surfaces) do
--     local biters = surface.find_entities_filtered{type={"unit"}, force={"enemy"}}
--     for every, biter in pairs(biters) do
--       global.data.sleeping_biters[biter.unit_number] = {
--         biter = biter,
--         position = biter.position,
--         counter = 1
--       }
--     end
--   end
-- end
--
-- local function add_biter(event)
--   local biter = event.created_entity or event.entity
--   global.data.biters[biter.unit_number] = {
--     biter = biter,
--     position = biter.position,
--     counter = 1
--   }
-- end
--
-- local function get_player_forces()
--   if not global.data.player_forces then
--     global.data.player_forces = {}
--   end
--   for each, player in pairs(game.players) do
--     if player.valid and player.force then
--       local forces = global.data.player_forces
--       local force_name = player.force.name
--       if not forces[force_name] then
--         global.data.player_forces[force_name] = {
--           force = player.force,
--           number_of_players = 1
--         }
--       else
--         global.data.player_forces[force_name].number_of_players = forces[force_name].number_of_players + 1
--       end
--     end
--   end
-- end
--
-- script.on_event(defines.events.on_player_changed_force, function(event)
--   if not global.data.player_forces then
--     global.data.player_forces = {}
--   end
--   local forces = global.data.player_forces
--   local player = game.get_player(event.player_index)
--   local force_name = player.force.name
--   if not forces[force_name] then
--     global.data.player_forces[force_name] = {
--       force = player.force,
--       number_of_players = 1
--     }
--   else
--     global.data.player_forces[force_name].number_of_players = forces[force_name].number_of_players + 1
--   end
--   local old_force_name = event.force.name
--   if forces[old_force_name] then
--     local number_of_players = forces[old_force_name].number_of_players
--     if number_of_players == 1 then
--       global.data.player_forces[old_force_name] = nil
--     else
--       global.data.player_forces[old_force_name].number_of_players = number_of_players - 1
--     end
--   end
-- end)
--
-- script.on_event(defines.events.on_entity_spawned, function(event)
--   if event.entity and event.entity.type then
--     add_biter(event)
--   end
-- end)
--
--
-- local balance_to_ticks = {
--   ['super-pretty'] = 1,
--   pretty = 2,
--   balanced = 3,
--   performance = 4
-- }
--
-- local mod_settings -- local from global needs on_load handler
-- local function initialize_settings()
--   local settings = settings.global
--   global.settings = {}
--   global.settings["biter-trails-color"] = settings["biter-trails-color"].value
--   global.settings["biter-trails-glow"] = settings["biter-trails-glow"].value
--   global.settings["biter-trails-length"] = settings["biter-trails-length"].value
--   global.settings["biter-trails-scale"] = settings["biter-trails-scale"].value
--   global.settings["biter-trails-color-type"] = settings["biter-trails-color-type"].value
--   global.settings["biter-trails-speed"] = settings["biter-trails-speed"].value
--   global.settings["biter-trails-palette"] = settings["biter-trails-palette"].value
--   global.settings["biter-trails-balance"] = balance_to_ticks[settings["biter-trails-balance"].value]
--   mod_settings = global.settings
-- end
--
-- script.on_load(function()
--   mod_settings = global.settings
-- end)
--
-- script.on_event(defines.events.on_runtime_mod_setting_changed, function()
--   initialize_settings()
-- end)
--
-- script.on_configuration_changed(function()
--   if not global.data then
--     global.data = {}
--   end
--   initialize_settings()
--   get_all_biters()
--   get_player_forces()
-- end)
--
-- script.on_init(function()
--   if not global.data then
--     global.data = {}
--   end
--   initialize_settings()
--   get_all_biters()
--   get_player_forces()
-- end)
--
-- -- local function make_trails(settings, event)
-- --   local sprite = settings["biter-trails-color"]
-- --   local light = settings["biter-trails-glow"]
-- --   if sprite or light then
-- --     local length = tonumber(settings["biter-trails-length"])
-- --     local scale = tonumber(settings["biter-trails-scale"])
-- --     -- local color_mode = settings["biter-trails-color-type"]
-- --     -- local passengers_only = settings["biter-trails-passengers-only"]
-- --     local frequency = speeds[settings["biter-trails-speed"]]
-- --     local palette_choice = palette[settings["biter-trails-palette"]]
-- --     -- local tiptoe_mode = settings["biter-trails-tiptoe-mode"]
-- --     local global_data = global.data
-- --     local new_biter_data = global_data.biters
-- --     local new_sleeping_biter_data = global_data.sleeping_biters
-- --     local forces = global_data.player_forces
-- --     local num = 0
-- --     local event_tick = event.tick
-- --     local group_colors = global_data.group_colors
-- --     if not group_colors then
-- --       group_colors = {}
-- --       global.data.group_colors = {}
-- --     else
-- --       for group_number, data in pairs(group_colors) do
-- --         if not data.group and data.group.valid then
-- --           group_colors[group_number] = nil
-- --         else
-- --           group_colors[group_number].color = make_rainbow(event_tick, group_number, frequency, palette_choice)
-- --         end
-- --       end
-- --     end
-- --     if new_sleeping_biter_data then
-- --       -- local sleeping_biters = new_sleeping_biter_data
-- --       -- local nth_tick = 1
-- --       -- if event.nth_tick then
-- --       --   nth_tick = event.nth_tick
-- --       -- end
-- --       -- num = table_size(sleeping_biters) / 120 * nth_tick
-- --       num = table_size(new_sleeping_biter_data) * 0.008
-- --       global.data.from_key = table.for_n_of(new_sleeping_biter_data, global_data.from_key, num, function(data, key)
-- --         if data.biter and data.biter.valid then
-- --           local biter = data.biter
-- --           local unit_number = biter.unit_number
-- --           local last_position = data.position
-- --           local current_position = data.biter.position
-- --           local current_x = current_position.x
-- --           local current_y = current_position.y
-- --           local same_position = last_position and (last_position.x == current_x) and (last_position.y == current_position.y)
-- --           local chunk_is_visible = false
-- --           for _, data in pairs(forces) do
-- --             if data.force.is_chunk_visible(biter.surface, {current_x / 32, current_y / 32}) then
-- --               chunk_is_visible = true
-- --             end
-- --           end
-- --           if (not same_position) and chunk_is_visible then
-- --             new_biter_data[unit_number] = {
-- --               biter = biter,
-- --               position = current_position,
-- --               counter = 1
-- --             }
-- --             new_sleeping_biter_data[unit_number] = nil
-- --           end
-- --         end
-- --       end)
-- --     end
-- --     -- local biters = global_data.biters
-- --     if new_biter_data then
-- --       -- local new_biter_data = {}
-- --       for unit_number, data in pairs(new_biter_data) do
-- --         local biter = data.biter
-- --         if not biter.valid then
-- --           new_biter_data[unit_number] = nil
-- --         else
-- --           local last_position = data.position
-- --           local current_position = biter.position
-- --           local current_x = current_position.x
-- --           local current_y = current_position.y
-- --           local same_position = last_position and (last_position.x == current_x) and (last_position.y == current_y)
-- --           local chunk_is_hidden = false
-- --           local visible_check_timer = data.visible_check_timer
-- --           if visible_check_timer then
-- --             if visible_check_timer > 900 then
-- --               for _, data in pairs(forces) do
-- --                 if not data.force.is_chunk_visible(biter.surface, {current_x / 32, current_y / 32}) then
-- --                   chunk_is_hidden = true
-- --                 end
-- --               end
-- --               visible_check_timer = 1
-- --             else
-- --               visible_check_timer = visible_check_timer + 1
-- --             end
-- --           else
-- --             new_biter_data[unit_number].visible_check_timer = 1
-- --           end
-- --           -- if not same_position then
-- --           if (not same_position) and (not chunk_is_hidden) then
-- --             -- local event_tick = event.tick
-- --             -- local uuid = unit_number
-- --             local color = {}
-- --             if biter.unit_group then
-- --               local group_number = biter.unit_group.group_number
-- --               if group_colors then
-- --                 if group_colors[group_number] then
-- --                   color = group_colors[group_number].color
-- --                 else
-- --                   color = make_rainbow(event_tick, group_number, frequency, palette_choice)
-- --                   group_colors[group_number] = {
-- --                     group = biter.unit_group,
-- --                     color = color
-- --                   }
-- --                 end
-- --               end
-- --             else
-- --               color = make_rainbow(event_tick, unit_number, frequency, palette_choice)
-- --             end
-- --             local surface = biter.surface
-- --
-- --             if sprite then
-- --               -- sprite = rendering.draw_sprite{
-- --               rendering.draw_sprite{
-- --                 sprite = "biter-trail",
-- --                 target = current_position,
-- --                 surface = surface,
-- --                 x_scale = scale,
-- --                 y_scale = scale,
-- --                 render_layer = "radius-visualization",
-- --                 time_to_live = length,
-- --                 tint = color,
-- --               }
-- --             end
-- --             if light then
-- --               -- light = rendering.draw_light{
-- --               rendering.draw_light{
-- --                 sprite = "biter-trail",
-- --                 target = current_position,
-- --                 surface = surface,
-- --                 intensity = .175,
-- --                 scale = scale * 1.75,
-- --                 render_layer = "light-effect",
-- --                 time_to_live = length,
-- --                 color = color,
-- --               }
-- --             end
-- --             -- if sprite or light then
-- --             --   surface.create_particle{
-- --             --     name = "explosion-stone-particle-medium",
-- --             --     position = current_position,
-- --             --     movement = {0,0},
-- --             --     height = 10,
-- --             --     vertical_speed = 10,
-- --             --     frame_speed = 10
-- --             --   }
-- --             -- end
-- --             -- game.print("[gps="..biter.position.x..","..biter.position.y.."]")
-- --             new_biter_data[unit_number] = {
-- --               biter = biter,
-- --               position = current_position,
-- --               counter = 1
-- --             }
-- --           else
-- --             local counter = data.counter
-- --             if counter > 333 then
-- --               new_sleeping_biter_data[unit_number] = {
-- --                 biter = biter,
-- --                 position = current_position,
-- --                 counter = 1
-- --               }
-- --               new_biter_data[unit_number] = nil
-- --             else
-- --               new_biter_data[unit_number] = {
-- --                 biter = biter,
-- --                 position = current_position,
-- --                 counter = counter + 1
-- --               }
-- --             end
-- --           end
-- --         end
-- --       end
-- --       global.data.biters = new_biter_data
-- --       global.data.sleeping_biters = new_sleeping_biter_data
-- --       global.data.group_colors = group_colors
-- --       -- global.data.visible_check_timer = visible_check_timer
-- --     end
-- --     -- game.print("[color=blue]active biters: "..table_size(global.data.biters)..", sleeping biters: "..math.round(table_size(global.data.sleeping_biters))..", checked: "..num..", group_colors: "..table_size(global.data.group_colors).."[/color]")
-- --     game.print("[color=blue]active biters: "..table_size(global.data.biters)..", sleeping biters: "..math.round(table_size(global.data.sleeping_biters))..", checked: "..num.."[/color]")
-- --   end
-- -- end
--
-- local function make_trails(event_tick)
--   local sprite = mod_settings["biter-trails-color"]
--   local light = mod_settings["biter-trails-glow"]
--   if sprite or light then
--     local length = tonumber(mod_settings["biter-trails-length"])
--     local scale = tonumber(mod_settings["biter-trails-scale"])
--     -- local color_mode = settings["biter-trails-color-type"]
--     -- local passengers_only = settings["biter-trails-passengers-only"]
--     local frequency = speeds[mod_settings["biter-trails-speed"]]
--     local palette_choice = palette[mod_settings["biter-trails-palette"]]
--     -- local tiptoe_mode = settings["biter-trails-tiptoe-mode"]
--     local global_data = global.data
--     local biter_data = global_data.biters
--     local sleeping_biter_data = global_data.sleeping_biters
--     local forces = global_data.player_forces
--     local num = 0
--     -- local event_tick = event.tick
--     local group_colors = global_data.group_colors
--     if not group_colors then
--       group_colors = {}
--       global.data.group_colors = {}
--     else
--       for group_number, data in pairs(group_colors) do
--         if not data.group and data.group.valid then
--           group_colors[group_number] = nil
--         else
--           group_colors[group_number].color = make_rainbow(event_tick, group_number, frequency, palette_choice)
--         end
--       end
--     end
--     if sleeping_biter_data then
--       -- local sleeping_biters = new_sleeping_biter_data
--       -- local nth_tick = 1
--       -- if event.nth_tick then
--       --   nth_tick = event.nth_tick
--       -- end
--       -- num = table_size(sleeping_biters) / 120 * nth_tick
--       num = table_size(sleeping_biter_data) * 0.008
--       global_data.from_key = table.for_n_of(sleeping_biter_data, global_data.from_key, num, function(data, key)
--         if data.biter and data.biter.valid then
--           local biter = data.biter
--           local unit_number = biter.unit_number
--           local last_position = data.position
--           local current_position = data.biter.position
--           local current_x = current_position.x
--           local current_y = current_position.y
--           local same_position = last_position and (last_position.x == current_x) and (last_position.y == current_position.y)
--           if not same_position then
--             local chunk_is_visible = false
--             for _, data in pairs(forces) do
--               if data.force.is_chunk_visible(biter.surface, {current_x / 32, current_y / 32}) then
--                 chunk_is_visible = true
--               end
--             end
--             if chunk_is_visible then
--               biter_data[unit_number] = {
--                 biter = biter,
--                 position = current_position,
--                 counter = 1
--               }
--               sleeping_biter_data[unit_number] = nil
--             end
--           end
--         end
--       end)
--     end
--     -- local biters = global_data.biters
--     if biter_data then
--       -- local new_biter_data = {}
--       for unit_number, data in pairs(biter_data) do
--         local biter = data.biter
--         if not biter.valid then
--           biter_data[unit_number] = nil
--         else
--           local last_position = data.position
--           local current_position = biter.position
--           local current_x = current_position.x
--           local current_y = current_position.y
--           local same_position = last_position and (last_position.x == current_x) and (last_position.y == current_y)
--           local chunk_is_hidden = false
--           local visible_check_timer = data.visible_check_timer
--           if visible_check_timer then
--             if visible_check_timer > 900 then
--               for _, data in pairs(forces) do
--                 if not data.force.is_chunk_visible(biter.surface, {current_x / 32, current_y / 32}) then
--                   chunk_is_hidden = true
--                 end
--               end
--               visible_check_timer = 1
--             else
--               visible_check_timer = visible_check_timer + 1
--             end
--           else
--             biter_data[unit_number].visible_check_timer = 1
--           end
--           -- if not same_position then
--           if (not same_position) and (not chunk_is_hidden) then
--             -- local event_tick = event.tick
--             -- local uuid = unit_number
--             local color
--             if biter.unit_group then
--               local group_number = biter.unit_group.group_number
--               if group_colors then
--                 if group_colors[group_number] then
--                   color = group_colors[group_number].color
--                 else
--                   color = make_rainbow(event_tick, group_number, frequency, palette_choice)
--                   group_colors[group_number] = {
--                     group = biter.unit_group,
--                     color = color
--                   }
--                 end
--               end
--             else
--               color = make_rainbow(event_tick, unit_number, frequency, palette_choice)
--             end
--             local surface = biter.surface
--             if sprite then
--               -- sprite = rendering.draw_sprite{
--               rendering.draw_sprite{
--                 sprite = "biter-trail",
--                 target = current_position,
--                 surface = surface,
--                 x_scale = scale,
--                 y_scale = scale,
--                 render_layer = "radius-visualization",
--                 time_to_live = length,
--                 tint = color,
--               }
--             end
--             if light then
--               -- light = rendering.draw_light{
--               rendering.draw_light{
--                 sprite = "biter-trail",
--                 target = current_position,
--                 surface = surface,
--                 intensity = .175,
--                 scale = scale * 1.75,
--                 render_layer = "light-effect",
--                 time_to_live = length,
--                 color = color,
--               }
--             end
--             -- if sprite or light then
--             --   surface.create_particle{
--             --     name = "explosion-stone-particle-medium",
--             --     position = current_position,
--             --     movement = {0,0},
--             --     height = 10,
--             --     vertical_speed = 10,
--             --     frame_speed = 10
--             --   }
--             -- end
--             -- game.print("[gps="..biter.position.x..","..biter.position.y.."]")
--             biter_data[unit_number] = {
--               biter = biter,
--               position = current_position,
--               counter = 1
--             }
--           else
--             local counter = data.counter
--             if counter > 333 then
--               sleeping_biter_data[unit_number] = {
--                 biter = biter,
--                 position = current_position,
--                 counter = 1
--               }
--               biter_data[unit_number] = nil
--             else
--               biter_data[unit_number] = {
--                 biter = biter,
--                 position = current_position,
--                 counter = counter + 1
--               }
--             end
--           end
--         end
--       end
--       -- global.data.biters = biter_data
--       -- global.data.sleeping_biters = sleeping_biter_data
--       -- global.data.group_colors = group_colors
--       -- global.data.visible_check_timer = visible_check_timer
--     end
--     -- game.print("[color=blue]active biters: "..table_size(global.data.biters)..", sleeping biters: "..math.round(table_size(global.data.sleeping_biters))..", checked: "..num..", group_colors: "..table_size(global.data.group_colors).."[/color]")
--     -- game.print(event_tick..": [color=blue]active biters: "..table_size(global.data.biters)..", sleeping biters: "..math.round(table_size(global.data.sleeping_biters))..", checked: "..num.."[/color]")
--     game.print("[color=blue]active biters: "..table_size(global.data.biters)..", sleeping biters: "..math.round(table_size(global.data.sleeping_biters))..", checked: "..num.."[/color]")
--   end
-- end
--
-- script.on_event(defines.events.on_tick, function(event)
--   if (event.tick % mod_settings["biter-trails-balance"]) == 0 then
--     make_trails(event.tick) -- change make trails to use mod_settings upvalue, and change paramater to event_tick directly
--   end
--   -- game.print(event.tick .. ": " .. event.tick % mod_settings["biter-trails-balance"])
-- end)
--
-- -- script.on_event(defines.events.on_tick, function(event)
-- --   if not global.data.settings then
-- --     initialize_settings()
-- --   end
-- --   local settings = global.data.settings
-- --   if settings["biter-trails-balance"] == "super-pretty" then
-- --     make_trails(settings, event)
-- --     -- test()
-- --   end
-- -- end)
-- --
-- -- script.on_nth_tick(2, function(event)
-- --   local settings = global.data.settings
-- --   if settings["biter-trails-balance"] == "pretty" then
-- --     make_trails(settings, event)
-- --     -- test()
-- --   end
-- -- end)
-- --
-- -- script.on_nth_tick(3, function(event)
-- --   local settings = global.data.settings
-- --   if settings["biter-trails-balance"] == "balanced" then
-- --     make_trails(settings, event)
-- --     -- test()
-- --   end
-- -- end)
-- --
-- -- script.on_nth_tick(4, function(event)
-- --   local settings = global.data.settings
-- --   if settings["biter-trails-balance"] == "performance" then
-- --     make_trails(settings, event)
-- --     -- test()
-- --   end
-- -- end)
