-- Single source of truth for the game version, read from the VERSION file at
-- the repo root (kept in sync with conf.lua's window title). Falls back to a
-- hardcoded string if the file can't be read (e.g. fused builds).
local FALLBACK = "3.0.0"

local function read()
  if love and love.filesystem and love.filesystem.getInfo
     and love.filesystem.getInfo("VERSION") then
    local s = love.filesystem.read("VERSION")
    if s then
      s = s:gsub("%s+$", "")
      if #s > 0 then return s end
    end
  end
  return FALLBACK
end

return { string = read() }
