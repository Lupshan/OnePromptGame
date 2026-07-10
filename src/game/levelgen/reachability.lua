-- Reachability validation, two models:
--  * full flood: conservative player movement (single jump only -- no dash,
--    no double jump, no wall jump). Exit must be reachable => no softlocks.
--  * walk flood: walking and falling ONLY (no jumps, not even 1-tile steps).
--    For traversal rooms the exit must NOT be walk-reachable: this is the
--    iteration-02 acceptance test ("the exit must never be reachable by
--    walking on flat ground") enforced at generation time.
-- A room that fails either requirement is regenerated.
local physics = require("src.game.physics")

local reach = {}

-- Movement envelope of the FULL BASE KIT (iteration 03): jump + double
-- jump + dash. Physical maxima: jump ~3.2 tiles up; double jump ~5.7 up;
-- dash adds ~3.5 tiles of horizontal reach. Conservative model: rise up to
-- 5 rows, and a horizontal budget of 9 columns that shrinks 1 per row
-- risen. Distances are column counts (a 4-tile air gap = 5 columns).
-- Chunks may therefore REQUIRE double jumps and dashes; boon mobility
-- (extra charges, glide) stays unmodeled -- it only buys fluidity/skips.
local MAX_JUMP_UP = 5
local MAX_JUMP_ACROSS = 9

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

    -- jumps: rise, then drift to the target at apex. The rise may happen at
    -- the start column OR at any column along the way -- that's a diagonal
    -- jump beside an overhang, which pure "up-then-across" wrongly rejects.
    -- Rising costs horizontal reach (maxAcross shrinks with height).
    for up = 1, MAX_JUMP_UP do
      local apexR = r - up
      local maxAcross = MAX_JUMP_ACROSS - up
      -- straight up (through platforms)
      if columnClear(world, c, math.max(1, apexR - 1), r - 1)
         and standable(world, c, apexR) then
        push(c, apexR)
      end
      for _, dir in ipairs({ -1, 1 }) do
        for gap = 1, maxAcross do
          local tc = c + dir * gap
          if tc < 1 or tc > world.cols then break end
          for riseOff = 0, gap do
            local cc = c + dir * riseOff
            -- low drift toward the rise column (feet stay near takeoff height)
            if riseOff == 0 or rowClear(world, r - 1, c + dir, cc) then
              -- full vertical clearance at the rise column
              if columnClear(world, cc, math.max(1, apexR - 1), r - 1) then
                -- drift at apex from the rise column to the target
                if cc == tc or rowClear(world, apexR, cc + dir, tc) then
                  if standable(world, tc, apexR) then push(tc, apexR) end
                  local lr = fallLanding(world, tc, apexR)
                  if lr then push(tc, lr) end
                  break
                end
              end
            end
          end
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

    -- wall-jump chimneys: two facing solid walls, 2-4 clear columns apart,
    -- climbable while walls persist. Each wall jump gains ~2.7 rows, so a
    -- short break (<= 2 rows) in ONE wall is crossable while the other is
    -- solid; the climb dies when both walls are broken at once or a break
    -- exceeds 2 rows. Landings: any standable inside the shaft, and the top
    -- of a wall the moment it ends.
    do
      local wl, wr
      for k = 1, 3 do
        if not wl and world:get(c - k, r) == physics.SOLID
           and world:get(c - k, r - 1) == physics.SOLID then wl = c - k end
        if not wr and world:get(c + k, r) == physics.SOLID
           and world:get(c + k, r - 1) == physics.SOLID then wr = c + k end
      end
      if wl and wr and (wr - wl - 1) >= 2 and (wr - wl - 1) <= 4 then
        local rr = r - 2
        local gapL, gapR = 0, 0
        while rr >= 2 do
          local wallL = world:get(wl, rr) == physics.SOLID
          local wallR = world:get(wr, rr) == physics.SOLID
          gapL = wallL and 0 or (gapL + 1)
          gapR = wallR and 0 or (gapR + 1)
          -- a wall's top is a landing right where it ends
          if gapL == 1 and standable(world, wl, rr) then push(wl, rr) end
          if gapR == 1 and standable(world, wr, rr) then push(wr, rr) end
          if (gapL > 0 and gapR > 0) or gapL > 2 or gapR > 2 then break end
          -- interior must stay passable to keep climbing
          local interiorOk = true
          for ci = wl + 1, wr - 1 do
            if not bodyFits(world, ci, rr) then interiorOk = false break end
          end
          if not interiorOk then break end
          for ci = wl + 1, wr - 1 do
            if standable(world, ci, rr) then push(ci, rr) end
          end
          rr = rr - 1
        end
      end
    end
  end

  return visited, key
end

-- Walk-only flood: what a player could reach WITHOUT ever jumping.
-- Moves: walk along standable tiles, fall off edges. No step-ups.
function reach.walkFlood(world, startC, startR)
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
      if standable(world, nc, r) then push(nc, r) end
      if bodyFits(world, nc, r) then
        local lr = fallLanding(world, nc, r)
        if lr then push(nc, lr) end
      end
    end
  end
  return visited, key
end

local function anyNear(visited, key, t)
  for dc = -1, 1 do
    for dr = -2, 1 do
      if visited[key(t.c + dc, t.r + dr)] then return true end
    end
  end
  return false
end

-- Validate a room.
--  spawn/targets in tile coords {c=, r=} (feet positions); targets[1] must
--  be the exit. opts.requireTraversal: additionally reject the room if the
--  exit is reachable by walking/falling alone.
function reach.validate(world, spawn, targets, opts)
  opts = opts or {}
  local visited, key = reach.flood(world, spawn.c, spawn.r)
  local failed = {}
  for _, t in ipairs(targets) do
    if not anyNear(visited, key, t) then failed[#failed + 1] = t end
  end
  if #failed > 0 then return false, failed, visited end

  if opts.requireTraversal and targets[1] then
    local wVisited, wKey = reach.walkFlood(world, spawn.c, spawn.r)
    if anyNear(wVisited, wKey, targets[1]) then
      return false, { targets[1] }, visited, "walkable"
    end
  end
  return true, failed, visited
end

reach.MAX_JUMP_ACROSS = MAX_JUMP_ACROSS
reach.MAX_JUMP_UP = MAX_JUMP_UP
reach.standable = standable

return reach
