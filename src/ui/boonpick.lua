-- Boon choice overlay: three cards, keyboard/gamepad driven.
local draw = require("src.render.draw")
local boonsSys = require("src.game.boons")
local input = require("src.core.input")
local sfx = require("src.audio.sfx")
local locale = require("src.core.locale")

local boonpick = {}
boonpick.__index = boonpick

function boonpick.new(run, offer, onDone)
  local self = setmetatable({}, boonpick)
  self.run = run
  self.offer = offer
  self.onDone = onDone
  self.sel = 1
  self.t = 0
  return self
end

function boonpick:update(dt)
  self.t = self.t + dt
  if #self.offer == 0 then
    if self.onDone then self.onDone(nil) end
    return
  end
  if input.pressed("left") then
    self.sel = self.sel > 1 and self.sel - 1 or #self.offer
    sfx.play("uiMove")
  elseif input.pressed("right") then
    self.sel = self.sel < #self.offer and self.sel + 1 or 1
    sfx.play("uiMove")
  elseif input.pressed("confirm") or input.pressed("jump") then
    input.consume("confirm") input.consume("jump")
    local choice = self.offer[self.sel]
    boonsSys.grant(self.run, choice.def.id, choice.rarity.id)
    sfx.play("boon")
    if self.onDone then self.onDone(choice) end
  elseif input.pressed("map") then
    -- skip for a small ember consolation
    self.run:addEmbers(15)
    sfx.play("pickup")
    if self.onDone then self.onDone(nil) end
  end
end

function boonpick:draw()
  local sw, sh = love.graphics.getDimensions()
  love.graphics.setColor(0.02, 0.02, 0.05, 0.82)
  love.graphics.rectangle("fill", 0, 0, sw, sh)

  draw.textCentered(locale.t("ui.boonpick.header"), sw / 2, sh * 0.12, 26, { 1, 0.9, 0.7, 1 })
  draw.textCentered(locale.t("ui.boonpick.instructions"),
    sw / 2, sh * 0.12 + 36, 11, { 1, 1, 1, 0.5 })

  local n = #self.offer
  local cardW, cardH = 240, 300
  local gap = 30
  local totalW = n * cardW + (n - 1) * gap
  local x0 = (sw - totalW) / 2
  local y0 = sh * 0.28

  for i, choice in ipairs(self.offer) do
    local x = x0 + (i - 1) * (cardW + gap)
    local selected = i == self.sel
    local lift = selected and -10 or 0
    local y = y0 + lift

    local fam = boonsSys.family(choice.def.family)
    local famCol = fam and fam.color or { 1, 1, 1 }
    local rar = choice.rarity

    -- card body
    love.graphics.setColor(0.07, 0.07, 0.12, 0.96)
    love.graphics.rectangle("fill", x, y, cardW, cardH, 6, 6)
    love.graphics.setLineWidth(selected and 3 or 1.5)
    love.graphics.setColor(rar.color[1], rar.color[2], rar.color[3], selected and 1 or 0.5)
    love.graphics.rectangle("line", x, y, cardW, cardH, 6, 6)
    love.graphics.setLineWidth(1)

    if selected then
      draw.glow(x + cardW / 2, y + cardH / 2, cardW * 0.75,
        famCol[1], famCol[2], famCol[3], 0.14 + math.sin(self.t * 3) * 0.04)
    end

    -- family sigil
    love.graphics.setColor(famCol)
    draw.diamond("fill", x + cardW / 2, y + 44, 16)
    love.graphics.setColor(1, 1, 1, 0.85)
    draw.diamond("line", x + cardW / 2, y + 44, 20)

    -- duo second family
    if choice.def.duo then
      local fam2 = boonsSys.family(choice.def.family2)
      if fam2 then
        love.graphics.setColor(fam2.color)
        draw.diamond("fill", x + cardW / 2 + 14, y + 44, 10)
      end
    end

    local famLabel = boonsSys.familyName(fam)
    if choice.def.duo then
      local fam2 = boonsSys.family(choice.def.family2)
      famLabel = famLabel .. " × " .. boonsSys.familyName(fam2)
    end
    draw.textCentered(famLabel, x + cardW / 2, y + 74, 10,
      { famCol[1], famCol[2], famCol[3], 0.9 })

    draw.textCentered(boonsSys.name(choice.def), x + cardW / 2, y + 92, 16, { 1, 1, 1, 1 })

    local rarityLabel = boonsSys.rarityName(rar)
    if choice.isUpgrade then
      rarityLabel = rarityLabel .. "  ·  "
        .. locale.f("ui.boonpick.levelUp", choice.currentLevel, choice.currentLevel + 1)
    end
    draw.textCentered(rarityLabel, x + cardW / 2, y + 114, 11,
      { rar.color[1], rar.color[2], rar.color[3], 0.95 })

    local level = choice.isUpgrade and (choice.currentLevel + 1) or 1
    local desc = boonsSys.describe(choice.def, level, rar.id)
    draw.text(desc, x + 18, y + 142, 12, { 0.92, 0.93, 0.98, 0.95 }, "left", cardW - 36)

    if choice.def.flavor then
      draw.text('"' .. boonsSys.flavor(choice.def) .. '"', x + 18, y + cardH - 58, 10,
        { 1, 1, 1, 0.38 }, "left", cardW - 36)
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

return boonpick
