local event = require("__flib__.event")

local eller = require("scripts.eller")

event.on_init(function()
  -- TODO: Get rid of the 0
  global.random = game.create_random_generator(0)
  local Row = eller.new(21)
  for _ = 1, 21 do
    Row = eller.step(Row, true)
  end
end)
