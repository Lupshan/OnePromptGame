-- Biome 1 boss: the Pyravore. A furnace that learned hunger.
-- Grounded bruiser: charges, flame lobs, shockwaves, cinderling summons.
return {
  id = "pyravore",
  name = "PYRAVORE",
  title = "The Furnace That Hungers",
  hp = 620,
  damage = 16,
  w = 44, h = 40,
  speed = 34,
  drifts = true,
  knockbackMult = 0.1,
  color = { 0.9, 0.4, 0.15 },
  eyeColor = { 1, 0.95, 0.6 },
  projectileColor = { 1, 0.5, 0.15 },

  phases = {
    {
      below = 1.0, rest = 1.4,
      patterns = {
        function(boss, api)
          api.telegraph(0.55)
          api.charge(300)
        end,
        function(boss, api)
          api.telegraph(0.5)
          for _ = 1, 3 do
            api.aimed(190, { gravity = 500, kind = "blob", r = 5, damageMult = 0.9 })
            api.wait(0.4)
          end
        end,
        function(boss, api)
          api.telegraph(0.6)
          api.shockwave({ speed = 150 })
        end,
      },
    },
    {
      below = 0.62, rest = 1.15,
      onEnter = function(boss, api) api.summon("cinderling", 2) end,
      patterns = {
        function(boss, api)
          api.telegraph(0.5)
          api.charge(340)
          api.wait(0.25)
          api.shockwave({ speed = 170 })
        end,
        function(boss, api)
          api.telegraph(0.5)
          for i = 1, 4 do
            api.aimed(200, { gravity = 480, kind = "blob", r = 5, spread = (i - 2.5) * 0.16 })
            api.wait(0.28)
          end
        end,
        function(boss, api)
          api.summon("cinderling", 2)
          api.wait(0.6)
          api.radial(8, 120, { damageMult = 0.7 })
        end,
      },
    },
    {
      below = 0.28, rest = 0.9,
      patterns = {
        function(boss, api)
          api.telegraph(0.42)
          api.charge(380)
          api.wait(0.2)
          api.charge(380)
        end,
        function(boss, api)
          api.telegraph(0.5)
          api.radial(10, 140, { damageMult = 0.7 })
          api.wait(0.5)
          api.radial(10, 140, { angleOffset = math.pi / 10, damageMult = 0.7 })
        end,
        function(boss, api)
          api.telegraph(0.5)
          api.shockwave({ speed = 190 })
          api.wait(0.4)
          for _ = 1, 2 do
            api.aimed(210, { gravity = 460, kind = "blob", r = 5 })
            api.wait(0.3)
          end
        end,
      },
    },
  },
}
