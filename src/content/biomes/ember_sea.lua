-- Biome 3: The Ember Sea. An ocean of live coals under a black sky.
-- (The Hollow Spire moves to order 4; the run is four biomes deep.)
return {
  id = "ember_sea",
  name = "The Ember Sea",
  tagline = "Don't ask what it drowned. Ask what floats.",
  order = 3,
  boss = "tide_of_coals",

  palette = {
    skyTop = { 0.06, 0.03, 0.05 },
    skyBottom = { 0.25, 0.08, 0.05 },
    far = { 0.18, 0.07, 0.06 },
    near = { 0.28, 0.11, 0.07 },
    tile = { 0.32, 0.16, 0.12 },
    tileTop = { 0.62, 0.30, 0.18 },
    platform = { 0.7, 0.38, 0.2 },
    spike = { 1.0, 0.45, 0.15 },
    light = { 1.0, 0.55, 0.15 },
    accent = { 1.0, 0.65, 0.3 },
  },

  ambient = "embers",
  music = { root = 87.3, scale = "minorPent", tempo = 78,
            layers = { "drone", "bass", "pulse", "arp" } },

  enemyWeights = {
    ember_skirmisher = 3, ash_hound = 3, splitter = 3, mortar_shell = 2,
    soot_hulk = 2, emberfly = 2, leech_wisp = 2, pyre_totem = 1,
  },

  hazard = "spikes",
}
