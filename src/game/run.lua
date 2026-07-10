-- Run context: everything that lives exactly as long as one attempt.
-- Stats are rebuilt from scratch whenever boons change (idempotent), and a
-- run always starts at base power -- meta-progression only widens the pool
-- of what can be offered, never what you start with.
local config = require("src.core.config")
local util = require("src.core.util")
local RNG = require("src.core.rng")
local signals = require("src.core.signals")
local boonsSys = require("src.game.boons")
local registry = require("src.game.registry")
local rungraph = require("src.game.rungraph")
local save = require("src.core.save")

local Run = {}
Run.__index = Run

-- Hard caps: no boon stack may push these into degenerate territory.
local STAT_CAPS = {
  moveSpeedMult = { 0.5, 2.2 },
  damageMult = { 0.2, 6.0 },
  attackSpeedMult = { 0.4, 2.6 },
  damageTakenMult = { 0.25, 3.0 },
  dashCooldownMult = { 0.25, 3.0 },
  specialCooldownMult = { 0.3, 3.0 },
  critChance = { 0, 0.6 },
  luck = { 0.5, 4.0 },
  airJumps = { 0, 3 },
  airDashes = { 1, 2 },  -- HARD guardrail: mobility never becomes infinite
  glide = { 0, 1 },
  lifesteal = { 0, 6 }, -- flat hp per hit, capped
  thorns = { 0, 60 },
}

function Run.new(opts)
  opts = opts or {}
  local self = setmetatable({}, Run)
  self.seed = opts.seed or (love and love.math.random(1, 999999999)) or os.time()
  self.rng = RNG.new(self.seed)

  local charId = opts.characterId or save.get().lastCharacter or "wraith"
  self.character = registry.get("character", charId) or registry.all("character")[1]
  save.get().lastCharacter = self.character and self.character.id or nil

  self.boons = {}
  self.statsFlat = {}
  self.statsMult = {}
  self.boonGroup = nil
  self.custom = {} -- scratch space for boon/boss state, wiped per run

  self.embers = 0        -- run currency (lost on death)
  self.cindersEarned = 0 -- meta currency earned this attempt (banked live)

  self.biomeIndex = 1
  self.biomes = {}
  for _, b in ipairs(registry.all("biome")) do self.biomes[#self.biomes + 1] = b end
  table.sort(self.biomes, function(a, b) return (a.order or 99) < (b.order or 99) end)

  self.depth = 0        -- rooms cleared total (drives enemy scaling)
  self.time = 0
  self.kills = 0
  self.hp = 0
  self.currentRoom = nil
  self.graph = nil
  self.nodeId = nil

  self:rebuildBoons()
  self.hp = self:maxHP()
  self:buildGraph()
  return self
end

function Run:biome()
  return self.biomes[math.min(self.biomeIndex, #self.biomes)]
end

function Run:isFinalBiome()
  return self.biomeIndex >= math.min(config.run.biomesPerRun, #self.biomes)
end

function Run:buildGraph()
  self.graph = rungraph.generate(self.rng, "graph:" .. self.biomeIndex, {
    layers = config.run.graphLayers,
    minWidth = config.run.graphMinWidth,
    maxWidth = config.run.graphMaxWidth,
    biomeIndex = self.biomeIndex,
  })
  self.nodeId = self.graph.startId
end

function Run:currentNode()
  return self.graph.nodes[self.nodeId]
end

function Run:nextChoices()
  local node = self:currentNode()
  local out = {}
  for _, id in ipairs(node.edges) do
    out[#out + 1] = self.graph.nodes[id]
  end
  return out
end

function Run:advanceTo(nodeId)
  self.nodeId = nodeId
end

-- Stats ------------------------------------------------------------------------

function Run:addFlat(name, v)
  self.statsFlat[name] = (self.statsFlat[name] or 0) + v
end

function Run:addMult(name, pct)
  self.statsMult[name] = (self.statsMult[name] or 1) * (1 + pct)
end

function Run:stat(name, base)
  local v = (base + (self.statsFlat[name] or 0)) * (self.statsMult[name] or 1)
  local cap = STAT_CAPS[name]
  if cap then v = util.clamp(v, cap[1], cap[2]) end
  return v
end

function Run:maxHP()
  return math.floor(self:stat("maxHP", config.player.maxHP))
end

function Run:rebuildBoons()
  local prevMax = self.hp > 0 and self:maxHP() or nil
  self.statsFlat = {}
  self.statsMult = {}
  if self.boonGroup then self.boonGroup.clear() end
  self.boonGroup = signals.group()

  if self.character and self.character.apply then
    self.character.apply(self, { group = self.boonGroup })
  end

  for _, owned in ipairs(self.boons) do
    local def = boonsSys.def(owned.id)
    if def and def.apply then
      def.apply(self, {
        level = owned.level,
        mult = boonsSys.rarity(owned.rarity).mult,
        group = self.boonGroup,
        on = self.boonGroup.on,
      })
    end
  end

  -- growing max HP heals the difference; shrinking clamps
  local newMax = self:maxHP()
  if prevMax and newMax > prevMax then
    self.hp = self.hp + (newMax - prevMax)
  end
  self.hp = util.clamp(self.hp, 0, newMax)
  signals.emit("boonsRebuilt", self)
end

-- Economy ------------------------------------------------------------------------

function Run:addEmbers(n)
  self.embers = self.embers + math.floor(n * self:stat("emberGainMult", 1))
  signals.emit("embersChanged", self)
end

function Run:spendEmbers(n)
  if self.embers < n then return false end
  self.embers = self.embers - n
  signals.emit("embersChanged", self)
  return true
end

function Run:addCinders(n)
  self.cindersEarned = self.cindersEarned + n
  save.addCinders(n) -- banked immediately: death cannot take these
end

-- Lifecycle ------------------------------------------------------------------------

function Run:onRoomCleared(room)
  self.depth = self.depth + 1
  signals.emit("roomCleared", room, self)
end

function Run:destroy()
  if self.boonGroup then self.boonGroup.clear() end
end

return Run
