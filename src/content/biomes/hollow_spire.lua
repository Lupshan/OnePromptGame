-- Biome 3: The Hollow Spire. The tower where the wardens made their last stand.
return {
  id = "hollow_spire",
  name = "The Hollow Spire",
  tagline = "It still holds the sky up. Barely.",
  order = 3,
  boss = "last_warden",

  palette = {
    skyTop = { 0.05, 0.05, 0.13 },
    skyBottom = { 0.12, 0.10, 0.24 },
    far = { 0.10, 0.09, 0.20 },
    near = { 0.14, 0.12, 0.27 },
    tile = { 0.19, 0.17, 0.33 },
    tileTop = { 0.36, 0.32, 0.55 },
    platform = { 0.45, 0.38, 0.62 },
    spike = { 0.62, 0.45, 0.85 },
    light = { 0.85, 0.7, 1.0 },
    accent = { 0.95, 0.8, 0.45 },
  },

  ambient = "motes",
  music = { root = 130.8, scale = "lydian", tempo = 72,
            layers = { "drone", "bass", "arp", "melody", "pulse" } },

  enemyWeights = {
    sentinel = 3, warden_husk = 3, echo = 3, dervish = 3,
    willowisp = 1,
  },

  hazard = "spikes",
}
