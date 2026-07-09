-- Smooth-follow camera with lookahead, bounds clamping and shake hookup.
local util = require("src.core.util")
local config = require("src.core.config")

local Camera = {}
Camera.__index = Camera

function Camera.new()
  local self = setmetatable({}, Camera)
  self.x, self.y = 0, 0
  self.zoom = config.ZOOM
  self.lookahead = 0
  self.bounds = nil -- {x, y, w, h} in world px
  self.shakeX, self.shakeY = 0, 0
  return self
end

function Camera:setBounds(x, y, w, h)
  self.bounds = { x = x, y = y, w = w, h = h }
end

function Camera:snapTo(x, y)
  self.x, self.y = x, y
  self:clamp()
end

function Camera:follow(tx, ty, vx, dt)
  -- lead the camera in the direction of travel
  local targetLook = util.clamp((vx or 0) * 0.22, -46, 46)
  self.lookahead = util.damp(self.lookahead, targetLook, 4, dt)
  self.x = util.damp(self.x, tx + self.lookahead, 9, dt)
  self.y = util.damp(self.y, ty - 14, 7, dt)
  self:clamp()
end

function Camera:clamp()
  if not self.bounds then return end
  local sw, sh = love.graphics.getDimensions()
  local vw, vh = sw / self.zoom, sh / self.zoom
  local b = self.bounds
  if b.w <= vw then self.x = b.x + b.w / 2
  else self.x = util.clamp(self.x, b.x + vw / 2, b.x + b.w - vw / 2) end
  if b.h <= vh then self.y = b.y + b.h / 2
  else self.y = util.clamp(self.y, b.y + vh / 2, b.y + b.h - vh / 2) end
end

function Camera:apply()
  local sw, sh = love.graphics.getDimensions()
  love.graphics.push()
  love.graphics.translate(math.floor(sw / 2), math.floor(sh / 2))
  love.graphics.scale(self.zoom)
  love.graphics.translate(-math.floor(self.x + self.shakeX), -math.floor(self.y + self.shakeY))
end

function Camera:unapply()
  love.graphics.pop()
end

-- Screen -> world.
function Camera:toWorld(sx, sy)
  local sw, sh = love.graphics.getDimensions()
  return (sx - sw / 2) / self.zoom + self.x, (sy - sh / 2) / self.zoom + self.y
end

-- Visible world rect (for culling).
function Camera:visible()
  local sw, sh = love.graphics.getDimensions()
  local vw, vh = sw / self.zoom, sh / self.zoom
  return self.x - vw / 2, self.y - vh / 2, vw, vh
end

return Camera
