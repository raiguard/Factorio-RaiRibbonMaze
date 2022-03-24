local area = require("__flib__.area")
local table = require("__flib__.table")

local eller = require("scripts.eller")
local luastar = require("scripts.luastar")

-- --------------------------------------------------
-- Maze object

--- @class Resource
--- @field additional_richness number
--- @field base_density number
--- @field diameter number
--- @field in_starting_area boolean
--- @field margin number
--- @field name string
--- @field richness number
--- @field tile boolean
--- @field weight number

-- FIXME: Un-hardcode this
--- @type Resource[]
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

--- @class Maze
local Maze = {}

--- @param box BoundingBox
function Maze:void_area(box)
  local tiles_to_set = {}
  for pos in area.iterate(box) do
    table.insert(tiles_to_set, { name = "out-of-map", position = { pos.x, pos.y } })
  end
  self.surface.set_tiles(tiles_to_set, true, true, true, true)
end

--- @param until_y number
function Maze:gen_rows(until_y)
  until_y = until_y or self.y + 1
  for y = self.y, until_y, 2 do
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
end

--- Pick a resource, accounting for each resource's weight
--- @param resources Resource[]
--- @param random LuaRandomGenerator
--- @return Resource
local function pick_resource(resources, random)
  local poolsize = 0
  for _, resource in pairs(resources) do
    poolsize = poolsize + resource.weight
  end
  if poolsize > 0 then
    local selection = random() * poolsize
    for _, resource in pairs(resources) do
      selection = selection - resource.weight
      if selection <= 0 then
        return resource
      end
    end
  end
end

--- @param e on_chunk_generated
function Maze:on_chunk_generated(e)
  --- @type ChunkPosition
  local pos = e.position

  -- If the chunk is outside the radius we care about, just remove it
  local x_boundary = self.x_boundary
  if pos.x < -x_boundary or pos.x > x_boundary or pos.y < -1 then
    self:void_area(e.area)
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
    self:void_area(e.area)
    return
  end

  local row = self.rows[maze_pos.y]
  if not row then
    self:gen_rows(maze_pos.y)
    row = self.rows[maze_pos.y]
  end

  local encoded = row[maze_pos.x]

  -- Map generation

  -- Spawn cells are guaranteed to exist and must be free of resources
  local is_spawn = self.spawn_cells[maze_pos.y] and self.spawn_cells[maze_pos.y][maze_pos.x]

  -- Void this chunk if it's a maze boundary or outside the maze
  if not is_spawn and (not encoded or encoded == 0) then
    self:void_area(e.area)
    return
  end

  -- Remove all resources
  for _, resource in pairs(e.surface.find_entities_filtered({ area = e.area, type = "resource" })) do
    resource.destroy({ raise_destroy = true })
  end

  -- Determine if we should create resources here
  if not is_spawn and eller.is_dead_end(encoded) then
    -- The resource must be consistent regardless of chunk generation order, so create a new random generator for every resource
    local random = game.create_random_generator(self.seed + (maze_pos.y * 10000) + (maze_pos.x * 1000))

    local SpawningArea = area.load(e.area):expand(-1)
    local to_spawn = {}

    local is_starting_patch = self.starting_ore_patch.x == maze_pos.x and self.starting_ore_patch.y == maze_pos.y
    local is_starting_water = self.starting_water_patch.x == maze_pos.x and self.starting_water_patch.y == maze_pos.y
    if is_starting_patch then
      local starting_resources = table.array_filter(self.resources, function(resource)
        return resource.in_starting_area
      end)
      local chunks = math.max(math.ceil(math.sqrt(#starting_resources)), 2)
      while 30 % chunks ~= 0 do
        if chunks > 10 then
          error("Too many starting area resource chunks")
        end
        chunks = chunks + 1
      end
      local total_chunks = chunks ^ 2
      local chunk_width = SpawningArea:width() / chunks

      -- Guarantee that there is at least one of every resource
      local guaranteed = {}
      for _, resource in pairs(starting_resources) do
        local i = random(1, total_chunks)
        while guaranteed[i] do
          i = random(1, total_chunks)
        end
        guaranteed[i] = resource
      end

      -- Fill in the resources
      local i = 0
      for pos in SpawningArea:iterate(chunk_width) do
        i = i + 1
        if not to_spawn[i] then
          to_spawn[i] = {
            Area = area.load({
              left_top = { x = pos.x, y = pos.y },
              right_bottom = { x = pos.x + chunk_width, y = pos.y + chunk_width },
            }),
            resource = guaranteed[i] or pick_resource(starting_resources, random),
          }
        end
      end
    elseif is_starting_water then
      -- TODO: This is awful
      for _, res in pairs(self.resources) do
        if res.name == "water" then
          table.insert(to_spawn, { Area = SpawningArea, resource = res })
        end
      end
    else
      table.insert(to_spawn, { Area = SpawningArea, resource = pick_resource(self.resources, random) })
    end

    for _, to_spawn in pairs(to_spawn) do
      local Area = to_spawn.Area
      local resource = to_spawn.resource

      local combined_diameter = resource.diameter + resource.margin
      local margin = (Area:width() % combined_diameter) / 2
      local offset = math.floor(combined_diameter / 2 + margin)
      -- TODO: Create richness zones instead of having a flat progression
      local richness = (resource.richness * (random(4, 6) / 5) * (maze_pos.y * 60)) + resource.additional_richness
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
end

-- --------------------------------------------------
-- Public interface

local maze = {}

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

  --- @type Resource[]
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
  --- @type Resource[]
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

  -- Since we replace walls with empty cells, the maze algorithm needs to be half as wide
  local internal_width = math.ceil(width / 2)
  local cell_ratio = math.floor(cell_size / 32)

  -- Determine which cells should be ignored for resource spawning
  -- Spawn cell is half the width, so it's the same as the internal width
  local spawn_cell = { x = internal_width, y = 1 }
  local spawn_cells = {}
  if cell_ratio == 1 then
    spawn_cells = {
      [1] = { [spawn_cell.x - 2] = true, [spawn_cell.x - 1] = true, [spawn_cell.x] = true },
      [2] = { [spawn_cell.x - 2] = true, [spawn_cell.x - 1] = true, [spawn_cell.x] = true },
    }
  elseif cell_ratio == 2 then
    spawn_cells = {
      [1] = { [spawn_cell.x - 1] = true, [spawn_cell.x] = true },
    }
  else
    spawn_cells = {
      [1] = { [spawn_cell.x] = true },
    }
  end

  --- @type Maze
  local self = {
    cell_ratio = cell_ratio,
    height = height,
    random = game.create_random_generator(seed),
    resources = resources,
    Row = eller.new(internal_width),
    rows = {},
    seed = seed,
    spawn_cells = spawn_cells,
    surface = surface,
    width = width,
    x_boundary = math.floor((width * cell_ratio) / 2),
    y = 1,
  }
  maze.load(self)

  -- Determine two closest patches for starting resources and water
  self:gen_rows(14)
  local closest_cell
  local closest_len = math.huge
  local second_closest_cell
  local second_closest_len = math.huge
  for y, row in pairs(self.rows) do
    for x, connections in pairs(row) do
      local is_spawn = spawn_cells[y] and spawn_cells[y][x]
      if not is_spawn and eller.is_dead_end(connections) then
        local cell = { x = x, y = y }
        local path = luastar:find(width, 14, cell, spawn_cell, function(x, y)
          return self.rows[y][x] > 0
        end, true, true)
        if path then
          local length = #path
          if length < second_closest_len then
            second_closest_len = length
            second_closest_cell = cell
          end
          if length < closest_len then
            second_closest_len = closest_len
            closest_len = length

            second_closest_cell = closest_cell
            closest_cell = cell
          end
        end
      end
    end
  end

  self.starting_ore_patch = closest_cell
  self.starting_water_patch = second_closest_cell

  global.mazes[surface.index] = self
end

--- @param self Maze
function maze.load(self)
  setmetatable(self, { __index = Maze })
  eller.load(self.Row)
end

return maze
