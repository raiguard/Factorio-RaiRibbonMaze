local event = require("__flib__.event")

local maze = require("scripts.maze")

DEBUG = false

event.on_init(function()
  -- Gatekeeping: Don't let people add this to an existing world
  if game.tick ~= 0 then
    error("Cannot add ribbon maze to an existing game")
  end

  -- Guarantee the same maze on a given map seed and parameters
  if DEBUG then
    -- Always generate the same maze regardless of seed
    global.random = game.create_random_generator(0)
  else
    global.random = game.create_random_generator()
  end

  -- Create maze
  maze.init(settings.global["rrm-cell-size"].value, settings.global["rrm-maze-width"].value)
end)

event.on_chunk_generated(maze.on_chunk_generated)
