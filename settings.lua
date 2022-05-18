
local biterTrailsColor = {
  type = "bool-setting",
  name = "biter-trails-color",
  setting_type = "runtime-global",
  order = "a",
  default_value = true
}

local biterTrailsGlow = {
  type = "bool-setting",
  name = "biter-trails-glow",
  setting_type = "runtime-global",
  order = "b",
  default_value = true
}

local biterTrailsTiptoeMode = {
  type = "bool-setting",
  name = "biter-trails-tiptoe-mode",
  setting_type = "runtime-global",
  order = "c",
  default_value = true
}

local biterTrailsPassengersOnly = {
  type = "bool-setting",
  name = "biter-trails-passengers-only",
  setting_type = "runtime-global",
  order = "d",
  default_value = false
}

local biterTrailsScale = {
  type = "string-setting",
  name = "biter-trails-scale",
  setting_type = "runtime-global",
  order = "e",
  default_value = "5",
  allowed_values = {
    "1",
    "2",
    "3",
    "4",
    "5",
    "6",
    "8",
    "11",
    "20",
  }
}

local biterTrailsLength = {
  type = "string-setting",
  name = "biter-trails-length",
  setting_type = "runtime-global",
  order = "f",
  default_value = "120",
  allowed_values = {
    "15",
    "30",
    "60",
    "90",
    "120",
    "180",
    "210",
    "300",
    "600"
  }
}

local biterTrailsColorSync = {
  type = "string-setting",
  name = "biter-trails-color-type",
  setting_type = "runtime-global",
  order = "g",
  default_value = "spidertron",
  allowed_values = {
    "spidertron",
    "rainbow",
  }
}

local biterTrailsPalette = {
  type = "string-setting",
  name = "biter-trails-palette",
  setting_type = "runtime-global",
  order = "h",
  default_value = "default",
  allowed_values = {
    "light",
    "pastel",
    "default",
    "vibrant",
    "deep"
  }
}

local biterTrailsSpeed = {
  type = "string-setting",
  name = "biter-trails-speed",
  setting_type = "runtime-global",
  order = "i",
  default_value = "default",
  allowed_values = {
    "veryslow",
    "slow",
    "default",
    "fast",
    "veryfast"
  }
}

local biterTrailsBalance = {
  type = "string-setting",
  name = "biter-trails-balance",
  setting_type = "runtime-global",
  order = "j",
  default_value = "pretty",
  allowed_values = {
    -- "super-performance",
    "performance",
    "balanced",
    "pretty",
    "super-pretty"
  }
}

data:extend({
  biterTrailsColor,
  biterTrailsGlow,
  biterTrailsScale,
  biterTrailsLength,
  biterTrailsColorSync,
  biterTrailsPalette,
  biterTrailsSpeed,
  biterTrailsBalance,
  -- biterTrailsPassengersOnly,
  -- biterTrailsTiptoeMode
})
