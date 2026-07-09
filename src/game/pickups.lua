-- Pickups: run currency (embers), meta currency (cinders), health, healing
-- motes, and boon sigils. Magnetized to the player once close.
local util = require("src.core.util")
local physics = require("src.game.physics")
local particles = require("src.render.particles")
local draw = require("src.render.draw")
local sfx = require("src.audio.sfx")
local signals = require("src.core.signals")

local pickups = {}
pickups.__index = pickups

local KINDS = {
  ember = { color = { 1, 0.6, 0.2 }, r = 3, magnet = 70 },
  cinder = { color = { 0.65, 0.85, 1 }, r = 3.5, magnet = 90 },
  heart = { color = { 1, 0.35, 0.45 }, r = 4.5, magnet = 60 },
  mote = { color = { 0.4, 1, 0.55 }, r = 3, magnet = 80 },
  sigil = { color = { 1, 0.85, 0.4 }, r = 7, magnet = 0 },
}

function pickups.new(room)
  return setmetatable({ room = room, list = {} }, pickups)
end

-- spec: kind, x, y, value, scatter (bool: toss with random velocity)
function pickups:spawn(spec)
  local k = KINDS[spec.kind] or KINDS.ember
  local p = {
    kind = spec.kind, x = spec.x, y = spec.y,
    value = spec.value or 1,
    vx = 0, vy = 0, r = k.r, color = k.color, magnet = k.magnet,
    t = love.math.random() * 10, grounded = false,
    data = spec.data,
  }
  if spec.scatter then
    p.vx = (love.math.random() * 2 - 1) * 90
    p.vy = -60 - love.math.random() * 80
  end
  self.list[#self.list + 1] = p
  return p
end

function pickups:spawnBurst(kind, x, y, count, valueEach)
  for _ = 1, count do
    self:spawn({ kind = kind, x = x, y = y, value = valueEach or 1, scatter = true })
  end
end

local function collect(self, p)
  local room = self.room
  local run = room.run
  p.dead = true
  if p.kind == "ember" then
    if run then run:addEmbers(p.value) end
    sfx.play("pickup", 1 + love.math.random() * 0.15)
    particles.burst(p.x, p.y, p.color, 3, { speed = 40, gravity = 0, kind = "spark" })
  elseif p.kind == "cinder" then
    if run then run:addCinders(p.value) end
    sfx.play("cinder")
    particles.burst(p.x, p.y, p.color, 5, { speed = 50, gravity = 0, glow = 6 })
  elseif p.kind == "heart" then
    room.player:heal(p.value)
  elseif p.kind == "mote" then
    room.player:heal(p.value)
  elseif p.kind == "sigil" then
    sfx.play("boon")
    particles.ring(p.x, p.y, p.color, 30)
    if room.callbacks and room.callbacks.onSigil then
      room.callbacks.onSigil(p.data or {})
    end
  end
  signals.emit("pickupCollected", p)
end

function pickups:update(dt)
  local room = self.room
  local pl = room.player
  for _, p in ipairs(self.list) do
    p.t = p.t + dt
    local px, py = 0, 0
    local dist = math.huge
    if pl and not pl.dead then
      px, py = pl:center()
      dist = util.dist(p.x, p.y, px, py)
    end

    if p.magnet > 0 and dist < p.magnet then
      local a = util.angle(p.x, p.y, px, py)
      local pull = (1 - dist / p.magnet) * 620 + 120
      p.vx = util.damp(p.vx, math.cos(a) * pull, 8, dt)
      p.vy = util.damp(p.vy, math.sin(a) * pull, 8, dt)
      p.x = p.x + p.vx * dt
      p.y = p.y + p.vy * dt
    elseif not p.grounded and p.kind ~= "sigil" then
      p.vy = p.vy + 500 * dt
      p.x = p.x + p.vx * dt
      p.y = p.y + p.vy * dt
      -- settle on solid ground
      local c = math.floor(p.x / physics.TILE) + 1
      local r = math.floor((p.y + p.r) / physics.TILE) + 1
      if room.world:get(c, r) == physics.SOLID and p.vy > 0 then
        p.y = (r - 1) * physics.TILE - p.r
        p.vy = 0
        p.vx = p.vx * 0.6
        if math.abs(p.vx) < 5 then p.grounded = true end
      end
      -- keep inside the room
      if p.x < 8 then p.x, p.vx = 8, math.abs(p.vx) end
      if p.x > room.world.widthPx - 8 then p.x, p.vx = room.world.widthPx - 8, -math.abs(p.vx) end
      if p.y > room.world.heightPx + 20 then p.y = room.world.heightPx - 40 p.vy = 0 end
    end

    local touchR = p.kind == "sigil" and 14 or 6
    if dist < touchR + p.r then
      collect(self, p)
    end
  end
  util.sweep(self.list)
end

function pickups:draw()
  for _, p in ipairs(self.list) do
    local c = p.color
    local bob = math.sin(p.t * 3) * 1.5
    if p.kind == "sigil" then
      draw.glow(p.x, p.y + bob, 26, c[1], c[2], c[3], 0.55 + math.sin(p.t * 2) * 0.15)
      love.graphics.setColor(c)
      draw.diamond("fill", p.x, p.y + bob, p.r)
      love.graphics.setColor(1, 1, 1, 0.85)
      draw.diamond("line", p.x, p.y + bob, p.r + 2.5 + math.sin(p.t * 2) * 1.2)
    elseif p.kind == "heart" then
      draw.glow(p.x, p.y + bob, 12, c[1], c[2], c[3], 0.5)
      love.graphics.setColor(c)
      love.graphics.circle("fill", p.x - 1.7, p.y + bob - 1, 2.4)
      love.graphics.circle("fill", p.x + 1.7, p.y + bob - 1, 2.4)
      love.graphics.polygon("fill", p.x - 3.8, p.y + bob - 0.2, p.x + 3.8, p.y + bob - 0.2, p.x, p.y + bob + 4.2)
    else
      draw.glow(p.x, p.y + bob, p.r * 3.2, c[1], c[2], c[3], 0.45)
      love.graphics.setColor(c)
      draw.diamond("fill", p.x, p.y + bob, p.r)
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

return pickups
