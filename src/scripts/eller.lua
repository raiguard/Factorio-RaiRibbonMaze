-- Eller's Maze Generation Algorithm
-- Ref: https://weblog.jamisbuck.org/2010/12/29/maze-generation-eller-s-algorithm

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

  for _, cell in pairs(self.sets[target]) do
    table.insert(self.sets[sink], cell)
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
    --- @type Cell[]
    verticals = {},
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

-- Encoded connections

local directions = {
  north = 1, -- 0001
  east = 2, -- 0010
  south = 4, -- 0100
  west = 8, -- 1000
}

--- A cell's connections encoded into four binary bits
--- @alias EncodedConnections number

--- @param north boolean
--- @param east boolean
--- @param south boolean
--- @param west boolean
--- @return EncodedConnections
function eller.encode_connections(north, east, south, west)
  local map = 0
  if north then
    map = bit32.bor(map, directions.north)
  end
  if east then
    map = bit32.bor(map, directions.east)
  end
  if south then
    map = bit32.bor(map, directions.south)
  end
  if west then
    map = bit32.bor(map, directions.west)
  end
  return map
end

--- @param encoded_connections EncodedConnections
--- @return boolean
function eller.has_north(encoded_connections)
  return bit32.band(encoded_connections, directions.north) > 0
end

--- @param encoded_connections EncodedConnections
--- @return boolean
function eller.has_east(encoded_connections)
  return bit32.band(encoded_connections, directions.east) > 0
end

--- @param encoded_connections EncodedConnections
--- @return boolean
function eller.has_south(encoded_connections)
  return bit32.band(encoded_connections, directions.south) > 0
end

--- @param encoded_connections EncodedConnections
--- @return boolean
function eller.has_west(encoded_connections)
  return bit32.band(encoded_connections, directions.west) > 0
end

--- @param encoded_connections EncodedConnections
--- @return boolean
function eller.is_dead_end(encoded_connections)
  -- A power of two will only have a single connection
  return encoded_connections > 0 and bit32.band(encoded_connections, encoded_connections - 1) == 0
end

--- @param Row Row
--- @param random function
--- @param finish boolean
--- @return Row NextRow
--- @return EncodedConnections[] connections
function eller.step(Row, finish, random)
  -- Randomly merge adjacent sets

  --- @type Cell[][]
  local connected_groups = {}
  --- @type Cell[]
  local connected_group = { 1 }

  for cell = 1, Row.width - 1 do
    if Row:same(cell, cell + 1) or (not finish and random(5) <= 2) then
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

  local NextRow = Row:next()

  if not finish then
    for set, cells in pairs(Row.sets) do
      -- Get some random cells
      local to_connect = {}
      for _, cell in pairs(cells) do
        if random(2) <= 1 then
          to_connect[cell] = true
        end
      end
      -- Always need at least one
      if not next(to_connect) then
        to_connect[cells[random(1, #cells)]] = true
      end

      for cell in pairs(to_connect) do
        NextRow.verticals[cell] = true
        NextRow:add(cell, set)
      end
    end
  end

  -- Convert into a readable output

  local connections = {}
  for _, connected_set in pairs(connected_groups) do
    for i, cell in pairs(connected_set) do
      local first = (i == 1)
      local last = (i == #connected_set)
      table.insert(
        connections,
        eller.encode_connections(Row.verticals[cell], not last, NextRow.verticals[cell], not first)
      )
    end
  end

  -- Finish up

  NextRow:populate()

  return NextRow, connections
end

--- Replaces conceptual walls with actual empty cells
--- @param connections EncodedConnections[]
--- @return EncodedConnections[] first
--- @return EncodedConnections[] second
function eller.gen_wall_cells(connections)
  local first = {}
  local second = {}
  for _, encoded in pairs(connections) do
    table.insert(first, encoded)
    table.insert(first, eller.has_east(encoded) and eller.encode_connections(false, true, false, true) or 0)

    table.insert(second, eller.has_south(encoded) and eller.encode_connections(true, false, true, false) or 0)
    table.insert(second, 0)
  end
  -- Remove the last entries, which are always walls
  first[#first] = nil
  second[#second] = nil

  return first, second
end

return eller
