-- Title screen: the name in fire, a handful of options.
local state = require("src.core.state")
local draw = require("src.render.draw")
local input = require("src.core.input")
local particles = require("src.render.particles")
local music = require("src.audio.music")
local sfx = require("src.audio.sfx")
local save = require("src.core.save")
local config = require("src.core.config")
local locale = require("src.core.locale")
local version = require("src.core.version")

local title = {}

local OPTIONS = { "begin", "kiln", "codex", "options", "help", "quit" }

function title:enter()
  self.t = 0
  self.sel = 1
  particles.clear()
  music.setMood({
    key = "title", root = 98, scale = "phrygian", tempo = 52,
    layers = { "drone", "shimmer", "melody" }, intensity = 0.8, seed = 7,
  })
  if config.debug.smoke then
    self.smokeStart = 0.5
  end
end

function title:update(dt)
  self.t = self.t + dt
  particles.update(dt)

  -- drifting embers
  if love.math.random() < dt * 14 then
    local sw, sh = love.graphics.getDimensions()
    particles.spawn({
      x = love.math.random() * sw, y = sh + 10,
      vx = (love.math.random() - 0.5) * 20, vy = -(16 + love.math.random() * 34),
      life = 6 + love.math.random() * 5, size = 1 + love.math.random() * 2.2, sizeEnd = 0.2,
      color = { 1, 0.5 + love.math.random() * 0.3, 0.2 }, kind = "ember", gravity = -4, drag = 0.4,
      glow = 7,
    })
  end

  if self.smokeStart then
    self.smokeStart = self.smokeStart - dt
    if self.smokeStart <= 0 then
      self.smokeStart = nil
      state.switch("rungame", { seed = tonumber(os.getenv("CENDRE_SEED") or "") })
      return
    end
  end

  if input.pressed("up") then
    self.sel = self.sel > 1 and self.sel - 1 or #OPTIONS
    sfx.play("uiMove")
  elseif input.pressed("down") then
    self.sel = self.sel < #OPTIONS and self.sel + 1 or 1
    sfx.play("uiMove")
  elseif input.pressed("confirm") then
    input.consume("confirm")
    sfx.play("uiSelect")
    local opt = OPTIONS[self.sel]
    if opt == "begin" then
      state.switch("charselect")
    elseif opt == "kiln" then
      state.switch("kiln")
    elseif opt == "codex" then
      state.switch("codex")
    elseif opt == "options" then
      state.switch("options", "title")
    elseif opt == "help" then
      state.switch("help")
    elseif opt == "quit" then
      love.event.quit()
    end
  end
end

function title:draw()
  local sw, sh = love.graphics.getDimensions()

  -- sky
  draw.gradientV(0, 0, sw, sh, { 0.05, 0.03, 0.07 }, { 0.14, 0.06, 0.07 })
  draw.glow(sw / 2, sh * 0.34, sw * 0.4, 1, 0.4, 0.15, 0.14 + math.sin(self.t) * 0.03)

  particles.draw()

  -- wordmark
  local pulse = 0.85 + math.sin(self.t * 1.4) * 0.1
  draw.glow(sw / 2, sh * 0.3, 300, 1, 0.35, 0.15, 0.25 * pulse)
  draw.textCentered("C E N D R E", sw / 2, sh * 0.24, 64, { 1, 0.93, 0.85, 1 })
  draw.textCentered(locale.t("ui.title.tagline"), sw / 2, sh * 0.24 + 84, 13, { 1, 0.75, 0.55, 0.75 })

  -- menu
  local y0 = sh * 0.52
  for i, opt in ipairs(OPTIONS) do
    local label = locale.t("ui.title.menu_" .. opt)
    local selected = i == self.sel
    local y = y0 + (i - 1) * 32
    if selected then
      draw.textCentered(">", sw / 2 - draw.textWidth(label, 18) / 2 - 22, y + 3, 12, { 1, 0.55, 0.25, 1 })
    end
    draw.textCentered(label, sw / 2, y, 18,
      selected and { 1, 1, 1, 1 } or { 1, 1, 1, 0.45 })
  end

  -- footer stats
  local d = save.get()
  local line = locale.f("ui.title.stats", d.cinders, d.stats.runs, d.stats.victories)
  draw.textCentered(line, sw / 2, sh - 44, 11, { 1, 1, 1, 0.4 })

  -- version marker (bottom-right)
  draw.text("v" .. version.string, sw - 62, sh - 24, 11, { 1, 1, 1, 0.28 })
end

state.register("title", title)
return title
