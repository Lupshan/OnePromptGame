-- Pooled particle system, custom (no textures needed). Every particle is a
-- shape: dot, spark (streak), shard (triangle), ring, ember (glowing dot).
local util = require("src.core.util")
local draw = require("src.render.draw")

local particles = {}
local pool = {}
local live = {}

local function get()
  local p = table.remove(pool)
  if not p then p = {} end
  return p
end

-- spec: x, y, vx, vy, life, size, color {r,g,b}, kind, gravity, drag, fade,
--       spin, glow (extra glow radius), sizeEnd
function particles.spawn(spec)
  local p = get()
  p.x, p.y = spec.x, spec.y
  p.vx, p.vy = spec.vx or 0, spec.vy or 0
  p.life = spec.life or 0.5
  p.maxLife = p.life
  p.size = spec.size or 2
  p.sizeEnd = spec.sizeEnd
  local col = spec.color or { 1, 1, 1 }
  p.r, p.g, p.b = col[1], col[2], col[3]
  p.kind = spec.kind or "dot"
  p.gravity = spec.gravity or 0
  p.drag = spec.drag or 0
  p.spin = spec.spin or 0
  p.rot = spec.rot or love.math.random() * math.pi * 2
  p.glow = spec.glow
  p.dead = false
  live[#live + 1] = p
  return p
end

-- Convenience bursts -----------------------------------------------------------

function particles.burst(x, y, color, n, opts)
  opts = opts or {}
  for _ = 1, n do
    local a = love.math.random() * math.pi * 2
    local sp = (opts.speed or 90) * (0.4 + love.math.random() * 0.8)
    particles.spawn({
      x = x, y = y,
      vx = math.cos(a) * sp + (opts.vx or 0),
      vy = math.sin(a) * sp + (opts.vy or 0),
      life = (opts.life or 0.45) * (0.6 + love.math.random() * 0.8),
      size = (opts.size or 2.4) * (0.6 + love.math.random() * 0.8),
      sizeEnd = 0.4,
      color = color,
      kind = opts.kind or "spark",
      gravity = opts.gravity or 240,
      drag = opts.drag or 2.2,
      glow = opts.glow,
    })
  end
end

function particles.dust(x, y, dir, n)
  for _ = 1, n or 4 do
    particles.spawn({
      x = x + (love.math.random() * 8 - 4), y = y,
      vx = (dir or 0) * (20 + love.math.random() * 30) + (love.math.random() * 24 - 12),
      vy = -(10 + love.math.random() * 26),
      life = 0.3 + love.math.random() * 0.25,
      size = 1.6 + love.math.random() * 1.6,
      sizeEnd = 0.2,
      color = { 0.62, 0.6, 0.66 },
      kind = "dot",
      gravity = -30,
      drag = 3,
    })
  end
end

function particles.ring(x, y, color, size)
  particles.spawn({
    x = x, y = y, life = 0.28, size = 3, sizeEnd = size or 22,
    color = color, kind = "ring",
  })
end

function particles.ember(x, y, color)
  particles.spawn({
    x = x, y = y,
    vx = love.math.random() * 16 - 8,
    vy = -(8 + love.math.random() * 20),
    life = 1.2 + love.math.random() * 1.4,
    size = 1 + love.math.random() * 1.6,
    sizeEnd = 0.2,
    color = color,
    kind = "ember",
    gravity = -14,
    drag = 0.6,
    glow = 6,
  })
end

function particles.textPop(x, y, str, color, size)
  local p = particles.spawn({
    x = x, y = y, vy = -46, life = 0.7, size = size or 9,
    color = color, kind = "text", drag = 3.2,
  })
  p.str = str
end

-- Core -------------------------------------------------------------------------

function particles.update(dt)
  for i = 1, #live do
    local p = live[i]
    p.life = p.life - dt
    if p.life <= 0 then
      p.dead = true
      pool[#pool + 1] = p
    else
      p.vy = p.vy + p.gravity * dt
      if p.drag > 0 then
        p.vx = p.vx - p.vx * math.min(1, p.drag * dt)
        p.vy = p.vy - p.vy * math.min(1, p.drag * dt)
      end
      p.x = p.x + p.vx * dt
      p.y = p.y + p.vy * dt
      p.rot = p.rot + p.spin * dt
    end
  end
  util.sweep(live)
end

function particles.draw()
  for i = 1, #live do
    local p = live[i]
    local t = p.life / p.maxLife
    local size = p.sizeEnd and util.lerp(p.sizeEnd, p.size, t) or p.size
    local a = math.min(1, t * 2)
    if p.kind == "dot" or p.kind == "ember" then
      if p.glow then draw.glow(p.x, p.y, p.glow + size * 2, p.r, p.g, p.b, a * 0.55) end
      love.graphics.setColor(p.r, p.g, p.b, a)
      love.graphics.circle("fill", p.x, p.y, size)
    elseif p.kind == "spark" then
      love.graphics.setColor(p.r, p.g, p.b, a)
      local len = math.max(2, math.sqrt(p.vx * p.vx + p.vy * p.vy) * 0.035)
      local ang = math.atan2(p.vy, p.vx)
      love.graphics.push()
      love.graphics.translate(p.x, p.y)
      love.graphics.rotate(ang)
      love.graphics.rectangle("fill", -len, -size / 2, len * 2, size)
      love.graphics.pop()
    elseif p.kind == "shard" then
      love.graphics.setColor(p.r, p.g, p.b, a)
      love.graphics.push()
      love.graphics.translate(p.x, p.y)
      love.graphics.rotate(p.rot)
      love.graphics.polygon("fill", -size, size, size, size, 0, -size * 1.4)
      love.graphics.pop()
    elseif p.kind == "ring" then
      love.graphics.setColor(p.r, p.g, p.b, a * 0.9)
      love.graphics.setLineWidth(math.max(1, 2.5 * t))
      love.graphics.circle("line", p.x, p.y, size)
      love.graphics.setLineWidth(1)
    elseif p.kind == "text" then
      draw.textCentered(p.str, p.x, p.y, math.floor(p.size), { p.r, p.g, p.b, a })
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

function particles.clear()
  for i = 1, #live do pool[#pool + 1] = live[i] end
  live = {}
end

function particles.count() return #live end

return particles
