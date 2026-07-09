-- Biome backgrounds: sky gradient, two parallax layers of silhouette
-- geometry, ambient drifting particles. Everything derived from the biome
-- palette + a seed, no assets.
local draw = require("src.render.draw")
local util = require("src.core.util")

local Background = {}
Background.__index = Background

local function genSilhouette(rng, widthPx, baseY, jag, tall)
  -- a jagged skyline as a triangle strip
  local pts = {}
  local x = -100
  local y = baseY + rng:random() * 40
  while x < widthPx + 200 do
    pts[#pts + 1] = { x = x, y = y }
    x = x + 30 + rng:random() * 80
    y = util.clamp(baseY - rng:random() * tall + rng:random() * jag, baseY - tall, baseY + 30)
  end
  return pts
end

function Background.new(biome, worldW, worldH, seed)
  local self = setmetatable({}, Background)
  self.biome = biome
  self.worldW, self.worldH = worldW, worldH
  local rng = love.math.newRandomGenerator(seed or 1)

  self.farLine = genSilhouette(rng, worldW * 1.2, worldH * 0.72, 40, worldH * 0.5)
  self.nearLine = genSilhouette(rng, worldW * 1.2, worldH * 0.88, 60, worldH * 0.38)

  -- floating ambient particles
  self.ambient = {}
  local n = 42
  for i = 1, n do
    self.ambient[i] = {
      x = rng:random() * worldW,
      y = rng:random() * worldH,
      spd = 4 + rng:random() * 14,
      drift = rng:random() * 2 - 1,
      size = 0.8 + rng:random() * 1.8,
      phase = rng:random() * math.pi * 2,
    }
  end
  self.t = 0
  return self
end

function Background:update(dt)
  self.t = self.t + dt
  local style = self.biome.ambient
  for _, a in ipairs(self.ambient) do
    if style == "embers" then
      a.y = a.y - a.spd * dt
      a.x = a.x + math.sin(self.t + a.phase) * 8 * dt
      if a.y < -10 then a.y = self.worldH + 10 a.x = love.math.random() * self.worldW end
    elseif style == "spores" then
      a.y = a.y + a.spd * 0.4 * dt
      a.x = a.x + math.sin(self.t * 0.6 + a.phase) * 14 * dt
      if a.y > self.worldH + 10 then a.y = -10 a.x = love.math.random() * self.worldW end
    else -- motes
      a.x = a.x + a.drift * a.spd * dt
      a.y = a.y + math.sin(self.t * 0.5 + a.phase) * 6 * dt
      if a.x < -10 then a.x = self.worldW + 10 end
      if a.x > self.worldW + 10 then a.x = -10 end
    end
  end
end

local function drawLine(pts, color, bottomY)
  love.graphics.setColor(color)
  for i = 1, #pts - 1 do
    local a, b = pts[i], pts[i + 1]
    love.graphics.polygon("fill", a.x, a.y, b.x, b.y, b.x, bottomY, a.x, bottomY)
  end
end

-- camera: for parallax offsets. Draw in world space (camera applied outside).
function Background:draw(camera)
  local pal = self.biome.palette
  local camX = camera and camera.x or 0
  local vx, vy, vw, vh = 0, 0, self.worldW, self.worldH
  if camera then vx, vy, vw, vh = camera:visible() end

  -- sky: draw covering the visible rect
  draw.gradientV(vx - 20, vy - 20, vw + 40, vh + 40, pal.skyTop, pal.skyBottom)

  -- big soft light in the sky
  local lc = pal.light
  draw.glow(vx + vw * 0.5, vy + vh * 0.25, vw * 0.5, lc[1], lc[2], lc[3], 0.10)

  -- parallax silhouettes
  love.graphics.push()
  love.graphics.translate(camX * 0.25, 0)
  drawLine(self.farLine, pal.far, self.worldH + 60)
  love.graphics.pop()

  love.graphics.push()
  love.graphics.translate(camX * 0.12, 0)
  drawLine(self.nearLine, pal.near, self.worldH + 60)
  love.graphics.pop()

  -- ambient particles
  local ac = pal.accent
  for _, a in ipairs(self.ambient) do
    local tw = 0.35 + 0.3 * math.sin(self.t * 2 + a.phase)
    love.graphics.setColor(ac[1], ac[2], ac[3], tw)
    love.graphics.circle("fill", a.x, a.y, a.size)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

return Background
