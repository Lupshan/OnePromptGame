-- Playable cinder wraiths. Characters are sidegrades: different base kits,
-- never more raw power (the no-power-creep rule applies to them too).
return {
  {
    id = "wraith",
    name = "The Wraith",
    epithet = "First out of the fire",
    desc = "Balanced. The shape the ash takes when it remembers being someone.",
    color = { 0.88, 0.92, 1.0 },
    glowColor = { 0.55, 0.75, 1.0 },
    -- no unlock: always available
  },
  {
    id = "ashblade",
    name = "The Ashblade",
    epithet = "Edge without a sheath",
    desc = "+25% melee damage, faster dash — but 20 less HP. Get close, end it.",
    color = { 1.0, 0.7, 0.6 },
    glowColor = { 1.0, 0.45, 0.3 },
    unlock = "char_ashblade",
    apply = function(run, ctx)
      _ = ctx
      run:addMult("damageMult", 0.25)
      run:addMult("dashCooldownMult", -0.2)
      run:addFlat("maxHP", -20)
    end,
  },
  {
    id = "stormcaller",
    name = "The Stormcaller",
    epithet = "A grudge with weather",
    desc = "An extra air jump and a swifter dash, weaker blade. Never touch the ground.",
    color = { 0.8, 0.85, 1.0 },
    glowColor = { 1.0, 0.95, 0.5 },
    unlock = "char_stormcaller",
    apply = function(run, ctx)
      _ = ctx
      run:addFlat("airJumps", 1)
      run:addMult("dashCooldownMult", -0.15)
      run:addMult("damageMult", -0.15)
    end,
  },
  {
    id = "verdant",
    name = "The Verdant",
    epithet = "The part that refused to burn",
    desc = "+25 HP and stronger healing, slower feet. Outlast everything.",
    color = { 0.75, 1.0, 0.8 },
    glowColor = { 0.45, 1.0, 0.55 },
    unlock = "char_verdant",
    apply = function(run, ctx)
      _ = ctx
      run:addFlat("maxHP", 25)
      run:addMult("healingMult", 0.3)
      run:addMult("moveSpeedMult", -0.08)
    end,
  },
}
