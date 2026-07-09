-- The run state: owns the Run, the current Room, the camera, and the
-- in-run overlays (map, boon pick, pause). This is the heartbeat of a run.
local state = require("src.core.state")
local config = require("src.core.config")
local input = require("src.core.input")
local signals = require("src.core.signals")
local juice = require("src.render.juice")
local particles = require("src.render.particles")
local draw = require("src.render.draw")
local Camera = require("src.render.camera")
local Run = require("src.game.run")
local Room = require("src.game.room")
local boonsSys = require("src.game.boons")
local hud = require("src.ui.hud")
local Boonpick = require("src.ui.boonpick")
local Mapview = require("src.ui.mapview")
local music = require("src.audio.music")
local sfx = require("src.audio.sfx")
local save = require("src.core.save")
local locale = require("src.core.locale")

local rungame = {}

local function setMusicForRoom(self)
  local biome = self.run:biome()
  local m = biome.music or {}
  local isBoss = self.room and self.room.roomType == "boss"
  music.setMood({
    key = biome.id .. (isBoss and ":boss" or ""),
    root = (m.root or 110) * (isBoss and 1.0 or 1.0),
    scale = m.scale, tempo = isBoss and (m.tempo or 70) + 18 or m.tempo,
    layers = isBoss and { "drone", "bass", "arp", "pulse", "melody" } or m.layers,
    intensity = isBoss and 1.25 or 1,
    seed = self.run.seed + self.run.biomeIndex * 977 + (isBoss and 5 or 0),
  })
end

function rungame:enterRoom(node)
  if self.room then self.room:destroy() end
  juice.reset()
  local stateSelf = self
  self.room = Room.new({
    run = self.run,
    node = node,
    callbacks = {
      onExit = function(room) stateSelf:onRoomExit(room) end,
      onSigil = function(data) stateSelf:openBoonOffer(data) end,
    },
  })
  self.run.currentRoom = self.room
  node.visited = true

  local p = self.room.player
  self.camera:setBounds(0, 0, self.room.world.widthPx, self.room.world.heightPx)
  self.camera:snapTo(p.x + p.w / 2, p.y + p.h / 2)
  self.mode = "room"
  self.roomFade = 1 -- fade-in
  setMusicForRoom(self)

  if config.debug.smoke then
    print(("[smoke] room type=%s biome=%s depth=%d fallback=%s"):format(
      self.room.roomType, self.run:biome().id, self.run.depth, tostring(self.room.usedFallback)))
  end
end

function rungame:enter(opts)
  opts = opts or {}
  signals.clear()
  local registry = require("src.game.registry")
  if not registry.loaded then
    registry.loadAll()
    registry.loaded = true
  end

  self.run = Run.new({ seed = opts.seed, characterId = opts.characterId })
  save.stat("runs", 1)
  self.camera = Camera.new()
  self.mode = "room"
  self.overlay = nil
  self.deathTimer = nil
  self.transition = nil
  hud.update(0)

  -- start node: gentle entry room, then a free first boon via the map flow
  self:enterRoom(self.run:currentNode())
  self:openBoonOffer({}) -- every run opens with a founding boon choice

  -- automated smoke script: hold right, jump periodically, pick first options
  if config.debug.smoke and love.smokeScript then
    local ticker = 0
    love.smokeScript(function(frame)
      ticker = ticker + 1
      if self.mode ~= "room" then
        if frame % 30 == 0 then input.keypressed("space") end
      else
        love.keyboard = love.keyboard -- real keyboard not scriptable; movement AI below
      end
      _ = ticker
    end)
  end
end

function rungame:leave()
  if self.room then self.room:destroy() end
  music.stop()
  if self.run then self.run:destroy() end
  signals.clear()
end

-- Flow ---------------------------------------------------------------------------

function rungame:onRoomExit(room)
  if self.transition then return end
  sfx.play("door")
  if room.roomType == "boss" then
    -- biome cleared
    self.run:addCinders(config.economy.cinderPerBiome)
    if self.run:isFinalBiome() then
      -- victory!
      local runRef = self.run
      self.transition = { t = 0, fn = function()
        state.switch("victory", runRef)
      end }
      return
    else
      self.run.biomeIndex = self.run.biomeIndex + 1
      self.run:buildGraph()
      self.run:onRoomCleared(room)
      self.transition = { t = 0, fn = function()
        self.overlay = Mapview.new(self.run, function(node)
          self.run:advanceTo(node.id)
          self.overlay = nil
          self:enterRoom(node)
        end)
        self.mode = "overlay"
      end }
      return
    end
  end

  self.run:onRoomCleared(room)
  self.transition = { t = 0, fn = function()
    self.overlay = Mapview.new(self.run, function(node)
      self.run:advanceTo(node.id)
      self.overlay = nil
      self:enterRoom(node)
    end)
    self.mode = "overlay"
  end }
end

function rungame:openBoonOffer(data)
  data = data or {}
  local rng = self.run.rng
  local offer = boonsSys.generateOffer(self.run, rng, "boons", config.run.boonChoices)
  if data.epicBias then
    for _, o in ipairs(offer) do
      if o.rarity.id == "common" then o.rarity = boonsSys.rarity("rare") end
    end
  end
  if #offer == 0 then
    self.run:addEmbers(25)
    return
  end
  self.overlay = Boonpick.new(self.run, offer, function()
    self.overlay = nil
    self.mode = "room"
  end)
  self.mode = "overlay"
end

-- Update ---------------------------------------------------------------------------

function rungame:update(dt)
  hud.update(dt)

  if self.transition then
    self.transition.t = self.transition.t + dt * 2.4
    if self.transition.t >= 1 then
      local fn = self.transition.fn
      self.transition = nil
      fn()
    end
    return
  end

  if self.mode == "overlay" and self.overlay then
    self.overlay:update(dt)
    return
  end

  if self.mode == "paused" then
    self:updatePause()
    return
  end

  if input.pressed("pause") then
    input.consume("pause")
    self.mode = "paused"
    self.pauseSel = 1
    return
  end

  -- smoke mode: drive the player automatically so headless runs exercise gameplay
  if config.debug.smoke then
    self:smokeDrive(dt)
  end

  local gdt = juice.filterDt(dt)
  self.run.time = self.run.time + gdt

  if gdt > 0 then
    self.room:update(gdt)
    signals.emit("tick", gdt, self.room, self.run)
  end
  particles.update(gdt)
  juice.update(dt, self.camera)

  local p = self.room.player
  if p and not p.dead then
    self.camera:follow(p.x + p.w / 2, p.y + p.h / 2, p.vx, dt)
  end

  self.roomFade = math.max(0, (self.roomFade or 0) - dt * 2.2)

  -- death
  if p and p.dead and not self.deathTimer then
    self.deathTimer = 1.4
    save.stat("deaths", 1)
    local st = save.get().stats
    st.bestBiome = math.max(st.bestBiome or 0, self.run.biomeIndex)
    save.write()
    juice.slow(0.3, 0.8)
    particles.burst(p.x + p.w / 2, p.y + p.h / 2, { 0.9, 0.95, 1 }, 26, { speed = 160, glow = 8 })
  end
  if self.deathTimer then
    self.deathTimer = self.deathTimer - dt
    if self.deathTimer <= 0 then
      state.switch("gameover", self.run)
    end
  end
end

-- Pause menu: resume, live settings, abandon.
local PAUSE_ITEMS = { "resume", "music", "sfx", "shake", "language", "abandon" }

function rungame:updatePause()
  local settings = save.get().settings
  self.pauseSel = self.pauseSel or 1

  if input.pressed("pause") or input.pressed("cancel") then
    input.consume("pause") input.consume("cancel")
    save.write()
    self.mode = "room"
    return
  end
  if input.pressed("up") then
    self.pauseSel = self.pauseSel > 1 and self.pauseSel - 1 or #PAUSE_ITEMS
    sfx.play("uiMove")
  elseif input.pressed("down") then
    self.pauseSel = self.pauseSel < #PAUSE_ITEMS and self.pauseSel + 1 or 1
    sfx.play("uiMove")
  end

  local item = PAUSE_ITEMS[self.pauseSel]
  local delta = 0
  if input.pressed("left") then delta = -0.1 end
  if input.pressed("right") then delta = 0.1 end
  if delta ~= 0 then
    local util = require("src.core.util")
    if item == "music" then
      settings.musicVolume = util.clamp((settings.musicVolume or 0.7) + delta, 0, 1)
      music.applyVolume()
    elseif item == "sfx" then
      settings.sfxVolume = util.clamp((settings.sfxVolume or 0.8) + delta, 0, 1)
      sfx.play("uiSelect")
    elseif item == "shake" then
      settings.screenShake = util.clamp((settings.screenShake or 1) + delta, 0, 1.5)
    elseif item == "language" then
      locale.cycle()
    end
  end

  if input.pressed("confirm") then
    input.consume("confirm")
    if item == "resume" then
      save.write()
      self.mode = "room"
    elseif item == "language" then
      locale.cycle()
    elseif item == "abandon" then
      save.write()
      state.switch("title")
    end
  end
end

function rungame:drawPause()
  local sw, sh = love.graphics.getDimensions()
  local settings = save.get().settings
  love.graphics.setColor(0.02, 0.02, 0.05, 0.85)
  love.graphics.rectangle("fill", 0, 0, sw, sh)
  draw.textCentered(locale.t("ui.pause.header"), sw / 2, sh * 0.22, 30, { 1, 1, 1, 1 })

  local values = {
    music = math.floor((settings.musicVolume or 0.7) * 100 + 0.5) .. "%",
    sfx = math.floor((settings.sfxVolume or 0.8) * 100 + 0.5) .. "%",
    shake = math.floor((settings.screenShake or 1) * 100 + 0.5) .. "%",
    language = locale.languageName(),
  }
  local y0 = sh * 0.36
  for i, item in ipairs(PAUSE_ITEMS) do
    local selected = i == self.pauseSel
    local y = y0 + (i - 1) * 34
    local label = locale.t("ui.pause." .. item)
    if values[item] then label = label .. "   < " .. values[item] .. " >" end
    if selected then
      draw.textCentered(">", sw / 2 - draw.textWidth(label, 16) / 2 - 20, y + 2, 12, { 1, 0.55, 0.25, 1 })
    end
    draw.textCentered(label, sw / 2, y, 16, selected and { 1, 1, 1, 1 } or { 1, 1, 1, 0.5 })
  end

  -- current build summary
  local boonList = {}
  for _, owned in ipairs(self.run.boons) do
    local def = boonsSys.def(owned.id)
    if def then boonList[#boonList + 1] = boonsSys.name(def) .. " " .. owned.level end
  end
  if #boonList > 0 then
    draw.text(table.concat(boonList, "  ·  "), sw * 0.1, sh - 70, 10,
      { 1, 1, 1, 0.45 }, "center", sw * 0.8)
  end
end

-- Autopilot used only in CENDRE_SMOKE=1 headless runs. It cheats (culls
-- enemies, teleports to the exit) because its job is to traverse EVERY
-- system -- rooms, waves, bosses, boons, map, biome transitions, victory --
-- and crash if any of them is broken. It is not an AI player.
function rungame:smokeDrive(dt)
  self.smokeT = (self.smokeT or 0) + dt
  local room = self.room
  local p = room.player
  if not p or p.dead then return end

  -- exercise movement/combat systems
  p.vx = math.max(p.vx, 100)
  if p.onGround and (p.hitWall or love.math.random() < dt * 2) then p:doJump() end
  if love.math.random() < dt * 1.2 then p:doMelee() end
  if love.math.random() < dt * 0.4 and p.dashCd <= 0 then p:doDash(1) end

  -- survive: this is a systems tour, not a skill test
  if self.run.hp < 65 then self.run.hp = self.run:maxHP() end

  -- cull enemies so objectives progress
  self.smokeKillT = (self.smokeKillT or 0) + dt
  if self.smokeKillT > 0.5 then
    self.smokeKillT = 0
    local killed = 0
    for _, e in ipairs(room.enemies) do
      if not e.dead and killed < 3 then
        e:takeDamage(e.isBoss and 120 or 400, 0, p, { melee = true })
        killed = killed + 1
      end
    end
  end

  -- grab boon sigils
  for _, pk in ipairs(room.pickups.list) do
    if pk.kind == "sigil" and not pk.dead then
      p.x, p.y = pk.x - p.w / 2, pk.y - p.h
    end
  end

  -- head for the exit once it opens
  if room.exitOpen then
    self.smokeExitT = (self.smokeExitT or 0) + dt
    if self.smokeExitT > 2 then
      local T = require("src.game.physics").TILE
      p.x = (room.exitTile.c - 1.5) * T
      p.y = room.exitTile.r * T - p.h
      p.vx, p.vy = 0, 0
    end
  else
    self.smokeExitT = 0
  end
end

-- Draw ---------------------------------------------------------------------------

function rungame:draw()
  local sw, sh = love.graphics.getDimensions()

  self.camera:apply()
  self.room:draw(self.camera)
  self.camera:unapply()

  hud.draw(self.run, self.room)

  if self.roomFade and self.roomFade > 0 then
    love.graphics.setColor(0, 0, 0, self.roomFade)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
  end

  if self.transition then
    love.graphics.setColor(0, 0, 0, math.min(1, self.transition.t))
    love.graphics.rectangle("fill", 0, 0, sw, sh)
  end

  if self.mode == "overlay" and self.overlay then
    self.overlay:draw()
  end

  if self.mode == "paused" then
    self:drawPause()
  end

  love.graphics.setColor(1, 1, 1, 1)
end

state.register("rungame", rungame)
return rungame
