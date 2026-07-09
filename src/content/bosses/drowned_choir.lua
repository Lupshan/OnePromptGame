-- Biome 2 boss: the Drowned Choir. Three voices in one drowned body.
-- Flying bullet-pattern caster: radial hymns, homing verses, wisp summons.
local function drawChoir(boss)
  local love = love
  local cx, cy = boss:center()
  local t = boss.anim
  -- three hooded figures orbiting a shared core
  for i = 0, 2 do
    local a = t * 0.9 + i * math.pi * 2 / 3
    local ox = math.cos(a) * boss.w * 0.34
    local oy = math.sin(a) * boss.h * 0.22
    love.graphics.polygon("fill",
      cx + ox, cy + oy - 14,
      cx + ox + 9, cy + oy + 10,
      cx + ox, cy + oy + 14,
      cx + ox - 9, cy + oy + 10)
  end
  love.graphics.circle("fill", cx, cy, 7 + math.sin(t * 3) * 1.5)
end

return {
  id = "drowned_choir",
  name = "THE DROWNED CHOIR",
  title = "Three Voices, One Grave",
  hp = 760,
  damage = 14,
  w = 52, h = 40,
  flying = true,
  immovable = true,
  color = { 0.25, 0.6, 0.55 },
  eyeColor = { 0.6, 1, 0.9 },
  projectileColor = { 0.45, 0.95, 0.8 },
  drawShape = drawChoir,

  phases = {
    {
      below = 1.0, rest = 1.3,
      patterns = {
        function(boss, api)
          -- hymn: slow expanding rings
          api.telegraph(0.6)
          for i = 1, 3 do
            api.radial(9, 95 + i * 12, { angleOffset = i * 0.23, damageMult = 0.7 })
            api.wait(0.55)
          end
        end,
        function(boss, api)
          -- drift over the player, drop verses
          local px = api.playerPos()
          api.moveTo(px, boss.room.world.heightPx * 0.3, 130)
          api.telegraph(0.4)
          for _ = 1, 3 do
            api.aimed(150, { homing = true, homingStrength = 1.6, trail = true, damageMult = 0.85 })
            api.wait(0.45)
          end
        end,
      },
    },
    {
      below = 0.6, rest = 1.1,
      onEnter = function(boss, api) api.summon("willowisp", 2, { maxAdds = 3 }) end,
      patterns = {
        function(boss, api)
          api.telegraph(0.55)
          for i = 1, 4 do
            api.radial(11, 105, { angleOffset = i * 0.35, damageMult = 0.65 })
            api.wait(0.45)
          end
        end,
        function(boss, api)
          -- sweep across the arena raining shots
          local w = boss.room.world.widthPx
          local y = boss.room.world.heightPx * 0.28
          api.moveTo(w * 0.2, y, 170)
          local t = 0
          while t < 1.6 do
            api.aimed(170, { gravity = 220, damageMult = 0.8 })
            api.wait(0.3)
            t = t + 0.3
            local cx = boss:center()
            boss.x = boss.x + 130 * 0.3 * (cx < w * 0.8 and 1 or 0)
          end
        end,
        function(boss, api)
          api.summon("bogshade", 1, { maxAdds = 3 })
          api.wait(0.5)
          api.aimed(160, { homing = true, homingStrength = 2.0, trail = true })
        end,
      },
    },
    {
      below = 0.25, rest = 0.85,
      patterns = {
        function(boss, api)
          -- the full choir sings
          api.telegraph(0.6)
          for i = 1, 5 do
            api.radial(13, 115, { angleOffset = i * 0.29, damageMult = 0.6 })
            api.wait(0.38)
          end
        end,
        function(boss, api)
          for _ = 1, 4 do
            api.aimed(185, { homing = true, homingStrength = 2.4, trail = true, damageMult = 0.8 })
            api.wait(0.32)
          end
        end,
      },
    },
  },
}
