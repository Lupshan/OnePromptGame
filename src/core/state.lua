-- Game state machine (title, run, gameover, ...). States are tables with
-- optional callbacks: enter(...), leave, update(dt), draw, keypressed(key),
-- keyreleased(key), gamepadpressed(joy, btn), resize(w, h), textinput(t).
local state = {}
local current, currentName
local registry = {}

function state.register(name, s)
  registry[name] = s
  s.name = name
end

function state.switch(name, ...)
  local s = registry[name]
  assert(s, "unknown state: " .. tostring(name))
  if current and current.leave then current:leave() end
  current, currentName = s, name
  if s.enter then s:enter(...) end
end

function state.current() return currentName end
function state.get(name) return registry[name] end

local forwarded = {
  "update", "draw", "keypressed", "keyreleased", "mousepressed",
  "mousereleased", "mousemoved", "wheelmoved", "gamepadpressed",
  "gamepadreleased", "resize", "textinput",
}
for _, fn in ipairs(forwarded) do
  state[fn] = function(...)
    if current and current[fn] then return current[fn](current, ...) end
  end
end

return state
