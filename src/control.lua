local event = require("__flib__.event")

local eller = require("scripts.eller")

event.on_init(function()
  global.Row = eller.new(5)
end)

event.on_gui_closed(function()
  global.Row = eller.step(global.Row)
end)
