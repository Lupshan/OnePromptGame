-- Tiny event bus. Boons, audio, UI and juice all react to gameplay events
-- through here, which keeps the core loop free of content-specific code.
local signals = {}
local listeners = {}

function signals.on(event, fn)
  local l = listeners[event]
  if not l then l = {} listeners[event] = l end
  l[#l + 1] = fn
  return fn
end

function signals.off(event, fn)
  local l = listeners[event]
  if not l then return end
  for i = #l, 1, -1 do
    if l[i] == fn then table.remove(l, i) end
  end
end

function signals.emit(event, ...)
  local l = listeners[event]
  if not l then return end
  -- iterate over a snapshot so handlers may subscribe/unsubscribe safely
  for i = 1, #l do
    local fn = l[i]
    if fn then fn(...) end
  end
end

-- Remove every listener (used when tearing down a run so boon hooks die with it).
function signals.clear(event)
  if event then listeners[event] = nil
  else listeners = {} end
end

-- Scoped groups: group:on(...) registrations can be nuked together.
function signals.group()
  local g = { subs = {} }
  function g.on(event, fn)
    signals.on(event, fn)
    g.subs[#g.subs + 1] = { event = event, fn = fn }
    return fn
  end
  function g.clear()
    for i = 1, #g.subs do
      signals.off(g.subs[i].event, g.subs[i].fn)
    end
    g.subs = {}
  end
  return g
end

return signals
