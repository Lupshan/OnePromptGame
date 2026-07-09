-- Duo boons: require owning at least one boon from EACH of two families.
-- These are the build-defining payoffs that make a run click together.
local particles = require("src.render.particles")
local util = require("src.core.util")
local sfx = require("src.audio.sfx")

return {
  {
    id = "plasma_storm",
    family = "ember", family2 = "tempest", duo = true,
    name = "Plasma Storm",
    flavor = "Fire argued with lightning. Everyone lost.",
    maxLevel = 1,
    desc = function(l, m)
      _ = l
      return ("Burning enemies you strike detonate: %d damage in a blast."):format(math.floor(16 * m))
    end,
    apply = function(run, ctx)
      ctx.on("enemyDamaged", function(enemy, amount, meta, source)
        if meta.status or meta.plasmaProc or enemy.dead then return end
        if enemy.status.burn and (meta.melee or meta.bolt) then
          enemy.status.burn = nil
          local cx, cy = enemy:center()
          particles.burst(cx, cy, { 1, 0.7, 0.3 }, 12, { speed = 130, glow = 8 })
          particles.ring(cx, cy, { 1, 0.95, 0.5 }, 42)
          sfx.play("explosion", 1.2, 0.6)
          for _, e in ipairs(run.currentRoom:enemiesInRadius(cx, cy, 46)) do
            if not e.dead then
              e:takeDamage(16 * ctx.mult, nil, source, { plasmaProc = true, noHitstop = true })
            end
          end
        end
      end)
    end,
  },
  {
    id = "cinder_doom",
    family = "ember", family2 = "gloom", duo = true,
    name = "Cinder Doom",
    flavor = "The verdict arrives already on fire.",
    maxLevel = 1,
    desc = function(l, m)
      _ = l _ = m
      return "Doom bursts ignite everything near the victim."
    end,
    apply = function(run, ctx)
      ctx.on("enemyDamaged", function(enemy, amount, meta, source)
        if meta.status == "doom" then
          local room = run.currentRoom
          if not room then return end
          local cx, cy = enemy:center()
          particles.ring(cx, cy, { 1, 0.5, 0.2 }, 50)
          for _, e in ipairs(room:enemiesInRadius(cx, cy, 55)) do
            if not e.dead then
              e:applyStatus("burn", { time = 3, power = 2 * ctx.mult * run:stat("burnPower", 1), source = source })
            end
          end
        end
      end)
    end,
  },
  {
    id = "emberbloom",
    family = "ember", family2 = "verdance", duo = true,
    name = "Emberbloom",
    flavor = "Ash is just soil that hasn't decided yet.",
    maxLevel = 1,
    desc = function(l, m)
      _ = l
      return ("Enemies that die burning drop a healing mote (%d HP)."):format(math.floor(3 * m))
    end,
    apply = function(run, ctx)
      ctx.on("enemyKilled", function(enemy, source, meta)
        if meta.cleanup then return end
        if enemy.status.burn or meta.status == "burn" then
          local room = run.currentRoom
          if not room then return end
          local cx, cy = enemy:center()
          room:spawnPickup({ kind = "mote", x = cx, y = cy, value = math.floor(3 * ctx.mult), scatter = true })
        end
      end)
    end,
  },
  {
    id = "slipstream_surge",
    family = "tempest", family2 = "zephyr", duo = true,
    name = "Slipstream Surge",
    flavor = "Wear the storm like a second skin.",
    maxLevel = 1,
    desc = function(l, m)
      _ = l
      return ("Dashing zaps the 2 nearest enemies for %d lightning damage."):format(math.floor(12 * m))
    end,
    apply = function(run, ctx)
      ctx.on("playerDash", function(player)
        local room = run.currentRoom
        if not room then return end
        local cx, cy = player:center()
        local sorted = {}
        for _, e in ipairs(room.enemies) do
          if not e.dead then
            local ex, ey = e:center()
            sorted[#sorted + 1] = { e = e, d = util.dist2(cx, cy, ex, ey) }
          end
        end
        table.sort(sorted, function(a, b) return a.d < b.d end)
        for i = 1, math.min(2, #sorted) do
          if sorted[i].d < 150 * 150 then
            local e = sorted[i].e
            local ex, ey = e:center()
            for j = 0, 5 do
              local t = j / 5
              particles.spawn({ x = util.lerp(cx, ex, t), y = util.lerp(cy, ey, t),
                life = 0.18, size = 2, sizeEnd = 0, color = { 1, 0.95, 0.5 }, kind = "dot", glow = 6 })
            end
            e:takeDamage(12 * ctx.mult, nil, player, { zapProc = true, noHitstop = true })
          end
        end
        if #sorted > 0 then sfx.play("zap", 0.9) end
      end)
    end,
  },
  {
    id = "null_ward",
    family = "gloom", family2 = "aegis", duo = true,
    name = "Null Ward",
    flavor = "The shield doesn't break. It disagrees.",
    maxLevel = 1,
    desc = function(l, m)
      _ = l _ = m
      return "When your shield absorbs a hit, nearby enemies are Doomed."
    end,
    apply = function(run, ctx)
      ctx.on("shieldBroken", function(player)
        local room = run.currentRoom
        if not room then return end
        local cx, cy = player:center()
        particles.ring(cx, cy, { 0.7, 0.45, 1 }, 60)
        for _, e in ipairs(room:enemiesInRadius(cx, cy, 66)) do
          if not e.dead then
            e:applyStatus("doom", { time = 2, power = ctx.mult, source = player })
          end
        end
      end)
    end,
  },
  {
    id = "heartwood",
    family = "verdance", family2 = "aegis", duo = true,
    name = "Heartwood",
    flavor = "The oldest walls are trees.",
    maxLevel = 1,
    desc = function(l, m)
      return ("Shield recharges heal %d HP. +%d max HP."):format(math.floor(6 * m), math.floor(10 * m))
    end,
    apply = function(run, ctx)
      run:addFlat("maxHP", math.floor(10 * ctx.mult))
      local last = 0
      ctx.on("tick", function(dt, room)
        local shield = run.custom.shield
        if not shield then return end
        if shield.charges > last and room and room.player and not room.player.dead then
          room.player:heal(math.floor(6 * ctx.mult))
        end
        last = shield.charges
      end)
    end,
  },
  {
    id = "backdraft",
    unlock = "boons_duo_rare",
    family = "ember", family2 = "aegis", duo = true,
    name = "Backdraft",
    flavor = "Open the door. Regret is instantaneous.",
    maxLevel = 1,
    desc = function(l, m)
      _ = l
      return ("Retaliation: getting hurt ignites everything within 70 px (power %.1f)."):format(2 * m)
    end,
    apply = function(run, ctx)
      ctx.on("playerHurt", function(player, amount)
        local room = run.currentRoom
        if not room then return end
        local cx, cy = player:center()
        particles.ring(cx, cy, { 1, 0.5, 0.2 }, 70)
        for _, e in ipairs(room:enemiesInRadius(cx, cy, 70)) do
          e:applyStatus("burn", { time = 3, power = 2 * ctx.mult * run:stat("burnPower", 1), source = player })
        end
      end)
    end,
  },
  {
    id = "static_collapse",
    unlock = "boons_duo_rare",
    family = "tempest", family2 = "gloom", duo = true,
    name = "Static Collapse",
    flavor = "First the crackle. Then the quiet.",
    maxLevel = 1,
    desc = function(l, m)
      _ = l _ = m
      return "Applying Shock also Weakens. Applying Doom also Shocks."
    end,
    apply = function(run, ctx)
      ctx.on("statusApplied", function(enemy, kind, status)
        if enemy.dead then return end
        if kind == "shock" and not enemy.status.weaken then
          enemy:applyStatus("weaken", { time = 4, power = ctx.mult, maxPower = 4 })
        elseif kind == "doom" and not enemy.status.shock then
          enemy:applyStatus("shock", { time = 3, power = ctx.mult, maxPower = 3 })
        end
      end)
    end,
  },
  {
    id = "windfall",
    family = "zephyr", family2 = "verdance", duo = true,
    name = "Windfall",
    flavor = "What falls from the sky is yours to keep.",
    maxLevel = 1,
    desc = function(l, m)
      return ("Kills while airborne restore %d HP."):format(math.floor(3 * m))
    end,
    apply = function(run, ctx)
      ctx.on("enemyKilled", function(enemy, source, meta)
        if meta.cleanup then return end
        local room = run.currentRoom
        local p = room and room.player
        if p and not p.dead and not p.onGround then
          p:heal(math.floor(3 * ctx.mult))
        end
      end)
    end,
  },
  {
    id = "umbral_step",
    unlock = "boons_duo_rare",
    family = "gloom", family2 = "zephyr", duo = true,
    name = "Umbral Step",
    flavor = "Step out of the world. Let it miss you.",
    maxLevel = 1,
    desc = function(l, m)
      _ = l _ = m
      return "Dash i-frames last twice as long, and dashing Chills nearby enemies."
    end,
    apply = function(run, ctx)
      ctx.on("playerDash", function(player)
        player.invuln = math.max(player.invuln, 0.32)
        local room = run.currentRoom
        if not room then return end
        local cx, cy = player:center()
        for _, e in ipairs(room:enemiesInRadius(cx, cy, 50)) do
          if not e.dead then
            e:applyStatus("chill", { time = 2.5, power = 1.5 * ctx.mult, maxPower = 2.6 })
          end
        end
      end)
    end,
  },
}
