-- Run graph: the Slay-the-Spire-style node map for one biome. Layers of
-- nodes, edges only between adjacent layers, every node lies on a path from
-- start to boss (validated by construction + prune).
local rungraph = {}

-- Node types (iteration 02): traversal is the default fabric of a biome;
-- combat marks contested paths (enemies as hazards, exit never locked);
-- arena is the rare sealed fight. Specials as before.

-- opts: layers, minWidth, maxWidth, biomeIndex
function rungraph.generate(rng, stream, opts)
  local L = opts.layers
  local nodes = {}
  local layers = {}
  local nextId = 1

  local function addNode(layer, idx, count)
    local id = nextId
    nextId = nextId + 1
    nodes[id] = { id = id, layer = layer, index = idx, count = count,
                  edges = {}, type = "combat", visited = false }
    return id
  end

  -- start node (biome entrance)
  local startId = addNode(0, 1, 1)
  layers[0] = { startId }

  for l = 1, L do
    local width = rng:random(stream, opts.minWidth, opts.maxWidth)
    layers[l] = {}
    for i = 1, width do
      layers[l][i] = addNode(l, i, width)
    end
  end
  -- boss layer
  local bossId = addNode(L + 1, 1, 1)
  layers[L + 1] = { bossId }
  nodes[bossId].type = "boss"

  -- edges: connect each layer to the next preserving order (no crossings)
  for l = 0, L do
    local a, b = layers[l], layers[l + 1]
    -- every node in a gets >=1 edge; every node in b gets >=1 incoming
    local incoming = {}
    for i, fromId in ipairs(a) do
      -- map position proportionally
      local lo = math.max(1, math.floor((i - 1) / #a * #b) + 1 - 1)
      local hi = math.min(#b, math.ceil(i / #a * #b) + 1)
      lo = math.max(1, lo)
      local n = rng:random(stream, 1, 2)
      local picks = {}
      for _ = 1, n do
        local j = rng:random(stream, lo, hi)
        picks[j] = true
      end
      -- guarantee at least one
      if not next(picks) then picks[lo] = true end
      for j in pairs(picks) do
        local toId = b[j]
        local dup = false
        for _, e in ipairs(nodes[fromId].edges) do if e == toId then dup = true end end
        if not dup then
          nodes[fromId].edges[#nodes[fromId].edges + 1] = toId
          incoming[j] = true
        end
      end
    end
    -- orphans in b: connect from nearest node in a
    for j = 1, #b do
      if not incoming[j] then
        local i = math.max(1, math.min(#a, math.floor((j - 0.5) / #b * #a) + 1))
        local fromId = a[i]
        nodes[fromId].edges[#nodes[fromId].edges + 1] = b[j]
      end
    end
    -- sort edges left-to-right for stable UI
    for _, fromId in ipairs(a) do
      table.sort(nodes[fromId].edges, function(x, y)
        return nodes[x].index < nodes[y].index
      end)
    end
  end

  -- assign types ---------------------------------------------------------
  -- guarantees per biome: 1 shop, 1 rest (late), >=1 treasure, 1-2 elites
  local mids = {}
  for l = 1, L do
    for _, id in ipairs(layers[l]) do mids[#mids + 1] = id end
  end

  for _, id in ipairs(mids) do
    nodes[id].type = rng:chance(stream, 0.6) and "traversal" or "combat"
  end

  local function placeType(t, layerLo, layerHi, count)
    local candidates = {}
    for _, id in ipairs(mids) do
      local n = nodes[id]
      if n.layer >= layerLo and n.layer <= layerHi
         and (n.type == "combat" or n.type == "traversal") then
        candidates[#candidates + 1] = id
      end
    end
    rng:shuffle(stream, candidates)
    for i = 1, math.min(count, #candidates) do
      nodes[candidates[i]].type = t
    end
  end

  placeType("shop", 2, L - 1, 1)
  placeType("rest", L - 1, L, 1)
  placeType("treasure", 1, L, rng:random(stream, 1, 2))
  placeType("arena", 2, L, 1) -- THE sealed fight of the biome (plus the boss)
  placeType("event", 1, L, rng:random(stream, 0, 2))

  nodes[startId].type = "start"

  return {
    nodes = nodes,
    layers = layers,
    startId = startId,
    bossId = bossId,
    layerCount = L + 1,
  }
end

return rungraph
