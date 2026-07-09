-- Localization. UI strings live in src/locale/<code>.lua as nested tables;
-- content (boons, enemies, biomes...) is translated in the same files under
-- `content`, keyed by content id, falling back to the def's own English
-- fields. Adding a language = adding one file + one entry in LANGUAGES.
local locale = {}

locale.LANGUAGES = {
  { code = "en", name = "English" },
  { code = "fr", name = "Français" },
}

local tables = {}
local current = "en"

local function load(code)
  if not tables[code] then
    local ok, t = pcall(require, "src.locale." .. code)
    tables[code] = ok and t or {}
  end
  return tables[code]
end

function locale.set(code)
  current = code
  load(code)
  local save = require("src.core.save")
  save.get().settings.language = code
  save.write()
end

function locale.init()
  local save = require("src.core.save")
  current = save.get().settings.language or "en"
  load("en")
  load(current)
end

function locale.get() return current end

function locale.cycle()
  for i, l in ipairs(locale.LANGUAGES) do
    if l.code == current then
      locale.set(locale.LANGUAGES[(i % #locale.LANGUAGES) + 1].code)
      return
    end
  end
  locale.set("en")
end

function locale.languageName()
  for _, l in ipairs(locale.LANGUAGES) do
    if l.code == current then return l.name end
  end
  return current
end

local function lookup(tbl, path)
  local node = tbl
  for part in path:gmatch("[^%.]+") do
    if type(node) ~= "table" then return nil end
    node = node[part]
  end
  return node
end

-- t("ui.title.begin") -> localized string (falls back to en, then the key).
function locale.t(path)
  local v = lookup(load(current), path)
  if v == nil and current ~= "en" then v = lookup(load("en"), path) end
  if v == nil then return path end
  return v
end

-- f("ui.hud.wave", 2, 3) -> formatted localized string.
function locale.f(path, ...)
  local template = locale.t(path)
  local ok, out = pcall(string.format, template, ...)
  return ok and out or template
end

-- Content lookup: content("boons", "kindled_blade", "name", def.name).
-- Returns the translation if the current language provides one, else fallback.
function locale.content(kind, id, field, fallback)
  local v = lookup(load(current), "content." .. kind .. "." .. id .. "." .. field)
  if v ~= nil then return v end
  return fallback
end

-- Localized boon description: locale files may provide desc as a
-- function(level, mult) mirroring the def's own desc.
function locale.boonDesc(def, level, mult)
  local v = lookup(load(current), "content.boons." .. def.id .. ".desc")
  if type(v) == "function" then
    local ok, out = pcall(v, level, mult)
    if ok then return out end
  elseif type(v) == "string" then
    return v
  end
  if type(def.desc) == "function" then return def.desc(level, mult) end
  return def.desc or ""
end

return locale
