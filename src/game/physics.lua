-- Tile-grid AABB physics. Actors move with swept per-axis resolution and
-- sub-pixel accumulation. Tiles are indexed [row][col], 1-based.
local config = require("src.core.config")

local physics = {}

local T = config.TILE

-- Tile ids
physics.EMPTY = 0
physics.SOLID = 1
physics.PLATFORM = 2 -- one-way, passable from below/sides
physics.SPIKE = 3    -- hazard, non-solid
physics.DECOR = 4    -- background decoration, non-solid

local World = {}
World.__index = World
physics.World = World

function physics.newWorld(cols, rows)
  local self = setmetatable({}, World)
  self.cols, self.rows = cols, rows
  self.tiles = {}
  for r = 1, rows do
    local row = {}
    for c = 1, cols do row[c] = physics.EMPTY end
    self.tiles[r] = row
  end
  self.widthPx = cols * T
  self.heightPx = rows * T
  return self
end

function World:get(c, r)
  if c < 1 or c > self.cols or r < 1 or r > self.rows then
    -- outside the room counts as solid so nothing escapes sideways;
    -- below the room is empty (handled as a kill plane by the room)
    if r > self.rows then return physics.EMPTY end
    return physics.SOLID
  end
  return self.tiles[r][c]
end

function World:set(c, r, v)
  if c >= 1 and c <= self.cols and r >= 1 and r <= self.rows then
    self.tiles[r][c] = v
  end
end

function World:isSolidAt(c, r)
  return self:get(c, r) == physics.SOLID
end

-- Does the AABB overlap any solid tile?
function World:rectHitsSolid(x, y, w, h)
  local c1 = math.floor(x / T) + 1
  local c2 = math.floor((x + w - 0.001) / T) + 1
  local r1 = math.floor(y / T) + 1
  local r2 = math.floor((y + h - 0.001) / T) + 1
  for r = r1, r2 do
    for c = c1, c2 do
      if self:get(c, r) == physics.SOLID then return true, c, r end
    end
  end
  return false
end

function World:rectHitsTile(x, y, w, h, tileId)
  local c1 = math.floor(x / T) + 1
  local c2 = math.floor((x + w - 0.001) / T) + 1
  local r1 = math.floor(y / T) + 1
  local r2 = math.floor((y + h - 0.001) / T) + 1
  for r = r1, r2 do
    for c = c1, c2 do
      if self:get(c, r) == tileId then return true, c, r end
    end
  end
  return false
end

-- One-way platform check: feet cross the platform top while moving down.
local function platformBlocksFall(world, x, y, w, h, newY, dropThrough)
  if dropThrough then return nil end
  local feetOld = y + h
  local feetNew = newY + h
  if feetNew <= feetOld then return nil end
  local c1 = math.floor(x / T) + 1
  local c2 = math.floor((x + w - 0.001) / T) + 1
  local r1 = math.floor(feetOld / T) + 1
  local r2 = math.floor((feetNew - 0.001) / T) + 1
  for r = r1, r2 do
    local top = (r - 1) * T
    if feetOld <= top + 0.001 and feetNew > top then
      for c = c1, c2 do
        if world:get(c, r) == physics.PLATFORM then
          return top - h
        end
      end
    end
  end
  return nil
end

-- Move an actor. Actor needs: x, y, w, h, vx, vy plus scratch fields (_rx, _ry).
-- opts: dropThrough (bool), cornerCorrection (px), ledgeStep (px),
--       onCollideX(fn), onCollideY(fn)
-- Sets actor.onGround, actor.hitCeiling, actor.hitWall (=dir or nil).
function physics.move(world, a, dt, opts)
  opts = opts or {}
  a._rx = a._rx or 0
  a._ry = a._ry or 0
  a.onGround = false
  a.hitCeiling = false
  a.hitWall = nil

  -- X axis -------------------------------------------------------------
  local dx = a.vx * dt + a._rx
  local moveX = (dx >= 0) and math.floor(dx) or math.ceil(dx)
  a._rx = dx - moveX
  if moveX ~= 0 then
    local step = moveX > 0 and 1 or -1
    for _ = 1, math.abs(moveX) do
      local nx = a.x + step
      if not world:rectHitsSolid(nx, a.y, a.w, a.h) then
        a.x = nx
      else
        -- ledge step-up: small lips don't stop grounded runners
        local stepped = false
        if opts.ledgeStep and a.onGroundPrev then
          for up = 1, opts.ledgeStep do
            if not world:rectHitsSolid(nx, a.y - up, a.w, a.h)
               and world:rectHitsSolid(nx, a.y - up + 1, a.w, a.h) == false then
              a.x, a.y = nx, a.y - up
              stepped = true
              break
            end
          end
        end
        if not stepped then
          a.hitWall = step
          a._rx = 0
          if opts.onCollideX then opts.onCollideX(step) end
          if a.vx * step > 0 then a.vx = 0 end
          break
        end
      end
    end
  end

  -- Y axis -------------------------------------------------------------
  local dy = a.vy * dt + a._ry
  local moveY = (dy >= 0) and math.floor(dy) or math.ceil(dy)
  a._ry = dy - moveY

  -- one-way platforms: resolve before stepping (they only matter falling)
  if moveY > 0 then
    local snapY = platformBlocksFall(world, a.x, a.y, a.w, a.h, a.y + moveY, opts.dropThrough)
    if snapY then
      a.y = snapY
      a.vy = 0
      a._ry = 0
      a.onGround = true
      a.onPlatform = true
      moveY = 0
      if opts.onCollideY then opts.onCollideY(1) end
    else
      a.onPlatform = false
    end
  end

  if moveY ~= 0 then
    local step = moveY > 0 and 1 or -1
    for _ = 1, math.abs(moveY) do
      local ny = a.y + step
      if not world:rectHitsSolid(a.x, ny, a.w, a.h) then
        a.y = ny
      else
        if step < 0 and opts.cornerCorrection then
          -- head bumped a corner: nudge sideways if that frees the path
          local fixed = false
          for off = 1, opts.cornerCorrection do
            if not world:rectHitsSolid(a.x + off, ny, a.w, a.h) then
              a.x = a.x + off fixed = true break
            elseif not world:rectHitsSolid(a.x - off, ny, a.w, a.h) then
              a.x = a.x - off fixed = true break
            end
          end
          if fixed then
            a.y = ny
          else
            a.hitCeiling = true
            a.vy = 0
            a._ry = 0
            if opts.onCollideY then opts.onCollideY(-1) end
            break
          end
        else
          if step > 0 then
            a.onGround = true
          else
            a.hitCeiling = true
          end
          a.vy = 0
          a._ry = 0
          if opts.onCollideY then opts.onCollideY(step) end
          break
        end
      end
    end
  end

  -- grounded check when standing still (vy == 0)
  if not a.onGround and a.vy >= 0 then
    if world:rectHitsSolid(a.x, a.y + 1, a.w, a.h) then
      a.onGround = true
    elseif not opts.dropThrough then
      -- standing exactly on a platform top
      local feet = a.y + a.h
      if feet % T == 0 then
        local r = math.floor(feet / T) + 1
        local c1 = math.floor(a.x / T) + 1
        local c2 = math.floor((a.x + a.w - 0.001) / T) + 1
        for c = c1, c2 do
          if world:get(c, r) == physics.PLATFORM then
            a.onGround = true
            a.onPlatform = true
            break
          end
        end
      end
    end
  end

  a.onGroundPrev = a.onGround
end

-- Is a wall directly beside the actor? (for wall slide/jump). dir: 1 or -1.
function physics.touchingWall(world, a, dir)
  return world:rectHitsSolid(a.x + dir, a.y, a.w, a.h)
end

-- Simple raycast against solids on the tile grid (DDA). Returns hit x, y or nil.
function physics.raycast(world, x, y, dx, dy, maxDist)
  local dist = 0
  local stepLen = T / 2
  local len = math.sqrt(dx * dx + dy * dy)
  if len == 0 then return nil end
  dx, dy = dx / len, dy / len
  while dist < maxDist do
    dist = dist + stepLen
    local px, py = x + dx * dist, y + dy * dist
    local c = math.floor(px / T) + 1
    local r = math.floor(py / T) + 1
    if world:get(c, r) == physics.SOLID then
      return px, py, dist
    end
  end
  return nil
end

physics.TILE = T

return physics
