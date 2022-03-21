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
--- @return Row NextRow
--- @return string result
function eller.step(Row)
  -- Randomly merge adjacent sets

  --- @type Cell[][]
  local connected_sets = {}
  --- @type Cell[]
  local connected_set = { 1 }

  for cell = 1, Row.width - 1 do
    if Row:same(cell, cell + 1) or math.random(2) == 1 then
      -- There is a wall
      table.insert(connected_sets, connected_set)
      connected_set = { cell + 1 }
    else
      -- Merge the cells
      Row:merge(cell, cell + 1)
      table.insert(connected_set, cell + 1)
    end
  end

  table.insert(connected_sets, connected_set)

  -- Add vertical connections

  local verticals = {}
  local NextRow = Row:next()

  for set, cells in pairs(Row.sets) do
    -- Sort randomly
    local to_connect = table.filter(cells, function(_)
      return math.random(2) == 1
    end)
    -- Always need at least one
    if #to_connect == 0 then
      table.insert(to_connect, cells[math.random(1, #cells)])
    end
    verticals = table.array_merge({ verticals, to_connect })
    for _, cell in pairs(to_connect) do
      NextRow:add(cell, set)
    end
  end

  -- Convert into an array of connections

  local connections = {}
  for _, connected_set in pairs(connected_sets) do
    for i, cell in pairs(connected_set) do
      local last = (i == #connected_set)
      local map = { e = not last, s = table.find(verticals, cell) }
      table.insert(connections, map)
    end
  end

  -- Convert into a readable output

  local wall = " "
  local passage = "X"

  local result = ""

  local line = wall
  local next_line = wall
  for _, connections in ipairs(connections) do
    line = line .. passage .. (connections.e and passage or wall)
    next_line = next_line .. (connections.s and passage or wall) .. wall
  end
  result = result .. line .. "\n" .. next_line

  -- Finish up

  NextRow:populate()

  return NextRow, result
end

return eller
