-- Projectile manager: friendly bolts, enemy shots, lobbed blobs, orbs.
local util = require("src.core.util")
local physics = require("src.game.physics")
local particles = require("src.render.particles")
local draw = require("src.render.draw")
local signals = require("src.core.signals")

local projectiles = {}
projectiles.__index = projectiles

function projectiles.new(room)
  return setmetatable({ room = room, list = {} }, projectiles)
end

-- spec: x, y, vx, vy, damage, friendly, color, kind ("bolt"|"orb"|"blob"),
--       r, gravity, homing (target), homingStrength, pierce, life, trail,
--       onHit(target), bounces
function projectiles:spawn(spec)
  spec.r = spec.r or 3
  spec.life = spec.life or 3
  spec.pierce = spec.pierce or 0
  spec.hitList = {}
  self.list[#self.list + 1] = spec
  return spec
end

local function hitsTile(world, p)
  local c = math.floor(p.x / physics.TILE) + 1
  local r = math.floor(p.y / physics.TILE) + 1
  return world:get(c, r) == physics.SOLID
end

function projectiles:update(dt)
  local room = self.room
  local world = room.world
  for _, p in ipairs(self.list) do
    p.life = p.life - dt
    if p.life <= 0 then p.dead = true end
    if not p.dead then
      if p.gravity then p.vy = p.vy + p.gravity * dt end
      if p.homing and not p.homing.dead then
        local tx, ty = p.homing:center()
        local desired = util.angle(p.x, p.y, tx, ty)
        local cur = math.atan2(p.vy, p.vx)
        local diff = ((desired - cur + math.pi) % (2 * math.pi)) - math.pi
        local turn = (p.homingStrength or 3) * dt
        cur = cur + util.clamp(diff, -turn, turn)
        local sp = math.sqrt(p.vx * p.vx + p.vy * p.vy)
        p.vx, p.vy = math.cos(cur) * sp, math.sin(cur) * sp
      end
      p.x = p.x + p.vx * dt
      p.y = p.y + p.vy * dt

      if p.trail and love.math.random() < dt * 40 then
        particles.spawn({ x = p.x, y = p.y, life = 0.3, size = p.r * 0.7,
          sizeEnd = 0, color = p.color, kind = "dot" })
      end

      -- walls
      if hitsTile(world, p) then
        if p.bounces and p.bounces > 0 then
          p.bounces = p.bounces - 1
          -- crude reflect: step back and flip the dominant axis
          p.x = p.x - p.vx * dt
          p.y = p.y - p.vy * dt
          if math.abs(p.vx) > math.abs(p.vy) then p.vx = -p.vx else p.vy = -p.vy end
        else
          p.dead = true
          particles.burst(p.x, p.y, p.color, 4, { speed = 50, kind = "dot", gravity = 0 })
        end
      end
      -- out of room
      if p.x < -40 or p.x > world.widthPx + 40 or p.y < -60 or p.y > world.heightPx + 60 then
        p.dead = true
      end
    end

    if not p.dead then
      if p.friendly then
        for _, e in ipairs(room.enemies) do
          if not e.dead and not p.hitList[e]
             and util.aabb(p.x - p.r, p.y - p.r, p.r * 2, p.r * 2, e.x, e.y, e.w, e.h) then
            local ang = math.atan2(p.vy, p.vx)
            e:takeDamage(p.damage, ang, room.player, { bolt = true, projectile = p })
            signals.emit("boltHit", p, e)
            if p.onHit then p.onHit(e) end
            p.hitList[e] = true
            if p.pierce > 0 then
              p.pierce = p.pierce - 1
            else
              p.dead = true
              particles.burst(p.x, p.y, p.color, 5, { speed = 70, kind = "spark", gravity = 0 })
              break
            end
          end
        end
      else
        local pl = room.player
        if pl and not pl.dead
           and util.aabb(p.x - p.r, p.y - p.r, p.r * 2, p.r * 2, pl.x, pl.y, pl.w, pl.h) then
          pl:hurt(p.damage, p.x, p.y)
          p.dead = true
          particles.burst(p.x, p.y, p.color, 5, { speed = 70, kind = "spark", gravity = 0 })
        end
      end
    end
  end
  util.sweep(self.list)
end

function projectiles:draw()
  for _, p in ipairs(self.list) do
    local c = p.color or { 1, 1, 1 }
    draw.glow(p.x, p.y, p.r * 4, c[1], c[2], c[3], 0.5)
    love.graphics.setColor(c)
    if not p.friendly then
      -- SHAPE LANGUAGE: everything hostile is a shard pointing where it flies
      local ang = math.atan2(p.vy, p.vx)
      love.graphics.push()
      love.graphics.translate(p.x, p.y)
      love.graphics.rotate(ang)
      love.graphics.polygon("fill", p.r * 2.2, 0, -p.r * 1.4, -p.r, -p.r * 0.6, 0, -p.r * 1.4, p.r)
      love.graphics.pop()
    elseif p.kind == "bolt" then
      local ang = math.atan2(p.vy, p.vx)
      love.graphics.push()
      love.graphics.translate(p.x, p.y)
      love.graphics.rotate(ang)
      love.graphics.ellipse("fill", 0, 0, p.r * 2.2, p.r * 0.85)
      love.graphics.pop()
    else -- friendly orb: round, like the player
      love.graphics.circle("fill", p.x, p.y, p.r)
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

function projectiles:clear()
  self.list = {}
end

return projectiles
