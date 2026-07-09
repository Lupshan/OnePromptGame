-- Boon system. A boon is content: a def with an apply() that registers stat
-- modifiers and event hooks. The run rebuilds all boons from scratch whenever
-- the set changes, so apply() must be idempotent and self-contained.
--
-- Families give identity; duo boons unlock when you own at least one boon
-- from each of their two families -- the Hades-style "build explosion".
local registry = require("src.game.registry")
local save = require("src.core.save")
local locale = require("src.core.locale")

local boons = {}

boons.RARITIES = {
  { id = "common", name = "Common", mult = 1.0, weight = 100, color = { 0.75, 0.78, 0.85 } },
  { id = "rare", name = "Rare", mult = 1.5, weight = 42, color = { 0.4, 0.75, 1.0 } },
  { id = "epic", name = "Epic", mult = 2.2, weight = 14, color = { 0.8, 0.5, 1.0 } },
  { id = "heroic", name = "Heroic", mult = 3.0, weight = 4, color = { 1.0, 0.75, 0.3 } },
}

function boons.rarity(id)
  for _, r in ipairs(boons.RARITIES) do
    if r.id == id then return r end
  end
  return boons.RARITIES[1]
end

function boons.family(id)
  return registry.get("family", id)
end

function boons.def(id)
  return registry.get("boon", id)
end

-- Families are registered by content files through this helper.
function boons.defineFamily(def)
  registry.add("family", def)
end

-- Which families does the run own at least one boon of?
local function ownedFamilies(run)
  local fams = {}
  for _, owned in ipairs(run.boons) do
    local def = boons.def(owned.id)
    if def then
      fams[def.family] = true
      if def.family2 then fams[def.family2] = true end
    end
  end
  return fams
end

function boons.owned(run, id)
  for _, o in ipairs(run.boons) do
    if o.id == id then return o end
  end
  return nil
end

-- Is this def offerable to this run right now?
local function offerable(run, def)
  if def.unlock and not save.isUnlocked(def.unlock) then return false end
  local owned = boons.owned(run, def.id)
  if owned and owned.level >= (def.maxLevel or 3) then return false end
  if def.duo then
    local fams = ownedFamilies(run)
    if not (fams[def.family] and fams[def.family2]) then return false end
    if owned then return false end -- duos don't level
  end
  if def.requires and not boons.owned(run, def.requires) then return false end
  return true
end

-- Roll one rarity given a luck multiplier (>1 shifts toward better).
function boons.rollRarity(rng, stream, luck)
  luck = luck or 1
  local total = 0
  local weights = {}
  for i, r in ipairs(boons.RARITIES) do
    local w = r.weight
    if i > 1 then w = w * luck end
    weights[i] = w
    total = total + w
  end
  local roll = rng:range(stream, 0, total)
  for i, w in ipairs(weights) do
    roll = roll - w
    if roll <= 0 then return boons.RARITIES[i] end
  end
  return boons.RARITIES[1]
end

-- Generate an offer of n distinct boon choices.
-- Returns list of { def, rarity, isUpgrade, currentLevel }
function boons.generateOffer(run, rng, stream, n)
  local pool = {}
  for _, def in ipairs(registry.all("boon")) do
    if offerable(run, def) then
      local w = def.weight or 1
      if def.duo then w = w * 1.6 end -- duos are the fun part: surface them
      pool[#pool + 1] = { def = def, weight = w }
    end
  end

  local luck = run:stat("luck", 1)
  local offer = {}
  for _ = 1, n do
    if #pool == 0 then break end
    local pick = rng:pickWeighted(stream, pool, function(p) return p.weight end)
    if not pick then break end
    for i, p in ipairs(pool) do
      if p == pick then table.remove(pool, i) break end
    end
    local owned = boons.owned(run, pick.def.id)
    local rarity = boons.rollRarity(rng, stream, luck)
    if pick.def.duo and rarity.id == "common" then rarity = boons.rarity("rare") end
    offer[#offer + 1] = {
      def = pick.def,
      rarity = rarity,
      isUpgrade = owned ~= nil,
      currentLevel = owned and owned.level or 0,
    }
  end
  return offer
end

-- Grant a boon (new or +1 level).
function boons.grant(run, defId, rarityId)
  local def = boons.def(defId)
  if not def then return end
  local owned = boons.owned(run, defId)
  if owned then
    owned.level = math.min(owned.level + 1, def.maxLevel or 3)
    local newR, oldR = boons.rarity(rarityId), boons.rarity(owned.rarity)
    if newR.mult > oldR.mult then owned.rarity = rarityId end
  else
    run.boons[#run.boons + 1] = { id = defId, level = 1, rarity = rarityId or "common" }
  end
  save.markSeen("boon:" .. defId)
  run:rebuildBoons()
end

function boons.describe(def, level, rarityId)
  local mult = boons.rarity(rarityId).mult
  return locale.boonDesc(def, level, mult)
end

-- Localized display helpers (fall back to the def's own English fields).
function boons.name(def)
  return locale.content("boons", def.id, "name", def.name)
end

function boons.flavor(def)
  return locale.content("boons", def.id, "flavor", def.flavor)
end

function boons.familyName(famDef)
  if not famDef then return "" end
  return locale.content("families", famDef.id, "name", famDef.name)
end

function boons.rarityName(rar)
  return locale.t("ui.rarity." .. rar.id)
end

return boons
