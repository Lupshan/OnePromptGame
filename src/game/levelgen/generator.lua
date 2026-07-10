-- Room generator, iteration-02 shape: a room is a TRAVERSAL CHALLENGE.
--
-- Forms:
--  * horizontal: chunks side by side, doors carved at each end at the height
--    the end chunks ask for (low/mid/high) -- no continuous ground shelf.
--  * vclimb / vdescent: chunks stacked vertically, exit above or below the
--    spawn, Celeste-screen style.
--
-- Every generated room is validated twice (see reachability.lua): the exit
-- must be reachable by the base movement kit, and -- for traversal-required
-- archetypes -- must NOT be reachable by walking/falling alone. Rooms that
-- fail are regenerated; after maxRegenAttempts a known-safe flat corridor is
-- used (the anti-softlock net; it is intentionally the only walkable layout
-- left in the game and it should essentially never appear).
--
-- MOBILITY CALIBRATION DECISION (iteration 02): generation is calibrated on
-- the BASE movement kit and validated against it, forever. Mobility boons
-- (air dashes, glide, extra jumps...) only add fluidity and optional skips;
-- they are hard-capped in run.lua and never REQUIRED by any room. This keeps
-- reachability provable and skips intentional rather than accidental.
local physics = require("src.game.physics")
local registry = require("src.game.registry")
local reachability = require("src.game.levelgen.reachability")
local config = require("src.core.config")
local save = require("src.core.save")

local generator = {}

local H = config.levelgen.roomHeight
local WALL = 3
local VWIDTH = 24 -- authored width of vertical chunks

local CHAR_TILE = {
  ["#"] = physics.SOLID,
  ["."] = physics.EMPTY,
  ["-"] = physics.PLATFORM,
  ["^"] = physics.SPIKE,
}

-- Door geometry per height tag: feet row + carved rows (3 tall).
local DOOR = {
  low = { feet = H - 3 },
  mid = { feet = 11 },
  high = { feet = 5 },
}

-- Which archetypes must be impossible to cross by walking alone.
local REQUIRE_TRAVERSAL = {
  traversal = true, combat = true, vclimb = true,
  treasure = true, shop = true, rest = true, event = true,
}

-- Parse a chunk's ASCII map into { rows, width }.
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
-- A seam is traversable if the next chunk's entry is at or BELOW the
-- previous chunk's exit (falling is free); rising across a seam is only
-- allowed when the tags match exactly (the chunks themselves provide it).
local function heightsCompatible(prevExit, nextEntry)
  return (heightRank[nextEntry] or 1) <= (heightRank[prevExit] or 1)
end

-- Pick a horizontal sequence of chunks for a room archetype.
local function pickSequence(rng, streamName, archetype, biomeId, difficulty, count)
  local seq = {}
  local entries = chunkPool("entry", biomeId, difficulty)
  local exits = chunkPool("exit", biomeId, difficulty)
  seq[1] = rng:pick(streamName, entries)

  local isSpecial = archetype ~= "traversal" and archetype ~= "combat"
    and archetype ~= "entry" and archetype ~= "arena" and archetype ~= "boss"

  local prevExit = seq[1] and seq[1].exit or "low"
  for i = 2, count - 1 do
    local kind = "platform"
    if archetype == "arena" then kind = "arena" end
    -- specials embed their prop chunk in the middle slot
    if isSpecial and i == math.ceil(count / 2) then kind = archetype end
    local pool = chunkPool(kind, biomeId, isSpecial and 3 or difficulty)
    local fits = {}
    for _, chunk in ipairs(pool) do
      if heightsCompatible(prevExit, chunk.entry or "low") then fits[#fits + 1] = chunk end
    end
    local pick = rng:pick(streamName, #fits > 0 and fits or pool)
    seq[i] = pick
    prevExit = pick and pick.exit or "low"
  end

  local exitFits = {}
  for _, chunk in ipairs(exits) do
    if heightsCompatible(prevExit, chunk.entry or "low") then exitFits[#exitFits + 1] = chunk end
  end
  seq[count] = rng:pick(streamName, #exitFits > 0 and exitFits or exits)

  if archetype == "boss" then
    local specials = chunkPool("boss", biomeId, 3)
    local bossChunk = rng:pick(streamName, specials) or seq[2]
    local lowEntries, lowExits = {}, {}
    for _, chunk in ipairs(entries) do
      if heightsCompatible(chunk.exit or "low", bossChunk.entry or "low") then
        lowEntries[#lowEntries + 1] = chunk
      end
    end
    for _, chunk in ipairs(exits) do
      if heightsCompatible(bossChunk.exit or "low", chunk.entry or "low") then
        lowExits[#lowExits + 1] = chunk
      end
    end
    seq = { rng:pick(streamName, #lowEntries > 0 and lowEntries or entries),
            bossChunk,
            rng:pick(streamName, #lowExits > 0 and lowExits or exits) }
  end

  for i = 1, #seq do
    if not seq[i] then seq[i] = registry.all("chunk")[1] end
  end
  return seq
end

-- Collect a marker into the right list.
local function addMarker(markers, ch, wc, r)
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

local function newMarkers()
  return { enemies = {}, chests = {}, lights = {}, heals = {}, shops = {}, altars = {} }
end

-- Carve a 3-tall door whose feet land on `feet`, in the left or right wall,
-- with a guaranteed landing shelf just inside.
local function carveDoorAt(world, side, feet)
  local totalW = world.cols
  local cLo, cHi, shelfLo, shelfHi
  if side == "left" then
    cLo, cHi = 1, WALL + 1
    shelfLo, shelfHi = 1, WALL + 2
  else
    cLo, cHi = totalW - WALL, totalW
    shelfLo, shelfHi = totalW - WALL - 1, totalW
  end
  -- landing shelf: solid under the doorway (2 rows thick)
  for c = shelfLo, shelfHi do
    for r = feet + 1, math.min(feet + 2, world.rows) do
      world:set(c, r, physics.SOLID)
    end
    -- headroom + feet clear of spikes
    for r = feet - 2, feet do
      if world:get(c, r) == physics.SPIKE then world:set(c, r, physics.EMPTY) end
    end
  end
  for r = feet - 2, feet do
    for c = cLo, cHi do world:set(c, r, physics.EMPTY) end
  end
  return { c = side == "left" and (WALL + 1) or (totalW - WALL), r = feet }
end

-- Assemble a horizontal room from chosen chunks.
local function assemble(seq)
  local totalW = WALL * 2
  local parsed = {}
  for i, chunk in ipairs(seq) do
    local rows, width = parseMap(chunk.map)
    parsed[i] = { rows = rows, width = width, def = chunk }
    totalW = totalW + width
  end

  local world = physics.newWorld(totalW, H)
  local markers = newMarkers()

  for r = 1, H do
    for c = 1, WALL do world:set(c, r, physics.SOLID) end
    for c = totalW - WALL + 1, totalW do world:set(c, r, physics.SOLID) end
  end
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
          addMarker(markers, ch, wc, r)
        end
      end
    end
    cx = cx + p.width
  end

  local entryTag = seq[1].entry or "low"
  local exitTag = seq[#seq].exit or "low"
  local spawn = carveDoorAt(world, "left", DOOR[entryTag].feet)
  local exit = carveDoorAt(world, "right", DOOR[exitTag].feet)
  return world, markers, spawn, exit
end

-- Assemble a vertical room (stacked chunks). direction: "climb" | "descent".
local function assembleVertical(seq, direction)
  local levels = #seq
  local totalH = levels * H
  local totalW = VWIDTH + WALL * 2
  local world = physics.newWorld(totalW, totalH)
  local markers = newMarkers()

  for r = 1, totalH do
    for c = 1, WALL do world:set(c, r, physics.SOLID) end
    for c = totalW - WALL + 1, totalW do world:set(c, r, physics.SOLID) end
  end
  for c = 1, totalW do
    world:set(c, 1, physics.SOLID)
    for r = totalH - 1, totalH do world:set(c, r, physics.SOLID) end
  end

  -- seq[1] is the TOP chunk
  for i, chunk in ipairs(seq) do
    local rows, width = parseMap(chunk.map)
    local rOff = (i - 1) * H
    for r = 1, H do
      local line = rows[r]
      for ci = 1, VWIDTH do
        local ch = (ci <= #line) and line:sub(ci, ci) or "."
        local wc = WALL + ci
        local wr = rOff + r
        if wr > 1 and wr < totalH - 1 then
          local tile = CHAR_TILE[ch]
          if tile then
            world:set(wc, wr, tile)
          else
            world:set(wc, wr, physics.EMPTY)
            addMarker(markers, ch, wc, wr)
          end
        end
        _ = width
      end
    end
  end

  local bottomFeet = totalH - 3
  local topFeet = 5
  local spawn, exit
  if direction == "climb" then
    spawn = carveDoorAt(world, "left", bottomFeet)
    exit = carveDoorAt(world, "right", topFeet)
    -- approach ledges: bridge from the central ladder to the top-right door
    for _, ledge in ipairs({ { row = topFeet + 2, c1 = totalW - 13, c2 = totalW - 11 },
                             { row = topFeet + 1, c1 = totalW - 9, c2 = totalW - 7 } }) do
      for c = ledge.c1, ledge.c2 do
        if world:get(c, ledge.row) == physics.EMPTY then
          world:set(c, ledge.row, physics.PLATFORM)
        end
      end
    end
  else
    spawn = carveDoorAt(world, "left", topFeet)
    exit = carveDoorAt(world, "right", bottomFeet)
  end
  return world, markers, spawn, exit
end

-- Project a marker to the feet row a player would stand at.
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

-- Known-safe fallback: flat corridor. Walkable BY DESIGN -- this is the
-- anti-softlock emergency net, not a room the generator should ever need.
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
  local markers = newMarkers()
  for c = 10, width - 10, 12 do
    for cc = c, math.min(c + 3, width - 4) do
      world:set(cc, H - 5, physics.PLATFORM)
    end
    markers.lights[#markers.lights + 1] = { x = (c + 1.5) * physics.TILE, y = (H - 7) * physics.TILE }
  end
  local spawn = carveDoorAt(world, "left", H - 3)
  local exit = carveDoorAt(world, "right", H - 3)
  return world, markers, spawn, exit
end

-- Public API -------------------------------------------------------------------
-- params: { roomType (archetype), biomeId, depth, rng, streamName, form }
-- Archetypes: traversal | combat | arena | treasure | shop | rest | event
--             | entry | boss  (traversal may take a vertical form)
-- Returns { world, markers, spawn, exit, form, usedFallback, attempts }
function generator.generate(params)
  local rng = params.rng
  local streamName = params.streamName or "levelgen"
  local archetype = params.roomType
  local difficulty = math.min(3, 1 + math.floor((params.depth or 0) / 3))

  -- pick the room form
  local form = params.form or "horizontal"
  if archetype == "traversal" and not params.form then
    local roll = rng:random(streamName, 1, 100)
    if roll <= 25 and #chunkPool("vclimb", params.biomeId, difficulty) >= 2 then
      form = "vclimb"
    elseif roll <= 40 and #chunkPool("vdescent", params.biomeId, difficulty) >= 2 then
      form = "vdescent"
    end
  end

  local requireTraversal = REQUIRE_TRAVERSAL[archetype] or false
  if form == "vdescent" then requireTraversal = false end

  local counts = (archetype == "combat" or archetype == "arena")
    and config.levelgen.chunksCombat or config.levelgen.chunksPlatforming
  local nChunks = rng:random(streamName, counts[1], counts[2])
  if archetype == "entry" or archetype == "boss" then nChunks = 3 end
  if archetype ~= "traversal" and archetype ~= "combat"
     and archetype ~= "entry" and archetype ~= "arena" and archetype ~= "boss" then
    nChunks = 4 -- entry, platform, special, exit
  end

  local lastSeqIds
  for attempt = 1, config.levelgen.maxRegenAttempts do
    local ok, world, markers, spawn, exit
    if form == "vclimb" or form == "vdescent" then
      local pool = chunkPool(form, params.biomeId, difficulty)
      local levels = rng:random(streamName, 2, 3)
      local stack = {}
      for _ = 1, levels do
        stack[#stack + 1] = rng:pick(streamName, pool)
      end
      if #pool == 0 then
        form = "horizontal"
      else
        ok, world, markers, spawn, exit = pcall(assembleVertical, stack,
          form == "vclimb" and "climb" or "descent")
      end
    end
    if form == "horizontal" then
      local seq = pickSequence(rng, streamName, archetype, params.biomeId, difficulty, nChunks)
      lastSeqIds = {}
      for i, chunk in ipairs(seq) do lastSeqIds[i] = chunk.id end
      ok, world, markers, spawn, exit = pcall(assemble, seq)
    end

    if ok then
      local targets = { exit }
      for _, m in ipairs(markers.chests) do targets[#targets + 1] = groundTarget(world, m) end
      for _, m in ipairs(markers.heals) do targets[#targets + 1] = groundTarget(world, m) end
      for _, m in ipairs(markers.shops) do targets[#targets + 1] = groundTarget(world, m) end
      for _, m in ipairs(markers.altars) do targets[#targets + 1] = groundTarget(world, m) end
      local valid = reachability.validate(world, spawn, targets,
        { requireTraversal = requireTraversal })
      if valid then
        return {
          world = world, markers = markers, spawn = spawn, exit = exit,
          form = form, usedFallback = false, attempts = attempt,
        }
      end
    end
  end

  local world, markers, spawn, exit = fallbackRoom()
  return { world = world, markers = markers, spawn = spawn, exit = exit,
           form = "horizontal", usedFallback = true, lastSeqIds = lastSeqIds,
           attempts = config.levelgen.maxRegenAttempts }
end

generator.parseMap = parseMap
generator.fallbackRoom = fallbackRoom
generator.DOOR = DOOR

return generator
