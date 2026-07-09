-- Death screen: what the run was, what it left behind.
local state = require("src.core.state")
local draw = require("src.render.draw")
local input = require("src.core.input")
local music = require("src.audio.music")
local util = require("src.core.util")
local save = require("src.core.save")

local gameover = {}

function gameover:enter(run)
  self.run = run
  self.t = 0
  if require("src.core.config").debug.smoke then print("[smoke] GAMEOVER") end
  music.setMood({
    key = "gameover", root = 82, scale = "minor", tempo = 46,
    layers = { "drone", "melody" }, intensity = 0.7, seed = 13,
  })
end

function gameover:update(dt)
  self.t = self.t + dt
  if self.t < 0.8 then return end
  if input.pressed("confirm") then
    input.consume("confirm")
    state.switch("charselect")
  elseif input.pressed("map") then
    state.switch("kiln")
  elseif input.pressed("cancel") or input.pressed("pause") then
    state.switch("title")
  end
end

function gameover:draw()
  local sw, sh = love.graphics.getDimensions()
  draw.gradientV(0, 0, sw, sh, { 0.04, 0.02, 0.04 }, { 0.1, 0.04, 0.05 })

  local a = math.min(1, self.t * 1.4)
  draw.textCentered("THE ASH TAKES YOU BACK", sw / 2, sh * 0.2, 30, { 1, 0.85, 0.75, a })

  local run = self.run
  if run then
    local biome = run:biome()
    local lines = {
      ("fell in %s  ·  depth %d"):format(biome.name, run.depth),
      ("%d kills  ·  %s survived"):format(run.kills, util.formatTime(run.time)),
      ("%d cinders carried home"):format(run.cindersEarned),
      ("seed %d"):format(run.seed),
    }
    for i, line in ipairs(lines) do
      local la = util.clamp(self.t * 1.4 - i * 0.25, 0, 1)
      draw.textCentered(line, sw / 2, sh * 0.36 + (i - 1) * 26, 14, { 1, 1, 1, 0.8 * la })
    end

    -- boons held
    local boonsSys = require("src.game.boons")
    local names = {}
    for _, owned in ipairs(run.boons) do
      local def = boonsSys.def(owned.id)
      if def then names[#names + 1] = def.name end
    end
    if #names > 0 then
      local la = util.clamp(self.t * 1.4 - 1.4, 0, 1)
      draw.textCentered("carried: " .. table.concat(names, " · "), sw / 2, sh * 0.36 + 118, 10,
        { 1, 1, 1, 0.4 * la })
    end
  end

  local d = save.get()
  draw.textCentered(("the Kiln holds %d cinders"):format(d.cinders),
    sw / 2, sh * 0.66, 13, { 0.75, 0.88, 1, 0.85 })

  if self.t > 0.8 then
    draw.textCentered("[SPACE] rise again      [TAB] the Kiln      [ESC] title",
      sw / 2, sh - 60, 13, { 1, 1, 1, 0.55 + math.sin(self.t * 2) * 0.15 })
  end
end

state.register("gameover", gameover)
return gameover
