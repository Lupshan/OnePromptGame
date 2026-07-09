-- Codex: everything the ash has shown you so far. Unseen entries stay dark.
local state = require("src.core.state")
local draw = require("src.render.draw")
local input = require("src.core.input")
local registry = require("src.game.registry")
local save = require("src.core.save")
local sfx = require("src.audio.sfx")

local codex = {}

local TABS = { "Enemies", "Boons", "Wardens" }

function codex:enter()
  local reg = require("src.game.registry")
  if not reg.loaded then
    reg.loadAll()
    reg.loaded = true
  end
  self.tab = 1
  self.scroll = 0
  self.t = 0
end

local function entries(tab)
  if tab == 1 then
    local out = {}
    for _, e in ipairs(registry.all("enemy")) do
      out[#out + 1] = { name = e.name, desc = e.desc, seen = save.get().seen["enemy:" .. e.id] }
    end
    return out
  elseif tab == 2 then
    local boonsSys = require("src.game.boons")
    local out = {}
    for _, b in ipairs(registry.all("boon")) do
      local fam = boonsSys.family(b.family)
      out[#out + 1] = {
        name = b.name, desc = b.flavor,
        tag = fam and fam.name or "", color = fam and fam.color,
        seen = save.get().seen["boon:" .. b.id],
      }
    end
    return out
  else
    local out = {}
    for _, b in ipairs(registry.all("boss")) do
      out[#out + 1] = { name = b.name, desc = b.title, seen = save.get().seen["boss:" .. b.id] }
    end
    return out
  end
end

function codex:update(dt)
  self.t = self.t + dt
  if input.pressed("left") then
    self.tab = self.tab > 1 and self.tab - 1 or #TABS
    self.scroll = 0
    sfx.play("uiMove")
  elseif input.pressed("right") then
    self.tab = self.tab < #TABS and self.tab + 1 or 1
    self.scroll = 0
    sfx.play("uiMove")
  elseif input.pressed("down") then
    self.scroll = self.scroll + 1
  elseif input.pressed("up") then
    self.scroll = math.max(0, self.scroll - 1)
  elseif input.pressed("cancel") or input.pressed("pause") then
    input.consume("cancel") input.consume("pause")
    state.switch("title")
  end
end

function codex:draw()
  local sw, sh = love.graphics.getDimensions()
  draw.gradientV(0, 0, sw, sh, { 0.04, 0.03, 0.07 }, { 0.1, 0.08, 0.11 })

  draw.textCentered("CODEX", sw / 2, sh * 0.05, 28, { 1, 0.92, 0.8, 1 })

  -- tabs
  local tw = 140
  local x0 = sw / 2 - (#TABS * tw) / 2
  for i, tab in ipairs(TABS) do
    local selected = i == self.tab
    draw.textCentered(tab, x0 + (i - 0.5) * tw, sh * 0.13, 15,
      selected and { 1, 0.75, 0.4, 1 } or { 1, 1, 1, 0.4 })
  end

  local list = entries(self.tab)
  local seenCount = 0
  for _, e in ipairs(list) do if e.seen then seenCount = seenCount + 1 end end
  draw.textCentered(("%d / %d witnessed"):format(seenCount, #list), sw / 2, sh * 0.13 + 26, 10,
    { 1, 1, 1, 0.4 })

  local rowH = 40
  local w = math.min(680, sw - 120)
  local xx = (sw - w) / 2
  local y0 = sh * 0.22
  local maxRows = math.floor((sh - y0 - 70) / rowH)
  self.scroll = math.min(self.scroll, math.max(0, #list - maxRows))

  for i = 1, maxRows do
    local idx = i + self.scroll
    local e = list[idx]
    if not e then break end
    local y = y0 + (i - 1) * rowH
    love.graphics.setColor(0.07, 0.07, 0.12, 0.72)
    love.graphics.rectangle("fill", xx, y, w, rowH - 6, 4, 4)
    if e.seen then
      local c = e.color or { 1, 1, 1 }
      love.graphics.setColor(c[1], c[2], c[3], 0.9)
      draw.diamond("fill", xx + 16, y + (rowH - 6) / 2, 5)
      draw.text(e.name .. (e.tag and e.tag ~= "" and ("   ·  " .. e.tag) or ""), xx + 32, y + 4, 13, { 1, 1, 1, 0.95 })
      draw.text(e.desc or "", xx + 32, y + 21, 9, { 1, 1, 1, 0.45 })
    else
      love.graphics.setColor(0.5, 0.5, 0.55, 0.4)
      draw.diamond("line", xx + 16, y + (rowH - 6) / 2, 5)
      draw.text("— unwitnessed —", xx + 32, y + 10, 12, { 1, 1, 1, 0.25 })
    end
  end

  draw.textCentered("<- -> tabs · up/down scroll · ESC back", sw / 2, sh - 40, 12, { 1, 1, 1, 0.5 })
  love.graphics.setColor(1, 1, 1, 1)
end

state.register("codex", codex)
return codex
