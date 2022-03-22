local event = require("__flib__.event")

local maze = require("scripts.maze")

DEBUG = true

event.on_init(function()
  -- Gatekeeping: Don't let people add this to an existing world
  if game.tick ~= 0 then
    error("Cannot add ribbon maze to an existing game")
  end

  -- Init mazes
  maze.init()

  -- Create Nauvis maze
  maze.new(
    game.surfaces.nauvis,
    settings.global["rrm-cell-size"].value,
    settings.global["rrm-maze-width"].value,
    -- Give a constant maze seed if in debug mode
    DEBUG and 0 or nil
  )
end)

event.on_surface_created(function(e)
  maze.new(
    game.surfaces[e.surface_index],
    settings.global["rrm-cell-size"].value,
    settings.global["rrm-maze-width"].value
  )
end)

event.on_chunk_generated(maze.on_chunk_generated)
