-- Room generator: picks a chunk sequence for the room type, assembles the
-- tile grid, populates spawns/props, then PROVES traversability with the
-- reachability validator. Fails -> reroll with different chunks; after
-- maxRegenAttempts -> emit a known-safe fallback layout. No softlocks, ever.
local physics = require("src.game.physics")
local registry = require("src.game.registry")
local reachability = require("src.game.levelgen.reachability")
local config = require("src.core.config")
local save = require("src.core.save")

local generator = {}

local H = config.levelgen.roomHeight

local CHAR_TILE = {
  ["#"] = physics.SOLID,
  ["."] = physics.EMPTY,
  ["-"] = physics.PLATFORM,
  ["^"] = physics.SPIKE,
}

-- Parse a chunk's ASCII map into { rows, width, markers }.
local function parseMap(str)
  local rows = {}
  for line in str:gmatch("[^\n]+") do
    if line:match("%S") then rows[#rows + 1] = line end
  end
  assert(#rows == H, "chunk map must be exactly " .. H .. " rows, got " .. #rows)
  local width = 0
  for _, line in ipairs(rows) do width = math.max(width, #line) end
  return rows, width
end

-- Chunk pool for a slot.
local function chunkPool(kind, biomeId, difficulty)
  local pool = {}
  for _, chunk in ipairs(registry.all("chunk")) do
    local ok = chunk.kind == kind
    if ok and chunk.biomes and not (function()
      for _, b in ipairs(chunk.biomes) do if b == biomeId then return true end end
      return false
    end)() then ok = false end
    if ok and chunk.unlock and not save.isUnlocked(chunk.unlock) then ok = false end
    if ok and (chunk.difficulty or 1) > difficulty then ok = false end
    if ok then pool[#pool + 1] = chunk end
  end
  return pool
end

local heightRank = { low = 1, mid = 2, high = 3 }
local function heightsCompatible(a, b)
  return math.abs((heightRank[a] or 1) - (heightRank[b] or 1)) <= 1
end

-- Pick a sequence of chunks for a room.
local function pickSequence(rng, streamName, roomType, biomeId, difficulty, count)
  local middleKind = roomType == "combat" and "combat" or "platform"
  local seq = {}

  local entries = chunkPool("entry", biomeId, difficulty)
  local exits = chunkPool("exit", biomeId, difficulty)
  seq[1] = rng:pick(streamName, entries)

  local prevExit = seq[1] and seq[1].exit or "low"
  for i = 2, count - 1 do
    local kind = middleKind
    if roomType == "combat" and rng:chance(streamName, 0.3) then kind = "platform" end
    if roomType == "platform" and rng:chance(streamName, 0.22) then kind = "combat" end
    local pool = chunkPool(kind, biomeId, difficulty)
    local fits = {}
    for _, chunk in ipairs(pool) do
      if heightsCompatible(prevExit, chunk.entry or "low") then fits[#fits + 1] = chunk end
    end
    local pick = rng:pick(streamName, #fits > 0 and fits or pool)
    seq[i] = pick
    prevExit = pick and pick.exit or "low"
  end

  -- last chunk: exit, preceded by something that lands low
  local exitFits = {}
  for _, chunk in ipairs(exits) do
    if heightsCompatible(prevExit, chunk.entry or "low") then exitFits[#exitFits + 1] = chunk end
  end
  seq[count] = rng:pick(streamName, #exitFits > 0 and exitFits or exits)

  -- special rooms replace the middle with their special chunk
  if roomType ~= "combat" and roomType ~= "platform" and roomType ~= "boss" then
    local specials = chunkPool(roomType, biomeId, 3)
    local mid = math.ceil(count / 2)
    local s = rng:pick(streamName, specials)
    if s then seq[mid] = s end
  elseif roomType == "boss" then
    local specials = chunkPool("boss", biomeId, 3)
    seq = { rng:pick(streamName, chunkPool("entry", biomeId, 1)),
            rng:pick(streamName, specials) or seq[2],
            rng:pick(streamName, chunkPool("exit", biomeId, 1)) }
  end

  -- guard: fill any nil slot with whatever exists
  for i = 1, #seq do
    if not seq[i] then
      seq[i] = registry.all("chunk")[1]
    end
  end
  return seq
end

-- Assemble chosen chunks into a world plus marker lists.
local function assemble(seq)
  -- door walls: 3 columns each side
  local WALL = 3
  local totalW = WALL * 2
  local parsed = {}
  for i, chunk in ipairs(seq) do
    local rows, width = parseMap(chunk.map)
    parsed[i] = { rows = rows, width = width, def = chunk }
    totalW = totalW + width
  end

  local world = physics.newWorld(totalW, H)
  local markers = { enemies = {}, chests = {}, lights = {}, heals = {}, shops = {}, altars = {} }

  -- side walls
  for r = 1, H do
    for c = 1, WALL do world:set(c, r, physics.SOLID) end
    for c = totalW - WALL + 1, totalW do world:set(c, r, physics.SOLID) end
  end
  -- ceiling
  for c = 1, totalW do world:set(c, 1, physics.SOLID) end

  local cx = WALL
  for _, p in ipairs(parsed) do
    for r = 1, H do
      local line = p.rows[r]
      for ci = 1, p.width do
        local ch = ci <= #line and line:sub(ci, ci) or "."
        local wc = cx + ci
        local tile = CHAR_TILE[ch]
        if tile then
          world:set(wc, r, tile)
        else
          world:set(wc, r, physics.EMPTY)
          local px = (wc - 0.5) * physics.TILE
          local py = (r - 0.5) * physics.TILE
          if ch == "e" then
            markers.enemies[#markers.enemies + 1] = { x = px, y = r * physics.TILE, flying = false, c = wc, r = r }
          elseif ch == "f" then
            markers.enemies[#markers.enemies + 1] = { x = px, y = py, flying = true, c = wc, r = r }
          elseif ch == "c" then
            markers.chests[#markers.chests + 1] = { x = px, y = r * physics.TILE, c = wc, r = r }
          elseif ch == "*" then
            markers.lights[#markers.lights + 1] = { x = px, y = py }
          elseif ch == "h" then
            markers.heals[#markers.heals + 1] = { x = px, y = r * physics.TILE, c = wc, r = r }
          elseif ch == "s" then
            markers.shops[#markers.shops + 1] = { x = px, y = r * physics.TILE, c = wc, r = r }
          elseif ch == "n" then
            markers.altars[#markers.altars + 1] = { x = px, y = r * physics.TILE, c = wc, r = r }
          end
        end
      end
    end
    cx = cx + p.width
  end

  -- carve doors (3 tall) at floor level in both walls. Chunk floors put
  -- their top surface at row H-2, so feet stand on row H-3.
  local doorRows = { H - 5, H - 4, H - 3 }
  local function carveDoor(cLo, cHi)
    for _, r in ipairs(doorRows) do
      for c = cLo, cHi do world:set(c, r, physics.EMPTY) end
    end
  end
  -- ensure solid ground through the doorway
  local function shelf(cLo, cHi)
    for c = cLo, cHi do
      for r = H - 2, H do world:set(c, r, physics.SOLID) end
    end
  end
  shelf(1, WALL + 2)
  shelf(totalW - WALL - 1, totalW)
  carveDoor(1, WALL + 1)
  carveDoor(totalW - WALL, totalW)

  local spawn = { c = WALL + 1, r = H - 3 }
  local exit = { c = totalW - WALL, r = H - 3 }
  return world, markers, spawn, exit
end

-- Project a marker to the feet row a player would stand at: scan down for
-- the first supported position (markers are often drawn floating in maps).
local function groundTarget(world, m)
  for r = m.r, math.min(m.r + 6, world.rows - 1) do
    local below = world:get(m.c, r + 1)
    if (below == physics.SOLID or below == physics.PLATFORM)
       and world:get(m.c, r) ~= physics.SOLID then
      return { c = m.c, r = r }
    end
  end
  return { c = m.c, r = m.r }
end

-- Known-safe fallback: flat corridor with a few platforms. By construction
-- always traversable.
local function fallbackRoom(width)
  width = width or 50
  local world = physics.newWorld(width, H)
  for c = 1, width do
    world:set(c, 1, physics.SOLID)
    for r = H - 2, H do world:set(c, r, physics.SOLID) end
  end
  for r = 1, H do
    for c = 1, 3 do world:set(c, r, physics.SOLID) end
    for c = width - 2, width do world:set(c, r, physics.SOLID) end
  end
  local doorRows = { H - 5, H - 4, H - 3 }
  for _, r in ipairs(doorRows) do
    for c = 1, 4 do world:set(c, r, physics.EMPTY) end
    for c = width - 3, width do world:set(c, r, physics.EMPTY) end
  end
  local markers = { enemies = {}, chests = {}, lights = {}, heals = {}, shops = {}, altars = {} }
  for c = 10, width - 10, 12 do
    for cc = c, math.min(c + 3, width - 4) do
      world:set(cc, H - 5, physics.PLATFORM) -- top row 15: single jump from the floor
    end
    markers.lights[#markers.lights + 1] = { x = (c + 1.5) * physics.TILE, y = (H - 7) * physics.TILE }
    markers.enemies[#markers.enemies + 1] = { x = (c + 2) * physics.TILE, y = (H - 2) * physics.TILE, flying = false, c = c + 2, r = H - 3 }
  end
  return world, markers, { c = 4, r = H - 3 }, { c = width - 3, r = H - 3 }
end

-- Public: generate a validated room.
-- params: { roomType, biomeId, depth, rng, streamName }
-- Returns { world, markers, spawn, exit, usedFallback, attempts }
function generator.generate(params)
  local rng = params.rng
  local streamName = params.streamName or "levelgen"
  local difficulty = math.min(3, 1 + math.floor((params.depth or 0) / 3))
  local counts = params.roomType == "combat" and config.levelgen.chunksCombat
    or config.levelgen.chunksPlatforming
  local nChunks = rng:random(streamName, counts[1], counts[2])
  if params.roomType ~= "combat" and params.roomType ~= "platform" then
    nChunks = 3
  end

  for attempt = 1, config.levelgen.maxRegenAttempts do
    local seq = pickSequence(rng, streamName, params.roomType, params.biomeId, difficulty, nChunks)
    local ok, world, markers, spawn, exit = pcall(assemble, seq)
    if ok then
      local targets = { exit }
      for _, m in ipairs(markers.chests) do targets[#targets + 1] = groundTarget(world, m) end
      for _, m in ipairs(markers.heals) do targets[#targets + 1] = groundTarget(world, m) end
      for _, m in ipairs(markers.shops) do targets[#targets + 1] = groundTarget(world, m) end
      for _, m in ipairs(markers.altars) do targets[#targets + 1] = groundTarget(world, m) end
      local valid = reachability.validate(world, spawn, targets)
      if valid then
        return {
          world = world, markers = markers, spawn = spawn, exit = exit,
          usedFallback = false, attempts = attempt,
          chunkIds = (function()
            local ids = {}
            for _, chunk in ipairs(seq) do ids[#ids + 1] = chunk.id end
            return ids
          end)(),
        }
      end
    end
  end

  local world, markers, spawn, exit = fallbackRoom()
  return { world = world, markers = markers, spawn = spawn, exit = exit,
           usedFallback = true, attempts = config.levelgen.maxRegenAttempts,
           chunkIds = { "fallback" } }
end

generator.parseMap = parseMap
generator.fallbackRoom = fallbackRoom

return generator
