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

function maze.init()
  global.mazes = {}
end

--- @param surface LuaSurface
--- @param cell_size number
--- @param width number
--- @param height number?
--- @param seed number?
function maze.new(surface, cell_size, width, height, seed)
  -- Width and height must be odd numbers
  width = width % 2 == 0 and width - 1 or width
  height = height or 0
  height = (height > 0 and height % 2 == 0) and height - 1 or height

  -- Adjust map size
  local gen = surface.map_gen_settings
  gen.width = (width + 1) * cell_size
  gen.height = 0
  surface.map_gen_settings = gen

  seed = seed or gen.seed

  local cell_ratio = math.floor(cell_size / 32)
  local maze_data = {
    cell_ratio = cell_ratio,
    height = height,
    print_water_warning = gen.water > 0,
    random = game.create_random_generator(seed),
    Row = eller.new(math.ceil(width / 2)), -- The maze generator needs a halved width
    rows = {},
    seed = seed,
    surface = surface,
    width = width,
    x_boundary = math.floor((width * cell_ratio) / 2),
    y = 1,
  }

  -- Determine resource ratios
  -- TODO: Remote interface for this
  local margins = {
    ["crude-oil"] = 2,
    ["mineral-water"] = 2,
    ["imersite"] = 12,
  }
  -- TODO: Un-hardcode this?
  local resources = {
    { type = "tile", name = "water", diameter = 1, margin = 0, weight = 1 },
  }
  -- FIXME: Un-hardcode this
  local base_density = {
    ["iron-ore"] = 10,
    ["copper-ore"] = 8,
    ["coal"] = 8,
    ["stone"] = 4,
    ["uranium-ore"] = 0.9,
    ["crude-oil"] = 1, -- This does not match the base game
    ["water"] = 0.5, -- Simulated
    ["imersite"] = 0.5,
    ["rare-metals"] = 1,
    ["mineral-water"] = 1,
  }
  for name in pairs(gen.autoplace_controls) do
    local prototype = game.entity_prototypes[name]
    if prototype and prototype.type == "resource" then
      table.insert(resources, {
        type = "entity",
        name = name,
        diameter = math.ceil(area.square(prototype.collision_box):width()),
        margin = margins[name] or 0,
        weight = base_density[name] or 1,
      })
    end
  end

  maze_data.resources = resources

  global.mazes[surface.index] = maze_data
end

local function weighted_random(pool, random)
  local poolsize = 0
  for _, v in pairs(pool) do
    poolsize = poolsize + v.weight
  end
  local selection = random() * poolsize
  for k, v in pairs(pool) do
    selection = selection - v.weight
    if selection <= 0 then
      return k
    end
  end
end

--- @param e on_chunk_generated
function maze.on_chunk_generated(e)
  local maze_data = global.mazes[e.surface.index]
  if not maze_data then
    return
  end

  --- @type ChunkPosition
  local pos = e.position

  -- If the chunk is outside the radius we care about, just remove it
  local x_boundary = maze_data.x_boundary
  if pos.x < -x_boundary or pos.x > x_boundary or pos.y < -1 then
    void_area(e.area, maze_data.surface)
    return
  end

  -- Retrieve or generate row

  -- Offset the position to begin at 0,0
  local maze_pos = { x = pos.x + x_boundary, y = pos.y + 1 }
  -- Convert chunk position to a maze position
  local maze_pos = {
    x = math.floor(maze_pos.x / maze_data.cell_ratio) + 1,
    y = math.floor(maze_pos.y / maze_data.cell_ratio) + 1,
  }

  -- If we have a finite maze, remove all chunks after the end
  if maze_data.height > 0 and maze_pos.y > maze_data.height then
    void_area(e.area, maze_data.surface)
    return
  end

  local row = maze_data.rows[maze_pos.y]
  if not row then
    for y = maze_data.y, maze_pos.y, 2 do
      local NextRow, connections = eller.step(maze_data.Row, y == maze_data.height, maze_data.random)
      local first, second = eller.gen_wall_cells(connections)
      maze_data.Row = NextRow
      maze_data.rows[y] = first
      maze_data.rows[y + 1] = second
      maze_data.y = math.max(y + 2, maze_data.y)

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
    row = maze_data.rows[maze_pos.y]
  end

  local encoded = row[maze_pos.x]

  -- Map generation

  -- "Guaranteed" chunks are the six chunks that comprise the crash site and spawn area - these always need to be generated
  local is_guaranteed = guaranteed_chunks[pos.y] and guaranteed_chunks[pos.y][pos.x] -- Use the unadjusted chunk position

  -- Void this chunk if it's a maze boundary or outside the maze
  if not is_guaranteed and (not encoded or encoded == 0) then
    void_area(e.area, e.surface)
    return
  end

  -- Remove all resources
  for _, resource in pairs(e.surface.find_entities_filtered({ area = e.area, type = "resource" })) do
    resource.destroy({ raise_destroy = true })
  end

  -- Determine if we should create resources here
  if not is_guaranteed and eller.is_dead_end(encoded) then
    -- The resource must be consistent regardless of chunk generation order, so create a new random generator for every resource
    local random = game.create_random_generator(maze_data.seed + (maze_pos.y * 10000) + (maze_pos.x * 1000))

    -- TODO: Use resource generation frequencies somehow
    local resource = maze_data.resources[weighted_random(maze_data.resources, random)]
    local Area = area.load(e.area):expand(-1)
    local combined_diameter = resource.diameter + resource.margin
    local margin = (Area:width() % combined_diameter) / 2
    local offset = math.floor(combined_diameter / 2 + margin)
    for pos in Area:iterate(combined_diameter, { x = offset, y = offset }) do
      if resource.type == "entity" then
        maze_data.surface.create_entity({
          name = resource.name,
          position = pos,
          create_build_effect_smoke = false,
          amount = 1000000,
          snap_to_tile_center = true,
        })
      elseif resource.type == "tile" then
        -- Fill all tiles in the resource's "bounding box"
        local ResourceArea =
          area.from_dimensions({ height = resource.diameter, width = resource.diameter }, pos):floor()
        local tiles = {}
        for pos in ResourceArea:iterate() do
          table.insert(tiles, { name = resource.name, position = pos })
        end
        maze_data.surface.set_tiles(tiles, true, true, true, true)
      end
    end
  end
end

return maze
