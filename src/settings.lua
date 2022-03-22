data:extend({
  {
    type = "int-setting",
    name = "rrm-maze-width",
    setting_type = "runtime-global",
    default_value = 21,
    minimum_value = 8,
    order = "a",
  },
  {
    type = "int-setting",
    name = "rrm-cell-size",
    setting_type = "runtime-global",
    default_value = 32,
    allowed_values = { 32, 64, 96, 128 },
    order = "b",
  },
})
