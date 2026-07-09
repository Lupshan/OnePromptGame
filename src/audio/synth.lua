-- Procedural audio synthesis: sfxr-style recipe -> SoundData. No sound
-- files exist anywhere; everything audible is generated here at runtime.
local synth = {}

local RATE = 22050

-- Recipe fields (all optional unless noted):
--   wave: "square" | "saw" | "sine" | "noise" | "triangle"
--   freq (required): start frequency in Hz
--   freqEnd: end frequency (linear slide); freqCurve: exponent of the slide
--   attack, sustain, decay: envelope segment lengths in seconds
--   duty: square duty cycle (0..1)
--   vibratoDepth (Hz), vibratoSpeed (Hz)
--   noiseColor: 0 (white) .. 1 (darker, low-passed)
--   crunch: bit-crush amount 0..1
--   punch: extra gain at note start
--   volume
function synth.render(r)
  local attack = r.attack or 0.005
  local sustain = r.sustain or 0.08
  local decay = r.decay or 0.12
  local dur = attack + sustain + decay
  local n = math.floor(dur * RATE)
  if n <= 0 then n = 1 end
  local data = love.sound.newSoundData(n, RATE, 16, 1)

  local wave = r.wave or "square"
  local freq = r.freq or 440
  local freqEnd = r.freqEnd or freq
  local curve = r.freqCurve or 1
  local duty = r.duty or 0.5
  local vol = r.volume or 0.8
  local vibD = r.vibratoDepth or 0
  local vibS = r.vibratoSpeed or 8
  local punch = r.punch or 0

  local phase = 0
  local lpState = 0
  local lp = r.noiseColor or 0

  for i = 0, n - 1 do
    local t = i / RATE
    local prog = i / n

    -- envelope
    local env
    if t < attack then env = t / attack
    elseif t < attack + sustain then
      env = 1 + punch * (1 - (t - attack) / sustain)
    else
      local d = (t - attack - sustain) / decay
      env = 1 - d
      if env < 0 then env = 0 end
      env = env * env -- smooth tail
    end

    -- frequency slide + vibrato
    local f = freq + (freqEnd - freq) * (prog ^ curve)
    if vibD > 0 then f = f + math.sin(t * vibS * math.pi * 2) * vibD end
    phase = phase + f / RATE
    local ph = phase % 1

    local s
    if wave == "square" then
      s = ph < duty and 1 or -1
    elseif wave == "saw" then
      s = ph * 2 - 1
    elseif wave == "sine" then
      s = math.sin(ph * math.pi * 2)
    elseif wave == "triangle" then
      s = ph < 0.5 and (ph * 4 - 1) or (3 - ph * 4)
    else -- noise
      s = love.math.random() * 2 - 1
      if lp > 0 then
        lpState = lpState + (s - lpState) * (1 - lp * 0.92)
        s = lpState
      end
    end

    if r.crunch and r.crunch > 0 then
      local steps = 2 + math.floor((1 - r.crunch) * 30)
      s = math.floor(s * steps) / steps
    end

    local v = s * env * vol
    if v > 1 then v = 1 elseif v < -1 then v = -1 end
    data:setSample(i, v)
  end
  return data
end

-- Layer several recipes into one SoundData (max length wins).
function synth.layered(recipes)
  local datas = {}
  local maxLen = 0
  for i = 1, #recipes do
    datas[i] = synth.render(recipes[i])
    maxLen = math.max(maxLen, datas[i]:getSampleCount())
  end
  local out = love.sound.newSoundData(maxLen, RATE, 16, 1)
  for i = 0, maxLen - 1 do
    local s = 0
    for j = 1, #datas do
      if i < datas[j]:getSampleCount() then
        s = s + datas[j]:getSample(i)
      end
    end
    if s > 1 then s = 1 elseif s < -1 then s = -1 end
    out:setSample(i, s)
  end
  return out
end

-- Render a musical tone with simple harmonics + soft envelope (for music).
-- opts: freq, dur, volume, harmonics {amp1, amp2, ...}, attack, release, wave
function synth.tone(opts)
  local dur = opts.dur or 1
  local n = math.floor(dur * RATE)
  local data = love.sound.newSoundData(n, RATE, 16, 1)
  local freq = opts.freq
  local vol = opts.volume or 0.5
  local harm = opts.harmonics or { 1, 0.35, 0.18, 0.08 }
  local attack = opts.attack or 0.02
  local release = opts.release or math.min(0.4, dur * 0.5)

  for i = 0, n - 1 do
    local t = i / RATE
    local env = 1
    if t < attack then env = t / attack end
    local tailStart = dur - release
    if t > tailStart then
      local d = (t - tailStart) / release
      env = env * (1 - d)
    end
    local s = 0
    for h = 1, #harm do
      s = s + math.sin(t * freq * h * math.pi * 2) * harm[h]
    end
    local v = s * env * vol
    if v > 1 then v = 1 elseif v < -1 then v = -1 end
    data:setSample(i, v)
  end
  return data
end

synth.RATE = RATE

return synth
