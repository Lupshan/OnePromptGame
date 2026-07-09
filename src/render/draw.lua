-- Procedural drawing helpers: everything on screen is built from these.
-- No image files anywhere — glow sprites and gradients are generated once
-- at startup into ImageData/Canvas and reused.
local draw = {}

local glowImage      -- radial gradient sprite used for all point lights / glows
local gradientMesh   -- 1x1 mesh reused for arbitrary linear gradients

function draw.load()
  -- Radial glow texture (white center -> transparent), tinted at draw time.
  local size = 128
  local id = love.image.newImageData(size, size)
  local c = (size - 1) / 2
  id:mapPixel(function(x, y)
    local dx, dy = (x - c) / c, (y - c) / c
    local d = math.sqrt(dx * dx + dy * dy)
    local a = math.max(0, 1 - d)
    a = a * a -- quadratic falloff reads as light
    return 1, 1, 1, a
  end)
  glowImage = love.graphics.newImage(id)
  glowImage:setFilter("linear", "linear")

  gradientMesh = love.graphics.newMesh({
    { 0, 0, 0, 0, 1, 1, 1, 1 },
    { 1, 0, 1, 0, 1, 1, 1, 1 },
    { 1, 1, 1, 1, 1, 1, 1, 1 },
    { 0, 1, 0, 1, 1, 1, 1, 1 },
  }, "fan", "static")
end

-- Soft additive glow at world position. r is the radius in px.
function draw.glow(x, y, r, cr, cg, cb, a)
  if not glowImage then return end
  love.graphics.setBlendMode("add")
  love.graphics.setColor(cr, cg, cb, a or 1)
  local s = (r * 2) / glowImage:getWidth()
  love.graphics.draw(glowImage, x, y, 0, s, s, glowImage:getWidth() / 2, glowImage:getHeight() / 2)
  love.graphics.setBlendMode("alpha")
end

-- Vertical linear gradient rectangle. topColor/bottomColor = {r,g,b,a?}.
function draw.gradientV(x, y, w, h, top, bottom)
  if not gradientMesh then
    love.graphics.setColor(top)
    love.graphics.rectangle("fill", x, y, w, h)
    return
  end
  local ta = top[4] or 1
  local ba = bottom[4] or 1
  gradientMesh:setVertex(1, 0, 0, 0, 0, top[1], top[2], top[3], ta)
  gradientMesh:setVertex(2, 1, 0, 1, 0, top[1], top[2], top[3], ta)
  gradientMesh:setVertex(3, 1, 1, 1, 1, bottom[1], bottom[2], bottom[3], ba)
  gradientMesh:setVertex(4, 0, 1, 0, 1, bottom[1], bottom[2], bottom[3], ba)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(gradientMesh, x, y, 0, w, h)
end

-- Outlined-feel silhouette rectangle with slight vertical shading.
function draw.shadedRect(x, y, w, h, color, shade)
  shade = shade or 0.75
  draw.gradientV(x, y, w, h, color, { color[1] * shade, color[2] * shade, color[3] * shade, color[4] or 1 })
end

-- Regular polygon (silhouette building block).
function draw.ngon(mode, x, y, r, n, rot)
  local pts = {}
  rot = rot or 0
  for i = 0, n - 1 do
    local a = rot + i / n * math.pi * 2
    pts[#pts + 1] = x + math.cos(a) * r
    pts[#pts + 1] = y + math.sin(a) * r
  end
  love.graphics.polygon(mode, pts)
end

-- Diamond, common motif of the game's geometry language.
function draw.diamond(mode, x, y, r)
  love.graphics.polygon(mode, x, y - r, x + r, y, x, y + r, x - r, y)
end

-- Text helpers ---------------------------------------------------------------

local fonts = {}
function draw.font(size)
  local f = fonts[size]
  if not f then
    f = love.graphics.newFont(size) -- LÖVE built-in font, no external file
    fonts[size] = f
  end
  return f
end

function draw.text(str, x, y, size, color, align, width)
  love.graphics.setFont(draw.font(size or 14))
  love.graphics.setColor(color or { 1, 1, 1, 1 })
  if align then
    love.graphics.printf(str, x, y, width or 10000, align)
  else
    love.graphics.print(str, x, y)
  end
end

function draw.textCentered(str, cx, y, size, color)
  local f = draw.font(size or 14)
  love.graphics.setFont(f)
  love.graphics.setColor(color or { 1, 1, 1, 1 })
  love.graphics.print(str, math.floor(cx - f:getWidth(str) / 2), math.floor(y))
end

function draw.textWidth(str, size)
  return draw.font(size or 14):getWidth(str)
end

return draw
