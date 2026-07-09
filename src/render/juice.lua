-- Game feel toolkit: screen shake, hitstop, flashes. All effects are short
-- and damped -- flair supports readability, never fights it.
local save = require("src.core.save")

local juice = {}

local shakeAmp, shakeTime, shakeDur = 0, 0, 0
local hitstopTime = 0
local flash = { r = 1, g = 1, b = 1, a = 0 }
local slowmo = { factor = 1, time = 0 }

function juice.shake(amp, dur)
  local mult = save.get().settings.screenShake or 1
  amp = amp * mult
  if amp > shakeAmp then
    shakeAmp, shakeDur = amp, dur or 0.25
    shakeTime = shakeDur
  end
end

function juice.hitstop(t)
  hitstopTime = math.max(hitstopTime, t)
end

function juice.flashScreen(r, g, b, a)
  flash.r, flash.g, flash.b, flash.a = r, g, b, a
end

function juice.slow(factor, dur)
  slowmo.factor = factor
  slowmo.time = dur
end

-- Returns the dt the game world should use this frame (0 during hitstop).
function juice.filterDt(dt)
  if hitstopTime > 0 then
    hitstopTime = hitstopTime - dt
    return 0
  end
  if slowmo.time > 0 then
    slowmo.time = slowmo.time - dt
    return dt * slowmo.factor
  end
  return dt
end

function juice.update(dt, camera)
  if shakeTime > 0 then
    shakeTime = shakeTime - dt
    local decay = shakeTime / shakeDur
    local a = shakeAmp * decay * decay
    camera.shakeX = (love.math.random() * 2 - 1) * a
    camera.shakeY = (love.math.random() * 2 - 1) * a
  else
    camera.shakeX, camera.shakeY = 0, 0
  end
  if flash.a > 0 then
    flash.a = math.max(0, flash.a - dt * 3.5)
  end
end

-- Draw over everything, in screen space.
function juice.drawOverlay()
  if flash.a > 0 then
    love.graphics.setColor(flash.r, flash.g, flash.b, flash.a)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
    love.graphics.setColor(1, 1, 1, 1)
  end
end

function juice.reset()
  shakeAmp, shakeTime, shakeDur = 0, 0, 0
  hitstopTime = 0
  flash.a = 0
  slowmo.factor, slowmo.time = 1, 0
end

return juice
