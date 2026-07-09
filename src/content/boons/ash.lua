-- Ash: neutral utility boons. No family identity, quiet power.
local function pct(v) return math.floor(v * 100 + 0.5) end

return {
  {
    id = "keen_edge",
    family = "ash",
    name = "Keen Edge",
    flavor = "Sharp is a philosophy.",
    maxLevel = 3,
    desc = function(l, m)
      return ("+%d%% melee damage."):format(pct(0.1 * l * m))
    end,
    apply = function(run, ctx)
      run:addMult("damageMult", 0.1 * ctx.level * ctx.mult)
    end,
  },
  {
    id = "hunters_eye",
    family = "ash",
    name = "Hunter's Eye",
    flavor = "Weak points introduce themselves.",
    maxLevel = 3,
    desc = function(l, m)
      return ("+%d%% critical chance (crits deal double damage)."):format(pct(0.05 * l * m))
    end,
    apply = function(run, ctx)
      run:addFlat("critChance", 0.05 * ctx.level * ctx.mult)
    end,
  },
  {
    id = "long_reach",
    family = "ash",
    name = "Long Reach",
    flavor = "The blade ends where you decide it does.",
    maxLevel = 3,
    desc = function(l, m)
      return ("+%d%% melee range."):format(pct(0.1 * l * m))
    end,
    apply = function(run, ctx)
      run:addMult("rangeMult", 0.1 * ctx.level * ctx.mult)
    end,
  },
  {
    id = "magpie_soul",
    family = "ash",
    name = "Magpie Soul",
    flavor = "Everything shiny wants to be found.",
    maxLevel = 3,
    desc = function(l, m)
      return ("+%d%% embers from all sources."):format(pct(0.2 * l * m))
    end,
    apply = function(run, ctx)
      run:addMult("emberGainMult", 0.2 * ctx.level * ctx.mult)
    end,
  },
  {
    id = "fortunes_favor",
    family = "ash",
    name = "Fortune's Favor",
    flavor = "Luck is loyalty the world hasn't explained.",
    maxLevel = 3,
    desc = function(l, m)
      return ("+%d%% chance of rarer boons."):format(pct(0.25 * l * m))
    end,
    apply = function(run, ctx)
      run:addMult("luck", 0.25 * ctx.level * ctx.mult)
    end,
  },
}
