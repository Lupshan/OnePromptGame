-- Central tuning. Everything gameplay-feel related lives here so the human
-- polish pass has one file to tweak.
local C = {}

C.TILE = 16          -- world tile size in pixels
C.ZOOM = 2.4         -- base camera zoom (world px -> screen px)

-- Player movement ----------------------------------------------------------
C.player = {
  w = 10, h = 17,
  runSpeed = 176,
  groundAccel = 2300,
  groundDecel = 2600,
  airAccel = 1750,
  airDecel = 900,
  gravity = 1450,
  fallGravityMult = 1.32,     -- heavier when falling: snappy arcs
  apexGravityMult = 0.55,     -- floaty at apex for landing control
  apexThreshold = 45,         -- |vy| below this counts as apex
  maxFall = 460,
  jumpVel = 388,
  jumpCutMult = 0.42,         -- releasing jump early cuts vy to this
  coyoteTime = 0.095,         -- ~6 frames
  jumpBuffer = 0.13,          -- ~8 frames
  cornerCorrection = 5,       -- px of head-bump forgiveness
  ledgeStep = 4,              -- px of automatic step-up over tiny lips

  doubleJumpVel = 356,

  dashSpeed = 430,
  dashTime = 0.14,
  dashCooldown = 0.42,
  dashRefreshOnGround = true,

  wallSlideSpeed = 78,
  wallJumpVelX = 235,
  wallJumpVelY = 360,
  wallJumpLockTime = 0.13,    -- horizontal input ignored briefly after walljump
  wallCoyoteTime = 0.08,

  maxHP = 100,
  invulnTime = 0.9,           -- after taking a hit
  contactDamage = 12,         -- damage taken from touching enemies (base)

  attackCooldown = 0.26,
  comboWindow = 0.55,
  attackDamage = 14,
  attackRange = 30,
  attackArc = 1.25,           -- radians half-angle of melee arc
  lungeSpeed = 60,            -- small forward push when attacking

  boltDamage = 10,
  boltSpeed = 380,
  boltCooldown = 0.85,
  boltRange = 240,            -- auto-aim acquisition radius
}

-- Juice ---------------------------------------------------------------------
C.juice = {
  hitstopLight = 0.045,
  hitstopHeavy = 0.11,
  shakeLight = 2.2,
  shakeHeavy = 5.5,
  squashJump = 0.16,
  squashLand = 0.22,
}

-- Run structure ---------------------------------------------------------------
C.run = {
  biomesPerRun = 3,          -- biomes traversed before the final boss
  graphLayers = 6,           -- node layers per biome (before boss layer)
  graphMinWidth = 2,
  graphMaxWidth = 4,
  healFountainAmount = 0.35, -- % of max HP restored at rest nodes
  shopSlots = 4,
  boonChoices = 3,
}

-- Economy ---------------------------------------------------------------------
C.economy = {
  emberDropCombat = { 14, 22 },   -- run currency from combat rooms
  emberDropElite = { 30, 42 },
  cinderDropBoss = { 55, 80 },    -- meta currency from bosses
  cinderDropElite = { 8, 14 },
  cinderPerBiome = 20,            -- flat meta payout for clearing a biome
}

-- Level generation ------------------------------------------------------------
C.levelgen = {
  roomHeight = 20,        -- tiles
  chunkWidth = 18,        -- tiles per chunk
  chunksCombat = { 3, 4 },
  chunksPlatforming = { 5, 7 },
  maxRegenAttempts = 5,   -- reachability failures before safe fallback
  maxGapTiles = 4,        -- conservative single-jump clearance used by the validator
  maxJumpUpTiles = 3,
}

C.debug = {
  -- Set by environment for automated smoke tests; see main.lua.
  smoke = os.getenv and (os.getenv("CENDRE_SMOKE") == "1") or false,
  screenshotDir = os.getenv and os.getenv("CENDRE_SHOTS") or nil,
}

return C
