-- Aegis: shields, damage reduction, counters. The defense family.
local particles = require("src.render.particles")
local sfx = require("src.audio.sfx")

local function pct(v) return math.floor(v * 100 + 0.5) end

return {
  {
    id = "ember_shield",
    family = "aegis",
    name = "Ember Shield",
    flavor = "A wall the size of a heartbeat.",
    maxLevel = 3,
    desc = function(l, m)
      return ("A shield absorbs one hit, recharging after %.0fs."):format(math.max(6, 14 - 2 * l * m))
    end,
    apply = function(run, ctx)
      run.custom.shield = run.custom.shield or {}
      local shield = run.custom.shield
      shield.max = 1
      shield.charges = shield.charges or 1
      shield.rechargeTime = math.max(6, 14 - 2 * ctx.level * ctx.mult)
      shield.timer = shield.timer or 0

      ctx.on("tick", function(dt, room)
        if shield.charges < shield.max then
          shield.timer = shield.timer + dt
          if shield.timer >= shield.rechargeTime then
            shield.timer = 0
            shield.charges = shield.charges + 1
            sfx.play("shield")
            if room and room.player then
              local cx, cy = room.player:center()
              particles.ring(cx, cy, { 0.4, 0.75, 1 }, 26)
            end
          end
        end
      end)
      ctx.on("playerPreHurt", function(player, ev)
        if ev.prevented then return end
        if shield.charges > 0 then
          shield.charges = shield.charges - 1
          shield.timer = 0
          ev.prevented = true
          sfx.play("shield", 0.7)
          local cx, cy = player:center()
          particles.ring(cx, cy, { 0.4, 0.75, 1 }, 34)
          require("src.core.signals").emit("shieldBroken", player)
        end
      end)
    end,
  },
  {
    id = "tempered",
    family = "aegis",
    name = "Tempered",
    flavor = "Quenched in worse than this.",
    maxLevel = 3,
    desc = function(l, m)
      return ("Take %d%% less damage."):format(pct(0.08 * l * m))
    end,
    apply = function(run, ctx)
      run:addMult("damageTakenMult", -0.08 * ctx.level * ctx.mult)
    end,
  },
  {
    id = "bulwark_dash",
    family = "aegis",
    name = "Bulwark Dash",
    flavor = "Moving is a kind of armor.",
    maxLevel = 3,
    desc = function(l, m)
      return ("Dashing destroys enemy projectiles within %d px."):format(math.floor(28 + 8 * l * m))
    end,
    apply = function(run, ctx)
      ctx.on("playerDash", function(player)
        local room = run.currentRoom
        if not room then return end
        local cx, cy = player:center()
        local r = 28 + 8 * ctx.level * ctx.mult
        local util = require("src.core.util")
        local n = 0
        for _, p in ipairs(room.projectiles.list) do
          if not p.friendly and not p.dead and util.dist(cx, cy, p.x, p.y) < r then
            p.dead = true
            n = n + 1
            particles.burst(p.x, p.y, { 0.4, 0.75, 1 }, 4, { speed = 60, kind = "spark", gravity = 0 })
          end
        end
        if n > 0 then sfx.play("shield", 1.2, 0.6) end
      end)
    end,
  },
  {
    id = "retribution",
    family = "aegis",
    name = "Retribution",
    flavor = "Receipts, promptly issued.",
    maxLevel = 3,
    desc = function(l, m)
      return ("Taking a hit unleashes a shockwave: %d damage nearby."):format(math.floor(16 * l * m))
    end,
    apply = function(run, ctx)
      ctx.on("playerHurt", function(player, amount)
        local room = run.currentRoom
        if not room then return end
        local cx, cy = player:center()
        particles.ring(cx, cy, { 0.4, 0.75, 1 }, 52)
        sfx.play("explosion", 1.4, 0.5)
        for _, e in ipairs(room:enemiesInRadius(cx, cy, 58)) do
          e:takeDamage(16 * ctx.level * ctx.mult, nil, player, { retributionProc = true, noHitstop = true })
        end
      end)
    end,
  },
  {
    id = "poise",
    family = "aegis",
    name = "Poise",
    flavor = "The stance outlasts the storm.",
    maxLevel = 3,
    desc = function(l, m)
      return ("+%d max HP and +%d%% melee damage."):format(math.floor(8 * l * m), pct(0.06 * l * m))
    end,
    apply = function(run, ctx)
      run:addFlat("maxHP", math.floor(8 * ctx.level * ctx.mult))
      run:addMult("damageMult", 0.06 * ctx.level * ctx.mult)
    end,
  },
  {
    id = "unbreakable",
    family = "aegis",
    name = "Unbreakable",
    flavor = "They will write that you did not move.",
    maxLevel = 1,
    legendary = true,
    unlock = "boons_legendary",
    weight = 0.35,
    desc = function(l, m)
      _ = l
      return ("Dropping below 30%% HP triggers a %d-damage nova and 2s of invulnerability (once per room).")
        :format(math.floor(30 * m))
    end,
    apply = function(run, ctx)
      ctx.on("roomEntered", function() run.custom.unbreakableUsed = false end)
      ctx.on("playerHurt", function(player, amount)
        if run.custom.unbreakableUsed then return end
        if run.hp > 0 and run.hp / run:maxHP() < 0.3 then
          run.custom.unbreakableUsed = true
          player.invuln = math.max(player.invuln, 2)
          local room = run.currentRoom
          if not room then return end
          local cx, cy = player:center()
          particles.ring(cx, cy, { 0.4, 0.75, 1 }, 70)
          particles.burst(cx, cy, { 0.4, 0.75, 1 }, 18, { speed = 150, glow = 8 })
          sfx.play("explosion")
          for _, e in ipairs(room:enemiesInRadius(cx, cy, 80)) do
            e:takeDamage(30 * ctx.mult, nil, player, { novaProc = true })
          end
        end
      end)
    end,
  },
}
