-- Reachability validation: proves a generated room is traversable by a
-- conservative model of the player's movement (single jump only -- no dash,
-- no double jump, no wall jump), so any real player can always get through.
-- A room that fails here is regenerated; this is the anti-softlock guarantee.
local physics = require("src.game.physics")

local reach = {}

-- Conservative movement envelope. Real jump: ~3.2 tiles up, ~5.9 across.
-- MAX_JUMP_ACROSS is a column distance (a 4-tile air gap = 5 columns of
-- travel). Height trades against distance: jumping N tiles up shortens the
-- horizontal reach by N columns (see maxAcross below).
local MAX_JUMP_UP = 3
local MAX_JUMP_ACROSS = 5

local function passable(world, c, r)
  local t = world:get(c, r)
  -- spikes are treated as walls: the guaranteed path never crosses damage
  return t == physics.EMPTY or t == physics.PLATFORM or t == physics.DECOR
end

local function bodyFits(world, c, r) -- player feet at (c, r), body is 1x2 tiles
  return passable(world, c, r) and passable(world, c, r - 1)
end

local function standable(world, c, r)
  if not bodyFits(world, c, r) then return false end
  local below = world:get(c, r + 1)
  return below == physics.SOLID or below == physics.PLATFORM
end

-- Find the row the body lands on if it falls in column c starting at feet row r.
local function fallLanding(world, c, r)
  local rr = r
  while rr <= world.rows do
    if standable(world, c, rr) then return rr end
    if not bodyFits(world, c, rr) then return nil end
    rr = rr + 1
  end
  return nil -- fell out of the room
end

-- Vertical clearance for jumping: feet can rise from row r to row rTop in column c.
local function columnClear(world, c, rTop, r)
  for rr = rTop, r do
    if not bodyFits(world, c, rr) then return false end
  end
  return true
end

-- Horizontal clearance at feet row r from column c1 to c2 (inclusive).
local function rowClear(world, r, c1, c2)
  local step = c1 <= c2 and 1 or -1
  for cc = c1, c2, step do
    if not bodyFits(world, cc, r) then return false end
  end
  return true
end

-- Compute the set of standable tiles reachable from (startC, startR).
-- Returns set keyed by (r * cols + c) and a helper.
function reach.flood(world, startC, startR)
  local cols = world.cols
  local visited = {}
  local queue = {}
  local function key(c, r) return r * (cols + 2) + c end
  local function push(c, r)
    if c < 1 or c > world.cols or r < 1 or r > world.rows then return end
    local k = key(c, r)
    if visited[k] then return end
    if not standable(world, c, r) then return end
    visited[k] = true
    queue[#queue + 1] = { c = c, r = r }
  end

  -- normalize start: if not standable, fall to a landing
  if not standable(world, startC, startR) then
    local lr = fallLanding(world, startC, startR)
    if lr then startR = lr end
  end
  push(startC, startR)

  local head = 1
  while head <= #queue do
    local node = queue[head]
    head = head + 1
    local c, r = node.c, node.r

    for _, dir in ipairs({ -1, 1 }) do
      local nc = c + dir
      -- walk
      if standable(world, nc, r) then push(nc, r) end
      -- step up one
      if bodyFits(world, c, r - 1) and standable(world, nc, r - 1) then
        push(nc, r - 1)
      end
      -- walk off the edge and fall
      if bodyFits(world, nc, r) then
        local lr = fallLanding(world, nc, r)
        if lr then push(nc, lr) end
      end
    end

    -- jumps: up-then-across. Rising costs horizontal reach.
    for up = 1, MAX_JUMP_UP do
      local apexR = r - up
      if not columnClear(world, c, apexR - 1 < 1 and 1 or apexR - 1, r - 1) then break end
      -- land directly above? (through a platform)
      if standable(world, c, apexR) then push(c, apexR) end
      local maxAcross = MAX_JUMP_ACROSS - up
      for _, dir in ipairs({ -1, 1 }) do
        for gap = 1, maxAcross do
          local tc = c + dir * gap
          if tc < 1 or tc > world.cols then break end
          if not rowClear(world, apexR, c + dir, tc) then break end
          -- land at apex height
          if standable(world, tc, apexR) then push(tc, apexR) end
          -- or drop from the apex corridor down to a landing
          local lr = fallLanding(world, tc, apexR)
          if lr then push(tc, lr) end
        end
      end
    end

    -- level jumps across gaps (small hop, no net rise): the body crosses at
    -- one tile above the start row, so require that corridor clear.
    for _, dir in ipairs({ -1, 1 }) do
      for gap = 1, MAX_JUMP_ACROSS do
        local tc = c + dir * gap
        if tc < 1 or tc > world.cols then break end
        if not rowClear(world, r - 1, c + dir, tc) then break end
        if standable(world, tc, r) then push(tc, r) end
        local lr = fallLanding(world, tc, r - 1)
        if lr then push(tc, lr) end
      end
    end
  end

  return visited, key
end

-- Validate that from the spawn tile every target tile is reachable.
-- spawn/targets in tile coords {c=, r=} (feet positions).
function reach.validate(world, spawn, targets)
  local visited, key = reach.flood(world, spawn.c, spawn.r)
  local failed = {}
  for _, t in ipairs(targets) do
    local ok = false
    -- accept if the exact tile or a neighbor column is reached (doors are 2 wide)
    for dc = -1, 1 do
      for dr = -2, 1 do
        if visited[key(t.c + dc, t.r + dr)] then ok = true break end
      end
      if ok then break end
    end
    if not ok then failed[#failed + 1] = t end
  end
  return #failed == 0, failed, visited
end

reach.MAX_JUMP_ACROSS = MAX_JUMP_ACROSS
reach.MAX_JUMP_UP = MAX_JUMP_UP
reach.standable = standable

return reach
