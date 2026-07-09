-- Character select: wraiths as sidegrades, locked ones point at the Kiln.
local state = require("src.core.state")
local draw = require("src.render.draw")
local input = require("src.core.input")
local registry = require("src.game.registry")
local save = require("src.core.save")
local sfx = require("src.audio.sfx")

local charselect = {}

function charselect:enter()
  local reg = require("src.game.registry")
  if not reg.loaded then
    reg.loadAll()
    reg.loaded = true
  end
  self.chars = registry.all("character")
  self.sel = 1
  local last = save.get().lastCharacter
  for i, c in ipairs(self.chars) do
    if c.id == last then self.sel = i end
  end
  self.t = 0
  self.seedInput = nil
end

local function isLocked(c)
  return c.unlock and not save.isUnlocked(c.unlock)
end

function charselect:update(dt)
  self.t = self.t + dt
  if input.pressed("left") then
    self.sel = self.sel > 1 and self.sel - 1 or #self.chars
    sfx.play("uiMove")
  elseif input.pressed("right") then
    self.sel = self.sel < #self.chars and self.sel + 1 or 1
    sfx.play("uiMove")
  elseif input.pressed("confirm") then
    input.consume("confirm")
    local c = self.chars[self.sel]
    if isLocked(c) then
      sfx.play("uiDeny")
    else
      sfx.play("uiSelect")
      state.switch("rungame", { characterId = c.id })
    end
  elseif input.pressed("cancel") or input.pressed("pause") then
    input.consume("cancel") input.consume("pause")
    state.switch("title")
  end
end

function charselect:draw()
  local sw, sh = love.graphics.getDimensions()
  draw.gradientV(0, 0, sw, sh, { 0.05, 0.03, 0.07 }, { 0.12, 0.07, 0.09 })

  draw.textCentered("CHOOSE YOUR REMNANT", sw / 2, sh * 0.1, 26, { 1, 0.92, 0.8, 1 })

  local n = #self.chars
  local cardW, cardH = 200, 270
  local gap = 24
  local totalW = n * cardW + (n - 1) * gap
  local x0 = (sw - totalW) / 2
  local y0 = sh * 0.24

  for i, c in ipairs(self.chars) do
    local x = x0 + (i - 1) * (cardW + gap)
    local selected = i == self.sel
    local locked = isLocked(c)
    local y = y0 + (selected and -8 or 0)

    love.graphics.setColor(0.07, 0.07, 0.12, 0.96)
    love.graphics.rectangle("fill", x, y, cardW, cardH, 6, 6)
    local gc = c.glowColor or { 1, 1, 1 }
    love.graphics.setLineWidth(selected and 3 or 1.5)
    love.graphics.setColor(gc[1], gc[2], gc[3], selected and 1 or 0.4)
    love.graphics.rectangle("line", x, y, cardW, cardH, 6, 6)
    love.graphics.setLineWidth(1)

    -- figure
    local fx, fy = x + cardW / 2, y + 84
    if not locked then
      draw.glow(fx, fy, 40, gc[1], gc[2], gc[3], selected and 0.5 or 0.25)
      love.graphics.setColor(c.color)
    else
      love.graphics.setColor(0.25, 0.25, 0.3)
    end
    love.graphics.polygon("fill",
      fx, fy - 22, fx + 12, fy - 4, fx + 10, fy + 22, fx - 10, fy + 22, fx - 12, fy - 4)
    if not locked then
      love.graphics.setColor(gc[1] * 1.2, gc[2] * 1.2, gc[3] * 1.2)
      love.graphics.rectangle("fill", fx - 4, fy - 12, 2.6, 3)
      love.graphics.rectangle("fill", fx + 1.4, fy - 12, 2.6, 3)
    end

    draw.textCentered(locked and "???" or c.name, x + cardW / 2, y + 128, 15, { 1, 1, 1, locked and 0.5 or 1 })
    draw.textCentered(locked and "" or (c.epithet or ""), x + cardW / 2, y + 148, 10,
      { gc[1], gc[2], gc[3], 0.8 })

    if locked then
      draw.text("Sealed.\n\nLight this wraith at the Kiln.", x + 16, y + 176, 11,
        { 1, 1, 1, 0.45 }, "center", cardW - 32)
    else
      draw.text(c.desc or "", x + 16, y + 170, 11, { 0.92, 0.93, 0.98, 0.9 }, "center", cardW - 32)
    end
  end

  draw.textCentered("<- -> choose · SPACE begin · ESC back",
    sw / 2, sh - 48, 12, { 1, 1, 1, 0.5 })
  love.graphics.setColor(1, 1, 1, 1)
end

state.register("charselect", charselect)
return charselect
