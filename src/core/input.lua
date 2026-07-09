-- Action-based input: keyboard + gamepad merged. States query actions,
-- never raw keys. Keyboard bindings are remappable: overrides live in
-- save.settings.keymap (action -> list of keys) and replace the defaults.
local input = {}

local defaultKeyMap = {
  left = { "left", "a", "q" },       -- q for AZERTY comfort
  right = { "right", "d" },
  up = { "up", "w", "z" },
  down = { "down", "s" },
  jump = { "space", "c", "k" },
  attack = { "x", "j" },
  special = { "v", "l" },
  dash = { "lshift", "rshift", "z", "i" },
  interact = { "e", "up", "return" },
  pause = { "escape", "p" },
  map = { "tab", "m" },
  confirm = { "return", "space", "x", "j" },
  cancel = { "escape", "c" },
}
-- note: z appears in both up and dash; dash takes lshift primarily on AZERTY/QWERTY.

local keyMap = {}

local function rebuildKeyMap()
  local save = require("src.core.save")
  local overrides = save.get().settings.keymap or {}
  keyMap = {}
  for action, keys in pairs(defaultKeyMap) do
    keyMap[action] = overrides[action] or keys
  end
end

-- Remappable actions surfaced in the options menu (system keys excluded).
input.REMAPPABLE = {
  "left", "right", "up", "down", "jump", "attack", "dash", "interact", "map", "pause",
}

function input.rebind(action, key)
  local save = require("src.core.save")
  local settings = save.get().settings
  settings.keymap = settings.keymap or {}
  settings.keymap[action] = { key }
  save.write()
  rebuildKeyMap()
end

function input.resetBindings()
  local save = require("src.core.save")
  save.get().settings.keymap = nil
  save.write()
  rebuildKeyMap()
end

function input.bindingLabel(action)
  local keys = keyMap[action] or defaultKeyMap[action] or {}
  return table.concat(keys, " / ")
end

local padMap = {
  jump = { "a" },
  attack = { "x" },
  special = { "y" },
  dash = { "b", "rightshoulder" },
  interact = { "dpup", "a" },
  pause = { "start" },
  map = { "back" },
  confirm = { "a" },
  cancel = { "b" },
  left = { "dpleft" },
  right = { "dpright" },
  up = { "dpup" },
  down = { "dpdown" },
}

local pressedThisFrame = {}
local joystick

function input.gamepadAdded(j)
  if j:isGamepad() then joystick = j end
end

function input.init()
  rebuildKeyMap()
  local joys = love.joystick.getJoysticks()
  for _, j in ipairs(joys) do
    if j:isGamepad() then joystick = j break end
  end
end

function input.down(action)
  local keys = keyMap[action]
  if keys then
    for i = 1, #keys do
      if love.keyboard.isDown(keys[i]) then return true end
    end
  end
  if joystick then
    local btns = padMap[action]
    if btns then
      for i = 1, #btns do
        if joystick:isGamepadDown(btns[i]) then return true end
      end
    end
    -- analog stick for movement
    if action == "left" and joystick:getGamepadAxis("leftx") < -0.35 then return true end
    if action == "right" and joystick:getGamepadAxis("leftx") > 0.35 then return true end
    if action == "up" and joystick:getGamepadAxis("lefty") < -0.5 then return true end
    if action == "down" and joystick:getGamepadAxis("lefty") > 0.5 then return true end
  end
  return false
end

-- Horizontal axis in [-1, 1].
function input.axisX()
  local x = 0
  if input.down("left") then x = x - 1 end
  if input.down("right") then x = x + 1 end
  if x == 0 and joystick then
    local ax = joystick:getGamepadAxis("leftx")
    if math.abs(ax) > 0.25 then x = ax end
  end
  return x
end

-- Edge-triggered press: fed by love callbacks, consumed by states each frame.
function input.keypressed(key)
  for action, keys in pairs(keyMap) do
    for i = 1, #keys do
      if keys[i] == key then pressedThisFrame[action] = true end
    end
  end
end

function input.gamepadpressed(_, btn)
  for action, btns in pairs(padMap) do
    for i = 1, #btns do
      if btns[i] == btn then pressedThisFrame[action] = true end
    end
  end
end

function input.pressed(action)
  return pressedThisFrame[action] == true
end

-- Consume a press so it doesn't double-trigger (e.g. menu then game).
function input.consume(action)
  pressedThisFrame[action] = nil
end

function input.endFrame()
  for k in pairs(pressedThisFrame) do pressedThisFrame[k] = nil end
end

return input
