local event = require("__flib__.event")

local maze = require("scripts.maze")

event.on_init(function()
  -- Gatekeeping: Don't let people add this to an existing world
  if game.tick ~= 0 then
    error("Cannot add ribbon maze to an existing game")
  end

  -- Guarantee the same maze on a given map seed and parameters
  global.random = game.create_random_generator()

  maze.init(32, 21)
end)

event.on_chunk_generated(maze.on_chunk_generated)
