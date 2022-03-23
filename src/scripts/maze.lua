local area = require("__flib__.area")
local table = require("__flib__.table")

local eller = require("scripts.eller")

-- y -> table of x
local guaranteed_chunks = {
  [-1] = { [-2] = true, [-1] = true, [0] = true },
  [0] = { [-2] = true, [-1] = true, [0] = true },
}

-- FIXME: Un-hardcode this
local hardcoded = {
  {
    additional_richness = 0,
    base_density = 8,
    in_starting_area = true,
    margin = 0,
    name = "coal",
    richness = 1,
  },
  {
    additional_richness = 0,
    base_density = 8,
    in_starting_area = true,
    margin = 0,
    name = "copper-ore",
    richness = 1,
  },
  {
    additional_richness = 11000,
    base_density = 1,
    in_starting_area = false,
    margin = 2,
    name = "crude-oil",
    richness = 1,
  }, -- This does not match the base game
  {
    additional_richness = 0,
    base_density = 10,
    in_starting_area = true,
    margin = 0,
    name = "iron-ore",
    richness = 1,
  },
  {
    additional_richness = 0,
    base_density = 4,
    in_starting_area = true,
    margin = 0,
    name = "stone",
    richness = 1,
  },
  {
    additional_richness = 0,
    base_density = 0.9,
    in_starting_area = false,
    margin = 0,
    name = "uranium-ore",
    richness = 1,
  },
  {
    additional_richness = 0,
    base_density = 0.5,
    in_starting_area = false,
    margin = 0,
    name = "water",
    richness = 1,
    tile = true,
  }, -- Simulated
  -- Krastorio 2
  {
    additional_richness = 0,
    base_density = 0.5,
    in_starting_area = false,
    margin = 12,
    name = "imersite",
    richness = 1,
  },
  {
    additional_richness = 11000,
    base_density = 1,
    in_starting_area = false,
    margin = 2,
    name = "mineral-water",
    richness = 1,
  },
  {
    additional_richness = 0,
    base_density = 1,
    in_starting_area = false,
    name = "rare-metals",
    richness = 1,
  },
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

function maze.gen_resource_data()
  local resources = {}
  for _, hardcoded in pairs(hardcoded) do
    local data = table.deep_copy(hardcoded)
    local prototype = game.entity_prototypes[hardcoded.name]
    if prototype and prototype.type == "resource" then
      data.diameter = math.ceil(area.square(prototype.collision_box):width())
      table.insert(resources, data)
    elseif game.tile_prototypes[hardcoded.name] then
      data.diameter = 1
      table.insert(resources, data)
    end
  end

  global.resources = resources
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

  -- Adjust resource weights
  -- TODO: Handle if the weight or richness are changed midway
  local controls = gen.autoplace_controls
  local resources = table.map(global.resources, function(data)
    local control = controls[data.name]
    if control then
      data.richness = data.richness * control.richness
      data.weight = data.base_density * control.frequency
    else
      data.weight = data.base_density
    end
    return data
  end)

  -- game.forces.player.chart(surface, { left_top = { x = -350, y = -30 }, right_bottom = { x = 350, y = 3000 } })

  local cell_ratio = math.floor(cell_size / 32)
  --- @class Maze
  global.mazes[surface.index] = {
    cell_ratio = cell_ratio,
    height = height,
    random = game.create_random_generator(seed),
    resources = resources,
    Row = eller.new(math.ceil(width / 2)), -- The maze generator needs a halved width
    rows = {},
    seed = seed,
    surface = surface,
    width = width,
    x_boundary = math.floor((width * cell_ratio) / 2),
    y = 1,
  }
end

--- @param self Maze
function maze.load(self)
  eller.load(self.Row)
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
  local self = global.mazes[e.surface.index]
  if not self then
    return
  end

  --- @type ChunkPosition
  local pos = e.position

  -- If the chunk is outside the radius we care about, just remove it
  local x_boundary = self.x_boundary
  if pos.x < -x_boundary or pos.x > x_boundary or pos.y < -1 then
    void_area(e.area, self.surface)
    return
  end

  -- Retrieve or generate row

  -- Offset the position to begin at 0,0
  local maze_pos = { x = pos.x + x_boundary, y = pos.y + 1 }
  -- Convert chunk position to a maze position
  local maze_pos = {
    x = math.floor(maze_pos.x / self.cell_ratio) + 1,
    y = math.floor(maze_pos.y / self.cell_ratio) + 1,
  }

  -- If we have a finite maze, remove all chunks after the end
  if self.height > 0 and maze_pos.y > self.height then
    void_area(e.area, self.surface)
    return
  end

  local row = self.rows[maze_pos.y]
  if not row then
    for y = self.y, maze_pos.y, 2 do
      local NextRow, connections = eller.step(self.Row, y == self.height, self.random)
      local first, second = eller.gen_wall_cells(connections)
      self.Row = NextRow
      self.rows[y] = first
      self.rows[y + 1] = second
      self.y = math.max(y + 2, self.y)

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
    row = self.rows[maze_pos.y]
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
    local random = game.create_random_generator(self.seed + (maze_pos.y * 10000) + (maze_pos.x * 1000))

    -- TODO: Generate starting area mixed resources and water
    local resource = self.resources[weighted_random(self.resources, random)]
    local Area = area.load(e.area):expand(-1)
    local combined_diameter = resource.diameter + resource.margin
    local margin = (Area:width() % combined_diameter) / 2
    local offset = math.floor(combined_diameter / 2 + margin)
    -- TODO: Create richness zones instead of having a flat progression
    local richness = ((resource.control_richness or 1) * (random(4, 6) / 5) * (maze_pos.y * 60))
      + resource.additional_richness
    for pos in Area:iterate(combined_diameter, { x = offset, y = offset }) do
      if resource.tile then
        -- Fill all tiles in the resource's "bounding box"
        local ResourceArea =
          area.from_dimensions({ height = resource.diameter, width = resource.diameter }, pos):floor()
        local tiles = {}
        for pos in ResourceArea:iterate() do
          table.insert(tiles, { name = resource.name, position = pos })
        end
        self.surface.set_tiles(tiles, true, true, true, true)
      else
        self.surface.create_entity({
          name = resource.name,
          position = pos,
          create_build_effect_smoke = false,
          amount = richness * (random(90, 110) / 100),
          snap_to_tile_center = true,
        })
      end
    end
  end
end

return maze
