-- Named sound effects. Each name maps to a recipe *generator* so every
-- trigger sounds slightly different (pitch/length jitter) -- no machine-gun
-- repetition. A few variants per name are pre-rendered and cycled.
local synth = require("src.audio.synth")
local save = require("src.core.save")

local sfx = {}
local enabled = true
local cache = {} -- name -> { SoundData, ... }
local VARIANTS = 4

local function jitter(v, amount)
  return v * (1 + (love.math.random() * 2 - 1) * amount)
end

-- Recipe generators -----------------------------------------------------------
local recipes = {}

recipes.jump = function()
  return { wave = "square", freq = jitter(240, 0.08), freqEnd = jitter(520, 0.08),
    duty = 0.4, attack = 0.002, sustain = 0.05, decay = 0.09, volume = 0.32 }
end

recipes.land = function()
  return { wave = "noise", freq = 200, noiseColor = 0.85, attack = 0.001,
    sustain = 0.02, decay = 0.09, volume = 0.4, punch = 0.6 }
end

recipes.dash = function()
  return { wave = "noise", freq = 800, noiseColor = 0.45, attack = 0.004,
    sustain = 0.05, decay = 0.12, volume = 0.3 }
end

recipes.swing = function()
  return { wave = "noise", freq = 900, noiseColor = 0.3, attack = 0.002,
    sustain = 0.02, decay = 0.07, volume = 0.22 }
end

recipes.hit = function()
  return {
    { wave = "square", freq = jitter(160, 0.15), freqEnd = 60, duty = 0.3,
      attack = 0.001, sustain = 0.03, decay = 0.1, volume = 0.4, punch = 0.8 },
    { wave = "noise", freq = 400, noiseColor = 0.5, attack = 0.001,
      sustain = 0.015, decay = 0.06, volume = 0.3 },
  }
end

recipes.kill = function()
  return {
    { wave = "square", freq = jitter(300, 0.1), freqEnd = 40, duty = 0.25,
      attack = 0.001, sustain = 0.06, decay = 0.22, volume = 0.42, punch = 0.9 },
    { wave = "noise", freq = 300, noiseColor = 0.6, attack = 0.001,
      sustain = 0.04, decay = 0.18, volume = 0.32 },
  }
end

recipes.bolt = function()
  return { wave = "saw", freq = jitter(920, 0.1), freqEnd = jitter(340, 0.1),
    attack = 0.002, sustain = 0.04, decay = 0.1, volume = 0.26, vibratoDepth = 30, vibratoSpeed = 40 }
end

recipes.playerHurt = function()
  return {
    { wave = "square", freq = 220, freqEnd = 90, duty = 0.5, attack = 0.001,
      sustain = 0.06, decay = 0.16, volume = 0.45, punch = 0.7 },
    { wave = "noise", freq = 200, noiseColor = 0.7, attack = 0.001,
      sustain = 0.05, decay = 0.12, volume = 0.3 },
  }
end

recipes.heal = function()
  return { wave = "sine", freq = jitter(520, 0.05), freqEnd = jitter(880, 0.05),
    attack = 0.01, sustain = 0.08, decay = 0.18, volume = 0.3 }
end

recipes.pickup = function()
  return { wave = "square", freq = jitter(880, 0.06), freqEnd = jitter(1320, 0.06),
    duty = 0.5, attack = 0.001, sustain = 0.03, decay = 0.08, volume = 0.24 }
end

recipes.cinder = function()
  return { wave = "sine", freq = jitter(1180, 0.08), freqEnd = jitter(1700, 0.08),
    attack = 0.001, sustain = 0.02, decay = 0.1, volume = 0.2 }
end

recipes.boon = function()
  return {
    { wave = "sine", freq = 440, freqEnd = 660, attack = 0.01, sustain = 0.12, decay = 0.3, volume = 0.28 },
    { wave = "sine", freq = 660, freqEnd = 990, attack = 0.05, sustain = 0.1, decay = 0.3, volume = 0.2 },
  }
end

recipes.door = function()
  return { wave = "triangle", freq = 180, freqEnd = 300, attack = 0.01,
    sustain = 0.1, decay = 0.25, volume = 0.3 }
end

recipes.uiMove = function()
  return { wave = "square", freq = 600, duty = 0.5, attack = 0.001,
    sustain = 0.015, decay = 0.03, volume = 0.14 }
end

recipes.uiSelect = function()
  return { wave = "square", freq = 700, freqEnd = 1050, duty = 0.5,
    attack = 0.001, sustain = 0.03, decay = 0.07, volume = 0.2 }
end

recipes.uiDeny = function()
  return { wave = "square", freq = 240, freqEnd = 180, duty = 0.3,
    attack = 0.001, sustain = 0.05, decay = 0.08, volume = 0.2 }
end

recipes.enemyShoot = function()
  return { wave = "saw", freq = jitter(500, 0.12), freqEnd = jitter(260, 0.12),
    attack = 0.002, sustain = 0.03, decay = 0.09, volume = 0.22 }
end

recipes.explosion = function()
  return {
    { wave = "noise", freq = 100, noiseColor = 0.88, attack = 0.002,
      sustain = 0.1, decay = 0.4, volume = 0.5, punch = 1 },
    { wave = "square", freq = 90, freqEnd = 30, duty = 0.5, attack = 0.001,
      sustain = 0.08, decay = 0.3, volume = 0.4 },
  }
end

recipes.bossRoar = function()
  return {
    { wave = "saw", freq = 90, freqEnd = 55, attack = 0.03, sustain = 0.35,
      decay = 0.5, volume = 0.45, vibratoDepth = 14, vibratoSpeed = 11 },
    { wave = "noise", freq = 100, noiseColor = 0.9, attack = 0.05,
      sustain = 0.3, decay = 0.45, volume = 0.3 },
  }
end

recipes.burn = function()
  return { wave = "noise", freq = 300, noiseColor = 0.55, attack = 0.004,
    sustain = 0.05, decay = 0.14, volume = 0.16 }
end

recipes.zap = function()
  return { wave = "square", freq = jitter(1400, 0.2), freqEnd = jitter(500, 0.2),
    duty = 0.15, attack = 0.001, sustain = 0.02, decay = 0.08, volume = 0.22, crunch = 0.5 }
end

recipes.shield = function()
  return { wave = "sine", freq = 300, freqEnd = 480, attack = 0.005,
    sustain = 0.06, decay = 0.2, volume = 0.3, vibratoDepth = 20, vibratoSpeed = 30 }
end

recipes.unlock = function()
  return {
    { wave = "sine", freq = 523, freqEnd = 523, attack = 0.01, sustain = 0.08, decay = 0.2, volume = 0.25 },
    { wave = "sine", freq = 784, freqEnd = 784, attack = 0.09, sustain = 0.1, decay = 0.3, volume = 0.25 },
    { wave = "sine", freq = 1046, freqEnd = 1046, attack = 0.18, sustain = 0.14, decay = 0.4, volume = 0.22 },
  }
end

-- Engine ------------------------------------------------------------------------

local function build(name)
  local gen = recipes[name]
  if not gen then return nil end
  local variants = {}
  for i = 1, VARIANTS do
    local r = gen()
    local ok, data = pcall(function()
      if r[1] then return synth.layered(r) end
      return synth.render(r)
    end)
    if ok then variants[i] = data end
  end
  return variants
end

function sfx.load()
  if not (love.audio and love.sound) then enabled = false return end
  -- probe: some headless environments have no audio device
  local ok = pcall(function()
    local d = love.sound.newSoundData(8, 22050, 16, 1)
    local s = love.audio.newSource(d)
    s:setVolume(0)
  end)
  enabled = ok
  if not enabled then return end
  for name in pairs(recipes) do
    cache[name] = build(name)
  end
end

function sfx.play(name, pitch, vol)
  if not enabled then return end
  local variants = cache[name]
  if not variants or #variants == 0 then return end
  local data = variants[love.math.random(1, #variants)]
  local okSrc, src = pcall(love.audio.newSource, data)
  if not okSrc then enabled = false return end
  src:setVolume((vol or 1) * (save.get().settings.sfxVolume or 0.8))
  src:setPitch((pitch or 1) * (0.96 + love.math.random() * 0.08))
  pcall(function() src:play() end)
end

function sfx.isEnabled() return enabled end

return sfx
