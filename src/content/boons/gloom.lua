-- Gloom: weaken, chill, doom, executions. The debuff family.
local particles = require("src.render.particles")

local function pct(v) return math.floor(v * 100 + 0.5) end

return {
  {
    id = "withering_mark",
    family = "gloom",
    name = "Withering Mark",
    flavor = "Name a thing frail and watch it agree.",
    maxLevel = 3,
    desc = function(l, m)
      return ("Your bolt Weakens enemies: they take +%d%% damage for 5s."):format(pct(0.15 * l * m))
    end,
    apply = function(run, ctx)
      ctx.on("boltHit", function(projectile, enemy)
        if not enemy.dead then
          enemy:applyStatus("weaken", { time = 5, power = ctx.level * ctx.mult, maxPower = 4 })
        end
      end)
    end,
  },
  {
    id = "grasp_of_gloom",
    family = "gloom",
    name = "Grasp of Gloom",
    flavor = "Cold hands make slow enemies.",
    maxLevel = 3,
    desc = function(l, m)
      return ("Melee strikes Chill enemies, slowing them %d%% for 3s."):format(
        math.min(65, pct(0.25 * l * m)))
    end,
    apply = function(run, ctx)
      ctx.on("enemyDamaged", function(enemy, amount, meta, source)
        if meta.melee and not meta.status and not enemy.dead then
          enemy:applyStatus("chill", { time = 3, power = ctx.level * ctx.mult, maxPower = 2.6 })
        end
      end)
    end,
  },
  {
    id = "executioner",
    family = "gloom",
    name = "Executioner",
    flavor = "Mercy is a door. Close it.",
    maxLevel = 3,
    desc = function(l, m)
      return ("Enemies below %d%% HP take a bonus %d%% of their max HP when struck."):format(
        20 + 2 * l, pct(0.08 * l * m))
    end,
    apply = function(run, ctx)
      ctx.on("enemyDamaged", function(enemy, amount, meta, source)
        if meta.execProc or meta.status or enemy.dead then return end
        local threshold = (20 + 2 * ctx.level) / 100
        if enemy.hp > 0 and enemy.hp / enemy.maxHP <= threshold then
          local bonus = enemy.maxHP * 0.08 * ctx.level * ctx.mult
          if enemy.isBoss then bonus = math.min(bonus, 25) end -- no boss deletion
          local cx, cy = enemy:center()
          particles.burst(cx, cy, { 0.7, 0.45, 1 }, 6, { speed = 90, kind = "shard" })
          enemy:takeDamage(bonus, nil, source, { execProc = true, noHitstop = true })
        end
      end)
    end,
  },
  {
    id = "creeping_doom",
    family = "gloom",
    name = "Creeping Doom",
    flavor = "Some debts collect themselves.",
    maxLevel = 3,
    desc = function(l, m)
      return ("Melee finishers apply Doom: %d damage after 2 seconds."):format(math.floor(26 * l * m))
    end,
    apply = function(run, ctx)
      ctx.on("enemyDamaged", function(enemy, amount, meta, source)
        if meta.melee and meta.finisher and not meta.status and not enemy.dead then
          enemy:applyStatus("doom", { time = 2, power = ctx.level * ctx.mult, source = source })
        end
      end)
    end,
  },
  {
    id = "umbral_veil",
    family = "gloom",
    name = "Umbral Veil",
    flavor = "The dark keeps what it likes. It likes you.",
    maxLevel = 3,
    desc = function(l, m)
      return ("Take %d%% less damage."):format(pct(0.07 * l * m))
    end,
    apply = function(run, ctx)
      run:addMult("damageTakenMult", -0.07 * ctx.level * ctx.mult)
    end,
  },
  {
    id = "event_horizon",
    family = "gloom",
    name = "Event Horizon",
    flavor = "Everything falls in. Eventually. Today.",
    maxLevel = 1,
    legendary = true,
    unlock = "boons_legendary",
    weight = 0.35,
    desc = function(l, m)
      _ = l _ = m
      return "Kills drag nearby enemies toward the corpse and Chill them."
    end,
    apply = function(run, ctx)
      ctx.on("enemyKilled", function(enemy, source, meta)
        if meta.cleanup then return end
        local room = run.currentRoom
        if not room then return end
        local cx, cy = enemy:center()
        particles.ring(cx, cy, { 0.7, 0.45, 1 }, 52)
        for _, e in ipairs(room:enemiesInRadius(cx, cy, 90)) do
          if not e.dead and not e.isBoss and not e.def.immovable then
            local ex, ey = e:center()
            local a = math.atan2(cy - ey, cx - ex)
            e.vx = e.vx + math.cos(a) * 180
            e.vy = e.vy + math.sin(a) * 120
            e:applyStatus("chill", { time = 2.5, power = 1.4 * ctx.mult, maxPower = 2.6 })
          end
        end
      end)
    end,
  },
}
