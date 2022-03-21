local area = require("__flib__.area")

local eller = require("scripts.eller")

-- y -> table of x
local guaranteed_chunks = {
  [-1] = { [-2] = true, [-1] = true, [0] = true },
  [0] = { [-2] = true, [-1] = true, [0] = true },
}

local maze = {}

--- @param box BoundingBox
--- @param surface LuaSurface
local function void_area(box, surface)
  local tiles_to_set = {}
  for pos in area.iterate(box) do
    table.insert(tiles_to_set, { name = "out-of-map", position = { pos.x, pos.y } })
  end
  surface.set_tiles(tiles_to_set, true, true, true, true)
end

--- @param tile_size number
--- @param width number
function maze.init(tile_size, width)
  -- Create global data
  global.maze = {
    Row = eller.new(math.ceil(width / 2)), -- The maze generator needs a halved width
    rows = {},
    tile_size = tile_size,
    width = width,
    x_boundary = math.floor(width / 2),
    y = -1,
  }
end

--- @param e on_chunk_generated
function maze.on_chunk_generated(e)
  --- @type ChunkPosition
  local pos = e.position

  -- If the chunk is outside the radius we care about, just remove it
  local x_boundary = global.maze.x_boundary
  if pos.x < -x_boundary or pos.x > x_boundary or pos.y < -1 then
    void_area(e.area, e.surface)
    return
  end

  local is_guaranteed = guaranteed_chunks[pos.y] and guaranteed_chunks[pos.y][pos.x]
  if is_guaranteed then
    return
  end

  -- Retrieve or generate row
  local row = global.maze.rows[pos.y]
  if not row then
    for y = global.maze.y, pos.y, 2 do
      -- TODO: Don't print maze rows
      local NextRow, rows = eller.step(global.maze.Row, true)
      global.maze.Row = NextRow
      global.maze.rows[y] = rows[1]
      global.maze.rows[y + 1] = rows[2]
      global.maze.y = math.max(y + 2, global.maze.y)
    end
    row = global.maze.rows[pos.y]
  end

  -- Void this chunk if it's a maze boundary
  local cell = pos.x + x_boundary + 1
  if not row[cell] then
    void_area(e.area, e.surface)
    return
  end

  -- Remove all resources
  for _, resource in pairs(e.surface.find_entities_filtered({ type = "resource" })) do
    resource.destroy({ raise_destroy = true })
  end
end

return maze
