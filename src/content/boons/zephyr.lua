-- Zephyr: mobility, air control, speed-as-a-weapon.
local particles = require("src.render.particles")
local util = require("src.core.util")

local function pct(v) return math.floor(v * 100 + 0.5) end

return {
  {
    id = "skyborn",
    family = "zephyr",
    name = "Skyborn",
    flavor = "The ground is a rumor.",
    maxLevel = 2,
    desc = function(l, m)
      _ = m
      return ("+%d air jump%s."):format(l, l > 1 and "s" or "")
    end,
    apply = function(run, ctx)
      run:addFlat("airJumps", ctx.level)
    end,
  },
  {
    id = "slipstream",
    family = "zephyr",
    name = "Slipstream",
    flavor = "Pass through. Leave the cutting to the wake.",
    maxLevel = 3,
    desc = function(l, m)
      return ("Dashing through enemies deals %d damage."):format(math.floor(12 * l * m))
    end,
    apply = function(run, ctx)
      local hitSet = {}
      ctx.on("playerDash", function() hitSet = {} end)
      ctx.on("tick", function(dt, room)
        local p = room and room.player
        if not p or p.dead or p.dashTimer <= 0 then return end
        for _, e in ipairs(room.enemies) do
          if not e.dead and not hitSet[e]
             and util.aabb(p.x - 4, p.y - 4, p.w + 8, p.h + 8, e.x, e.y, e.w, e.h) then
            hitSet[e] = true
            local ang = math.atan2(p.dashDy, p.dashDx)
            e:takeDamage(12 * ctx.level * ctx.mult, ang, p, { dashProc = true })
          end
        end
      end)
    end,
  },
  {
    id = "featherweight",
    family = "zephyr",
    name = "Featherweight",
    flavor = "Weigh less than the wind's patience.",
    maxLevel = 3,
    desc = function(l, m)
      return ("+%d%% move speed, +%d%% jump height."):format(pct(0.09 * l * m), pct(0.05 * l * m))
    end,
    apply = function(run, ctx)
      run:addMult("moveSpeedMult", 0.09 * ctx.level * ctx.mult)
      run:addMult("jumpMult", 0.05 * ctx.level * ctx.mult)
    end,
  },
  {
    id = "momentum",
    family = "zephyr",
    name = "Momentum",
    flavor = "Arrive like a verdict.",
    maxLevel = 3,
    desc = function(l, m)
      return ("After dashing, your next melee strike deals +%d%% damage."):format(pct(0.3 * l * m))
    end,
    apply = function(run, ctx)
      ctx.on("playerDash", function()
        run.custom.nextMeleeBonus = 0.3 * ctx.level * ctx.mult
      end)
    end,
  },
  {
    id = "windlass",
    family = "zephyr",
    name = "Windlass",
    flavor = "The bow the storm strings itself.",
    maxLevel = 3,
    desc = function(l, m)
      return ("-%d%% bolt cooldown."):format(pct(0.12 * l * m))
    end,
    apply = function(run, ctx)
      run:addMult("specialCooldownMult", -0.12 * ctx.level * ctx.mult)
    end,
  },
  {
    id = "ghost_step",
    family = "zephyr",
    name = "Ghost Step",
    flavor = "Between one place and another, there is no you to hit.",
    maxLevel = 1,
    legendary = true,
    unlock = "boons_legendary",
    weight = 0.35,
    desc = function(l, m)
      _ = l _ = m
      return "-40% dash cooldown, and dashing releases cutting winds around you."
    end,
    apply = function(run, ctx)
      run:addMult("dashCooldownMult", -0.4)
      ctx.on("playerDash", function(player)
        local room = run.currentRoom
        if not room then return end
        local cx, cy = player:center()
        particles.ring(cx, cy, { 0.55, 0.95, 0.9 }, 40)
        for _, e in ipairs(room:enemiesInRadius(cx, cy, 44)) do
          e:takeDamage(8 * ctx.mult, nil, player, { windProc = true, noHitstop = true })
        end
      end)
    end,
  },
}
