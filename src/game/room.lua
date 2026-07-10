-- A live room: generated geometry + entities + props + doors + objective.
-- Combat rooms lock their exit until every wave is dead; the reward (boon
-- sigil, currency) spawns on clear. Everything here reads content through
-- registries, so new room types/enemies plug in without touching this file.
local config = require("src.core.config")
local util = require("src.core.util")
local physics = require("src.game.physics")
local generator = require("src.game.levelgen.generator")
local registry = require("src.game.registry")
local Enemy = require("src.game.enemy")
local Boss = require("src.game.boss")
local Player = require("src.game.player")
local Projectiles = require("src.game.projectiles")
local Pickups = require("src.game.pickups")
local Background = require("src.render.background")
local particles = require("src.render.particles")
local draw = require("src.render.draw")
local sfx = require("src.audio.sfx")
local signals = require("src.core.signals")
local save = require("src.core.save")
local locale = require("src.core.locale")

local Room = {}
Room.__index = Room

local T = physics.TILE

-- opts: run, node (graph node), callbacks { onExit, onSigil, onShopBuy... }
function Room.new(opts)
  local self = setmetatable({}, Room)
  local run = opts.run
  self.run = run
  self.node = opts.node
  self.roomType = opts.node and opts.node.type or opts.roomType or "traversal"
  if self.roomType == "start" then self.roomType = "entry" end
  self.biome = run:biome()
  self.depth = run.depth
  self.callbacks = opts.callbacks or {}

  -- generate geometry (seeded by run seed + node identity: same seed, same
  -- room -- and the streams are RESET first, so restarting after a death
  -- rebuilds the exact same room)
  local streamName = ("room:%d:%s"):format(run.biomeIndex, opts.node and opts.node.id or "solo")
  run.rng:resetPrefix(streamName)
  local gen = generator.generate({
    roomType = self.roomType, biomeId = self.biome.id, depth = self.depth,
    rng = run.rng, streamName = streamName,
  })
  self.world = gen.world
  self.markers = gen.markers
  self.spawnTile = gen.spawn
  self.exitTile = gen.exit
  self.form = gen.form
  self.usedFallback = gen.usedFallback

  self.enemies = {}
  self.projectiles = Projectiles.new(self)
  self.pickups = Pickups.new(self)
  self.props = {}
  self.boss = nil
  self.waves = {}
  self.waveIndex = 0
  self.pendingSpawns = {}
  self.cleared = false
  self.rewardGiven = false
  self.exitOpen = true
  self.time = 0

  self.background = Background.new(self.biome, self.world.widthPx, self.world.heightPx,
    run.seed + (opts.node and opts.node.id or 0) * 131)

  -- player
  local px = (self.spawnTile.c - 0.5) * T
  local py = self.spawnTile.r * T
  self.player = Player.new(self, px - config.player.w / 2, py - config.player.h, run)
  self.spawnX, self.spawnY = self.player.x, self.player.y

  self:populate(streamName)
  signals.emit("roomEntered", self)
  return self
end

-- Fill the room based on its type.
function Room:populate(streamName)
  local run = self.run
  local rng = run.rng
  local rt = self.roomType

  -- prop lights from markers
  for _, m in ipairs(self.markers.lights) do
    self.props[#self.props + 1] = { kind = "light", x = m.x, y = m.y }
  end

  if rt == "arena" then
    -- THE sealed fight: the only room type (besides bosses) that locks its exit
    self.exitOpen = false
    self:buildWaves(streamName, true)
    self:nextWave()
  elseif rt == "combat" then
    -- contested path: every authored marker spawns, exit stays open;
    -- clearing them all is optional and rewarded with a boon sigil
    self:spawnMarkedEnemies(streamName, 1.0)
    self.hadEnemies = #self.enemies > 0
    local n = rng:random(streamName, 2, 4)
    for _ = 1, n do
      local spot = self:randomGroundSpot(streamName)
      if spot then
        self.pickups:spawn({ kind = "ember", x = spot.x, y = spot.y - 8,
          value = rng:random(streamName, 2, 4) })
      end
    end
  elseif rt == "traversal" or rt == "entry" then
    -- enemies are sparse hazards in the way, not the point
    self:spawnMarkedEnemies(streamName, rt == "entry" and 0.2 or 0.45)
    local n = rng:random(streamName, 4, 7)
    for _ = 1, n do
      local spot = self:randomGroundSpot(streamName)
      if spot then
        self.pickups:spawn({ kind = "ember", x = spot.x, y = spot.y - 8,
          value = rng:random(streamName, 2, 4) })
      end
    end
    -- a perched challenge sigil: earn a boon by going out of your way
    if rt == "traversal" and rng:chance(streamName, 0.5) then
      self:placeChallengeSigil()
    end
  elseif rt == "treasure" then
    for _, m in ipairs(self.markers.chests) do
      self.props[#self.props + 1] = { kind = "chest", x = m.x, y = m.y, opened = false }
    end
    for _, m in ipairs(self.markers.altars) do
      self.props[#self.props + 1] = { kind = "altar", x = m.x, y = m.y, used = false }
    end
    -- guarantee at least one prize even if the chunk had no markers
    if #self.markers.chests == 0 and #self.markers.altars == 0 then
      local spot = self:randomGroundSpot(streamName)
      if spot then
        self.props[#self.props + 1] = { kind = "chest", x = spot.x, y = spot.y, opened = false }
      end
    end
  elseif rt == "rest" then
    for _, m in ipairs(self.markers.heals) do
      self.props[#self.props + 1] = { kind = "fountain", x = m.x, y = m.y, used = false }
    end
    if #self.markers.heals == 0 then
      local spot = self:randomGroundSpot(streamName)
      if spot then
        self.props[#self.props + 1] = { kind = "fountain", x = spot.x, y = spot.y, used = false }
      end
    end
  elseif rt == "shop" then
    self:stockShop(streamName)
  elseif rt == "event" then
    for _, m in ipairs(self.markers.altars) do
      self.props[#self.props + 1] = { kind = "shrine", x = m.x, y = m.y, used = false }
    end
    if #self.markers.altars == 0 then
      local spot = self:randomGroundSpot(streamName)
      if spot then
        self.props[#self.props + 1] = { kind = "shrine", x = spot.x, y = spot.y, used = false }
      end
    end
  elseif rt == "boss" then
    self.exitOpen = false
    local bossDef = registry.get("boss", self.biome.boss)
    if bossDef then
      local bx = self.world.widthPx * 0.65
      local by = (config.levelgen.roomHeight - 2) * T
      self.boss = Boss.new(bossDef, self, bx, by)
      self.enemies[#self.enemies + 1] = self.boss
    else
      -- content safety net: no boss registered -> elite gauntlet
      self:buildWaves(streamName, true)
      self:nextWave()
    end
  end
end

-- Challenge sigil: placed on a reachable perch in the upper part of the
-- room (computed from the same flood the validator uses, so the base kit
-- can always earn it).
function Room:placeChallengeSigil()
  local reach = require("src.game.levelgen.reachability")
  local visited = reach.flood(self.world, self.spawnTile.c, self.spawnTile.r)
  local best, bestR
  local cols = self.world.cols
  for k in pairs(visited) do
    local r = math.floor(k / (cols + 2))
    local c = k % (cols + 2)
    -- keep away from doors, prefer the highest standable perch
    if c > 7 and c < cols - 7 and (not bestR or r < bestR) then
      best, bestR = { c = c, r = r }, r
    end
  end
  if best and bestR and bestR < self.world.rows * 0.75 then
    self.pickups:spawn({
      kind = "sigil",
      x = (best.c - 0.5) * T,
      y = (best.r - 0.6) * T,
      data = {},
    })
  end
end

-- Enemy selection ------------------------------------------------------------

function Room:pickEnemyDef(streamName, flying)
  local rng = self.run.rng
  local weights = self.biome.enemyWeights or {}
  local pool = {}
  for id, w in pairs(weights) do
    local def = registry.get("enemy", id)
    if def and (def.flying or false) == flying
       and (not def.minDepth or self.depth >= def.minDepth)
       and (not def.unlock or save.isUnlocked(def.unlock)) then
      pool[#pool + 1] = { def = def, weight = w * (def.weight or 1) }
    end
  end
  if #pool == 0 then
    -- fall back to any matching enemy from the global registry
    for _, def in ipairs(registry.all("enemy")) do
      if (def.flying or false) == flying and not def.unlock then
        pool[#pool + 1] = { def = def, weight = def.weight or 1 }
      end
    end
  end
  local pick = rng:pickWeighted(streamName, pool, function(p) return p.weight end)
  return pick and pick.def or nil
end

function Room:spawnMarkedEnemies(streamName, fraction)
  local rng = self.run.rng
  for _, m in ipairs(self.markers.enemies) do
    if rng:chance(streamName, fraction or 1) then
      local def = self:pickEnemyDef(streamName, m.flying)
      if def then
        self.enemies[#self.enemies + 1] = Enemy.new(def, self, m.x, m.y)
      end
    end
  end
end

function Room:buildWaves(streamName, elite)
  local rng = self.run.rng
  local markers = {}
  for _, m in ipairs(self.markers.enemies) do markers[#markers + 1] = m end
  -- top up sparse rooms with extra spawn points on the ground
  local want = math.min(3 + math.floor(self.depth / 2) + (elite and 2 or 0), 10)
  while #markers < want do
    local spot = self:randomGroundSpot(streamName)
    if not spot then break end
    markers[#markers + 1] = { x = spot.x, y = spot.y, flying = rng:chance(streamName, 0.3) }
  end
  rng:shuffle(streamName, markers)
  while #markers > want do table.remove(markers) end

  local waveCount = #markers <= 3 and 1 or (#markers <= 6 and 2 or 3)
  self.waves = {}
  for i = 1, waveCount do self.waves[i] = {} end
  for i, m in ipairs(markers) do
    local w = ((i - 1) % waveCount) + 1
    local def = self:pickEnemyDef(streamName, m.flying)
    if def then
      self.waves[w][#self.waves[w] + 1] = { def = def, x = m.x, y = m.y }
    end
  end
  -- elite: crown one enemy in the last wave
  if elite and #self.waves > 0 then
    local lastWave = self.waves[#self.waves]
    if #lastWave > 0 then
      local pick = lastWave[rng:random(streamName, 1, #lastWave)]
      pick.elite = true
      pick.eliteMod = rng:pick(streamName, { "volatile", "regenerating", "vampiric", "stormtouched" })
    end
  end
end

function Room:nextWave()
  self.waveIndex = self.waveIndex + 1
  local wave = self.waves[self.waveIndex]
  if not wave then return false end
  for _, spawn in ipairs(wave) do
    -- telegraphed spawn: portal effect, enemy appears after a beat
    self.pendingSpawns[#self.pendingSpawns + 1] = {
      def = spawn.def, x = spawn.x, y = spawn.y, elite = spawn.elite,
      eliteMod = spawn.eliteMod,
      timer = 0.55 + love.math.random() * 0.3,
    }
  end
  if self.waveIndex > 1 then sfx.play("door", 0.7) end
  return true
end

function Room:aliveEnemies()
  local n = 0
  for _, e in ipairs(self.enemies) do
    if not e.dead then n = n + 1 end
  end
  return n + #self.pendingSpawns
end

-- Shop -----------------------------------------------------------------------

function Room:stockShop(streamName)
  local run = self.run
  local boonsSys = require("src.game.boons")
  local pedestals = self.markers.shops
  local offer = boonsSys.generateOffer(run, run.rng, streamName .. ":shop", math.max(#pedestals - 1, 1))
  local idx = 1
  for i, m in ipairs(pedestals) do
    if i == 1 then
      self.props[#self.props + 1] = {
        kind = "shopItem", x = m.x, y = m.y, item = "heal",
        price = 35, labelKey = "ui.room.mend", sold = false,
      }
    else
      local o = offer[idx]
      idx = idx + 1
      if o then
        self.props[#self.props + 1] = {
          kind = "shopItem", x = m.x, y = m.y, item = "boon", offer = o,
          price = math.floor(45 * o.rarity.mult),
          sold = false,
        }
      end
    end
  end
end

-- Spatial queries ---------------------------------------------------------------

function Room:nearestEnemy(x, y, maxDist)
  local best, bestD = nil, (maxDist or math.huge) ^ 2
  for _, e in ipairs(self.enemies) do
    if not e.dead then
      local ex, ey = e:center()
      local d = util.dist2(x, y, ex, ey)
      if d < bestD then best, bestD = e, d end
    end
  end
  return best
end

function Room:enemiesInArc(x, y, angle, range, halfArc)
  local out = {}
  for _, e in ipairs(self.enemies) do
    if not e.dead then
      local ex, ey = e:center()
      local d = util.dist(x, y, ex, ey) - math.max(e.w, e.h) * 0.4
      if d <= range then
        local a = util.angle(x, y, ex, ey)
        local diff = math.abs(((a - angle + math.pi) % (2 * math.pi)) - math.pi)
        if diff <= halfArc then out[#out + 1] = e end
      end
    end
  end
  return out
end

function Room:enemiesInRadius(x, y, r)
  local out = {}
  for _, e in ipairs(self.enemies) do
    if not e.dead then
      local ex, ey = e:center()
      if util.dist(x, y, ex, ey) <= r + math.max(e.w, e.h) * 0.4 then
        out[#out + 1] = e
      end
    end
  end
  return out
end

function Room:randomGroundSpot(streamName)
  local rng = self.run.rng
  local reach = require("src.game.levelgen.reachability")
  for _ = 1, 40 do
    local c = rng:random(streamName, 6, self.world.cols - 6)
    for r = 3, self.world.rows - 2 do
      if reach.standable(self.world, c, r) then
        if love and love.math.random() < 0.7 then
          return { x = (c - 0.5) * T, y = r * T }
        end
      end
    end
  end
  return nil
end

function Room:randomAirSpot(nearX, nearY, radius)
  for _ = 1, 30 do
    local x = nearX + (love.math.random() * 2 - 1) * radius
    local y = nearY + (love.math.random() * 2 - 1) * radius
    local c = math.floor(x / T) + 1
    local r = math.floor(y / T) + 1
    if c > 3 and c < self.world.cols - 3 and r > 2 and r < self.world.rows - 3
       and self.world:get(c, r) == physics.EMPTY
       and self.world:get(c, r - 1) == physics.EMPTY then
      return { x = x, y = y }
    end
  end
  return nil
end

function Room:spawnProjectile(spec)
  return self.projectiles:spawn(spec)
end

function Room:spawnPickup(spec)
  return self.pickups:spawn(spec)
end

function Room:respawnPlayer(p)
  p.x, p.y = self.spawnX, self.spawnY
  p.vx, p.vy = 0, 0
  p._rx, p._ry = 0, 0
end

-- Objective / rewards --------------------------------------------------------------

function Room:onCleared()
  self.cleared = true
  self.exitOpen = true
  sfx.play("door")
  local ex = (self.exitTile.c - 0.5) * T
  local ey = (self.exitTile.r + 0.5) * T
  particles.ring(ex, ey, { 1, 0.9, 0.5 }, 30)

  if self.rewardGiven then return end
  self.rewardGiven = true
  local run = self.run
  local rng = run.rng
  local rt = self.roomType
  local cx = self.world.widthPx / 2

  if rt == "combat" then
    local e = config.economy.emberDropCombat
    self.pickups:spawnBurst("ember", cx, self.world.heightPx * 0.5,
      6, math.ceil(rng:random("rewards", e[1], e[2]) / 6))
    self.pickups:spawn({ kind = "sigil", x = ex - 40, y = ey - 24, data = {} })
  elseif rt == "arena" then
    local e = config.economy.emberDropElite
    self.pickups:spawnBurst("ember", cx, self.world.heightPx * 0.5,
      8, math.ceil(rng:random("rewards", e[1], e[2]) / 8))
    local cd = config.economy.cinderDropElite
    self.pickups:spawnBurst("cinder", cx, self.world.heightPx * 0.45,
      3, math.ceil(rng:random("rewards", cd[1], cd[2]) / 3))
    self.pickups:spawn({ kind = "sigil", x = ex - 40, y = ey - 24, data = { epicBias = true } })
  elseif rt == "boss" then
    local cd = config.economy.cinderDropBoss
    self.pickups:spawnBurst("cinder", cx, self.world.heightPx * 0.4,
      6, math.ceil(rng:random("rewards", cd[1], cd[2]) / 6))
    self.pickups:spawn({ kind = "heart", x = cx - 30, y = self.world.heightPx * 0.5, value = 35 })
    self.pickups:spawn({ kind = "sigil", x = ex - 40, y = ey - 24, data = { epicBias = true } })
  end
  signals.emit("roomObjectiveDone", self)
end

-- Update -----------------------------------------------------------------------------

function Room:update(dt)
  self.time = self.time + dt
  self.background:update(dt)

  -- pending telegraphed spawns
  for _, s in ipairs(self.pendingSpawns) do
    s.timer = s.timer - dt
    if love.math.random() < dt * 20 then
      particles.spawn({ x = s.x + (love.math.random() * 20 - 10), y = s.y - love.math.random() * 20,
        life = 0.4, size = 2, sizeEnd = 0, color = self.biome.palette.accent, kind = "dot", gravity = -60 })
    end
    if s.timer <= 0 then
      s.dead = true
      local e = Enemy.new(s.def, self, s.x, s.y, { elite = s.elite, eliteMod = s.eliteMod })
      self.enemies[#self.enemies + 1] = e
      particles.ring(s.x, s.y - 8, self.biome.palette.accent, 18)
    end
  end
  util.sweep(self.pendingSpawns)

  if self.player and not self.player.dead then
    self.player:update(dt)
  end

  for _, e in ipairs(self.enemies) do
    if not e.dead then e:update(dt) end
  end
  -- reap dead enemies AFTER update so death-frame effects resolve
  for _, e in ipairs(self.enemies) do
    if e.dead and not e.reaped then
      e.reaped = true
      self:onEnemyDead(e)
    end
  end
  util.sweep(self.enemies)

  self.projectiles:update(dt)
  self.pickups:update(dt)
  self:updateProps(dt)

  -- objective progression
  if not self.cleared and (self.roomType == "arena"
      or (self.roomType == "boss" and not self.boss)) then
    if self:aliveEnemies() == 0 then
      if not self:nextWave() then
        self:onCleared()
      end
    end
  end
  -- contested paths: clearing every enemy is optional but rewarded
  if not self.cleared and self.roomType == "combat" and self.hadEnemies then
    if self:aliveEnemies() == 0 then
      self:onCleared()
    end
  end
  if self.boss and self.boss.dead and not self.cleared then
    self:onCleared()
  end

  -- exit door
  if self.exitOpen and self.player and not self.player.dead then
    local ex = (self.exitTile.c - 1) * T
    local ey = (self.exitTile.r - 2) * T
    if util.aabb(self.player.x, self.player.y, self.player.w, self.player.h,
        ex, ey, T * 3, T * 3) then
      if self.callbacks.onExit then self.callbacks.onExit(self) end
    end
  end
end

function Room:onEnemyDead(e)
  local run = self.run
  run.kills = run.kills + 1
  save.stat("kills", 1)
  local cx, cy = e:center()
  -- small ember trickle from kills
  if love.math.random() < 0.5 then
    self.pickups:spawnBurst("ember", cx, cy, 1, love.math.random(1, 2))
  end
  if e.elite then
    self.pickups:spawnBurst("cinder", cx, cy, 2, 3)
  end
end

-- Props ---------------------------------------------------------------------------

function Room:updateProps(dt)
  local input = require("src.core.input")
  local p = self.player
  if not p or p.dead then return end
  local px, py = p:center()
  self.nearProp = nil
  for _, prop in ipairs(self.props) do
    if prop.kind ~= "light" then
      local d = util.dist(px, py, prop.x, prop.y - 8)
      if d < 22 then
        local usable =
          (prop.kind == "chest" and not prop.opened)
          or (prop.kind == "altar" and not prop.used)
          or (prop.kind == "fountain" and not prop.used)
          or (prop.kind == "shrine" and not prop.used)
          or (prop.kind == "shopItem" and not prop.sold)
        if usable then
          self.nearProp = prop
          if input.pressed("interact") then
            input.consume("interact")
            self:useProp(prop)
          end
        end
      end
    end
  end
  _ = dt
end

function Room:useProp(prop)
  local run = self.run
  if prop.kind == "chest" then
    prop.opened = true
    sfx.play("pickup", 0.8)
    particles.burst(prop.x, prop.y - 8, { 1, 0.85, 0.4 }, 14, { speed = 110 })
    local roll = love.math.random()
    if roll < 0.55 then
      self.pickups:spawnBurst("ember", prop.x, prop.y - 10, 8, 4)
    elseif roll < 0.8 then
      self.pickups:spawn({ kind = "heart", x = prop.x, y = prop.y - 14, value = 25 })
    else
      self.pickups:spawnBurst("cinder", prop.x, prop.y - 10, 3, 3)
    end
  elseif prop.kind == "altar" then
    prop.used = true
    sfx.play("boon")
    particles.ring(prop.x, prop.y - 10, { 1, 0.85, 0.4 }, 34)
    if self.callbacks.onSigil then self.callbacks.onSigil({}) end
  elseif prop.kind == "fountain" then
    prop.used = true
    sfx.play("heal")
    local amount = math.floor(run:maxHP() * config.run.healFountainAmount)
    self.player:heal(amount)
    particles.ring(prop.x, prop.y - 10, { 0.4, 1, 0.6 }, 30)
  elseif prop.kind == "shrine" then
    prop.used = true
    self:runShrineEvent(prop)
  elseif prop.kind == "shopItem" then
    if run:spendEmbers(prop.price) then
      prop.sold = true
      sfx.play("uiSelect")
      if prop.item == "heal" then
        self.player:heal(40)
      elseif prop.item == "boon" then
        local boonsSys = require("src.game.boons")
        boonsSys.grant(run, prop.offer.def.id, prop.offer.rarity.id)
        particles.ring(prop.x, prop.y - 12, prop.offer.rarity.color, 30)
      end
    else
      sfx.play("uiDeny")
    end
  end
end

-- Shrine events: small gambles, clearly telegraphed by their result text.
-- The "Listening Stones" unlock widens the outcome table.
function Room:runShrineEvent(prop)
  local run = self.run
  local px, py = prop.x, prop.y - 12
  local outcomes = {
    function()
      -- blood price: lose hp, gain a boon
      local cost = math.floor(run:maxHP() * 0.15)
      run.hp = math.max(1, run.hp - cost)
      particles.burst(px, py, { 1, 0.3, 0.35 }, 12, { speed = 90 })
      sfx.play("playerHurt", 0.7)
      if self.callbacks.onSigil then self.callbacks.onSigil({}) end
      prop.resultText = locale.f("ui.room.shrine_blood", cost)
    end,
    function()
      self.pickups:spawnBurst("ember", px, py, 10, 5)
      sfx.play("pickup")
      prop.resultText = locale.t("ui.room.shrine_embers")
    end,
    function()
      self.pickups:spawnBurst("cinder", px, py, 3, 4)
      sfx.play("cinder")
      prop.resultText = locale.t("ui.room.shrine_cinders")
    end,
  }
  if save.isUnlocked("shrine_events") then
    outcomes[#outcomes + 1] = function()
      -- deepening ritual: a random owned boon grows a level
      local boonsSys = require("src.game.boons")
      local candidates = {}
      for _, owned in ipairs(run.boons) do
        local def = boonsSys.def(owned.id)
        if def and owned.level < (def.maxLevel or 3) then candidates[#candidates + 1] = owned end
      end
      if #candidates > 0 then
        local pick = candidates[love.math.random(1, #candidates)]
        boonsSys.grant(run, pick.id, pick.rarity)
        local def = boonsSys.def(pick.id)
        particles.ring(px, py, { 1, 0.85, 0.4 }, 40)
        sfx.play("boon")
        prop.resultText = locale.f("ui.room.shrine_deepen", def and boonsSys.name(def) or "?")
      else
        self.pickups:spawnBurst("ember", px, py, 8, 5)
        prop.resultText = locale.t("ui.room.shrine_deepen_none")
      end
    end
    outcomes[#outcomes + 1] = function()
      -- greed gamble: double or half your embers
      if love.math.random() < 0.5 then
        local gain = math.max(20, run.embers)
        run:addEmbers(gain)
        sfx.play("pickup")
        prop.resultText = locale.f("ui.room.shrine_greed_win", gain)
      else
        local loss = math.floor(run.embers / 2)
        run.embers = run.embers - loss
        sfx.play("uiDeny")
        prop.resultText = locale.f("ui.room.shrine_greed_lose", loss)
      end
    end
    outcomes[#outcomes + 1] = function()
      -- mending covenant: strong heal now, the shrine holds your dash a while
      self.player:heal(math.floor(run:maxHP() * 0.3))
      self.player.dashCd = 6
      sfx.play("heal")
      prop.resultText = locale.t("ui.room.shrine_mend")
    end
  end
  outcomes[love.math.random(1, #outcomes)]()
end

-- Drawing ---------------------------------------------------------------------------

function Room:drawTiles(camera)
  local pal = self.biome.palette
  local vx, vy, vw, vh = camera:visible()
  local c1 = math.max(1, math.floor(vx / T))
  local c2 = math.min(self.world.cols, math.ceil((vx + vw) / T) + 1)
  local r1 = math.max(1, math.floor(vy / T))
  local r2 = math.min(self.world.rows, math.ceil((vy + vh) / T) + 1)

  for r = r1, r2 do
    for c = c1, c2 do
      local t = self.world:get(c, r)
      local x, y = (c - 1) * T, (r - 1) * T
      if t == physics.SOLID then
        love.graphics.setColor(pal.tile)
        love.graphics.rectangle("fill", x, y, T, T)
        if self.world:get(c, r - 1) ~= physics.SOLID then
          love.graphics.setColor(pal.tileTop)
          love.graphics.rectangle("fill", x, y, T, 3)
        end
        if self.world:get(c, r + 1) ~= physics.SOLID then
          love.graphics.setColor(pal.tile[1] * 0.5, pal.tile[2] * 0.5, pal.tile[3] * 0.5)
          love.graphics.rectangle("fill", x, y + T - 2, T, 2)
        end
      elseif t == physics.PLATFORM then
        love.graphics.setColor(pal.platform)
        love.graphics.rectangle("fill", x, y, T, 4)
        love.graphics.setColor(pal.platform[1] * 0.6, pal.platform[2] * 0.6, pal.platform[3] * 0.6)
        love.graphics.rectangle("fill", x + 1, y + 4, T - 2, 2)
      elseif t == physics.SPIKE then
        love.graphics.setColor(pal.spike)
        local up = self.world:get(c, r + 1) == physics.SOLID
        if up then
          love.graphics.polygon("fill", x, y + T, x + T / 2, y + 2, x + T, y + T)
        else
          love.graphics.polygon("fill", x, y, x + T / 2, y + T - 2, x + T, y)
        end
      end
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

function Room:drawDoors()
  local pal = self.biome.palette
  local function door(tileC, tileR, open, isExit)
    local x = (tileC - 1) * T
    local y = (tileR - 3) * T
    local w, h = T, T * 3
    if open then
      local a = 0.4 + math.sin(self.time * 3) * 0.15
      local c = isExit and { 1, 0.9, 0.5 } or pal.accent
      draw.glow(x + w / 2, y + h / 2, 24, c[1], c[2], c[3], a * 0.6)
      love.graphics.setColor(c[1], c[2], c[3], a)
      love.graphics.rectangle("line", x + 2, y + 2, w - 4, h - 4)
    else
      love.graphics.setColor(pal.tileTop)
      love.graphics.rectangle("fill", x + 2, y, w - 4, h)
      love.graphics.setColor(pal.spike[1], pal.spike[2], pal.spike[3], 0.8)
      for i = 0, 2 do
        love.graphics.rectangle("fill", x + 3, y + 6 + i * 14, w - 6, 3)
      end
    end
  end
  -- entry door (always closed behind you)
  door(2, self.spawnTile.r + 1, false, false)
  -- exit door
  door(self.exitTile.c + 1, self.exitTile.r + 1, self.exitOpen, true)
end

function Room:drawProps()
  local pal = self.biome.palette
  for _, prop in ipairs(self.props) do
    local x, y = prop.x, prop.y
    if prop.kind == "light" then
      local lc = pal.light
      local flick = 0.4 + 0.12 * math.sin(self.time * 5 + x)
      draw.glow(x, y, 34, lc[1], lc[2], lc[3], flick)
      love.graphics.setColor(1, 1, 0.9, 0.9)
      love.graphics.circle("fill", x, y, 1.8)
    elseif prop.kind == "chest" then
      local col = prop.opened and { 0.4, 0.35, 0.3 } or { 0.85, 0.65, 0.3 }
      if not prop.opened then draw.glow(x, y - 6, 20, 1, 0.8, 0.3, 0.35) end
      love.graphics.setColor(col)
      love.graphics.rectangle("fill", x - 7, y - 10, 14, 10, 2, 2)
      love.graphics.setColor(col[1] * 0.6, col[2] * 0.6, col[3] * 0.6)
      love.graphics.rectangle("fill", x - 7, y - 6, 14, 2)
    elseif prop.kind == "altar" then
      local used = prop.used
      local c = used and { 0.4, 0.4, 0.45 } or { 1, 0.85, 0.4 }
      if not used then draw.glow(x, y - 14, 30, c[1], c[2], c[3], 0.5 + math.sin(self.time * 2) * 0.15) end
      love.graphics.setColor(0.35, 0.32, 0.4)
      love.graphics.rectangle("fill", x - 6, y - 8, 12, 8)
      love.graphics.setColor(c)
      draw.diamond(used and "line" or "fill", x, y - 15, 5)
    elseif prop.kind == "fountain" then
      local used = prop.used
      local c = used and { 0.4, 0.45, 0.42 } or { 0.4, 1, 0.6 }
      love.graphics.setColor(0.35, 0.38, 0.4)
      love.graphics.rectangle("fill", x - 8, y - 6, 16, 6)
      if not used then
        draw.glow(x, y - 10, 26, c[1], c[2], c[3], 0.45)
        love.graphics.setColor(c[1], c[2], c[3], 0.8)
        love.graphics.ellipse("fill", x, y - 7, 6, 2.4)
        if love.math.random() < 0.1 then
          particles.spawn({ x = x + love.math.random(-5, 5), y = y - 8, vy = -20,
            life = 0.6, size = 1.2, sizeEnd = 0, color = c, kind = "dot", gravity = -20 })
        end
      end
    elseif prop.kind == "shrine" then
      local used = prop.used
      local c = used and { 0.4, 0.38, 0.45 } or { 0.8, 0.55, 1 }
      if not used then draw.glow(x, y - 14, 30, c[1], c[2], c[3], 0.45 + math.sin(self.time * 1.7) * 0.14) end
      love.graphics.setColor(0.3, 0.28, 0.36)
      draw.ngon("fill", x, y - 8, 8, 5, -math.pi / 2)
      love.graphics.setColor(c)
      draw.ngon(used and "line" or "fill", x, y - 12, 4, 5, self.time)
    elseif prop.kind == "shopItem" then
      love.graphics.setColor(0.35, 0.32, 0.4)
      love.graphics.rectangle("fill", x - 6, y - 5, 12, 5)
      if not prop.sold then
        local c = prop.item == "heal" and { 1, 0.4, 0.5 } or (prop.offer and prop.offer.rarity.color) or { 1, 1, 1 }
        draw.glow(x, y - 12, 20, c[1], c[2], c[3], 0.45)
        love.graphics.setColor(c)
        draw.diamond("fill", x, y - 12, 4.5)
        draw.textCentered(prop.price .. "", x, y - 30, 9, { 1, 0.75, 0.35, 0.95 })
      end
    end
  end
  love.graphics.setColor(1, 1, 1, 1)

  -- interact hint
  if self.nearProp then
    local prop = self.nearProp
    local label
    if prop.kind == "chest" then label = locale.t("ui.room.open")
    elseif prop.kind == "altar" then label = locale.t("ui.room.commune")
    elseif prop.kind == "fountain" then label = locale.t("ui.room.drink")
    elseif prop.kind == "shrine" then label = locale.t("ui.room.offer")
    elseif prop.kind == "shopItem" then
      local boonsSys = require("src.game.boons")
      local name = prop.labelKey and locale.t(prop.labelKey)
        or (prop.offer and boonsSys.name(prop.offer.def)) or "?"
      label = locale.f("ui.room.buy", name, prop.price)
    end
    if label then
      draw.textCentered("[E] " .. label, prop.x, prop.y - 44, 10, { 1, 1, 1, 0.85 })
    end
  end
end

-- First-room onboarding: floating key hints over the spawn area, using the
-- player's LIVE bindings (remaps show up here).
function Room:drawHints()
  local input = require("src.core.input")
  local hints = {
    { key = input.bindingLabel("left"):match("^[^/]+"):gsub("%s+$", "") .. "/"
        .. input.bindingLabel("right"):match("^[^/]+"):gsub("%s+$", ""),
      label = locale.t("ui.room.hint_move"), x = 90 },
    { key = input.bindingLabel("jump"):match("^[^/]+"):gsub("%s+$", ""),
      label = locale.t("ui.room.hint_jump"), x = 210 },
    { key = input.bindingLabel("dash"):match("^[^/]+"):gsub("%s+$", ""),
      label = locale.t("ui.room.hint_dash"), x = 330 },
    { key = input.bindingLabel("attack"):match("^[^/]+"):gsub("%s+$", ""),
      label = locale.t("ui.room.hint_attack"), x = 430 },
  }
  local y = self.spawnY - 40
  for _, h in ipairs(hints) do
    local a = 0.5 + math.sin(self.time * 2) * 0.12
    draw.textCentered("[" .. h.key:upper() .. "]", h.x, y, 9, { 1, 0.85, 0.6, a })
    draw.textCentered(h.label, h.x, y + 12, 8, { 1, 1, 1, a * 0.85 })
  end
end

function Room:draw(camera)
  self.background:draw(camera)
  self:drawTiles(camera)
  self:drawDoors()
  self:drawProps()
  if self.roomType == "entry" and self.run.biomeIndex == 1 and self.depth == 0 then
    self:drawHints()
  end
  self.pickups:draw()
  for _, e in ipairs(self.enemies) do
    if not e.dead then e:draw() end
  end
  if self.player and not self.player.dead then
    self.player:draw()
  end
  self.projectiles:draw()
  particles.draw()
end

function Room:destroy()
  particles.clear()
end

return Room
