-- The remaining duo pairs: every family combination now has a payoff.
local particles = require("src.render.particles")
local sfx = require("src.audio.sfx")

return {
  {
    id = "afterburner",
    family = "ember", family2 = "zephyr", duo = true,
    name = "Afterburner",
    flavor = "Exits should cost something. Make them pay it.",
    maxLevel = 1,
    desc = function(l, m)
      _ = l
      return ("Dashing launches two fireballs behind you (%d damage, ignite)."):format(math.floor(9 * m))
    end,
    apply = function(run, ctx)
      ctx.on("playerDash", function(player)
        local room = run.currentRoom
        if not room then return end
        local cx, cy = player:center()
        local back = math.atan2(-player.dashDy, -player.dashDx)
        for i = -1, 1, 2 do
          local a = back + i * 0.22
          room:spawnProjectile({
            x = cx, y = cy, vx = math.cos(a) * 240, vy = math.sin(a) * 240,
            damage = 9 * ctx.mult, friendly = true,
            color = { 1, 0.55, 0.2 }, kind = "bolt", r = 3, life = 1.2, trail = true,
            onHit = function(e)
              if not e.dead then
                e:applyStatus("burn", { time = 2.5, power = ctx.mult * run:stat("burnPower", 1), source = player })
              end
            end,
          })
        end
        sfx.play("bolt", 0.8, 0.6)
      end)
    end,
  },
  {
    id = "storm_sap",
    family = "tempest", family2 = "verdance", duo = true,
    name = "Storm Sap",
    flavor = "Lightning is just the sky watering something.",
    maxLevel = 1,
    desc = function(l, m)
      return ("Lightning procs (chains, discharges, zaps) restore %d HP (max once per second)."):format(math.floor(2 * m))
    end,
    apply = function(run, ctx)
      local cd = 0
      ctx.on("tick", function(dt) cd = math.max(0, cd - dt) end)
      ctx.on("enemyDamaged", function(enemy, amount, meta)
        if (meta.chainProc or meta.shockProc or meta.zapProc or meta.tempestProc) and cd <= 0 then
          cd = 1
          local room = run.currentRoom
          if room and room.player and not room.player.dead then
            room.player:heal(math.floor(2 * ctx.mult))
          end
        end
      end)
    end,
  },
  {
    id = "faraday_ward",
    family = "tempest", family2 = "aegis", duo = true,
    name = "Faraday Ward",
    flavor = "Wear the cage. Be the storm inside it.",
    maxLevel = 1,
    desc = function(l, m)
      return ("+%d%% attack speed, and a broken shield zaps everything within 90 px for %d damage.")
        :format(math.floor(8 * m), math.floor(14 * m))
    end,
    apply = function(run, ctx)
      run:addMult("attackSpeedMult", 0.08 * ctx.mult)
      ctx.on("shieldBroken", function(player)
        local room = run.currentRoom
        if not room then return end
        local cx, cy = player:center()
        particles.ring(cx, cy, { 1, 0.95, 0.5 }, 90)
        sfx.play("zap")
        for _, e in ipairs(room:enemiesInRadius(cx, cy, 90)) do
          e:takeDamage(14 * ctx.mult, nil, player, { zapProc = true, noHitstop = true })
        end
      end)
    end,
  },
  {
    id = "blight_bloom",
    family = "gloom", family2 = "verdance", duo = true,
    name = "Blight Bloom",
    flavor = "Rot is a garden reading its own future.",
    maxLevel = 1,
    desc = function(l, m)
      return ("Doom bursts feed you: %d HP per detonation."):format(math.floor(4 * m))
    end,
    apply = function(run, ctx)
      ctx.on("enemyDamaged", function(enemy, amount, meta)
        if meta.status == "doom" then
          local room = run.currentRoom
          if room and room.player and not room.player.dead then
            room.player:heal(math.floor(4 * ctx.mult))
          end
        end
      end)
    end,
  },
  {
    id = "zephyr_rampart",
    family = "aegis", family2 = "zephyr", duo = true,
    name = "Zephyr's Rampart",
    flavor = "The best wall is the one that isn't there anymore.",
    maxLevel = 1,
    desc = function(l, m)
      _ = l _ = m
      return "Taking a hit instantly refreshes your dash and briefly hastens you."
    end,
    apply = function(run, ctx)
      ctx.on("playerHurt", function(player)
        player.dashCd = 0
        player.dashAvailable = true
        run.custom.rampartUntil = (run.custom.rampartUntil or 0)
        -- short burst of speed handled as a one-shot velocity kick
        player.vx = player.vx * 1.6
        particles.ring(player:center())
      end)
    end,
  },
}
