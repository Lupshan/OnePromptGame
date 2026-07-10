-- Second wave of family boons: more texture per family, one more legendary.
local particles = require("src.render.particles")
local sfx = require("src.audio.sfx")

local function pct(v) return math.floor(v * 100 + 0.5) end

return {
  {
    id = "slow_roast",
    family = "ember",
    name = "Slow Roast",
    flavor = "Patience is also a temperature.",
    maxLevel = 2,
    desc = function(l, m)
      return ("Burns you inflict last +%d%% longer and tick +%d%% harder."):format(
        50 * l, pct(0.15 * l * m))
    end,
    apply = function(run, ctx)
      run:addMult("burnPower", 0.15 * ctx.level * ctx.mult)
      run.custom.burnTimeMult = 1 + 0.5 * ctx.level
    end,
  },
  {
    id = "dread_aura",
    family = "gloom",
    name = "Dread Aura",
    flavor = "They flinch before they know why.",
    maxLevel = 3,
    desc = function(l, m)
      return ("Every 2s, enemies within %d px are Weakened."):format(math.floor(50 + 10 * l * m))
    end,
    apply = function(run, ctx)
      local acc = 0
      ctx.on("tick", function(dt, room)
        acc = acc + dt
        if acc >= 2 then
          acc = acc - 2
          local p = room and room.player
          if p and not p.dead then
            local cx, cy = p:center()
            local r = 50 + 10 * ctx.level * ctx.mult
            local hit = false
            for _, e in ipairs(room:enemiesInRadius(cx, cy, r)) do
              if not e.dead then
                e:applyStatus("weaken", { time = 2.5, power = ctx.mult, maxPower = 4 })
                hit = true
              end
            end
            if hit then particles.ring(cx, cy, { 0.7, 0.45, 1 }, r * 0.6) end
          end
        end
      end)
    end,
  },
  {
    id = "overgrowth",
    family = "verdance",
    name = "Overgrowth",
    flavor = "Heavier. Greener. Harder to uproot.",
    maxLevel = 2,
    desc = function(l, m)
      return ("+%d max HP, but -%d%% move speed."):format(math.floor(22 * l * m), 5 * l)
    end,
    apply = function(run, ctx)
      run:addFlat("maxHP", math.floor(22 * ctx.level * ctx.mult))
      run:addMult("moveSpeedMult", -0.05 * ctx.level)
    end,
  },
  {
    id = "iron_resolve",
    family = "aegis",
    name = "Iron Resolve",
    flavor = "Decide to be heavier than the hit.",
    maxLevel = 3,
    desc = function(l, m)
      return ("+%d max HP and %d%% less damage taken."):format(math.floor(7 * l * m), pct(0.04 * l * m))
    end,
    apply = function(run, ctx)
      run:addFlat("maxHP", math.floor(7 * ctx.level * ctx.mult))
      run:addMult("damageTakenMult", -0.04 * ctx.level * ctx.mult)
    end,
  },
  {
    id = "free_runner",
    family = "zephyr",
    name = "Free Runner",
    flavor = "Walls are suggestions with good posture.",
    maxLevel = 3,
    desc = function(l, m)
      return ("+%d%% move speed; wall jumps empower your next strike (+%d%%)."):format(
        pct(0.05 * l * m), pct(0.25 * l * m))
    end,
    apply = function(run, ctx)
      run:addMult("moveSpeedMult", 0.05 * ctx.level * ctx.mult)
      ctx.on("playerJump", function(player)
        -- only wall jumps carry the hurtLock signature
        if player.hurtLock and player.hurtLock > 0.1 and not player.onGround then
          run.custom.nextMeleeBonus = math.max(run.custom.nextMeleeBonus or 0, 0.25 * ctx.level * ctx.mult)
        end
      end)
    end,
  },
  {
    id = "arc_lantern",
    family = "tempest",
    name = "Arc Lantern",
    flavor = "It doesn't light the way. It clears it.",
    maxLevel = 3,
    desc = function(l, m)
      return ("Entering a room zaps the nearest enemy for %d damage."):format(math.floor(18 * l * m))
    end,
    apply = function(run, ctx)
      -- the strike waits until the room has something to hit (spawns telegraph in)
      ctx.on("roomEntered", function(room) run.custom.arcPending = room end)
      ctx.on("tick", function(dt, r)
        if run.custom.arcPending ~= r then return end
        local p = r.player
        if not p or p.dead then return end
        local e = r:nearestEnemy(p.x, p.y, 400)
        if e then
          run.custom.arcPending = nil
          local ex, ey = e:center()
          particles.burst(ex, ey, { 1, 0.95, 0.5 }, 8, { speed = 90, kind = "spark", gravity = 0 })
          sfx.play("zap", 0.9)
          e:takeDamage(18 * ctx.level * ctx.mult, nil, p, { zapProc = true, noHitstop = true })
        end
      end)
    end,
  },
  {
    id = "glasswing",
    family = "ash",
    name = "Glasswing",
    flavor = "Fragile things cut deepest.",
    maxLevel = 1,
    legendary = true,
    unlock = "boons_legendary",
    weight = 0.35,
    desc = function(l, m)
      _ = l
      return ("+%d%% crit chance, and crits instantly refresh your dash."):format(pct(0.15 * m))
    end,
    apply = function(run, ctx)
      run:addFlat("critChance", 0.15 * ctx.mult)
      ctx.on("enemyDamaged", function(enemy, amount, meta)
        if meta.crit then
          local room = run.currentRoom
          if room and room.player then
            room.player.dashCd = 0
            room.player.airDashesUsed = 0
          end
        end
      end)
    end,
  },
}
