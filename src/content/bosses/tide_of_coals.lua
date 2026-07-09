-- Biome 3 boss: the Tide of Coals. The sea noticed you walking on it.
-- A rolling wave-serpent: dives under the floor, erupts beneath the player,
-- rains coals, spits skimming fireballs along the ground.
local function drawTide(boss)
  local love = love
  local cx = boss.x + boss.w / 2
  local t = boss.anim
  -- serpent of coal segments, undulating
  for i = 0, 4 do
    local k = i / 4
    local ox = (k - 0.5) * boss.w * 0.95 * boss.facing
    local oy = math.sin(t * 3 + i * 1.2) * 6 - k * 4
    local r = (1 - k * 0.55) * boss.h * 0.32
    love.graphics.circle("fill", cx + ox, boss.y + boss.h * 0.55 + oy, r)
  end
  -- molten cracks
  love.graphics.setColor(1, 0.8, 0.3, 0.85)
  for i = 0, 3 do
    local ox = (i / 3 - 0.5) * boss.w * 0.7 * boss.facing
    love.graphics.circle("fill", cx + ox, boss.y + boss.h * 0.52 + math.sin(t * 3 + i) * 5, 2.2)
  end
end

return {
  id = "tide_of_coals",
  name = "TIDE OF COALS",
  title = "The Sea That Would Not Cool",
  hp = 850,
  damage = 15,
  w = 58, h = 34,
  speed = 60,
  drifts = true,
  flying = false,
  knockbackMult = 0.05,
  color = { 0.55, 0.2, 0.1 },
  eyeColor = { 1, 0.85, 0.4 },
  projectileColor = { 1, 0.55, 0.15 },
  drawShape = drawTide,

  phases = {
    {
      below = 1.0, rest = 1.25,
      patterns = {
        function(boss, api)
          -- skim: fireballs racing along the floor both ways
          api.telegraph(0.5)
          api.shockwave({ speed = 160, color = { 1, 0.55, 0.15 } })
        end,
        function(boss, api)
          -- coal rain over the player
          api.telegraph(0.55)
          local px = api.playerPos()
          for i = -2, 2 do
            boss.room:spawnProjectile({
              x = px + i * 34, y = 24, vx = 0, vy = 150 + math.abs(i) * 18,
              gravity = 160, damage = boss.damage * 0.8, friendly = false,
              color = { 1, 0.55, 0.15 }, kind = "blob", r = 4, life = 4,
            })
            api.wait(0.09)
          end
        end,
        function(boss, api)
          -- undertow: dive and erupt under the player
          local room = boss.room
          boss.telegraph = 0.3
          api.wait(0.3)
          boss.telegraph = 0
          local oldY = boss.y
          -- sink out of sight
          local t = 0
          while t < 0.4 do
            local dt = coroutine.yield()
            t = t + dt
            boss.y = boss.y + 90 * dt
          end
          api.wait(0.5)
          local px = api.playerPos()
          boss.x = px - boss.w / 2
          boss.y = oldY + 40
          -- eruption
          boss.telegraph = 0.45
          api.wait(0.45)
          boss.telegraph = 0
          t = 0
          while t < 0.3 do
            local dt = coroutine.yield()
            t = t + dt
            boss.y = boss.y - 300 * dt
          end
          boss.y = oldY
          api.radial(7, 130, { angleOffset = -math.pi / 2, damageMult = 0.75 })
          require("src.render.juice").shake(5, 0.3)
          _ = room
        end,
      },
    },
    {
      below = 0.55, rest = 1.0,
      onEnter = function(boss, api) api.summon("emberfly", 2, { maxAdds = 3 }) end,
      patterns = {
        function(boss, api)
          api.telegraph(0.45)
          api.charge(330)
          api.shockwave({ speed = 180, color = { 1, 0.55, 0.15 } })
        end,
        function(boss, api)
          api.telegraph(0.5)
          local px = api.playerPos()
          for i = -3, 3 do
            boss.room:spawnProjectile({
              x = px + i * 30, y = 24, vx = 0, vy = 160 + math.abs(i) * 16,
              gravity = 170, damage = boss.damage * 0.75, friendly = false,
              color = { 1, 0.55, 0.15 }, kind = "blob", r = 4, life = 4,
            })
            api.wait(0.07)
          end
        end,
        function(boss, api)
          api.summon("splitter", 1, { maxAdds = 3 })
          api.wait(0.4)
          for _ = 1, 3 do
            api.aimed(180, { gravity = 140, kind = "blob", r = 4.5, damageMult = 0.85 })
            api.wait(0.3)
          end
        end,
      },
    },
    {
      below = 0.25, rest = 0.8,
      patterns = {
        function(boss, api)
          -- boiling point: alternating skims and rains
          api.telegraph(0.4)
          api.shockwave({ speed = 200, color = { 1, 0.6, 0.2 } })
          api.wait(0.5)
          local px = api.playerPos()
          for i = -2, 2 do
            boss.room:spawnProjectile({
              x = px + i * 40, y = 24, vx = 0, vy = 190,
              gravity = 180, damage = boss.damage * 0.75, friendly = false,
              color = { 1, 0.6, 0.2 }, kind = "blob", r = 4, life = 4,
            })
          end
        end,
        function(boss, api)
          api.telegraph(0.4)
          api.charge(380)
          api.wait(0.15)
          api.charge(380)
          api.radial(9, 140, { damageMult = 0.65 })
        end,
      },
    },
  },
}
