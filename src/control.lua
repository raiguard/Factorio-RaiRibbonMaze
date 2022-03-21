local event = require("__flib__.event")

local eller = require("scripts.eller")

event.on_init(function()
  local Row = eller.new(21)
  local result
  for _ = 1, 10 do
    Row, result = eller.step(Row)
    print(result)
  end
end)
