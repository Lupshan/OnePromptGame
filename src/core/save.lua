-- Persistent profile: meta currency, unlocks, stats, settings.
-- IMPORTANT (design rule): unlocks only ever WIDEN the content pool.
-- Nothing in here may grant permanent power to a run.
local util = require("src.core.util")

local save = {}
local FILE = "profile.lua"

local defaults = {
  version = 1,
  cinders = 0,              -- meta currency
  totalCinders = 0,
  unlocked = {},            -- set of unlock ids (boons, characters, chunks...)
  seen = {},                -- content the player has encountered (codex)
  stats = {
    runs = 0,
    victories = 0,
    kills = 0,
    deaths = 0,
    bestBiome = 0,
    bestTime = nil,
    playTime = 0,
  },
  settings = {
    screenShake = 1.0,
    musicVolume = 0.7,
    sfxVolume = 0.8,
    showTimer = false,
  },
  lastCharacter = nil,
}

local data

local function ensure()
  if not data then save.load() end
  return data
end

function save.load()
  data = util.deepcopy(defaults)
  if love and love.filesystem and love.filesystem.getInfo(FILE) then
    local ok, chunk = pcall(love.filesystem.load, FILE)
    if ok and chunk then
      local ok2, loaded = pcall(chunk)
      if ok2 and type(loaded) == "table" then
        -- merge over defaults so new fields appear on old profiles
        local function merge(dst, src)
          for k, v in pairs(src) do
            if type(v) == "table" and type(dst[k]) == "table" then merge(dst[k], v)
            else dst[k] = v end
          end
        end
        merge(data, loaded)
      end
    end
  end
  return data
end

function save.write()
  if not data then return end
  if love and love.filesystem then
    love.filesystem.write(FILE, "return " .. util.serialize(data))
  end
end

function save.get() return ensure() end

-- Unlocks --------------------------------------------------------------------

function save.isUnlocked(id)
  return ensure().unlocked[id] == true
end

function save.unlock(id)
  local d = ensure()
  if d.unlocked[id] then return false end
  d.unlocked[id] = true
  save.write()
  return true
end

function save.markSeen(id)
  local d = ensure()
  if not d.seen[id] then
    d.seen[id] = true
  end
end

-- Currency --------------------------------------------------------------------

function save.addCinders(n)
  local d = ensure()
  d.cinders = d.cinders + n
  d.totalCinders = d.totalCinders + math.max(0, n)
  save.write()
end

function save.spendCinders(n)
  local d = ensure()
  if d.cinders < n then return false end
  d.cinders = d.cinders - n
  save.write()
  return true
end

function save.stat(key, delta)
  local d = ensure()
  d.stats[key] = (d.stats[key] or 0) + (delta or 1)
end

return save
