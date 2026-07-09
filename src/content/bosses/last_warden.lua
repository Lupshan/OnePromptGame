-- Final boss: the Last Warden. What's left of the one who held the Spire.
-- Hybrid duelist: sword charges, beam volleys, arena-wide slams, echo summons.
local function drawWarden(boss)
  local love = love
  local cx = boss.x + boss.w / 2
  local bob = math.sin(boss.anim * 1.6) * 2
  local y = boss.y + bob
  -- towering armored silhouette
  love.graphics.polygon("fill",
    cx, y - 6,
    boss.x + boss.w + 2, y + boss.h * 0.4,
    boss.x + boss.w - 4, y + boss.h,
    boss.x + 4, y + boss.h,
    boss.x - 2, y + boss.h * 0.4)
  -- greatsword at rest, flips with facing
  local sx = cx + boss.facing * boss.w * 0.62
  love.graphics.rectangle("fill", sx - 2, y + boss.h * 0.15, 4, boss.h * 0.95)
  love.graphics.rectangle("fill", sx - 7, y + boss.h * 0.3, 14, 4)
  -- halo crown
  love.graphics.setColor(1, 0.85, 0.4, 0.8)
  love.graphics.circle("line", cx, y - 2, 10 + math.sin(boss.anim * 2) * 1.5)
end

return {
  id = "last_warden",
  name = "THE LAST WARDEN",
  title = "Still At His Post",
  hp = 950,
  damage = 18,
  w = 30, h = 46,
  speed = 46,
  drifts = true,
  knockbackMult = 0.05,
  color = { 0.42, 0.38, 0.66 },
  eyeColor = { 1, 0.85, 0.4 },
  projectileColor = { 0.95, 0.8, 0.45 },
  drawShape = drawWarden,

  phases = {
    {
      below = 1.0, rest = 1.3,
      patterns = {
        function(boss, api)
          api.telegraph(0.5)
          api.charge(330)
          api.wait(0.2)
          api.shockwave({ speed = 175, color = { 0.95, 0.8, 0.45 } })
        end,
        function(boss, api)
          api.telegraph(0.55)
          for i = -1, 1 do
            api.aimed(220, { spread = i * 0.22, damageMult = 0.85 })
          end
          api.wait(0.5)
          for i = -1, 1 do
            api.aimed(220, { spread = i * 0.22, damageMult = 0.85 })
          end
        end,
        function(boss, api)
          local px = api.playerPos()
          api.leapTo(px - boss.w / 2, boss.y, 0.8)
          api.shockwave({ speed = 160 })
        end,
      },
    },
    {
      below = 0.66, rest = 1.05,
      onEnter = function(boss, api) api.summon("echo", 1, { maxAdds = 2 }) end,
      patterns = {
        function(boss, api)
          api.telegraph(0.45)
          api.charge(370)
          api.wait(0.15)
          api.charge(370)
          api.shockwave({ speed = 185 })
        end,
        function(boss, api)
          api.telegraph(0.5)
          api.radial(12, 135, { damageMult = 0.65, color = { 0.95, 0.8, 0.45 } })
          api.wait(0.55)
          for i = -1, 1 do
            api.aimed(230, { spread = i * 0.2, damageMult = 0.8 })
          end
        end,
        function(boss, api)
          api.summon("sentinel", 1, { maxAdds = 2 })
          local px = api.playerPos()
          api.leapTo(px - boss.w / 2, boss.y, 0.7)
          api.shockwave({ speed = 175 })
        end,
      },
    },
    {
      below = 0.33, rest = 0.8,
      patterns = {
        function(boss, api)
          -- the Spire itself answers: raining judgment
          api.telegraph(0.6)
          local w = boss.room.world.widthPx
          for i = 1, 7 do
            local x = w * (0.12 + 0.12 * (i - 1))
            boss.room:spawnProjectile({
              x = x, y = 20, vx = 0, vy = 240,
              damage = boss.damage * 0.85, friendly = false,
              color = { 1, 0.85, 0.45 }, kind = "bolt", r = 4, life = 3,
            })
            api.wait(0.14)
          end
        end,
        function(boss, api)
          api.telegraph(0.4)
          api.charge(400)
          api.shockwave({ speed = 200 })
          api.wait(0.2)
          api.radial(14, 150, { damageMult = 0.6, color = { 0.95, 0.8, 0.45 } })
        end,
        function(boss, api)
          for _ = 1, 3 do
            api.aimed(200, { homing = true, homingStrength = 2.2, trail = true, damageMult = 0.75 })
            api.wait(0.3)
          end
          local px = api.playerPos()
          api.leapTo(px - boss.w / 2, boss.y, 0.6)
          api.shockwave({ speed = 190 })
        end,
      },
    },
  },
}
