-- Enemy engine. An enemy is a def (data) + a behavior (small state machine
-- picked by name). New enemy types are pure content: a def in
-- src/content/enemies/ referencing one of these behaviors with params.
local config = require("src.core.config")
local util = require("src.core.util")
local physics = require("src.game.physics")
local signals = require("src.core.signals")
local particles = require("src.render.particles")
local juice = require("src.render.juice")
local draw = require("src.render.draw")
local sfx = require("src.audio.sfx")

local Enemy = {}
Enemy.__index = Enemy

-- Depth scaling: enemies get tougher deeper into the run (this is world
-- scaling, not player power -- the player's power comes only from boons).
local function depthScale(depth)
  return math.min(1 + (depth or 0) * 0.16, 4.2)
end

function Enemy.new(def, room, x, y, opts)
  opts = opts or {}
  local self = setmetatable({}, Enemy)
  self.def = def
  self.room = room
  self.w = def.w or 14
  self.h = def.h or 14
  self.x = x - self.w / 2
  self.y = y - self.h
  self.vx, self.vy = 0, 0
  self.facing = love.math.random() < 0.5 and -1 or 1

  local depth = room.depth or 0
  local scale = depthScale(depth)
  self.maxHP = (def.hp or 30) * scale * (opts.elite and 2.6 or 1)
  self.hp = self.maxHP
  self.damage = (def.damage or 10) * math.min(1 + depth * 0.06, 2.4) * (opts.elite and 1.5 or 1)
  self.elite = opts.elite or false
  self.eliteMod = opts.eliteMod -- volatile | regenerating | vampiric | stormtouched
  self.speed = (def.speed or 40) * (opts.elite and 1.2 or 1)
  self.stormTimer = 2

  self.state = "idle"
  self.stateTime = 0
  self.timer = love.math.random() * 1.2
  self.hitFlash = 0
  self.dead = false
  self.status = {}   -- burn/chill/shock/doom/weaken
  self.anim = love.math.random() * 10
  self.homeX, self.homeY = self.x, self.y
  self.noGravity = def.flying or false
  self.telegraph = 0
  require("src.core.save").markSeen((def.phases and "boss:" or "enemy:") .. def.id)
  return self
end

function Enemy:center()
  return self.x + self.w / 2, self.y + self.h / 2
end

function Enemy:playerDist()
  local p = self.room.player
  if not p or p.dead then return math.huge, 0, 0 end
  local cx, cy = self:center()
  local px, py = p:center()
  return util.dist(cx, cy, px, py), px - cx, py - cy
end

function Enemy:canSeePlayer()
  local p = self.room.player
  if not p or p.dead then return false end
  local cx, cy = self:center()
  local px, py = p:center()
  local hit = physics.raycast(self.room.world, cx, cy, px - cx, py - cy,
    util.dist(cx, cy, px, py))
  return hit == nil
end

-- Status effects ---------------------------------------------------------------

function Enemy:applyStatus(kind, data)
  -- Slow Roast etc: player-side modifiers on status durations
  if kind == "burn" then
    local run = self.room.run
    if run and run.custom.burnTimeMult then
      data.time = (data.time or 3) * run.custom.burnTimeMult
    end
  end
  local s = self.status[kind]
  if s then
    -- refresh & stack modestly (capped: no infinite stacking)
    s.time = math.max(s.time, data.time or 3)
    s.power = math.min((s.power or 1) + (data.power or 1) * 0.5, (data.maxPower or 4))
    s.source = data.source or s.source
  else
    self.status[kind] = {
      time = data.time or 3,
      power = data.power or 1,
      tick = 0,
      source = data.source,
    }
  end
  signals.emit("statusApplied", self, kind, self.status[kind])
end

local statusColor = {
  burn = { 1, 0.5, 0.15 },
  chill = { 0.5, 0.8, 1 },
  shock = { 1, 0.95, 0.4 },
  doom = { 0.75, 0.4, 1 },
  weaken = { 0.6, 1, 0.6 },
}

function Enemy:updateStatus(dt)
  for kind, s in pairs(self.status) do
    s.time = s.time - dt
    if kind == "burn" then
      s.tick = s.tick + dt
      if s.tick >= 0.5 then
        s.tick = s.tick - 0.5
        self:takeDamage(2.4 * s.power, nil, s.source, { status = "burn", noKnockback = true, noHitstop = true })
        local cx, cy = self:center()
        particles.ember(cx + love.math.random() * self.w - self.w / 2, cy, statusColor.burn)
      end
    elseif kind == "doom" then
      if s.time <= 0 then
        self:takeDamage(26 * s.power, nil, s.source, { status = "doom", noHitstop = true })
        particles.burst(self:center(), select(2, self:center()), statusColor.doom, 10, { speed = 80 })
      end
    end
    if s.time <= 0 then self.status[kind] = nil end
  end
end

function Enemy:statusSpeedMult()
  if self.status.chill then
    return math.max(0.35, 1 - 0.25 * self.status.chill.power)
  end
  return 1
end

-- Damage -------------------------------------------------------------------------

function Enemy:takeDamage(amount, angle, source, meta)
  if self.dead then return end
  meta = meta or {}
  if self.status.weaken then
    amount = amount * (1 + 0.15 * self.status.weaken.power)
  end
  -- armored front: shellback-style defense
  if self.def.armoredFront and meta.melee and not meta.finisher then
    local px = source and source.x or self.x
    local hitFromFront = util.sign(px - self.x) == -self.facing or util.sign(px - self.x) == 0
    if util.sign(px - self.x) == -self.facing then hitFromFront = false end
    hitFromFront = (util.sign((source and source.x or self.x) - self.x) == self.facing)
    if hitFromFront then
      amount = amount * 0.25
      particles.burst(self:center(), select(2, self:center()), { 0.8, 0.8, 0.85 }, 4, { speed = 60, kind = "spark" })
      sfx.play("swing", 0.6)
    end
  end

  self.hp = self.hp - amount
  self.hitFlash = 0.12

  local cx, cy = self:center()
  local col = meta.crit and { 1, 0.9, 0.3 } or { 1, 1, 1 }
  particles.textPop(cx + love.math.random(-4, 4), cy - self.h / 2 - 4,
    tostring(math.floor(amount + 0.5)), col, meta.crit and 11 or 8)
  particles.burst(cx, cy, self.def.color or { 1, 0.4, 0.4 }, meta.crit and 8 or 4,
    { speed = 90, kind = "shard" })

  if not meta.noKnockback and not self.def.immovable then
    local kb = (self.def.knockbackMult or 1) * (meta.melee and 130 or 60)
    if angle then
      self.vx = self.vx + math.cos(angle) * kb
      if not self.noGravity then self.vy = self.vy - 40
      else self.vy = self.vy + math.sin(angle) * kb end
    end
  end

  signals.emit("enemyDamaged", self, amount, meta, source)

  if self.hp <= 0 then
    self:die(source, meta)
  end
end

function Enemy:die(source, meta)
  if self.dead then return end
  self.dead = true
  local cx, cy = self:center()
  local col = self.def.color or { 1, 0.5, 0.3 }
  meta = meta or {}

  if not meta.cleanup then
    -- splitters: death spawns children
    if self.def.splitsInto then
      local registry = require("src.game.registry")
      local childDef = registry.get("enemy", self.def.splitsInto.id)
      if childDef then
        for i = 1, self.def.splitsInto.count do
          self.room.pendingSpawns[#self.room.pendingSpawns + 1] = {
            def = childDef, x = cx + (i - 1.5) * 18, y = self.y + self.h, timer = 0.4,
          }
        end
      end
    end
    -- volatile elites: dying burst of slow orbs, well telegraphed by the ring
    if self.eliteMod == "volatile" then
      particles.ring(cx, cy, { 1, 0.6, 0.2 }, 50)
      for i = 0, 5 do
        local a = i / 6 * math.pi * 2
        self.room:spawnProjectile({
          x = cx, y = cy, vx = math.cos(a) * 90, vy = math.sin(a) * 90,
          damage = self.damage * 0.8, friendly = false,
          color = { 1, 0.55, 0.2 }, kind = "orb", r = 3.5, life = 1.6,
        })
      end
      sfx.play("explosion", 1.1, 0.7)
    end
  end
  particles.burst(cx, cy, col, self.elite and 22 or 12, { speed = 130, glow = 8 })
  particles.ring(cx, cy, col, self.elite and 34 or 22)
  juice.hitstop(self.elite and config.juice.hitstopHeavy or 0.05)
  juice.shake(self.elite and 4 or 2, 0.2)
  sfx.play("kill", self.elite and 0.8 or 1)
  signals.emit("enemyKilled", self, source, meta or {})
end

-- Behaviors ------------------------------------------------------------------------

local behaviors = {}

-- Shared gravity/motion for grounded enemies.
local function groundMove(self, dt)
  self.vy = math.min(self.vy + 1300 * dt, 440)
  physics.move(self.room.world, self, dt, {})
end

local function airMove(self, dt)
  physics.move(self.room.world, self, dt, {})
end

behaviors.walker = function(self, dt)
  local p = self.def
  local dist, dx = self:playerDist()
  local sp = self.speed * self:statusSpeedMult()
  if dist < (p.aggroRange or 150) and self:canSeePlayer() then
    self.facing = util.sign(dx) ~= 0 and util.sign(dx) or self.facing
    self.vx = util.approach(self.vx, self.facing * sp * 1.5, 400 * dt)
    -- hop at the player when close
    if p.hops and self.onGround and dist < (p.hopRange or 60) then
      self.timer = self.timer - dt
      if self.timer <= 0 then
        self.vy = -(p.hopVel or 260)
        self.vx = self.facing * sp * 2.2
        self.timer = (p.hopCooldown or 1.4) * (0.8 + love.math.random() * 0.4)
      end
    end
  else
    -- patrol: turn at walls/ledges
    self.vx = util.approach(self.vx, self.facing * sp, 300 * dt)
    if self.onGround then
      local aheadX = self.facing > 0 and (self.x + self.w + 2) or (self.x - 2)
      local c = math.floor(aheadX / physics.TILE) + 1
      local r = math.floor((self.y + self.h + 2) / physics.TILE) + 1
      if self.room.world:get(c, r) == physics.EMPTY or self.hitWall then
        self.facing = -self.facing
      end
    end
  end
  groundMove(self, dt)
  if self.hitWall then self.facing = -self.facing end
end

behaviors.flyer = function(self, dt)
  local p = self.def
  local dist, dx, dy = self:playerDist()
  self.anim = self.anim + dt
  local sp = self.speed * self:statusSpeedMult()

  if self.state == "dive" then
    self.stateTime = self.stateTime - dt
    airMove(self, dt)
    if self.stateTime <= 0 or self.hitWall or self.onGround or self.hitCeiling then
      self.state = "idle"
      self.timer = (p.diveCooldown or 2.2) * (0.7 + love.math.random() * 0.6)
    end
    return
  end

  -- hover: bob around home, drift toward player when in range
  local tx, ty
  if dist < (p.aggroRange or 190) and self:canSeePlayer() then
    local px, py = self.room.player:center()
    tx = px + math.sin(self.anim * 1.3) * 40
    ty = py - (p.hoverHeight or 52) + math.sin(self.anim * 2.1) * 10
    self.timer = self.timer - dt
    if p.dives and self.timer <= 0 and math.abs(dx) < 90 and dy > 20 then
      self.state = "dive"
      self.stateTime = 0.55
      local a = util.angle(0, 0, dx, dy)
      self.vx = math.cos(a) * sp * 3.2
      self.vy = math.sin(a) * sp * 3.2
      sfx.play("swing", 0.7)
      return
    end
  else
    tx = self.homeX + math.sin(self.anim * 0.8) * 34
    ty = self.homeY + math.sin(self.anim * 1.7) * 14
  end
  self.vx = util.damp(self.vx, util.clamp((tx - self.x) * 3, -sp, sp), 6, dt)
  self.vy = util.damp(self.vy, util.clamp((ty - self.y) * 3, -sp, sp), 6, dt)
  self.facing = util.sign(dx) ~= 0 and util.sign(dx) or self.facing
  airMove(self, dt)
end

behaviors.turret = function(self, dt)
  local p = self.def
  local dist = self:playerDist()
  self.timer = self.timer - dt
  self.telegraph = math.max(0, self.telegraph - dt)
  if dist < (p.aggroRange or 220) and self:canSeePlayer() then
    if self.timer <= 0 then
      if self.telegraph <= 0 then
        self.telegraph = p.telegraphTime or 0.5
      end
    end
    if self.telegraph > 0 and self.telegraph <= dt * 2 and self.timer <= 0 then
      -- fire
      local cx, cy = self:center()
      local px, py = self.room.player:center()
      if p.lob then
        local t = 0.9
        local vx = (px - cx) / t
        local vy = (py - cy) / t - 0.5 * 700 * t
        self.room:spawnProjectile({
          x = cx, y = cy - 4, vx = vx, vy = util.clamp(vy, -420, 100),
          gravity = 700, damage = self.damage, friendly = false,
          color = p.projectileColor or { 1, 0.5, 0.2 }, kind = "blob", r = 4,
        })
      else
        local a = util.angle(cx, cy, px, py)
        self.room:spawnProjectile({
          x = cx, y = cy, vx = math.cos(a) * (p.projectileSpeed or 150),
          vy = math.sin(a) * (p.projectileSpeed or 150),
          damage = self.damage, friendly = false,
          color = p.projectileColor or { 1, 0.5, 0.2 }, kind = "orb", r = 3.5,
        })
      end
      sfx.play("enemyShoot")
      self.timer = (p.shootCooldown or 2) * (0.8 + love.math.random() * 0.4)
    end
  end
  if not self.def.flying then groundMove(self, dt) end
end

behaviors.floater = function(self, dt)
  -- ghost: drifts straight at the player, slow but relentless
  local dist, dx, dy = self:playerDist()
  local sp = self.speed * self:statusSpeedMult()
  self.anim = self.anim + dt
  if dist < (self.def.aggroRange or 240) then
    local a = util.angle(0, 0, dx, dy)
    self.vx = util.damp(self.vx, math.cos(a) * sp, 3, dt)
    self.vy = util.damp(self.vy, math.sin(a) * sp, 3, dt)
  else
    self.vx = util.damp(self.vx, math.sin(self.anim) * 10, 2, dt)
    self.vy = util.damp(self.vy, math.cos(self.anim * 0.7) * 10, 2, dt)
  end
  self.facing = util.sign(dx) ~= 0 and util.sign(dx) or self.facing
  -- phases through terrain: no collision, but stay in room bounds
  self.x = util.clamp(self.x + self.vx * dt, 8, self.room.world.widthPx - 8 - self.w)
  self.y = util.clamp(self.y + self.vy * dt, 8, self.room.world.heightPx - 8 - self.h)
end

behaviors.orbiter = function(self, dt)
  -- circles a point; radial burst when player is near
  local p = self.def
  self.anim = self.anim + dt * (p.orbitSpeed or 1.2)
  local r = p.orbitRadius or 30
  local tx = self.homeX + math.cos(self.anim) * r
  local ty = self.homeY + math.sin(self.anim) * r * 0.6
  self.vx = (tx - self.x) * 6
  self.vy = (ty - self.y) * 6
  self.x = self.x + self.vx * dt
  self.y = self.y + self.vy * dt

  local dist = self:playerDist()
  self.timer = self.timer - dt
  if dist < (p.aggroRange or 170) and self.timer <= 0 and self:canSeePlayer() then
    local cx, cy = self:center()
    local nShots = p.burstCount or 6
    for i = 0, nShots - 1 do
      local a = i / nShots * math.pi * 2 + self.anim
      self.room:spawnProjectile({
        x = cx, y = cy, vx = math.cos(a) * (p.projectileSpeed or 110),
        vy = math.sin(a) * (p.projectileSpeed or 110),
        damage = self.damage, friendly = false,
        color = p.projectileColor or { 0.5, 1, 0.8 }, kind = "orb", r = 3,
      })
    end
    sfx.play("enemyShoot", 0.8)
    self.timer = (p.shootCooldown or 2.6) * (0.8 + love.math.random() * 0.4)
  end
end

behaviors.charger = function(self, dt)
  local p = self.def
  local dist, dx = self:playerDist()
  local sp = self.speed * self:statusSpeedMult()

  if self.state == "windup" then
    self.stateTime = self.stateTime - dt
    self.vx = util.approach(self.vx, 0, 600 * dt)
    if self.stateTime <= 0 then
      self.state = "charge"
      self.stateTime = p.chargeTime or 0.8
      sfx.play("swing", 0.5)
    end
  elseif self.state == "charge" then
    self.stateTime = self.stateTime - dt
    self.vx = self.facing * sp * (p.chargeMult or 4)
    if self.hitWall then
      juice.shake(2.5, 0.2)
      particles.dust(self.x + (self.facing > 0 and self.w or 0), self.y + self.h, -self.facing, 6)
      self.state = "stunned"
      self.stateTime = p.stunTime or 0.8
      self.vx = -self.facing * 60
    elseif self.stateTime <= 0 then
      self.state = "idle"
      self.timer = p.chargeCooldown or 2
    end
  elseif self.state == "stunned" then
    self.stateTime = self.stateTime - dt
    self.vx = util.approach(self.vx, 0, 300 * dt)
    if self.stateTime <= 0 then self.state = "idle" end
  else
    self.timer = self.timer - dt
    if dist < (p.aggroRange or 170) and self.timer <= 0 and self:canSeePlayer() and math.abs(dx) > 30 then
      self.facing = util.sign(dx)
      self.state = "windup"
      self.stateTime = p.windupTime or 0.45
      self.telegraph = self.stateTime
    else
      -- amble
      self.vx = util.approach(self.vx, self.facing * sp * 0.5, 200 * dt)
      if self.hitWall and self.onGround then self.facing = -self.facing end
    end
  end
  groundMove(self, dt)
end

behaviors.caster = function(self, dt)
  -- teleports around, fires a homing orb
  local p = self.def
  local dist = self:playerDist()
  self.anim = self.anim + dt
  self.timer = self.timer - dt
  self.vy = 0 self.vx = 0
  if dist < (p.aggroRange or 260) then
    if self.timer <= 0 then
      if self.state ~= "cast" then
        self.state = "cast"
        self.stateTime = p.castTime or 0.7
        self.telegraph = self.stateTime
      end
    end
    if self.state == "cast" then
      self.stateTime = self.stateTime - dt
      if self.stateTime <= 0 then
        local cx, cy = self:center()
        self.room:spawnProjectile({
          x = cx, y = cy, vx = 0, vy = -60,
          damage = self.damage, friendly = false, homing = self.room.player,
          homingStrength = 2.2, life = 4,
          color = p.projectileColor or { 0.8, 0.5, 1 }, kind = "orb", r = 4, trail = true,
        })
        sfx.play("enemyShoot", 1.2)
        self.state = "idle"
        self.timer = p.shootCooldown or 3
        -- blink to a new perch
        local spot = self.room:randomAirSpot(self.x, self.y, 120)
        if spot then
          local cx2, cy2 = self:center()
          particles.burst(cx2, cy2, p.color, 8, { speed = 60, gravity = 0 })
          self.x, self.y = spot.x - self.w / 2, spot.y - self.h / 2
          particles.burst(spot.x, spot.y, p.color, 8, { speed = 60, gravity = 0 })
        end
      end
    end
  end
end

Enemy.behaviors = behaviors

-- Update/draw ------------------------------------------------------------------------

function Enemy:update(dt)
  if self.dead then return end
  self.hitFlash = math.max(0, self.hitFlash - dt)
  self:updateStatus(dt)

  -- elite modifiers
  if self.eliteMod == "regenerating" and self.hp < self.maxHP then
    self.hp = math.min(self.maxHP, self.hp + self.maxHP * 0.025 * dt)
  elseif self.eliteMod == "stormtouched" then
    self.stormTimer = self.stormTimer - dt
    if self.stormTimer <= 0 then
      self.stormTimer = 3.2
      local p = self.room.player
      if p and not p.dead then
        local cx, cy = self:center()
        local px, py = p:center()
        local a = util.angle(cx, cy, px, py)
        self.room:spawnProjectile({
          x = cx, y = cy, vx = math.cos(a) * 140, vy = math.sin(a) * 140,
          damage = self.damage * 0.6, friendly = false,
          color = { 1, 0.95, 0.5 }, kind = "orb", r = 3, life = 3,
        })
        sfx.play("zap", 0.8, 0.5)
      end
    end
  end

  local b = behaviors[self.def.behavior or "walker"]
  if b then b(self, dt) end

  -- contact damage
  local p = self.room.player
  if p and not p.dead and not self.def.noContactDamage then
    if util.aabb(self.x, self.y, self.w, self.h, p.x, p.y, p.w, p.h) then
      local before = p.invuln
      p:hurt(self.damage, self:center())
      -- leeches and vampiric elites feed on landed hits
      if p.invuln > before then
        local gain = (self.def.healsOnHit or 0) + (self.eliteMod == "vampiric" and self.maxHP * 0.1 or 0)
        if gain > 0 then
          self.hp = math.min(self.maxHP, self.hp + gain)
          particles.burst(self:center(), select(2, self:center()), { 0.9, 0.3, 0.5 }, 5,
            { speed = 40, gravity = -60 })
        end
      end
    end
  end
end

function Enemy:draw()
  local def = self.def
  local col = def.color or { 0.9, 0.4, 0.4 }
  local cx, cy = self:center()
  local t = love.timer.getTime()

  if self.elite then
    draw.glow(cx, cy, self.w * 2.4, 1, 0.85, 0.3, 0.5)
  end
  if def.glow then
    draw.glow(cx, cy, def.glow, col[1], col[2], col[3], 0.4)
  end

  -- telegraph flash: about to attack
  local flash = self.hitFlash > 0
  local tele = self.telegraph and self.telegraph > 0 and math.floor(t * 14) % 2 == 0
  if flash then love.graphics.setColor(1, 1, 1, 1)
  elseif tele then love.graphics.setColor(1, 0.8, 0.6, 1)
  else love.graphics.setColor(col) end

  local shape = def.shape or "blob"
  local bob = def.flying and math.sin(self.anim * 3 + self.x) * 2 or 0
  local y = self.y + bob

  if shape == "blob" then
    love.graphics.ellipse("fill", cx, y + self.h * 0.62, self.w * 0.55, self.h * 0.45)
    love.graphics.ellipse("fill", cx, y + self.h * 0.3, self.w * 0.4, self.h * 0.32)
  elseif shape == "spikeball" then
    draw.ngon("fill", cx, y + self.h / 2, self.w * 0.52, 5, t * 2)
    love.graphics.setColor(col[1] * 0.6, col[2] * 0.6, col[3] * 0.6)
    draw.ngon("fill", cx, y + self.h / 2, self.w * 0.3, 5, -t * 2)
  elseif shape == "wisp" then
    draw.glow(cx, y + self.h / 2, self.w * 1.6, col[1], col[2], col[3], 0.55)
    love.graphics.circle("fill", cx, y + self.h / 2, self.w * 0.34)
    for i = 1, 3 do
      local a = t * 2.4 + i * math.pi * 2 / 3
      love.graphics.circle("fill", cx + math.cos(a) * self.w * 0.55,
        y + self.h / 2 + math.sin(a) * self.w * 0.4, self.w * 0.12)
    end
  elseif shape == "totem" then
    draw.shadedRect(self.x + 1, y, self.w - 2, self.h, col)
    love.graphics.setColor(1, 1, 0.7, 0.9)
    love.graphics.circle("fill", cx, y + 5, 2.2)
  elseif shape == "shell" then
    love.graphics.arc("fill", cx, y + self.h, self.w * 0.62, math.pi, math.pi * 2)
    love.graphics.setColor(col[1] * 0.55, col[2] * 0.55, col[3] * 0.55)
    love.graphics.arc("fill", cx, y + self.h, self.w * 0.4, math.pi, math.pi * 2)
  elseif shape == "husk" then
    draw.shadedRect(self.x, y + 2, self.w, self.h - 2, col)
    love.graphics.polygon("fill", self.x, y + 2, cx, y - 4, self.x + self.w, y + 2)
  elseif shape == "shade" then
    local wob = math.sin(t * 3 + self.x) * 1.5
    love.graphics.polygon("fill",
      cx, y - 2 + wob,
      self.x + self.w + 1, y + self.h * 0.5,
      cx + math.sin(t * 5) * 3, y + self.h + 2,
      self.x - 1, y + self.h * 0.5)
  elseif shape == "dervish" then
    draw.diamond("fill", cx, y + self.h / 2, self.w * 0.6)
    love.graphics.setColor(1, 1, 1, 0.5)
    draw.diamond("line", cx, y + self.h / 2, self.w * (0.7 + math.sin(t * 8) * 0.12))
  end

  -- eyes
  if not def.noEyes then
    local eyeCol = def.eyeColor or { 1, 0.95, 0.8 }
    if flash then eyeCol = { 0.1, 0.1, 0.1 } end
    love.graphics.setColor(eyeCol)
    local ex = cx + self.facing * self.w * 0.16
    love.graphics.rectangle("fill", ex - 2.2, y + self.h * 0.3, 1.8, 2.2)
    love.graphics.rectangle("fill", ex + 0.8, y + self.h * 0.3, 1.8, 2.2)
  end

  -- status pips
  local sx = cx - 8
  for kind in pairs(self.status) do
    local c = statusColor[kind] or { 1, 1, 1 }
    love.graphics.setColor(c[1], c[2], c[3], 0.9)
    love.graphics.circle("fill", sx, y - 5, 1.8)
    sx = sx + 5
  end

  -- elite crown
  if self.elite then
    love.graphics.setColor(1, 0.85, 0.3, 1)
    love.graphics.polygon("fill", cx - 5, y - 7, cx - 2, y - 11, cx, y - 7.5,
      cx + 2, y - 11, cx + 5, y - 7)
  end

  -- hp bar when damaged
  if self.hp < self.maxHP then
    local w = math.max(self.w, 16)
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", cx - w / 2, y - 4, w, 2)
    love.graphics.setColor(1, 0.35, 0.35, 0.95)
    love.graphics.rectangle("fill", cx - w / 2, y - 4, w * math.max(0, self.hp / self.maxHP), 2)
  end

  love.graphics.setColor(1, 1, 1, 1)
end

return Enemy
