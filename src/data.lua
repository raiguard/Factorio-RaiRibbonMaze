-- Override the elevation generator to remove water
local noise = require("__core__.lualib.noise")
local elevation = data.raw["noise-expression"]["0_17-lakes-elevation"]
elevation.expression = noise.clamp(elevation.expression, 0, 1 / 0)
