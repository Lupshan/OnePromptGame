-- Biome 1: The Ashfall. A burned world of grey drifts and dying embers.
return {
  id = "ashfall",
  name = "The Ashfall",
  tagline = "Where the world burned first.",
  order = 1,
  boss = "pyravore",

  palette = {
    skyTop = { 0.10, 0.06, 0.09 },
    skyBottom = { 0.22, 0.10, 0.10 },
    far = { 0.16, 0.09, 0.11 },
    near = { 0.24, 0.13, 0.13 },
    tile = { 0.30, 0.22, 0.24 },
    tileTop = { 0.48, 0.32, 0.30 },
    platform = { 0.55, 0.34, 0.28 },
    spike = { 0.75, 0.30, 0.24 },
    light = { 1.0, 0.45, 0.2 },
    accent = { 1.0, 0.55, 0.25 },
  },

  ambient = "embers",      -- drifting particles style
  music = { root = 110, scale = "phrygian", tempo = 64,
            layers = { "drone", "bass", "arp", "shimmer" } },

  enemyWeights = {         -- which enemies favor this biome (id -> weight)
    cinderling = 4, ashmite = 3, emberfly = 3, pyre_totem = 2,
  },

  hazard = "spikes",
}
