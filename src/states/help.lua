-- How to Play: what the game expects from you, and which keys do it.
local state = require("src.core.state")
local draw = require("src.render.draw")
local input = require("src.core.input")
local locale = require("src.core.locale")

local help = {}

function help:enter()
  self.t = 0
end

function help:update(dt)
  self.t = self.t + dt
  if input.pressed("cancel") or input.pressed("pause") or input.pressed("confirm") then
    input.consume("cancel") input.consume("pause") input.consume("confirm")
    state.switch("title")
  end
end

function help:draw()
  local sw, sh = love.graphics.getDimensions()
  draw.gradientV(0, 0, sw, sh, { 0.04, 0.03, 0.07 }, { 0.1, 0.08, 0.11 })

  draw.textCentered(locale.t("ui.help.header"), sw / 2, sh * 0.06, 26, { 1, 0.92, 0.8, 1 })

  -- principles
  local lines = locale.t("ui.help.lines")
  local y = sh * 0.15
  if type(lines) == "table" then
    for _, line in ipairs(lines) do
      draw.textCentered(line, sw / 2, y, 12, { 0.92, 0.93, 0.98, line == "" and 0 or 0.9 })
      y = y + (line == "" and 10 or 19)
    end
  end

  -- controls table (live bindings, so remaps show up here)
  draw.textCentered(locale.t("ui.help.controlsHeader"), sw / 2, y + 18, 15, { 1, 0.8, 0.55, 1 })
  y = y + 46
  local colW = 300
  local x0 = sw / 2 - colW
  for i, action in ipairs(input.REMAPPABLE) do
    local col = (i - 1) % 2
    local row = math.floor((i - 1) / 2)
    local x = x0 + col * colW
    local yy = y + row * 24
    draw.text(locale.t("ui.actions." .. action), x, yy, 12, { 1, 1, 1, 0.85 })
    local binding = input.bindingLabel(action)
    draw.text(binding, x + 140, yy, 11, { 0.7, 0.9, 1, 0.8 })
  end

  draw.textCentered(locale.t("ui.common.cancelKey") .. " · " .. locale.t("ui.common.back"),
    sw / 2, sh - 40, 12, { 1, 1, 1, 0.5 })
  love.graphics.setColor(1, 1, 1, 1)
end

state.register("help", help)
return help
