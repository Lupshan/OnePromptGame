-- In-run HUD: health, dash/bolt cooldowns, currencies, boons, boss bar.
local draw = require("src.render.draw")
local boonsSys = require("src.game.boons")
local config = require("src.core.config")
local util = require("src.core.util")
local locale = require("src.core.locale")

local hud = {}

local damageFlash = 0
local shownHP = nil

function hud.notifyDamage() damageFlash = 0.35 end

function hud.update(dt)
  damageFlash = math.max(0, damageFlash - dt)
end

function hud.draw(run, room)
  local sw = love.graphics.getDimensions()
  local player = room.player

  -- HP bar ---------------------------------------------------------------
  local x, y, w, h = 18, 16, 220, 16
  local maxHP = run:maxHP()
  if shownHP == nil then shownHP = run.hp end
  shownHP = util.damp(shownHP, run.hp, 8, love.timer.getDelta())

  love.graphics.setColor(0, 0, 0, 0.55)
  love.graphics.rectangle("fill", x - 2, y - 2, w + 4, h + 4, 3, 3)
  -- damage ghost (white trail behind the red bar)
  love.graphics.setColor(1, 1, 1, 0.35)
  love.graphics.rectangle("fill", x, y, w * util.clamp(shownHP / maxHP, 0, 1), h)
  local hpFrac = util.clamp(run.hp / maxHP, 0, 1)
  local barR, barG = 0.9, 0.25
  if hpFrac > 0.5 then barR, barG = 0.85, 0.3 + (hpFrac - 0.5) * 0.8 end
  if damageFlash > 0 and math.floor(love.timer.getTime() * 16) % 2 == 0 then
    love.graphics.setColor(1, 1, 1, 0.9)
  else
    love.graphics.setColor(barR, barG, 0.25, 0.95)
  end
  love.graphics.rectangle("fill", x, y, w * hpFrac, h)
  draw.text(math.floor(run.hp) .. " / " .. maxHP, x + 6, y + 1, 11, { 1, 1, 1, 0.9 })

  -- shield pips
  local shield = run.custom.shield
  if shield and shield.max and shield.max > 0 then
    for i = 1, shield.max do
      local filled = i <= shield.charges
      love.graphics.setColor(0.4, 0.75, 1, filled and 0.95 or 0.25)
      draw.diamond("fill", x + w + 14 + (i - 1) * 14, y + h / 2, filled and 5 or 3)
    end
  end

  -- cooldowns -------------------------------------------------------------
  local cy = y + h + 8
  local function cdBar(frac, color, label)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", x, cy, 90, 5)
    love.graphics.setColor(color[1], color[2], color[3], frac >= 1 and 1 or 0.55)
    love.graphics.rectangle("fill", x, cy, 90 * util.clamp(frac, 0, 1), 5)
    draw.text(label, x + 94, cy - 4, 9, { 1, 1, 1, 0.6 })
    cy = cy + 9
  end
  local P = config.player
  cdBar(1 - player.dashCd / (P.dashCooldown * run:stat("dashCooldownMult", 1)),
    { 0.55, 0.95, 0.9 }, locale.t("ui.hud.dash"))

  -- currencies -------------------------------------------------------------
  local save = require("src.core.save")
  draw.diamond("fill", sw - 160, 24, 4)
  love.graphics.setColor(1, 0.6, 0.2)
  draw.diamond("fill", sw - 160, 24, 4)
  draw.text(tostring(run.embers), sw - 150, 17, 13, { 1, 0.75, 0.4 })
  love.graphics.setColor(0.65, 0.85, 1)
  draw.diamond("fill", sw - 90, 24, 4)
  draw.text(tostring(save.get().cinders), sw - 80, 17, 13, { 0.75, 0.88, 1 })

  -- biome / node label
  local biomeName = locale.content("biomes", run:biome().id, "name", run:biome().name)
  draw.text(locale.f("ui.hud.biomeDepth", biomeName, run.depth),
    sw - 260, 40, 10, { 1, 1, 1, 0.45 })
  draw.text(locale.f("ui.hud.seed", tostring(run.seed)), sw - 260, 54, 9, { 1, 1, 1, 0.3 })

  -- boons row ---------------------------------------------------------------
  local bx = 18
  local by = love.graphics.getHeight() - 26
  for _, owned in ipairs(run.boons) do
    local def = boonsSys.def(owned.id)
    if def then
      local fam = boonsSys.family(def.family)
      local col = fam and fam.color or { 1, 1, 1 }
      love.graphics.setColor(col[1], col[2], col[3], 0.9)
      draw.diamond("fill", bx + 6, by + 6, 5)
      if owned.level > 1 then
        draw.text(tostring(owned.level), bx + 11, by + 2, 9, { 1, 1, 1, 0.85 })
      end
      bx = bx + 22
    end
  end

  -- objective hint ------------------------------------------------------------
  if not room.exitOpen then
    local label = room.boss and (room.boss.introDone and "" or "")
      or locale.f("ui.hud.enemies", room:aliveEnemies())
    if room.waves and #room.waves > 1 and not room.boss then
      label = label .. "   " .. locale.f("ui.hud.wave", math.min(room.waveIndex, #room.waves), #room.waves)
    end
    if label ~= "" then
      draw.textCentered(label, sw / 2, 18, 11, { 1, 1, 1, 0.55 })
    end
  end

  -- boss bar --------------------------------------------------------------------
  local boss = room.boss
  if boss and not boss.dead then
    local bw = math.min(520, sw - 200)
    local bxx = (sw - bw) / 2
    local byy = love.graphics.getHeight() - 54
    local bossName = locale.content("bosses", boss.def.id, "name", boss.def.name)
    local bossTitle = locale.content("bosses", boss.def.id, "title", boss.def.title or "")
    if not boss.introDone then
      -- intro banner
      draw.textCentered(bossName, sw / 2, love.graphics.getHeight() * 0.32, 34,
        { 1, 1, 1, math.min(1, boss.intro) })
      draw.textCentered(bossTitle, sw / 2, love.graphics.getHeight() * 0.32 + 44, 14,
        { 1, 0.8, 0.5, math.min(1, boss.intro) * 0.9 })
    else
      love.graphics.setColor(0, 0, 0, 0.6)
      love.graphics.rectangle("fill", bxx - 2, byy - 2, bw + 4, 12, 3, 3)
      local c = boss.def.color
      love.graphics.setColor(c[1], c[2], c[3], 0.95)
      love.graphics.rectangle("fill", bxx, byy, bw * util.clamp(boss.hp / boss.maxHP, 0, 1), 8)
      draw.textCentered(bossName, sw / 2, byy - 18, 12, { 1, 1, 1, 0.85 })
    end
  end

  love.graphics.setColor(1, 1, 1, 1)
end

return hud
