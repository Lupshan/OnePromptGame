-- Seeded RNG streams. Every piece of run-affecting generation pulls from a
-- named stream derived from the run seed, so the same seed reproduces the
-- same run regardless of what cosmetic randomness happens in between.
-- Cosmetic randomness (particles, wobble) uses the shared `vfx` stream or
-- love.math.random and never touches generation streams.

local RNG = {}
RNG.__index = RNG

local function newGenerator(seed)
  if love and love.math then
    return love.math.newRandomGenerator(seed)
  end
  -- Headless fallback (tests under plain luajit): xorshift-ish LCG wrapper.
  local state = seed % 2147483647
  if state <= 0 then state = state + 2147483646 end
  local gen = {}
  local function nextInt()
    state = (state * 16807) % 2147483647
    return state
  end
  function gen:random(a, b)
    local r = nextInt() / 2147483647
    if a == nil then return r end
    if b == nil then return 1 + math.floor(r * a) end
    return a + math.floor(r * (b - a + 1))
  end
  function gen:setSeed(s) state = s % 2147483647 if state <= 0 then state = state + 2147483646 end end
  return gen
end

-- Simple string hash for deriving sub-seeds ("levelgen:room7" etc).
local function hashString(s)
  local h = 5381
  for i = 1, #s do
    h = (h * 33 + s:byte(i)) % 4294967296
  end
  return h
end

function RNG.new(seed)
  local self = setmetatable({}, RNG)
  self.seed = seed
  self.streams = {}
  return self
end

-- Reset every stream whose name starts with prefix: the next use replays
-- the exact same sequence. Used to regenerate a room identically when the
-- death model restarts it (hard-but-fair: the layout is learnable).
function RNG:resetPrefix(prefix)
  for name in pairs(self.streams) do
    if name:sub(1, #prefix) == prefix then
      self.streams[name] = nil
    end
  end
end

-- Get (or create) a named deterministic stream.
function RNG:stream(name)
  local s = self.streams[name]
  if not s then
    s = newGenerator((self.seed + hashString(name)) % 4294967296 + 1)
    self.streams[name] = s
  end
  return s
end

-- Convenience wrappers over a stream --------------------------------------

function RNG:random(name, a, b)
  return self:stream(name):random(a, b)
end

function RNG:chance(name, p)
  return self:stream(name):random() < p
end

function RNG:range(name, lo, hi) -- float in [lo, hi)
  return lo + self:stream(name):random() * (hi - lo)
end

function RNG:pick(name, list)
  if #list == 0 then return nil end
  return list[self:stream(name):random(1, #list)]
end

-- Weighted pick: items are {weight=..., ...} or pass weights via fn.
function RNG:pickWeighted(name, list, weightFn)
  local total = 0
  for i = 1, #list do
    total = total + (weightFn and weightFn(list[i]) or list[i].weight or 1)
  end
  if total <= 0 then return nil end
  local r = self:stream(name):random() * total
  for i = 1, #list do
    local w = weightFn and weightFn(list[i]) or list[i].weight or 1
    r = r - w
    if r <= 0 then return list[i] end
  end
  return list[#list]
end

-- In-place Fisher-Yates shuffle.
function RNG:shuffle(name, list)
  local s = self:stream(name)
  for i = #list, 2, -1 do
    local j = s:random(1, i)
    list[i], list[j] = list[j], list[i]
  end
  return list
end

RNG.hashString = hashString

return RNG
