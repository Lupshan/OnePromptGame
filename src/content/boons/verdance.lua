-- Verdance: life, healing, thorns. The sustain family.
local particles = require("src.render.particles")

local function pct(v) return math.floor(v * 100 + 0.5) end

return {
  {
    id = "sap_the_marrow",
    family = "verdance",
    name = "Sap the Marrow",
    flavor = "Green grows through whatever it must.",
    maxLevel = 3,
    desc = function(l, m)
      return ("Melee kills restore %d HP."):format(math.floor(2 * l * m))
    end,
    apply = function(run, ctx)
      ctx.on("enemyKilled", function(enemy, source, meta)
        if meta.cleanup then return end
        if meta.melee or (meta.status and meta.status == "doom") then
          local room = run.currentRoom
          if room and room.player and not room.player.dead then
            room.player:heal(math.floor(2 * ctx.level * ctx.mult))
          end
        end
      end)
    end,
  },
  {
    id = "regrowth",
    family = "verdance",
    name = "Regrowth",
    flavor = "Rest is also a weapon.",
    maxLevel = 3,
    desc = function(l, m)
      return ("Heal %d HP when a room is cleared."):format(math.floor(5 * l * m))
    end,
    apply = function(run, ctx)
      ctx.on("roomObjectiveDone", function(room)
        if room.player and not room.player.dead then
          room.player:heal(math.floor(5 * ctx.level * ctx.mult))
        end
      end)
    end,
  },
  {
    id = "barbed_hide",
    family = "verdance",
    name = "Barbed Hide",
    flavor = "Touch the bramble. See what it costs.",
    maxLevel = 3,
    desc = function(l, m)
      return ("Enemies that hurt you take %d damage."):format(math.floor(12 * l * m))
    end,
    apply = function(run, ctx)
      run:addFlat("thorns", 12 * ctx.level * ctx.mult)
      ctx.on("playerHurt", function(player, amount)
        local room = run.currentRoom
        if not room then return end
        local cx, cy = player:center()
        local dmg = run:stat("thorns", 0)
        particles.ring(cx, cy, { 0.45, 1, 0.55 }, 36)
        for _, e in ipairs(room:enemiesInRadius(cx, cy, 42)) do
          e:takeDamage(dmg, nil, player, { thornsProc = true, noHitstop = true })
        end
      end)
    end,
  },
  {
    id = "deep_roots",
    family = "verdance",
    name = "Deep Roots",
    flavor = "Hard to kill what half lives underground.",
    maxLevel = 3,
    desc = function(l, m)
      return ("+%d max HP."):format(math.floor(15 * l * m))
    end,
    apply = function(run, ctx)
      run:addFlat("maxHP", math.floor(15 * ctx.level * ctx.mult))
    end,
  },
  {
    id = "photosynthesis",
    family = "verdance",
    name = "Photosynthesis",
    flavor = "Even this light is enough.",
    maxLevel = 3,
    desc = function(l, m)
      return ("All healing you receive is +%d%% stronger."):format(pct(0.2 * l * m))
    end,
    apply = function(run, ctx)
      run:addMult("healingMult", 0.2 * ctx.level * ctx.mult)
    end,
  },
  {
    id = "second_bloom",
    family = "verdance",
    name = "Second Bloom",
    flavor = "The first death is a rehearsal.",
    maxLevel = 1,
    legendary = true,
    unlock = "boons_legendary",
    weight = 0.35,
    desc = function(l, m)
      _ = l _ = m
      return "Once per run: a killing blow leaves you at 30% HP instead."
    end,
    apply = function(run, ctx)
      ctx.on("playerPreHurt", function(player, ev)
        if run.custom.secondBloomUsed then return end
        if run.hp - ev.amount <= 0 then
          run.custom.secondBloomUsed = true
          ev.prevented = true
          run.hp = math.max(1, math.floor(run:maxHP() * 0.3))
          local cx, cy = player:center()
          particles.burst(cx, cy, { 0.45, 1, 0.55 }, 24, { speed = 140, glow = 10 })
          particles.ring(cx, cy, { 0.45, 1, 0.55 }, 60)
        end
      end)
    end,
  },
}
