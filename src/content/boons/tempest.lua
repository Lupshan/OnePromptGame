-- Tempest: chain lightning, shock, attack speed.
local particles = require("src.render.particles")
local util = require("src.core.util")
local sfx = require("src.audio.sfx")

local function pct(v) return math.floor(v * 100 + 0.5) end

-- spark visual between two points
local function arcVisual(x1, y1, x2, y2)
  local steps = 6
  for i = 0, steps do
    local t = i / steps
    local x = util.lerp(x1, x2, t) + (love.math.random() * 2 - 1) * 4
    local y = util.lerp(y1, y2, t) + (love.math.random() * 2 - 1) * 4
    particles.spawn({ x = x, y = y, life = 0.18, size = 2, sizeEnd = 0,
      color = { 1, 0.95, 0.5 }, kind = "dot", glow = 6 })
  end
end

return {
  {
    id = "static_edge",
    family = "tempest",
    name = "Static Edge",
    flavor = "The blade hums between strikes.",
    maxLevel = 3,
    desc = function(l, m)
      return ("Melee hits arc %d lightning damage to a nearby enemy."):format(math.floor(6 * l * m))
    end,
    apply = function(run, ctx)
      ctx.on("enemyDamaged", function(enemy, amount, meta, source)
        if not meta.melee or meta.chainProc or meta.status then return end
        local room = run.currentRoom
        if not room then return end
        local cx, cy = enemy:center()
        local best, bestD = nil, 95 * 95
        for _, e in ipairs(room.enemies) do
          if e ~= enemy and not e.dead then
            local ex, ey = e:center()
            local d = util.dist2(cx, cy, ex, ey)
            if d < bestD then best, bestD = e, d end
          end
        end
        if best then
          local ex, ey = best:center()
          arcVisual(cx, cy, ex, ey)
          sfx.play("zap", 1, 0.6)
          best:takeDamage(6 * ctx.level * ctx.mult, nil, source, { chainProc = true, noHitstop = true })
        end
      end)
    end,
  },
  {
    id = "storm_bolt",
    family = "tempest",
    name = "Storm Bolt",
    flavor = "Why send one message when the sky owns the wire?",
    maxLevel = 3,
    desc = function(l, m)
      return ("Your bolt pierces %d extra %s and applies Shock."):format(
        l, l == 1 and "enemy" or "enemies", m)
    end,
    apply = function(run, ctx)
      run:addFlat("boltPierce", ctx.level)
      ctx.on("boltHit", function(projectile, enemy)
        if not enemy.dead then
          enemy:applyStatus("shock", { time = 4, power = ctx.mult, maxPower = 3 })
        end
      end)
    end,
  },
  {
    id = "shock_conductor",
    family = "tempest",
    name = "Conductor",
    flavor = "Charge builds. Bills come due.",
    maxLevel = 3,
    desc = function(l, m)
      return ("Melee applies Shock. Hitting a Shocked enemy discharges it for %d bonus damage.")
        :format(math.floor(9 * l * m))
    end,
    apply = function(run, ctx)
      ctx.on("enemyDamaged", function(enemy, amount, meta, source)
        if meta.status or meta.shockProc then return end
        if enemy.dead then return end
        if enemy.status.shock and (meta.melee or meta.bolt) then
          local p = enemy.status.shock.power or 1
          enemy.status.shock = nil
          local cx, cy = enemy:center()
          particles.burst(cx, cy, { 1, 0.95, 0.5 }, 8, { speed = 100, kind = "spark", gravity = 0 })
          sfx.play("zap")
          enemy:takeDamage(9 * ctx.level * ctx.mult * p, nil, source, { shockProc = true, noHitstop = true })
        elseif meta.melee then
          enemy:applyStatus("shock", { time = 4, power = ctx.mult, maxPower = 3 })
        end
      end)
    end,
  },
  {
    id = "quickening",
    family = "tempest",
    name = "Quickening",
    flavor = "Between the thunder and the light, you.",
    maxLevel = 3,
    desc = function(l, m)
      return ("+%d%% attack speed."):format(pct(0.12 * l * m))
    end,
    apply = function(run, ctx)
      run:addMult("attackSpeedMult", 0.12 * ctx.level * ctx.mult)
    end,
  },
  {
    id = "tailwind",
    family = "tempest",
    name = "Tailwind",
    flavor = "The storm pushes whoever runs with it.",
    maxLevel = 3,
    desc = function(l, m)
      return ("+%d%% move speed, -%d%% dash cooldown."):format(pct(0.08 * l * m), pct(0.1 * l * m))
    end,
    apply = function(run, ctx)
      run:addMult("moveSpeedMult", 0.08 * ctx.level * ctx.mult)
      run:addMult("dashCooldownMult", -0.1 * ctx.level * ctx.mult)
    end,
  },
  {
    id = "tempest_call",
    family = "tempest",
    name = "Tempest Call",
    flavor = "Every fourth blow, the sky answers for you.",
    maxLevel = 1,
    legendary = true,
    unlock = "boons_legendary",
    weight = 0.35,
    desc = function(l, m)
      _ = l
      return ("Every 4th melee hit strikes ALL enemies for %d lightning damage."):format(math.floor(14 * m))
    end,
    apply = function(run, ctx)
      local count = 0
      ctx.on("enemyDamaged", function(enemy, amount, meta, source)
        if not meta.melee or meta.tempestProc or meta.status then return end
        count = count + 1
        if count >= 4 then
          count = 0
          local room = run.currentRoom
          if not room then return end
          sfx.play("zap", 0.7)
          local px, py = room.player:center()
          for _, e in ipairs(room.enemies) do
            if not e.dead then
              local ex, ey = e:center()
              arcVisual(px, py, ex, ey)
              e:takeDamage(14 * ctx.mult, nil, source, { tempestProc = true, noHitstop = true })
            end
          end
        end
      end)
    end,
  },
}
