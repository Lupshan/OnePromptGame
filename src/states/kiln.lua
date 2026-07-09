-- The Kiln: meta-progression shop. Cinders buy new CONTENT (characters,
-- boons, chunks) -- never starting power. See the no-power-creep rule.
local state = require("src.core.state")
local draw = require("src.render.draw")
local input = require("src.core.input")
local registry = require("src.game.registry")
local save = require("src.core.save")
local sfx = require("src.audio.sfx")
local locale = require("src.core.locale")

local kiln = {}

function kiln:enter()
  local reg = require("src.game.registry")
  if not reg.loaded then
    reg.loadAll()
    reg.loaded = true
  end
  self.items = registry.all("unlock")
  self.sel = 1
  self.t = 0
  self.message = nil
end

function kiln:update(dt)
  self.t = self.t + dt
  if input.pressed("up") then
    self.sel = self.sel > 1 and self.sel - 1 or #self.items
    sfx.play("uiMove")
  elseif input.pressed("down") then
    self.sel = self.sel < #self.items and self.sel + 1 or 1
    sfx.play("uiMove")
  elseif input.pressed("confirm") then
    input.consume("confirm")
    local item = self.items[self.sel]
    if save.isUnlocked(item.id) then
      sfx.play("uiDeny")
      self.message = locale.t("ui.kiln.already")
    elseif save.spendCinders(item.cost) then
      save.unlock(item.id)
      sfx.play("unlock")
      self.message = locale.f("ui.kiln.kindled", locale.content("unlocks", item.id, "name", item.name))
    else
      sfx.play("uiDeny")
      self.message = locale.t("ui.kiln.notEnough")
    end
  elseif input.pressed("cancel") or input.pressed("pause") then
    input.consume("cancel") input.consume("pause")
    state.switch("title")
  end
end

function kiln:draw()
  local sw, sh = love.graphics.getDimensions()
  draw.gradientV(0, 0, sw, sh, { 0.06, 0.03, 0.05 }, { 0.13, 0.07, 0.06 })
  draw.glow(sw / 2, sh * 0.1, 240, 1, 0.5, 0.2, 0.2 + math.sin(self.t * 1.3) * 0.05)

  draw.textCentered(locale.t("ui.kiln.header"), sw / 2, sh * 0.06, 30, { 1, 0.9, 0.75, 1 })
  draw.textCentered(locale.t("ui.kiln.sub"), sw / 2, sh * 0.06 + 40, 11,
    { 1, 1, 1, 0.5 })

  local d = save.get()
  love.graphics.setColor(0.65, 0.85, 1)
  draw.diamond("fill", sw / 2 - draw.textWidth(tostring(d.cinders), 18) / 2 - 16, sh * 0.155 + 9, 5)
  draw.textCentered(tostring(d.cinders), sw / 2, sh * 0.155, 18, { 0.75, 0.88, 1, 1 })

  local y0 = sh * 0.24
  local rowH = 54
  local w = math.min(620, sw - 120)
  local x0 = (sw - w) / 2
  for i, item in ipairs(self.items) do
    local y = y0 + (i - 1) * rowH
    local selected = i == self.sel
    local owned = save.isUnlocked(item.id)

    love.graphics.setColor(0.07, 0.07, 0.12, selected and 0.98 or 0.7)
    love.graphics.rectangle("fill", x0, y, w, rowH - 8, 4, 4)
    if selected then
      love.graphics.setColor(1, 0.6, 0.3, 0.9)
      love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", x0, y, w, rowH - 8, 4, 4)
      love.graphics.setLineWidth(1)
    end

    local nameCol = owned and { 1, 0.7, 0.4, 0.9 } or { 1, 1, 1, selected and 1 or 0.75 }
    draw.text(locale.content("unlocks", item.id, "name", item.name), x0 + 16, y + 7, 14, nameCol)
    draw.text(locale.content("unlocks", item.id, "desc", item.desc or ""), x0 + 16, y + 26, 10, { 1, 1, 1, 0.5 })

    if owned then
      draw.text(locale.t("ui.kiln.lit"), x0 + w - 50, y + 12, 12, { 1, 0.7, 0.4, 0.9 })
    else
      local afford = d.cinders >= item.cost
      love.graphics.setColor(0.65, 0.85, 1, afford and 1 or 0.4)
      draw.diamond("fill", x0 + w - 70, y + 19, 4)
      draw.text(tostring(item.cost), x0 + w - 60, y + 12, 12,
        afford and { 0.75, 0.88, 1, 1 } or { 0.75, 0.88, 1, 0.4 })
    end
  end

  if self.message then
    draw.textCentered(self.message, sw / 2, sh - 84, 12, { 1, 0.85, 0.6, 0.9 })
  end
  draw.textCentered(locale.t("ui.kiln.footer"), sw / 2, sh - 48, 12, { 1, 1, 1, 0.5 })
  love.graphics.setColor(1, 1, 1, 1)
end

state.register("kiln", kiln)
return kiln
