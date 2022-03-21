-- Eller's Maze Generation Algorithm
-- Ref: https://weblog.jamisbuck.org/2010/12/29/maze-generation-eller-s-algorithm

local table = require("__flib__.table")

-- --------------------------------------------------
-- Row object

--- Cell is the position of a cell on the map from left to right
--- @alias Cell number

--- @alias Set number

--- @class Row
local Row = {}

--- @param cell_1 Cell
--- @param cell_2 Cell
function Row:same(cell_1, cell_2)
  return self.cells[cell_1] == self.cells[cell_2]
end

--- @param cell Cell
--- @param set Set
function Row:add(cell, set)
  self.cells[cell] = set
  if not self.sets[set] then
    self.sets[set] = {}
  end
  table.insert(self.sets[set], cell)
end

--- @param sink_cell Cell
--- @param target_cell Cell
function Row:merge(sink_cell, target_cell)
  local sink = self.cells[sink_cell]
  local target = self.cells[target_cell]

  self.sets[sink] = table.array_merge({ self.sets[sink], self.sets[target] })
  for _, cell in pairs(self.sets[target]) do
    self.cells[cell] = sink
  end
  self.sets[target] = nil
end

function Row:populate()
  for cell = 1, self.width do
    if not self.cells[cell] then
      local set = self.next_set
      self.next_set = set + 1
      self.sets[set] = { cell }
      self.cells[cell] = set
    end
  end
end

--- @return Row
function Row:next()
  return self.new(self.width, self.next_set)
end

-- CONSTRUCTORS

--- @param width number
--- @param next_set number?
function Row.new(width, next_set)
  --- @type Row
  local self = {
    --- @type table<Cell, Set>
    cells = {},
    next_set = next_set or 1,
    --- @type table<Set, Cell[]>
    sets = {},
    width = width,
  }
  Row.load(self)

  -- self:populate()

  return self
end

function Row.load(self)
  setmetatable(self, { __index = Row })
end

-- --------------------------------------------------
-- Public interface

local eller = {}

--- @param width number
--- @return Row
function eller.new(width)
  local FirstRow = Row.new(width)
  FirstRow:populate()
  return FirstRow
end

--- @param Row Row
--- @param debug_print boolean
--- @return Row NextRow
--- @return boolean[][] rows
function eller.step(Row, debug_print)
  -- Randomly merge adjacent sets

  --- @type Cell[][]
  local connected_groups = {}
  --- @type Cell[]
  local connected_group = { 1 }

  for cell = 1, Row.width - 1 do
    if Row:same(cell, cell + 1) or global.random(5) <= 2 then
      -- There is a wall
      table.insert(connected_groups, connected_group)
      connected_group = { cell + 1 }
    else
      -- Merge the cells
      Row:merge(cell, cell + 1)
      table.insert(connected_group, cell + 1)
    end
  end

  table.insert(connected_groups, connected_group)

  -- Add vertical connections

  local verticals = {}
  local NextRow = Row:next()

  for set, cells in pairs(Row.sets) do
    -- Get some random cells
    local to_connect = table.filter(cells, function(_)
      return global.random(2) <= 1
    end, true)
    -- Always need at least one
    if #to_connect == 0 then
      table.insert(to_connect, cells[global.random(1, #cells)])
    end
    verticals = table.array_merge({ verticals, to_connect })
    for _, cell in pairs(to_connect) do
      NextRow:add(cell, set)
    end
  end

  -- Convert into a readable output

  local connections = {}
  for _, connected_set in pairs(connected_groups) do
    for i, cell in pairs(connected_set) do
      local last = (i == #connected_set)
      local map = {
        e = not last,
        s = table.find(verticals, cell) and true or false,
        cell = cell,
        set = Row.cells[cell],
      }
      table.insert(connections, map)
    end
  end

  -- Because we are generating empty chunks instead of walls, we produce two rows at a time
  local rows = { {}, {} }
  for _, connections in pairs(connections) do
    table.insert(rows[1], true)
    table.insert(rows[1], connections.e)

    table.insert(rows[2], connections.s)
    table.insert(rows[2], false)
  end
  -- Remove the last entries, which are always walls
  rows[1][#rows[1]] = nil
  rows[2][#rows[2]] = nil

  -- Print to console if desired
  if debug_print then
    for _, row in pairs(rows) do
      print(table.concat(
        table.map(row, function(cell)
          if cell then
            return "█"
          else
            return " "
          end
        end),
        ""
      ))
    end
  end

  -- Finish up

  NextRow:populate()

  return NextRow, rows
end

return eller

-- Debugging code:
--
-- if not global.y then
--   global.y = 0
-- end
-- local y = global.y
-- local g = 0.6

-- for x, connections in pairs(connections) do
--   local x = x * 2
--   local y = y * 2
--   rendering.draw_rectangle({
--     color = { g = g, a = 1 },
--     filled = true,
--     left_top = { x = x, y = y },
--     right_bottom = { x = x + 1, y = y + 1 },
--     surface = game.surfaces.nauvis,
--   })
--   rendering.draw_rectangle({
--     color = { g = connections.e and g or 0, a = 1 },
--     filled = true,
--     left_top = { x = x + 1, y = y },
--     right_bottom = { x = x + 2, y = y + 1 },
--     surface = game.surfaces.nauvis,
--   })
--   rendering.draw_rectangle({
--     color = { g = connections.s and g or 0, a = 1 },
--     filled = true,
--     left_top = { x = x, y = y + 1 },
--     right_bottom = { x = x + 1, y = y + 2 },
--     surface = game.surfaces.nauvis,
--   })
--   rendering.draw_rectangle({
--     color = { a = 1 },
--     filled = true,
--     left_top = { x = x + 1, y = y + 1 },
--     right_bottom = { x = x + 2, y = y + 2 },
--     surface = game.surfaces.nauvis,
--   })
--   rendering.draw_text({
--     text = connections.set,
--     surface = game.surfaces.nauvis,
--     target = { x = x + 0.5, y = y + 0.5 },
--     color = { r = 1, g = g, b = 1 },
--     alignment = "center",
--     vertical_alignment = "middle",
--   })
-- end

-- global.y = y + 1
