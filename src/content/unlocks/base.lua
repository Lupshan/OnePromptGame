-- Meta unlocks, bought with cinders between runs at the Kiln.
-- HARD RULE: unlocks only WIDEN the content pool (new boons, characters,
-- chunks, enemies). They never grant starting power or stat bonuses.
return {
  -- characters ---------------------------------------------------------
  {
    id = "char_ashblade",
    kind = "character",
    name = "The Ashblade",
    desc = "A wraith honed to an edge. +melee/-HP sidegrade kit.",
    cost = 120,
  },
  {
    id = "char_stormcaller",
    kind = "character",
    name = "The Stormcaller",
    desc = "A wraith that kept the storm. Bolt-focused sidegrade kit.",
    cost = 120,
  },
  {
    id = "char_verdant",
    kind = "character",
    name = "The Verdant",
    desc = "A wraith the green refused to release. Sustain sidegrade kit.",
    cost = 160,
  },

  -- boon pool wideners ---------------------------------------------------
  {
    id = "boons_legendary",
    kind = "pool",
    name = "Old Names",
    desc = "Legendary boons (Living Flame, Tempest Call, ...) may now appear.",
    cost = 90,
  },
  {
    id = "boons_duo_rare",
    kind = "pool",
    name = "Confluence",
    desc = "Three more duo boons join the pool: Backdraft, Static Collapse, Umbral Step.",
    cost = 80,
  },
  {
    id = "chunks_advanced",
    kind = "pool",
    name = "Deep Cartography",
    desc = "Harder, stranger room layouts join the generator's chunk pool.",
    cost = 60,
  },
  {
    id = "shrine_events",
    kind = "pool",
    name = "Listening Stones",
    desc = "Shrines remember more bargains (richer event outcomes).",
    cost = 50,
  },
}
