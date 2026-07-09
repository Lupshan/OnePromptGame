-- Boss engine. A boss def supplies attack patterns as coroutine functions
-- over a helper API (waits, radial bursts, charges, summons); the engine
-- handles hp/phases/intro/status like any enemy (it reuses Enemy for the
-- damage pipeline) plus pattern scheduling. Bosses are content files.
local util = require("src.core.util")
local physics = require("src.game.physics")
local Enemy = require("src.game.enemy")
local particles = require("src.render.particles")
local juice = require("src.render.juice")
local draw = require("src.render.draw")
local sfx = require("src.audio.sfx")
local signals = require("src.core.signals")

local Boss = setmetatable({}, { __index = Enemy })
Boss.__index = Boss

function Boss.new(def, room, x, y)
  local self = Enemy.new(def, room, x, y)
  setmetatable(self, Boss)
  self.isBoss = true
  self.maxHP = def.hp * (1 + (room.depth or 0) * 0.05)
  self.hp = self.maxHP
  self.phase = 1
  self.pattern = nil       -- active coroutine
  self.patternIdx = 0
  self.restTimer = 1.4     -- pause between patterns
  self.intro = 2.2         -- invulnerable banner time
  self.introDone = false
  self.noGravity = def.flying or false
  self.stagger = 0
  return self
end

-- Pattern helper API (passed to content coroutines) ---------------------------

local function makeAPI(boss)
  local room = boss.room
  local api = { boss = boss, room = room }

  function api.wait(t)
    while t > 0 do
      local dt = coroutine.yield()
      t = t - dt
    end
  end

  function api.playerPos()
    if room.player then return room.player:center() end
    return room.world.widthPx / 2, room.world.heightPx / 2
  end

  function api.telegraph(t)
    boss.telegraph = t
    api.wait(t)
    boss.telegraph = 0
  end

  function api.radial(n, speed, opts)
    opts = opts or {}
    local cx, cy = boss:center()
    for i = 0, n - 1 do
      local a = (opts.angleOffset or 0) + i / n * math.pi * 2
      room:spawnProjectile({
        x = cx, y = cy, vx = math.cos(a) * speed, vy = math.sin(a) * speed,
        damage = boss.damage * (opts.damageMult or 0.8), friendly = false,
        color = opts.color or boss.def.projectileColor or { 1, 0.5, 0.2 },
        kind = "orb", r = opts.r or 4, life = opts.life or 4,
      })
    end
    sfx.play("enemyShoot", 0.7)
  end

  function api.aimed(speed, opts)
    opts = opts or {}
    local cx, cy = boss:center()
    local px, py = api.playerPos()
    local a = util.angle(cx, cy, px, py) + (opts.spread or 0)
    room:spawnProjectile({
      x = cx, y = cy, vx = math.cos(a) * speed, vy = math.sin(a) * speed,
      damage = boss.damage * (opts.damageMult or 1), friendly = false,
      color = opts.color or boss.def.projectileColor or { 1, 0.5, 0.2 },
      kind = opts.kind or "orb", r = opts.r or 4,
      homing = opts.homing and room.player or nil,
      homingStrength = opts.homingStrength, life = opts.life or 4,
      gravity = opts.gravity, trail = opts.trail,
    })
    sfx.play("enemyShoot")
  end

  -- horizontal charge across the arena toward the player
  function api.charge(speed, opts)
    opts = opts or {}
    local px = api.playerPos()
    local cx = boss:center()
    local dir = util.sign(px - cx)
    if dir == 0 then dir = boss.facing end
    boss.facing = dir
    local t = 0
    while t < (opts.maxTime or 2.2) do
      local dt = coroutine.yield()
      t = t + dt
      boss.vx = dir * speed
      if boss.hitWall then
        juice.shake(5, 0.3)
        sfx.play("explosion", 0.7)
        particles.dust(boss.x + (dir > 0 and boss.w or 0), boss.y + boss.h, -dir, 12)
        boss.vx = -dir * 60
        break
      end
    end
    boss.vx = 0
  end

  function api.leapTo(tx, ty, time)
    local sx, sy = boss.x, boss.y
    local t = 0
    time = time or 0.7
    while t < time do
      local dt = coroutine.yield()
      t = t + dt
      local k = math.min(1, t / time)
      local arc = math.sin(k * math.pi) * 60
      boss.x = util.lerp(sx, tx, k)
      boss.y = util.lerp(sy, ty, k) - arc
    end
    juice.shake(4, 0.25)
    particles.dust(boss.x + boss.w / 2, boss.y + boss.h, 0, 10)
    sfx.play("land", 0.5)
  end

  function api.moveTo(tx, ty, speed)
    while true do
      local dt = coroutine.yield()
      local cx, cy = boss:center()
      local d = util.dist(cx, cy, tx, ty)
      if d < 8 then break end
      local a = util.angle(cx, cy, tx, ty)
      boss.x = boss.x + math.cos(a) * speed * dt
      boss.y = boss.y + math.sin(a) * speed * dt
    end
  end

  -- ground shockwave rings traveling outward along the floor
  function api.shockwave(opts)
    opts = opts or {}
    local cx = boss.x + boss.w / 2
    local floorY = boss.y + boss.h
    juice.shake(5, 0.3)
    sfx.play("explosion")
    for _, dir in ipairs({ -1, 1 }) do
      room:spawnProjectile({
        x = cx + dir * boss.w * 0.5, y = floorY - 6,
        vx = dir * (opts.speed or 170), vy = 0,
        damage = boss.damage * (opts.damageMult or 1), friendly = false,
        color = opts.color or { 1, 0.8, 0.4 }, kind = "orb", r = 6,
        life = 2.2,
      })
    end
  end

  function api.summon(enemyId, n, opts)
    opts = opts or {}
    local registry = require("src.game.registry")
    local def = registry.get("enemy", enemyId)
    if not def then return end
    -- cap adds so summon spam can't degenerate
    local alive = 0
    for _, e in ipairs(room.enemies) do
      if not e.dead and not e.isBoss then alive = alive + 1 end
    end
    n = math.min(n, math.max(0, (opts.maxAdds or 4) - alive))
    for i = 1, n do
      local spot = room:randomAirSpot(boss.x, boss.y - 40, 130)
        or { x = boss.x + (i - n / 2) * 40, y = boss.y - 20 }
      room.pendingSpawns[#room.pendingSpawns + 1] = {
        def = def, x = spot.x, y = spot.y, timer = 0.7,
      }
    end
    sfx.play("bossRoar", 1.4, 0.5)
  end

  function api.roar()
    juice.shake(4, 0.4)
    sfx.play("bossRoar")
    local cx, cy = boss:center()
    particles.ring(cx, cy, boss.def.color, 60)
  end

  return api
end

-- Engine ------------------------------------------------------------------------

function Boss:currentPhaseDef()
  local phases = self.def.phases
  local hpFrac = self.hp / self.maxHP
  for i = #phases, 1, -1 do
    if hpFrac <= (phases[i].below or 1) then
      return phases[i], i
    end
  end
  return phases[1], 1
end

function Boss:update(dt)
  if self.dead then return end
  self.hitFlash = math.max(0, self.hitFlash - dt)
  self:updateStatus(dt)
  self.anim = self.anim + dt

  -- intro: hold position, show banner (room HUD reads boss.intro)
  if not self.introDone then
    self.intro = self.intro - dt
    if self.intro <= 0 then
      self.introDone = true
      local api = makeAPI(self)
      api.roar()
      signals.emit("bossEngaged", self)
    end
    return
  end

  -- phase transitions
  local phaseDef, phaseIdx = self:currentPhaseDef()
  if phaseIdx ~= self.phase then
    self.phase = phaseIdx
    self.pattern = nil
    self.restTimer = 1.0
    self.stagger = 0.8
    local api = makeAPI(self)
    api.roar()
    if phaseDef.onEnter then phaseDef.onEnter(self, api) end
  end

  if self.stagger > 0 then
    self.stagger = self.stagger - dt
    self.vx = util.approach(self.vx, 0, 400 * dt)
  elseif self.pattern then
    local ok, err = coroutine.resume(self.pattern, dt)
    if not ok then
      -- a broken pattern must never freeze the fight
      print("[boss] pattern error: " .. tostring(err))
      self.pattern = nil
      self.restTimer = 1.2
    elseif coroutine.status(self.pattern) == "dead" then
      self.pattern = nil
      self.restTimer = (phaseDef.rest or 1.3) * (0.8 + love.math.random() * 0.4)
    end
  else
    self.restTimer = self.restTimer - dt
    -- drift toward the player between patterns (grounded bosses walk)
    if self.def.drifts then
      local _, dx = self:playerDist()
      self.facing = util.sign(dx) ~= 0 and util.sign(dx) or self.facing
      self.vx = util.approach(self.vx, self.facing * (self.def.speed or 30), 200 * dt)
    end
    if self.restTimer <= 0 then
      local pats = phaseDef.patterns
      self.patternIdx = (self.patternIdx % #pats) + 1
      local fn = pats[self.patternIdx]
      local api = makeAPI(self)
      self.pattern = coroutine.create(function(firstDt)
        _ = firstDt
        fn(self, api)
      end)
      coroutine.resume(self.pattern, 0)
    end
  end

  -- physics (grounded bosses)
  if not self.def.flying then
    self.vy = math.min(self.vy + 1300 * dt, 440)
    physics.move(self.room.world, self, dt, {})
  else
    physics.move(self.room.world, self, dt, {})
  end

  -- contact damage
  local p = self.room.player
  if p and not p.dead then
    if util.aabb(self.x, self.y, self.w, self.h, p.x, p.y, p.w, p.h) then
      p:hurt(self.damage, self:center())
    end
  end
end

function Boss:takeDamage(amount, angle, source, meta)
  if not self.introDone then return end
  Enemy.takeDamage(self, amount, angle, source, meta)
end

function Boss:die(source, meta)
  if self.dead then return end
  Enemy.die(self, source, meta)
  -- clear remaining adds and hostile projectiles: the kill is the moment
  for _, e in ipairs(self.room.enemies) do
    if not e.dead and e ~= self then e:die(source, { cleanup = true }) end
  end
  for _, pr in ipairs(self.room.projectiles.list) do
    if not pr.friendly then pr.dead = true end
  end
  juice.slow(0.25, 0.5)
  juice.flashScreen(1, 1, 1, 0.4)
  signals.emit("bossKilled", self)
end

function Boss:draw()
  local def = self.def
  local col = def.color
  local cx, cy = self:center()

  draw.glow(cx, cy, math.max(self.w, self.h) * 1.6, col[1], col[2], col[3],
    self.introDone and 0.4 or 0.7)

  local flash = self.hitFlash > 0
  local tele = self.telegraph and self.telegraph > 0 and math.floor(love.timer.getTime() * 14) % 2 == 0
  if flash then love.graphics.setColor(1, 1, 1, 1)
  elseif tele then love.graphics.setColor(1, 0.75, 0.55, 1)
  else love.graphics.setColor(col) end

  if def.drawShape then
    def.drawShape(self)
  else
    -- default: massive silhouette with crown of shards
    local bob = math.sin(self.anim * 2) * 2
    love.graphics.ellipse("fill", cx, self.y + self.h * 0.66 + bob, self.w * 0.55, self.h * 0.42)
    love.graphics.ellipse("fill", cx, self.y + self.h * 0.3 + bob, self.w * 0.42, self.h * 0.34)
    for i = -2, 2 do
      local a = i * 0.5
      love.graphics.polygon("fill",
        cx + i * self.w * 0.16 - 3, self.y + self.h * 0.12 + bob + math.abs(i) * 3,
        cx + i * self.w * 0.16 + 3, self.y + self.h * 0.12 + bob + math.abs(i) * 3,
        cx + i * self.w * 0.16 + math.sin(a) * 6, self.y - self.h * 0.1 + bob + math.abs(i) * 5)
    end
    local eyeCol = def.eyeColor or { 1, 0.9, 0.5 }
    if flash then eyeCol = { 0.1, 0.1, 0.1 } end
    love.graphics.setColor(eyeCol)
    love.graphics.rectangle("fill", cx + self.facing * 6 - 4, self.y + self.h * 0.26 + bob, 3.4, 4)
    love.graphics.rectangle("fill", cx + self.facing * 6 + 2, self.y + self.h * 0.26 + bob, 3.4, 4)
  end

  love.graphics.setColor(1, 1, 1, 1)
end

return Boss
