-- Biome 2: The Duskmire. Drowned lowlands where the smoke settled and stayed.
return {
  id = "duskmire",
  name = "The Duskmire",
  tagline = "The smoke came down to drink.",
  order = 2,
  boss = "drowned_choir",

  palette = {
    skyTop = { 0.03, 0.08, 0.10 },
    skyBottom = { 0.07, 0.16, 0.15 },
    far = { 0.06, 0.13, 0.13 },
    near = { 0.09, 0.18, 0.17 },
    tile = { 0.13, 0.24, 0.22 },
    tileTop = { 0.22, 0.42, 0.34 },
    platform = { 0.25, 0.45, 0.35 },
    spike = { 0.35, 0.65, 0.45 },
    light = { 0.35, 0.95, 0.75 },
    accent = { 0.45, 0.95, 0.8 },
  },

  ambient = "spores",
  music = { root = 98, scale = "dorian", tempo = 58,
            layers = { "drone", "bass", "melody", "shimmer" } },

  enemyWeights = {
    bogshade = 4, spitter = 3, willowisp = 3, shellback = 2,
    ashmite = 1, -- stragglers from above
  },

  hazard = "spikes",
}
