-- Options: language, volumes, screen shake, key remapping. Reachable from
-- the title screen; quick settings also live in the pause menu.
local state = require("src.core.state")
local draw = require("src.render.draw")
local input = require("src.core.input")
local save = require("src.core.save")
local sfx = require("src.audio.sfx")
local music = require("src.audio.music")
local locale = require("src.core.locale")
local util = require("src.core.util")

local options = {}

local ITEMS = { "language", "music", "sfx", "shake", "remap", "reset" }

function options:enter(returnTo)
  self.returnTo = returnTo or "title"
  self.sel = 1
  self.mode = "main"   -- main | remap
  self.remapSel = 1
  self.awaitingKey = false
  self.message = nil
  self.t = 0
end

function options:updateMain()
  local settings = save.get().settings
  if input.pressed("up") then
    self.sel = self.sel > 1 and self.sel - 1 or #ITEMS
    sfx.play("uiMove")
  elseif input.pressed("down") then
    self.sel = self.sel < #ITEMS and self.sel + 1 or 1
    sfx.play("uiMove")
  end

  local item = ITEMS[self.sel]
  local delta = 0
  if input.pressed("left") then delta = -0.1 end
  if input.pressed("right") then delta = 0.1 end
  if delta ~= 0 then
    if item == "music" then
      settings.musicVolume = util.clamp((settings.musicVolume or 0.7) + delta, 0, 1)
      music.applyVolume()
    elseif item == "sfx" then
      settings.sfxVolume = util.clamp((settings.sfxVolume or 0.8) + delta, 0, 1)
      sfx.play("uiSelect")
    elseif item == "shake" then
      settings.screenShake = util.clamp((settings.screenShake or 1) + delta, 0, 1.5)
    elseif item == "language" then
      locale.cycle()
    end
  end

  if input.pressed("confirm") then
    input.consume("confirm")
    if item == "language" then
      locale.cycle()
    elseif item == "remap" then
      self.mode = "remap"
      self.remapSel = 1
      self.awaitingKey = false
    elseif item == "reset" then
      input.resetBindings()
      sfx.play("uiSelect")
      self.message = locale.t("ui.options.resetDone")
    end
  elseif input.pressed("cancel") or input.pressed("pause") then
    input.consume("cancel") input.consume("pause")
    save.write()
    state.switch(self.returnTo)
  end
end

function options:updateRemap()
  if self.awaitingKey then return end -- handled in keypressed
  local n = #input.REMAPPABLE
  if input.pressed("up") then
    self.remapSel = self.remapSel > 1 and self.remapSel - 1 or n
    sfx.play("uiMove")
  elseif input.pressed("down") then
    self.remapSel = self.remapSel < n and self.remapSel + 1 or 1
    sfx.play("uiMove")
  elseif input.pressed("confirm") then
    input.consume("confirm")
    self.awaitingKey = true
    sfx.play("uiSelect")
  elseif input.pressed("cancel") or input.pressed("pause") then
    input.consume("cancel") input.consume("pause")
    self.mode = "main"
  end
end

function options:update(dt)
  self.t = self.t + dt
  if self.mode == "main" then self:updateMain() else self:updateRemap() end
end

-- Raw key capture for rebinding (bypasses the action layer on purpose).
function options:keypressed(key)
  if self.mode == "remap" and self.awaitingKey then
    if key ~= "escape" then
      local action = input.REMAPPABLE[self.remapSel]
      input.rebind(action, key)
      sfx.play("unlock")
    end
    self.awaitingKey = false
    -- swallow this frame's action presses so the captured key doesn't also
    -- trigger confirm/cancel in update()
    input.endFrame()
  end
end

function options:draw()
  local sw, sh = love.graphics.getDimensions()
  draw.gradientV(0, 0, sw, sh, { 0.04, 0.03, 0.07 }, { 0.1, 0.08, 0.11 })

  if self.mode == "main" then
    local settings = save.get().settings
    draw.textCentered(locale.t("ui.options.header"), sw / 2, sh * 0.08, 28, { 1, 0.92, 0.8, 1 })
    local values = {
      language = locale.languageName(),
      music = math.floor((settings.musicVolume or 0.7) * 100 + 0.5) .. "%",
      sfx = math.floor((settings.sfxVolume or 0.8) * 100 + 0.5) .. "%",
      shake = math.floor((settings.screenShake or 1) * 100 + 0.5) .. "%",
    }
    local y0 = sh * 0.26
    for i, item in ipairs(ITEMS) do
      local selected = i == self.sel
      local y = y0 + (i - 1) * 40
      local label = locale.t("ui.options." .. item)
      if values[item] then label = label .. "   < " .. values[item] .. " >" end
      if selected then
        draw.textCentered(">", sw / 2 - draw.textWidth(label, 17) / 2 - 22, y + 2, 12, { 1, 0.55, 0.25, 1 })
      end
      draw.textCentered(label, sw / 2, y, 17, selected and { 1, 1, 1, 1 } or { 1, 1, 1, 0.5 })
    end
    if self.message then
      draw.textCentered(self.message, sw / 2, sh - 88, 12, { 1, 0.85, 0.6, 0.9 })
    end
    draw.textCentered(locale.t("ui.options.footer"), sw / 2, sh - 48, 12, { 1, 1, 1, 0.5 })
  else
    draw.textCentered(locale.t("ui.options.remapHeader"), sw / 2, sh * 0.06, 26, { 1, 0.92, 0.8, 1 })
    draw.textCentered(locale.t("ui.options.remapHint"), sw / 2, sh * 0.06 + 36, 11, { 1, 1, 1, 0.5 })
    local y0 = sh * 0.18
    local rowH = math.min(38, (sh * 0.68) / #input.REMAPPABLE)
    for i, action in ipairs(input.REMAPPABLE) do
      local selected = i == self.remapSel
      local y = y0 + (i - 1) * rowH
      local name = locale.t("ui.actions." .. action)
      local binding = input.bindingLabel(action)
      if selected and self.awaitingKey then
        binding = locale.t("ui.options.pressKey")
      end
      love.graphics.setColor(0.07, 0.07, 0.12, selected and 0.95 or 0.6)
      love.graphics.rectangle("fill", sw * 0.22, y, sw * 0.56, rowH - 6, 4, 4)
      if selected then
        love.graphics.setColor(1, 0.6, 0.3, 0.9)
        love.graphics.rectangle("line", sw * 0.22, y, sw * 0.56, rowH - 6, 4, 4)
      end
      draw.text(name, sw * 0.24, y + (rowH - 6) / 2 - 8, 13, { 1, 1, 1, selected and 1 or 0.7 })
      local bw = draw.textWidth(binding, 12)
      draw.text(binding, sw * 0.76 - bw, y + (rowH - 6) / 2 - 7, 12,
        selected and self.awaitingKey and { 1, 0.75, 0.35, 0.8 + math.sin(self.t * 5) * 0.2 }
        or { 0.7, 0.9, 1, selected and 0.95 or 0.6 })
    end
    draw.textCentered(locale.t("ui.options.remapFooter"), sw / 2, sh - 40, 12, { 1, 1, 1, 0.5 })
  end
  love.graphics.setColor(1, 1, 1, 1)
end

state.register("options", options)
return options
