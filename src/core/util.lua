-- Small generic helpers used everywhere.
local util = {}

function util.clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

function util.lerp(a, b, t) return a + (b - a) * t end

-- Frame-rate independent exponential approach.
-- k is "fraction remaining after 1 second" style damping; higher = snappier.
function util.damp(a, b, k, dt)
  return util.lerp(a, b, 1 - math.exp(-k * dt))
end

function util.sign(v)
  if v > 0 then return 1 elseif v < 0 then return -1 end
  return 0
end

function util.round(v) return math.floor(v + 0.5) end

function util.dist(x1, y1, x2, y2)
  local dx, dy = x2 - x1, y2 - y1
  return math.sqrt(dx * dx + dy * dy)
end

function util.dist2(x1, y1, x2, y2)
  local dx, dy = x2 - x1, y2 - y1
  return dx * dx + dy * dy
end

function util.angle(x1, y1, x2, y2) return math.atan2(y2 - y1, x2 - x1) end

-- Move value toward target by at most `amount`.
function util.approach(v, target, amount)
  if v < target then return math.min(v + amount, target) end
  return math.max(v - amount, target)
end

function util.aabb(ax, ay, aw, ah, bx, by, bw, bh)
  return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah
end

function util.pointInRect(px, py, x, y, w, h)
  return px >= x and px <= x + w and py >= y and py <= y + h
end

-- Shallow copy.
function util.copy(t)
  local r = {}
  for k, v in pairs(t) do r[k] = v end
  return r
end

-- Deep copy (tables only, no cycles expected in our data).
function util.deepcopy(t)
  if type(t) ~= "table" then return t end
  local r = {}
  for k, v in pairs(t) do r[k] = util.deepcopy(v) end
  return r
end

-- Merge b into a copy of a (shallow).
function util.merged(a, b)
  local r = util.copy(a)
  if b then for k, v in pairs(b) do r[k] = v end end
  return r
end

function util.contains(list, v)
  for i = 1, #list do if list[i] == v then return true end end
  return false
end

function util.removeValue(list, v)
  for i = #list, 1, -1 do
    if list[i] == v then table.remove(list, i) return true end
  end
  return false
end

function util.keys(t)
  local r = {}
  for k in pairs(t) do r[#r + 1] = k end
  return r
end

function util.count(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

-- Filter list in place-ish (returns new list).
function util.filter(list, fn)
  local r = {}
  for i = 1, #list do
    if fn(list[i]) then r[#r + 1] = list[i] end
  end
  return r
end

function util.map(list, fn)
  local r = {}
  for i = 1, #list do r[i] = fn(list[i]) end
  return r
end

-- Remove dead entities in place (entity.dead == true). Preserves order.
function util.sweep(list)
  local j = 1
  for i = 1, #list do
    local e = list[i]
    if not e.dead then
      list[j] = e
      j = j + 1
    end
  end
  for i = #list, j, -1 do list[i] = nil end
end

-- Serialize a plain-data table (numbers, strings, booleans, nested tables) to lua source.
function util.serialize(v, indent)
  indent = indent or ""
  local t = type(v)
  if t == "number" or t == "boolean" then return tostring(v) end
  if t == "string" then return string.format("%q", v) end
  if t == "table" then
    local parts = {}
    local nextIndent = indent .. " "
    -- array part
    local n = #v
    for i = 1, n do
      parts[#parts + 1] = nextIndent .. util.serialize(v[i], nextIndent)
    end
    for k, val in pairs(v) do
      if not (type(k) == "number" and k >= 1 and k <= n and k == math.floor(k)) then
        local key
        if type(k) == "string" and k:match("^[%a_][%w_]*$") then
          key = k
        else
          key = "[" .. util.serialize(k, "") .. "]"
        end
        parts[#parts + 1] = nextIndent .. key .. " = " .. util.serialize(val, nextIndent)
      end
    end
    if #parts == 0 then return "{}" end
    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
  end
  return "nil"
end

-- Format seconds as M:SS.
function util.formatTime(s)
  local m = math.floor(s / 60)
  local sec = math.floor(s % 60)
  return string.format("%d:%02d", m, sec)
end

return util
