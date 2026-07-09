-- Generative music: several synthesized layers looping at mutually prime
-- lengths, so the combined texture evolves for minutes without perceived
-- repetition. Each biome supplies a mood (scale, root, tempo, palette of
-- layer styles); themes are rendered once and cached.
local synth = require("src.audio.synth")
local save = require("src.core.save")

local music = {}
local enabled = true
local current = nil   -- { sources = {...}, key = ... }
local cache = {}
local currentVol = 1
local RATE = synth.RATE

-- Scales as semitone offsets.
local SCALES = {
  minor = { 0, 2, 3, 5, 7, 8, 10 },
  dorian = { 0, 2, 3, 5, 7, 9, 10 },
  phrygian = { 0, 1, 3, 5, 7, 8, 10 },
  majorPent = { 0, 2, 4, 7, 9 },
  minorPent = { 0, 3, 5, 7, 10 },
  lydian = { 0, 2, 4, 6, 7, 9, 11 },
}

local function noteFreq(root, semis)
  return root * (2 ^ (semis / 12))
end

-- Render one looping layer into SoundData.
-- layer = { kind, measures, root, scale, tempo, volume, rng }
local function renderLayer(layer)
  local beatsPerMeasure = 4
  local beatLen = 60 / layer.tempo
  local totalLen = layer.measures * beatsPerMeasure * beatLen
  local n = math.floor(totalLen * RATE)
  local data = love.sound.newSoundData(n, RATE, 16, 1)
  local scale = SCALES[layer.scale] or SCALES.minor
  local rng = layer.rng
  local vol = layer.volume or 0.3

  local function addTone(startT, freq, dur, amp, harmonics, attack, release)
    local s0 = math.floor(startT * RATE)
    local sn = math.floor(dur * RATE)
    attack = attack or 0.02
    release = release or math.min(0.35, dur * 0.5)
    for i = 0, sn - 1 do
      local idx = s0 + i
      if idx >= n then idx = idx - n end -- wrap: seamless loop
      local t = i / RATE
      local env = 1
      if t < attack then env = t / attack end
      local tail = dur - release
      if t > tail then env = env * math.max(0, 1 - (t - tail) / release) end
      local s = 0
      for h = 1, #harmonics do
        s = s + math.sin(t * freq * h * math.pi * 2) * harmonics[h]
      end
      local v = data:getSample(idx) + s * env * amp
      if v > 1 then v = 1 elseif v < -1 then v = -1 end
      data:setSample(idx, v)
    end
  end

  if layer.kind == "drone" then
    -- two slowly beating detuned sines on the root, full loop length
    local f = layer.root / 2
    addTone(0, f, totalLen, vol * 0.8, { 1, 0.4, 0.15 }, 1.5, 1.5)
    addTone(0, f * 1.003, totalLen, vol * 0.5, { 1, 0.3 }, 2, 2)
    addTone(0, f * 1.5, totalLen, vol * 0.25, { 1 }, 3, 3)
  elseif layer.kind == "bass" then
    -- sparse low pulses on strong beats
    for m = 0, layer.measures - 1 do
      for b = 0, beatsPerMeasure - 1 do
        if b == 0 or (b == 2 and rng:random() < 0.5) then
          local deg = (rng:random() < 0.75) and 1 or rng:random(1, 3)
          local f = noteFreq(layer.root / 2, scale[deg])
          addTone((m * beatsPerMeasure + b) * beatLen, f, beatLen * 0.9,
            vol, { 1, 0.5, 0.2 }, 0.008, beatLen * 0.4)
        end
      end
    end
  elseif layer.kind == "arp" then
    -- eighth-note arpeggio with rests
    local half = beatLen / 2
    for m = 0, layer.measures - 1 do
      local pattern = {}
      for i = 1, 4 do pattern[i] = rng:random(1, #scale) end
      for step = 0, beatsPerMeasure * 2 - 1 do
        if rng:random() < 0.62 then
          local deg = pattern[(step % 4) + 1]
          local f = noteFreq(layer.root * 2, scale[deg])
          addTone((m * beatsPerMeasure) * beatLen + step * half, f, half * 0.85,
            vol * 0.55, { 1, 0.25 }, 0.004, half * 0.5)
        end
      end
    end
  elseif layer.kind == "melody" then
    -- long, sparse lead notes
    local t = 0
    local total = layer.measures * beatsPerMeasure * beatLen
    local deg = rng:random(1, #scale)
    while t < total - beatLen do
      if rng:random() < 0.7 then
        deg = deg + rng:random(-2, 2)
        while deg < 1 do deg = deg + #scale end
        while deg > #scale do deg = deg - #scale end
        local oct = rng:random() < 0.25 and 4 or 2
        local dur = beatLen * rng:random(2, 4)
        local f = noteFreq(layer.root * oct, scale[deg])
        addTone(t, f, math.min(dur, total - t), vol * 0.5, { 1, 0.3, 0.1 }, 0.05, dur * 0.5)
        t = t + dur
      else
        t = t + beatLen * rng:random(1, 3)
      end
    end
  elseif layer.kind == "shimmer" then
    -- rare high sparkles
    local total = layer.measures * beatsPerMeasure * beatLen
    local t = rng:random() * 2
    while t < total - 1 do
      local deg = rng:random(1, #scale)
      local f = noteFreq(layer.root * 4, scale[deg])
      addTone(t, f, 1.2, vol * 0.3, { 1 }, 0.15, 0.9)
      t = t + 1.5 + rng:random() * 4
    end
  elseif layer.kind == "pulse" then
    -- rhythmic noise-free tick using short sine blips (percussive-ish)
    for m = 0, layer.measures - 1 do
      for b = 0, beatsPerMeasure * 2 - 1 do
        if b % 2 == 0 or rng:random() < 0.3 then
          local f = (b % 4 == 0) and 160 or 220
          addTone((m * beatsPerMeasure) * beatLen + b * beatLen / 2, f, 0.06,
            vol * ((b % 4 == 0) and 0.8 or 0.4), { 1, 0.6 }, 0.002, 0.04)
        end
      end
    end
  end

  return data
end

-- mood = { key, root (Hz), scale, tempo, layers = {kindA, kindB...},
--          intensity (0..1), seed }
function music.setMood(mood)
  if not enabled then return end
  if current and current.key == mood.key then return end
  music.stop()

  local theme = cache[mood.key]
  if not theme then
    local ok, built = pcall(function()
      local sources = {}
      -- coprime measure counts keep the texture evolving
      local measureChoices = { 5, 7, 9, 11, 13 }
      local layers = mood.layers or { "drone", "bass", "arp", "shimmer" }
      local rngSeed = mood.seed or 1
      for i, kind in ipairs(layers) do
        local rng = love.math.newRandomGenerator(rngSeed + i * 7919)
        local data = renderLayer({
          kind = kind,
          measures = measureChoices[((i - 1) % #measureChoices) + 1],
          root = mood.root or 110,
          scale = mood.scale or "minor",
          tempo = mood.tempo or 70,
          volume = 0.28 * (mood.intensity or 1),
          rng = rng,
        })
        local src = love.audio.newSource(data)
        src:setLooping(true)
        sources[#sources + 1] = src
      end
      return sources
    end)
    if not ok then enabled = false return end
    theme = built
    cache[mood.key] = theme
  end

  current = { sources = theme, key = mood.key }
  music.applyVolume()
  for _, s in ipairs(theme) do pcall(function() s:play() end) end
end

function music.applyVolume()
  if not current then return end
  local v = (save.get().settings.musicVolume or 0.7) * currentVol
  for _, s in ipairs(current.sources) do
    pcall(function() s:setVolume(v) end)
  end
end

function music.setIntensity(v)
  currentVol = v
  music.applyVolume()
end

function music.stop()
  if current then
    for _, s in ipairs(current.sources) do pcall(function() s:stop() end) end
    current = nil
  end
end

function music.load()
  if not (love.audio and love.sound) then enabled = false return end
  local ok = pcall(function()
    local d = love.sound.newSoundData(8, RATE, 16, 1)
    love.audio.newSource(d)
  end)
  enabled = ok
end

function music.currentKey()
  return current and current.key or nil
end

return music
