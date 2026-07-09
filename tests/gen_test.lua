-- Headless generation test: runs under plain luajit (no LÖVE).
-- Usage: luajit tests/gen_test.lua [numSeeds]
-- Asserts: every chunk parses, and room generation across seeds/types/biomes
-- validates reachability without excessive fallbacks.
package.path = "./?.lua;" .. package.path

local registry = require("src.game.registry")
local generator = require("src.game.levelgen.generator")
local RNG = require("src.core.rng")

-- register chunk content only (enemies/boons not needed here)
local function loadChunks()
  for _, file in ipairs({ "basic", "platforming", "combat", "special" }) do
    local defs = require("src.content.chunks." .. file)
    for _, d in ipairs(defs) do registry.add("chunk", d) end
  end
end

loadChunks()

-- 1. every chunk parses to 20 rows
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
local types = { "combat", "platform", "treasure", "rest", "shop", "boss", "event" }
local biomes = { "ashfall", "duskmire", "hollow_spire" }
local total, fallbacks, attemptsSum = 0, 0, 0
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
        if room.usedFallback then fallbacks = fallbacks + 1 end
      end
    end
  end
end
print(("OK: %d rooms generated, %d fallbacks (%.1f%%), avg attempts %.2f")
  :format(total, fallbacks, fallbacks / total * 100, attemptsSum / total))
if fallbacks / total > 0.02 then
  print("FAIL: fallback rate too high — chunks or validator need fixing")
  os.exit(1)
end
print("ALL GENERATION TESTS PASSED")
