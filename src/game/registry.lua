-- Generic content registry. Content files live under src/content/<kind>/ and
-- are auto-discovered: adding content to the game = dropping a file in the
-- right folder. Each file returns either one def or a list of defs.
local registry = {}
local stores = {}

local function store(kind)
  local s = stores[kind]
  if not s then
    s = { byId = {}, list = {} }
    stores[kind] = s
  end
  return s
end

function registry.add(kind, def)
  assert(def.id, "content def missing id in kind " .. kind)
  local s = store(kind)
  assert(not s.byId[def.id], "duplicate content id: " .. kind .. "/" .. def.id)
  s.byId[def.id] = def
  s.list[#s.list + 1] = def
end

function registry.get(kind, id)
  local d = store(kind).byId[id]
  return d
end

function registry.all(kind)
  return store(kind).list
end

-- Load every content file in src/content/<kind>/.
local function loadDir(kind, dir)
  local items
  if love and love.filesystem then
    items = love.filesystem.getDirectoryItems(dir)
  else
    -- headless tests: shell out
    items = {}
    local p = io.popen('ls "' .. dir .. '" 2>/dev/null')
    if p then
      for line in p:lines() do items[#items + 1] = line end
      p:close()
    end
  end
  table.sort(items)
  for _, file in ipairs(items) do
    local name = file:match("^(.*)%.lua$")
    if name then
      local defs = require(dir:gsub("/", ".") .. "." .. name)
      if defs.id then
        registry.add(kind, defs)
      else
        for _, def in ipairs(defs) do registry.add(kind, def) end
      end
    end
  end
end

function registry.loadAll()
  loadDir("biome", "src/content/biomes")
  loadDir("enemy", "src/content/enemies")
  loadDir("chunk", "src/content/chunks")
  loadDir("boon", "src/content/boons")
  loadDir("character", "src/content/characters")
  loadDir("unlock", "src/content/unlocks")
  loadDir("boss", "src/content/bosses")
end

return registry
