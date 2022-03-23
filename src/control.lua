local event = require("__flib__.event")

local maze = require("scripts.maze")

-- Enable debugging niceties
DEBUG = true

event.on_init(function()
  -- Init mazes
  maze.init()

  -- Only create a maze if we just started a world
  if game.tick == 0 then
    -- Create Nauvis maze
    maze.new(
      game.surfaces.nauvis,
      settings.global["rrm-cell-size"].value,
      settings.global["rrm-maze-width"].value,
      settings.global["rrm-maze-height"].value,
      -- Give a constant maze seed if in debug mode
      DEBUG and 0
    )
  end
end)

event.on_surface_created(function(e)
  maze.new(
    game.surfaces[e.surface_index],
    settings.global["rrm-cell-size"].value,
    settings.global["rrm-maze-width"].value,
    settings.global["rrm-maze-height"].value
  )
end)

event.on_chunk_generated(maze.on_chunk_generated)

event.on_cutscene_cancelled(function(e)
  local player = game.get_player(e.player_index)
  local maze = global.mazes[player.surface.index]
  if maze and maze.print_water_warning then
    maze.print_water_warning = false
    player.surface.print({ "message.rrm-water-warning" })
  end
end)
