-- Headless generation test: runs under plain luajit (no LÖVE).
-- Usage: luajit tests/gen_test.lua [numSeeds]
-- Asserts:
--  * every chunk parses to 20 rows
--  * room generation across seeds/archetypes/biomes rarely falls back
--  * ITERATION-02 ACCEPTANCE: for traversal-required archetypes, the exit is
--    NEVER walk-reachable (no flat-ground path) unless the safety fallback
--    fired -- and fallbacks stay rare.
package.path = "./?.lua;" .. package.path

local registry = require("src.game.registry")
local generator = require("src.game.levelgen.generator")
local reachability = require("src.game.levelgen.reachability")
local RNG = require("src.core.rng")

local CHUNK_FILES = { "basic", "platforming", "combat", "special", "expansion", "vertical" }
for _, file in ipairs(CHUNK_FILES) do
  local defs = require("src.content.chunks." .. file)
  for _, d in ipairs(defs) do registry.add("chunk", d) end
end

-- 1. every chunk parses
local nChunks = 0
for _, chunk in ipairs(registry.all("chunk")) do
  local ok, err = pcall(generator.parseMap, chunk.map)
  if not ok then
    print("FAIL parse " .. chunk.id .. ": " .. tostring(err))
    os.exit(1)
  end
  nChunks = nChunks + 1
end
print(("OK: %d chunks parse"):format(nChunks))

-- 2. generation across seeds
local numSeeds = tonumber(arg and arg[1]) or 60
local TRAVERSAL_REQUIRED = {
  traversal = true, combat = true, treasure = true, shop = true, rest = true, event = true,
}
local types = { "traversal", "combat", "arena", "treasure", "rest", "shop", "boss", "event", "entry" }
local biomes = { "ashfall", "duskmire", "ember_sea", "hollow_spire" }
local total, fallbacks, attemptsSum = 0, 0, 0
local walkableLeaks = 0
local formCounts = {}

for seed = 1, numSeeds do
  local rng = RNG.new(seed * 7919 + 13)
  for _, t in ipairs(types) do
    for _, b in ipairs(biomes) do
      for depth = 0, 8, 4 do
        local room = generator.generate({
          roomType = t, biomeId = b, depth = depth, rng = rng,
          streamName = "test:" .. t .. b .. depth,
        })
        total = total + 1
        attemptsSum = attemptsSum + room.attempts
        formCounts[room.form] = (formCounts[room.form] or 0) + 1
        if room.usedFallback then
          fallbacks = fallbacks + 1
        elseif TRAVERSAL_REQUIRED[t] and room.form ~= "vdescent" then
          -- acceptance test: exit must NOT be walk-reachable
          local visited, key = reachability.walkFlood(room.world, room.spawn.c, room.spawn.r)
          local e = room.exit
          for dc = -1, 1 do
            for dr = -2, 1 do
              if visited[key(e.c + dc, e.r + dr)] then
                walkableLeaks = walkableLeaks + 1
                print(("WALKABLE LEAK: type=%s biome=%s depth=%d seed=%d"):format(t, b, depth, seed))
                goto continue
              end
            end
          end
          ::continue::
        end
      end
    end
  end
end

local formStr = {}
for f, n in pairs(formCounts) do formStr[#formStr + 1] = f .. "=" .. n end
print(("OK: %d rooms generated, %d fallbacks (%.1f%%), avg attempts %.2f, forms: %s")
  :format(total, fallbacks, fallbacks / total * 100, attemptsSum / total,
    table.concat(formStr, " ")))

if walkableLeaks > 0 then
  print(("FAIL: %d rooms have a walkable path to the exit"):format(walkableLeaks))
  os.exit(1)
end
if fallbacks / total > 0.02 then
  print("FAIL: fallback rate too high — chunks or validator need fixing")
  os.exit(1)
end
print("ALL GENERATION TESTS PASSED")
