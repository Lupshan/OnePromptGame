-- Victory: the Spire falls quiet. Stats, spoils, and back to the ash.
local state = require("src.core.state")
local draw = require("src.render.draw")
local input = require("src.core.input")
local music = require("src.audio.music")
local particles = require("src.render.particles")
local util = require("src.core.util")
local save = require("src.core.save")

local victory = {}

local VICTORY_BONUS = 60

function victory:enter(run)
  self.run = run
  self.t = 0
  if require("src.core.config").debug.smoke then print("[smoke] VICTORY") end
  save.stat("victories", 1)
  local st = save.get().stats
  st.bestBiome = math.max(st.bestBiome or 0, run.biomeIndex)
  if run.time and (not st.bestTime or run.time < st.bestTime) then
    st.bestTime = run.time
  end
  save.addCinders(VICTORY_BONUS)
  run.cindersEarned = run.cindersEarned + VICTORY_BONUS
  save.write()
  particles.clear()
  music.setMood({
    key = "victory", root = 130.8, scale = "majorPent", tempo = 60,
    layers = { "drone", "melody", "shimmer", "arp" }, intensity = 0.9, seed = 21,
  })
end

function victory:update(dt)
  self.t = self.t + dt
  particles.update(dt)
  local sw, sh = love.graphics.getDimensions()
  if love.math.random() < dt * 20 then
    particles.spawn({
      x = love.math.random() * sw, y = sh + 10,
      vx = (love.math.random() - 0.5) * 24, vy = -(30 + love.math.random() * 50),
      life = 5 + love.math.random() * 4, size = 1 + love.math.random() * 2, sizeEnd = 0.2,
      color = { 1, 0.8 + love.math.random() * 0.2, 0.4 }, kind = "ember", gravity = -6, drag = 0.4,
      glow = 8,
    })
  end
  if self.t > 1.2 and (input.pressed("confirm") or input.pressed("cancel")) then
    input.consume("confirm") input.consume("cancel")
    state.switch("title")
  end
end

function victory:draw()
  local sw, sh = love.graphics.getDimensions()
  draw.gradientV(0, 0, sw, sh, { 0.06, 0.05, 0.12 }, { 0.16, 0.12, 0.2 })
  draw.glow(sw / 2, sh * 0.3, 320, 1, 0.85, 0.45, 0.2 + math.sin(self.t) * 0.05)
  particles.draw()

  local a = math.min(1, self.t)
  draw.textCentered("THE SPIRE FALLS QUIET", sw / 2, sh * 0.18, 32, { 1, 0.95, 0.8, a })
  draw.textCentered("what burned is finally allowed to rest", sw / 2, sh * 0.18 + 46, 13,
    { 1, 0.9, 0.7, a * 0.7 })

  local run = self.run
  if run then
    local lines = {
      ("cleared in %s"):format(util.formatTime(run.time)),
      ("%d kills  ·  %d rooms"):format(run.kills, run.depth),
      ("%d cinders earned (+%d victory tribute)"):format(run.cindersEarned, VICTORY_BONUS),
      ("as %s  ·  seed %d"):format(run.character and run.character.name or "?", run.seed),
    }
    for i, line in ipairs(lines) do
      local la = util.clamp(self.t - 0.4 - i * 0.25, 0, 1)
      draw.textCentered(line, sw / 2, sh * 0.42 + (i - 1) * 28, 15, { 1, 1, 1, 0.85 * la })
    end
  end

  if self.t > 1.2 then
    draw.textCentered("[SPACE] return to the ash", sw / 2, sh - 70, 13,
      { 1, 1, 1, 0.55 + math.sin(self.t * 2) * 0.15 })
  end
end

state.register("victory", victory)
return victory
