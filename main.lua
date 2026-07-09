-- CENDRE — a nervous roguelike jumper. Everything procedural: no image,
-- sound or font files. Entry point wires the state machine and global
-- systems together.
local state = require("src.core.state")
local input = require("src.core.input")
local draw = require("src.render.draw")
local sfx = require("src.audio.sfx")
local music = require("src.audio.music")
local save = require("src.core.save")
local juice = require("src.render.juice")
local config = require("src.core.config")

local smoke = { frames = 0 }

function love.load(args)
  love.graphics.setDefaultFilter("nearest", "nearest")
  love.graphics.setLineStyle("smooth")
  save.load()
  draw.load()
  sfx.load()
  music.load()
  input.init()

  -- states register themselves
  require("src.states.title")
  require("src.states.rungame")
  require("src.states.gameover")
  require("src.states.victory")
  require("src.states.charselect")

  -- CLI: love . --seed 12345 jumps straight into a run with that seed
  local seed
  for i, a in ipairs(args or {}) do
    if a == "--seed" and args[i + 1] then seed = tonumber(args[i + 1]) end
  end
  if seed then
    state.switch("rungame", { seed = seed })
  else
    state.switch("title")
  end
end

function love.update(dt)
  dt = math.min(dt, 1 / 30) -- spiral-of-death guard
  save.get().stats.playTime = save.get().stats.playTime + dt
  state.update(dt)
  input.endFrame()

  if config.debug.smoke then
    smoke.frames = smoke.frames + 1
    if smoke.script then smoke.script(smoke.frames) end
    if smoke.frames >= (tonumber(os.getenv("CENDRE_SMOKE_FRAMES") or "") or 180) then
      if config.debug.screenshotDir then
        love.graphics.captureScreenshot(function(id)
          id:encode("png", "smoke.png")
          love.event.quit()
        end)
      else
        love.event.quit()
      end
    end
  end
end

function love.draw()
  state.draw()
  juice.drawOverlay()
end

function love.keypressed(key)
  input.keypressed(key)
  state.keypressed(key)
end

function love.keyreleased(key) state.keyreleased(key) end
function love.gamepadpressed(j, b)
  input.gamepadpressed(j, b)
  state.gamepadpressed(j, b)
end
function love.gamepadreleased(j, b) state.gamepadreleased(j, b) end
function love.joystickadded(j) input.gamepadAdded(j) end
function love.resize(w, h) state.resize(w, h) end
function love.textinput(t) state.textinput(t) end

function love.quit()
  save.write()
end

-- Smoke-mode hook: states can install an input script here for automated runs.
function love.smokeScript(fn) smoke.script = fn end
