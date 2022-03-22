local area = require("__flib__.area")
local table = require("__flib__.table")

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

--- @param cell_size number
--- @param width number
function maze.init(cell_size, width)
  local cell_ratio = math.floor(cell_size / 32)
  -- Create global data
  global.maze = {
    cell_ratio = cell_ratio,
    Row = eller.new(math.ceil(width / 2)), -- The maze generator needs a halved width
    rows = {},
    width = width,
    x_boundary = math.floor((width * cell_ratio) / 2),
    y = 1,
  }

  local nauvis = game.surfaces.nauvis
  local gen = nauvis.map_gen_settings
  gen.width = (width + 1) * cell_size
  gen.height = 0
  nauvis.map_gen_settings = gen
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

  -- Offset the position to begin at 0,0
  pos = { x = pos.x + x_boundary, y = pos.y + 1 }
  -- Convert chunk position to a maze position
  pos = { x = math.floor(pos.x / global.maze.cell_ratio) + 1, y = math.floor(pos.y / global.maze.cell_ratio) + 1 }

  -- Retrieve or generate row
  local row = global.maze.rows[pos.y]
  if not row then
    for y = global.maze.y, pos.y, 2 do
      local NextRow, connections = eller.step(global.maze.Row)
      local first, second = eller.gen_wall_cells(connections)
      global.maze.Row = NextRow
      global.maze.rows[y] = first
      global.maze.rows[y + 1] = second
      global.maze.y = math.max(y + 2, global.maze.y)

      -- Print to console if desired
      if DEBUG then
        for _, row in pairs({ first, second }) do
          print(table.concat(
            table.map(row, function(encoded)
              if encoded > 0 then
                return "█"
              else
                return " "
              end
            end),
            ""
          ))
        end
      end
    end
    row = global.maze.rows[pos.y]
  end

  local encoded = row[pos.x]

  -- Void this chunk if it's a maze boundary
  if not encoded or encoded == 0 then
    void_area(e.area, e.surface)
    return
  end

  -- Remove all resources
  for _, resource in pairs(e.surface.find_entities_filtered({ type = "resource" })) do
    resource.destroy({ raise_destroy = true })
  end

  -- Determine if we should create resources here
  if eller.is_dead_end(encoded) then
    rendering.draw_rectangle({
      color = { r = 0.6, a = 0.6 },
      filled = true,
      left_top = e.area.left_top,
      right_bottom = e.area.right_bottom,
      surface = game.surfaces.nauvis,
    })
  end
end

return maze
