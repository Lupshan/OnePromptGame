-- Ember: burn (damage over time), ignition, explosions.
local particles = require("src.render.particles")
local sfx = require("src.audio.sfx")

local function pct(v) return math.floor(v * 100 + 0.5) end

return {
  {
    id = "kindled_blade",
    family = "ember",
    name = "Kindled Blade",
    flavor = "The edge remembers the forge.",
    maxLevel = 3,
    desc = function(l, m)
      return ("Melee strikes ignite enemies: %.1f burn power for 3s."):format(l * m)
    end,
    apply = function(run, ctx)
      ctx.on("enemyDamaged", function(enemy, amount, meta, source)
        if meta.melee and not meta.status and not enemy.dead then
          enemy:applyStatus("burn", {
            time = 3, power = ctx.level * ctx.mult * run:stat("burnPower", 1),
            source = source,
          })
        end
      end)
    end,
  },
  {
    id = "ashen_bolt",
    family = "ember",
    name = "Ashen Bolt",
    flavor = "Cast fire. It knows the way.",
    maxLevel = 3,
    desc = function(l, m)
      return ("Your bolt deals +%d%% damage and ignites its target."):format(pct(0.25 * l * m))
    end,
    apply = function(run, ctx)
      run:addMult("boltDamageMult", 0.25 * ctx.level * ctx.mult)
      ctx.on("boltHit", function(projectile, enemy)
        if not enemy.dead then
          enemy:applyStatus("burn", {
            time = 3, power = ctx.level * ctx.mult * run:stat("burnPower", 1),
            source = run.currentRoom and run.currentRoom.player,
          })
        end
      end)
    end,
  },
  {
    id = "flashpoint",
    family = "ember",
    name = "Flashpoint",
    flavor = "Leave nothing behind but heat.",
    maxLevel = 3,
    desc = function(l, m)
      return ("Dashing ignites enemies within %d px."):format(34 + 8 * l * m)
    end,
    apply = function(run, ctx)
      ctx.on("playerDash", function(player)
        local room = run.currentRoom
        if not room then return end
        local cx, cy = player:center()
        local r = 34 + 8 * ctx.level * ctx.mult
        for _, e in ipairs(room:enemiesInRadius(cx, cy, r)) do
          e:applyStatus("burn", { time = 2.5, power = ctx.level * ctx.mult * run:stat("burnPower", 1), source = player })
        end
        particles.ring(cx, cy, { 1, 0.5, 0.2 }, r)
      end)
    end,
  },
  {
    id = "stoke_the_coals",
    family = "ember",
    name = "Stoke the Coals",
    flavor = "A fire fed is a fire owed.",
    maxLevel = 3,
    desc = function(l, m)
      return ("All burn you inflict is +%d%% stronger."):format(pct(0.4 * l * m))
    end,
    apply = function(run, ctx)
      run:addMult("burnPower", 0.4 * ctx.level * ctx.mult)
    end,
  },
  {
    id = "cinder_burst",
    family = "ember",
    name = "Cinder Burst",
    flavor = "Endings should be loud.",
    maxLevel = 3,
    desc = function(l, m)
      return ("Enemies explode on death: %d damage in a small blast."):format(math.floor(10 * l * m))
    end,
    apply = function(run, ctx)
      ctx.on("enemyKilled", function(enemy, source, meta)
        if meta.cleanup or meta.burstProc then return end
        local room = run.currentRoom
        if not room then return end
        local cx, cy = enemy:center()
        local dmg = 10 * ctx.level * ctx.mult
        particles.burst(cx, cy, { 1, 0.55, 0.2 }, 10, { speed = 120, glow = 8 })
        particles.ring(cx, cy, { 1, 0.5, 0.2 }, 34)
        sfx.play("explosion", 1.3, 0.5)
        for _, e in ipairs(room:enemiesInRadius(cx, cy, 38)) do
          if e ~= enemy and not e.dead then
            e:takeDamage(dmg, nil, source, { burstProc = true, noHitstop = true })
          end
        end
      end)
    end,
  },
  {
    id = "living_flame",
    family = "ember",
    name = "Living Flame",
    flavor = "You stopped carrying the fire. Now it carries you.",
    maxLevel = 1,
    legendary = true,
    unlock = "boons_legendary",
    weight = 0.35,
    desc = function(l, m)
      _ = l
      return ("A fire aura ignites nearby enemies every second (power %.1f)."):format(1.2 * m)
    end,
    apply = function(run, ctx)
      local acc = 0
      ctx.on("tick", function(dt, room)
        acc = acc + dt
        if acc >= 1.0 then
          acc = acc - 1.0
          local p = room and room.player
          if p and not p.dead then
            local cx, cy = p:center()
            particles.ring(cx, cy, { 1, 0.5, 0.2 }, 44)
            for _, e in ipairs(room:enemiesInRadius(cx, cy, 48)) do
              e:applyStatus("burn", { time = 2, power = 1.2 * ctx.mult * run:stat("burnPower", 1), source = p })
            end
          end
        end
      end)
    end,
  },
}
