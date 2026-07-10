-- The player: a cinder wraith. Movement follows the "invisible tolerances"
-- school -- coyote time, jump buffering, apex float, corner correction,
-- jump-cut -- so controls always feel "just".
local config = require("src.core.config")
local util = require("src.core.util")
local physics = require("src.game.physics")
local input = require("src.core.input")
local signals = require("src.core.signals")
local particles = require("src.render.particles")
local juice = require("src.render.juice")
local draw = require("src.render.draw")
local sfx = require("src.audio.sfx")

local P = config.player

local Player = {}
Player.__index = Player

function Player.new(room, x, y, run)
  local self = setmetatable({}, Player)
  self.room = room
  self.run = run
  self.character = run and run.character or nil
  self.x, self.y = x, y
  self.w, self.h = P.w, P.h
  self.vx, self.vy = 0, 0
  self.facing = 1

  self.coyote = 0
  self.jumpBuf = 0
  self.wallCoyote = 0
  self.wallCoyoteDir = 0
  self.jumping = false
  self.airJumpsUsed = 0

  self.dashTimer = 0
  self.dashCd = 0
  self.dashDx, self.dashDy = 0, 0
  self.dashAvailable = true

  self.attackCd = 0
  self.comboStep = 0
  self.comboTimer = 0
  self.attackAnim = 0
  self.attackAngle = 0

  self.invuln = 0
  self.hurtLock = 0
  self.dead = false

  self.squashX, self.squashY = 1, 1
  self.trail = {}
  self.afterimages = {}
  self.wasOnGround = false
  self.dropTimer = 0
  self.anim = 0
  return self
end

-- Stat access: falls back to sane defaults outside a run (playground/tests).
function Player:stat(name, base)
  if self.run then return self.run:stat(name, base) end
  return base
end

function Player:maxHP()
  if self.run then return self.run:maxHP() end
  return P.maxHP
end

function Player:hp()
  if self.run then return self.run.hp end
  return self._soloHP or P.maxHP
end

function Player:setHP(v)
  if self.run then self.run.hp = util.clamp(v, 0, self.run:maxHP())
  else self._soloHP = v end
end

function Player:center()
  return self.x + self.w / 2, self.y + self.h / 2
end

-- Movement --------------------------------------------------------------------

function Player:update(dt)
  if self.dead then return end
  self.anim = self.anim + dt

  local world = self.room.world
  local ax = input.axisX()
  if self.hurtLock > 0 then
    self.hurtLock = self.hurtLock - dt
    ax = 0
  end

  -- timers
  self.coyote = math.max(0, self.coyote - dt)
  self.jumpBuf = math.max(0, self.jumpBuf - dt)
  self.wallCoyote = math.max(0, self.wallCoyote - dt)
  self.dashCd = math.max(0, self.dashCd - dt)
  self.attackCd = math.max(0, self.attackCd - dt)
  self.invuln = math.max(0, self.invuln - dt)
  self.dropTimer = math.max(0, self.dropTimer - dt)
  self.comboTimer = math.max(0, self.comboTimer - dt)
  if self.comboTimer <= 0 then self.comboStep = 0 end
  self.attackAnim = math.max(0, self.attackAnim - dt * 3.4)
  self.squashX = util.damp(self.squashX, 1, 12, dt)
  self.squashY = util.damp(self.squashY, 1, 12, dt)

  if input.pressed("jump") then self.jumpBuf = P.jumpBuffer end

  local speed = P.runSpeed * self:stat("moveSpeedMult", 1)

  -- Dash state ---------------------------------------------------------
  if self.dashTimer > 0 then
    self.dashTimer = self.dashTimer - dt
    self.vx = self.dashDx * P.dashSpeed * self:stat("dashPowerMult", 1)
    self.vy = self.dashDy * P.dashSpeed * self:stat("dashPowerMult", 1)
    if #self.afterimages == 0 or self.afterimages[#self.afterimages].t < love.timer.getTime() - 0.02 then
      self.afterimages[#self.afterimages + 1] = { x = self.x, y = self.y, facing = self.facing, t = love.timer.getTime(), life = 0.25 }
    end
    if self.dashTimer <= 0 then
      -- keep some momentum out of the dash
      self.vx = self.dashDx * speed * 1.1
      self.vy = math.min(self.vy, 0)
    end
  else
    -- Horizontal ------------------------------------------------------
    local accel = self.onGround and P.groundAccel or P.airAccel
    local decel = self.onGround and P.groundDecel or P.airDecel
    if ax ~= 0 then
      if util.sign(self.vx) ~= util.sign(ax) and self.vx ~= 0 then
        -- turning: apply decel too for snappy direction changes
        self.vx = util.approach(self.vx, ax * speed, (accel + decel) * dt)
      else
        self.vx = util.approach(self.vx, ax * speed, accel * dt)
      end
      self.facing = util.sign(ax)
    else
      self.vx = util.approach(self.vx, 0, decel * dt)
    end

    -- Wall slide ------------------------------------------------------
    local sliding = false
    if not self.onGround and self.vy > 0 and ax ~= 0 then
      if physics.touchingWall(world, self, util.sign(ax)) then
        sliding = true
        self.vy = math.min(self.vy, P.wallSlideSpeed)
        self.wallCoyote = P.wallCoyoteTime
        self.wallCoyoteDir = -util.sign(ax)
        if love.math.random() < dt * 22 then
          particles.dust(self.x + (ax > 0 and self.w or 0), self.y + self.h * 0.7, -ax, 1)
        end
      end
    end

    -- Gravity ---------------------------------------------------------
    local g = P.gravity
    if math.abs(self.vy) < P.apexThreshold and self.jumping then
      g = g * P.apexGravityMult
    elseif self.vy > 0 then
      g = g * P.fallGravityMult
    end
    self.vy = math.min(self.vy + g * dt, P.maxFall)
    _ = sliding

    -- Jumping ---------------------------------------------------------
    if self.jumpBuf > 0 then
      if self.onGround or self.coyote > 0 then
        self:doJump()
      elseif self.wallCoyote > 0 then
        self:doWallJump(self.wallCoyoteDir)
      elseif self.airJumpsUsed < self:stat("airJumps", 1) then
        self:doAirJump()
      end
    end

    -- Jump cut: releasing jump shortens the arc
    if self.jumping and self.vy < 0 and not input.down("jump") then
      self.vy = self.vy * P.jumpCutMult
      self.jumping = false
    end
    if self.vy >= 0 then self.jumping = false end
  end

  -- Dash input ---------------------------------------------------------
  if input.pressed("dash") and self.dashCd <= 0 and self.dashAvailable and self.dashTimer <= 0 then
    self:doDash(ax)
  end

  -- Drop through platforms
  if self.onGround and self.onPlatform and input.down("down") and input.pressed("jump") then
    self.dropTimer = 0.18
    self.jumpBuf = 0
    self.vy = math.max(self.vy, 40)
  end

  -- Move ----------------------------------------------------------------
  local wasGrounded = self.onGround
  local prevVy = self.vy
  physics.move(world, self, dt, {
    dropThrough = self.dropTimer > 0,
    cornerCorrection = self.vy < 0 and P.cornerCorrection or nil,
    ledgeStep = P.ledgeStep,
  })

  if self.onGround then
    self.coyote = P.coyoteTime
    self.airJumpsUsed = 0
    if P.dashRefreshOnGround then self.dashAvailable = true end
  end

  -- Landing juice
  if self.onGround and not wasGrounded and prevVy > 120 then
    local hard = prevVy > 380
    self.squashX, self.squashY = 1 + (hard and 0.35 or config.juice.squashLand), 1 - (hard and 0.3 or 0.18)
    particles.dust(self.x + self.w / 2, self.y + self.h, 0, hard and 8 or 4)
    sfx.play("land", hard and 1.0 or 0.6)
    if hard then juice.shake(1.6, 0.15) end
    signals.emit("playerLand", self, prevVy)
  end

  -- Run dust
  if self.onGround and math.abs(self.vx) > speed * 0.7 and love.math.random() < dt * 9 then
    particles.dust(self.x + self.w / 2 - self.facing * 4, self.y + self.h, -self.facing, 1)
  end

  -- Attack ---------------------------------------------------------------
  if input.pressed("attack") and self.attackCd <= 0 and self.dashTimer <= 0 then
    self:doMelee()
  end

  -- afterimages decay
  for i = #self.afterimages, 1, -1 do
    local a = self.afterimages[i]
    a.life = a.life - dt
    if a.life <= 0 then table.remove(self.afterimages, i) end
  end

  -- Hazards ---------------------------------------------------------------
  if world:rectHitsTile(self.x, self.y, self.w, self.h, physics.SPIKE) then
    self:hurt(14, self.x, self.y + 40)
    -- pop out of the hazard so spikes can't chain-kill
    self.vy = -300
    self.jumping = false
    self.dashTimer = 0
  end
  -- Kill plane: fell out of the room
  if self.y > world.heightPx + 60 then
    self:hurt(20, self.x, self.y, true)
    if not self.dead then self.room:respawnPlayer(self) end
  end

  self.wasOnGround = self.onGround
end

function Player:doJump()
  self.vy = -P.jumpVel * self:stat("jumpMult", 1)
  self.jumping = true
  self.jumpBuf = 0
  self.coyote = 0 -- consumed: prevents phantom double jumps
  self.squashX, self.squashY = 1 - config.juice.squashJump, 1 + config.juice.squashJump
  particles.dust(self.x + self.w / 2, self.y + self.h, 0, 3)
  sfx.play("jump")
  signals.emit("playerJump", self)
end

function Player:doAirJump()
  self.vy = -P.doubleJumpVel * self:stat("jumpMult", 1)
  self.jumping = true
  self.jumpBuf = 0
  self.airJumpsUsed = self.airJumpsUsed + 1
  self.squashX, self.squashY = 1 - config.juice.squashJump, 1 + config.juice.squashJump
  particles.ring(self.x + self.w / 2, self.y + self.h, { 0.7, 0.85, 1.0 }, 14)
  sfx.play("jump", 1.15)
  signals.emit("playerJump", self, true)
end

function Player:doWallJump(dir)
  self.vy = -P.wallJumpVelY
  self.vx = dir * P.wallJumpVelX
  self.facing = dir
  self.jumping = true
  self.jumpBuf = 0
  self.wallCoyote = 0
  self.hurtLock = math.max(self.hurtLock, P.wallJumpLockTime)
  self.squashX, self.squashY = 1 - config.juice.squashJump, 1 + config.juice.squashJump
  particles.dust(self.x + (dir > 0 and 0 or self.w), self.y + self.h / 2, dir, 5)
  sfx.play("jump", 0.9)
  signals.emit("playerJump", self)
end

function Player:doDash(ax)
  local dx, dy = 0, 0
  if input.down("left") then dx = -1 elseif input.down("right") then dx = 1 end
  if input.down("up") then dy = -1 elseif input.down("down") and not self.onGround then dy = 1 end
  if dx == 0 and dy == 0 then dx = self.facing end
  local len = math.sqrt(dx * dx + dy * dy)
  self.dashDx, self.dashDy = dx / len, dy / len
  if dx ~= 0 then self.facing = util.sign(dx) end
  self.dashTimer = P.dashTime
  self.dashCd = P.dashCooldown * self:stat("dashCooldownMult", 1)
  if not self.onGround then self.dashAvailable = false end
  self.vy = 0
  self.jumping = false
  self.invuln = math.max(self.invuln, P.dashTime + 0.02) -- dash i-frames
  particles.burst(self.x + self.w / 2, self.y + self.h / 2, { 0.65, 0.9, 1.0 }, 6, { speed = 40, gravity = 0, kind = "spark" })
  sfx.play("dash")
  signals.emit("playerDash", self)
  _ = ax
end

-- Combat -----------------------------------------------------------------------

function Player:doMelee()
  self.comboStep = (self.comboTimer > 0) and (self.comboStep % 3) + 1 or 1
  self.comboTimer = P.comboWindow
  self.attackCd = P.attackCooldown / self:stat("attackSpeedMult", 1)
  self.attackAnim = 1

  -- aim: up/down override, else facing; slight auto-aim toward nearest enemy
  local angle
  if input.down("up") then angle = -math.pi / 2
  elseif input.down("down") and not self.onGround then angle = math.pi / 2
  else
    angle = self.facing > 0 and 0 or math.pi
    local cx, cy = self:center()
    local nearest = self.room:nearestEnemy(cx, cy, P.attackRange * 1.6)
    if nearest then
      local ex, ey = nearest:center()
      local toward = util.angle(cx, cy, ex, ey)
      -- only adjust if roughly in the direction we're already facing
      local diff = math.abs(((toward - angle + math.pi) % (2 * math.pi)) - math.pi)
      if diff < 1.0 then angle = toward end
    end
  end
  self.attackAngle = angle

  local range = P.attackRange * self:stat("rangeMult", 1)
  local dmg = P.attackDamage * self:stat("damageMult", 1)
  local isFinisher = self.comboStep == 3
  if isFinisher then dmg = dmg * 1.6 end
  -- one-shot bonuses (e.g. Momentum after a dash)
  if self.run and self.run.custom.nextMeleeBonus then
    dmg = dmg * (1 + self.run.custom.nextMeleeBonus)
  end

  local cx, cy = self:center()
  local hits = self.room:enemiesInArc(cx, cy, angle, range, P.attackArc)
  local anyHit = false
  local downStrike = math.sin(angle) > 0.5
  for _, e in ipairs(hits) do
    anyHit = true
    local crit = love.math.random() < self:stat("critChance", 0)
    local final = crit and dmg * 2 or dmg
    e:takeDamage(final, angle, self, {
      melee = true, crit = crit, finisher = isFinisher, combo = self.comboStep,
      downStrike = downStrike, airborne = not self.onGround,
    })
  end

  -- pogo: down-strike on an enemy bounces the player
  if anyHit and math.sin(angle) > 0.5 then
    self.vy = -P.jumpVel * 0.85
    self.dashAvailable = true
    self.airJumpsUsed = 0
  end

  if anyHit then
    juice.hitstop(isFinisher and config.juice.hitstopHeavy or config.juice.hitstopLight)
    juice.shake(isFinisher and config.juice.shakeHeavy or config.juice.shakeLight, 0.18)
    if self.run then self.run.custom.nextMeleeBonus = nil end
  end
  sfx.play(anyHit and "hit" or "swing", isFinisher and 1.25 or 1)
  signals.emit("playerAttack", self, self.comboStep, anyHit)
end

function Player:hurt(amount, fromX, fromY, ignoreInvuln)
  if self.dead then return end
  if self.invuln > 0 and not ignoreInvuln then return end
  if self.invuln > 0 and ignoreInvuln and self.invuln > P.invulnTime - 0.1 then return end

  amount = amount * self:stat("damageTakenMult", 1)
  -- boons may intercept (shields etc.) by mutating this table
  local ev = { amount = amount, prevented = false }
  signals.emit("playerPreHurt", self, ev)
  if ev.prevented then
    self.invuln = math.max(self.invuln, 0.5)
    local cx, cy = self:center()
    particles.ring(cx, cy, { 0.4, 0.75, 1 }, 26)
    return
  end
  amount = ev.amount

  self:setHP(self:hp() - amount)
  self.invuln = P.invulnTime
  self.hurtLock = 0.18
  local cx = self:center()
  local dir = util.sign(cx - (fromX or cx))
  if dir == 0 then dir = -self.facing end
  self.vx = dir * 190
  self.vy = -160
  juice.shake(config.juice.shakeHeavy, 0.3)
  juice.hitstop(0.08)
  juice.flashScreen(1, 0.2, 0.25, 0.22)
  particles.burst(self.x + self.w / 2, self.y + self.h / 2, { 1, 0.3, 0.35 }, 10, { speed = 120 })
  sfx.play("playerHurt")
  signals.emit("playerHurt", self, amount)

  if self:hp() <= 0 then
    self.dead = true
    signals.emit("playerDied", self)
  end
end

function Player:heal(amount)
  amount = math.floor(amount * self:stat("healingMult", 1) + 0.5)
  local before = self:hp()
  self:setHP(before + amount)
  local gained = self:hp() - before
  if gained > 0 then
    particles.burst(self.x + self.w / 2, self.y + self.h / 2, { 0.4, 1, 0.55 }, 6, { speed = 40, gravity = -80 })
    particles.textPop(self.x + self.w / 2, self.y - 6, "+" .. math.floor(gained), { 0.4, 1, 0.55 })
    sfx.play("heal")
    signals.emit("playerHeal", self, gained)
  end
  return gained
end

-- Drawing ------------------------------------------------------------------------

function Player:draw()
  local col = self.character and self.character.color or { 0.88, 0.92, 1.0 }
  local glowCol = self.character and self.character.glowColor or { 0.55, 0.75, 1.0 }

  -- dash afterimages
  for _, a in ipairs(self.afterimages) do
    local t = a.life / 0.25
    love.graphics.setColor(glowCol[1], glowCol[2], glowCol[3], 0.35 * t)
    love.graphics.rectangle("fill", a.x, a.y + 3, self.w, self.h - 3, 3, 3)
  end

  local cx, cy = self:center()

  -- invuln flicker
  if self.invuln > 0 and math.floor(love.timer.getTime() * 18) % 2 == 0 and self.dashTimer <= 0 then
    love.graphics.setColor(1, 1, 1, 0.35)
  else
    love.graphics.setColor(col)
  end

  draw.glow(cx, cy, 26, glowCol[1], glowCol[2], glowCol[3], 0.35)

  -- body: rounded silhouette with squash & stretch
  local sw = self.w * self.squashX
  local sh = self.h * self.squashY
  local bx = cx - sw / 2
  local by = self.y + self.h - sh
  love.graphics.push()
  love.graphics.translate(cx, self.y + self.h)
  love.graphics.scale(self.squashX, self.squashY)
  love.graphics.translate(-cx, -(self.y + self.h))
  -- cloak silhouette
  love.graphics.polygon("fill",
    self.x + self.w / 2, self.y - 1,
    self.x + self.w + 1, self.y + self.h * 0.45,
    self.x + self.w - 1, self.y + self.h,
    self.x + 1, self.y + self.h,
    self.x - 1, self.y + self.h * 0.45)
  love.graphics.pop()
  _ = bx _ = by _ = sw _ = sh

  -- eyes: bright, face direction
  local ex = cx + self.facing * 2.4
  local ey = self.y + 5
  love.graphics.setColor(glowCol[1] * 1.2, glowCol[2] * 1.2, glowCol[3] * 1.2, 1)
  love.graphics.rectangle("fill", ex - 2.6, ey, 2, 2.4)
  love.graphics.rectangle("fill", ex + 1.2, ey, 2, 2.4)

  -- melee arc flash
  if self.attackAnim > 0 then
    local t = self.attackAnim
    local range = P.attackRange * self:stat("rangeMult", 1)
    love.graphics.setColor(1, 1, 1, t * 0.75)
    love.graphics.setLineWidth(2.5 * t)
    local a0 = self.attackAngle - P.attackArc * (1 - t * 0.4)
    local a1 = self.attackAngle + P.attackArc * (1 - t * 0.4)
    love.graphics.arc("line", "open", cx, cy, range * (0.75 + 0.25 * (1 - t)), a0, a1)
    love.graphics.setLineWidth(1)
  end

  love.graphics.setColor(1, 1, 1, 1)
end

return Player
