local event = require("__flib__.event")

local maze = require("scripts.maze")

-- Enable debugging niceties
DEBUG = false

event.on_init(function()
  -- Init mazes
  maze.init()
  maze.gen_resource_data()

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

event.on_load(function()
  for _, maze_data in pairs(global.mazes) do
    maze.load(maze_data)
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

event.on_chunk_generated(function(e)
  local Maze = global.mazes[e.surface.index]
  if Maze then
    Maze:on_chunk_generated(e)
  end
end)

-- event.on_player_created(function()
--   game.forces.player.chart(
--     game.surfaces.nauvis,
--     { left_top = { x = -350, y = -30 }, right_bottom = { x = 350, y = 3000 } }
--   )
-- end)
