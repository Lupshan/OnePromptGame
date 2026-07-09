-- Run map overlay: the biome's node graph, drawn bottom-up. The player picks
-- the next node among the current node's edges. Readability rules: the
-- current node, selectable choices, visited trail and locked nodes each get
-- a clearly distinct treatment, and every choice is labeled in plain words.
local draw = require("src.render.draw")
local input = require("src.core.input")
local sfx = require("src.audio.sfx")
local locale = require("src.core.locale")

local mapview = {}
mapview.__index = mapview

local TYPE_STYLE = {
  start = { color = { 0.7, 0.7, 0.75 } },
  traversal = { color = { 0.55, 0.95, 0.9 } },
  combat = { color = { 1, 0.45, 0.4 } },
  arena = { color = { 1, 0.8, 0.3 } },
  treasure = { color = { 1, 0.85, 0.4 } },
  shop = { color = { 0.6, 0.9, 1 } },
  rest = { color = { 0.45, 1, 0.55 } },
  event = { color = { 0.8, 0.55, 1 } },
  boss = { color = { 1, 0.3, 0.3 } },
  -- transitional aliases (pre-iteration-02 node names)
  platform = { color = { 0.55, 0.95, 0.9 }, alias = "traversal" },
  elite = { color = { 1, 0.8, 0.3 }, alias = "arena" },
}

local function typeLabel(nodeType)
  local style = TYPE_STYLE[nodeType] or TYPE_STYLE.traversal
  return locale.t("ui.map.label_" .. (style.alias or nodeType))
end

function mapview.new(run, onPick)
  local self = setmetatable({}, mapview)
  self.run = run
  self.onPick = onPick
  self.choices = run:nextChoices()
  self.sel = 1
  self.t = 0
  return self
end

function mapview:update(dt)
  self.t = self.t + dt
  if #self.choices == 0 then return end
  if input.pressed("left") then
    self.sel = self.sel > 1 and self.sel - 1 or #self.choices
    sfx.play("uiMove")
  elseif input.pressed("right") then
    self.sel = self.sel < #self.choices and self.sel + 1 or 1
    sfx.play("uiMove")
  elseif input.pressed("confirm") or input.pressed("jump") then
    input.consume("confirm") input.consume("jump")
    sfx.play("uiSelect")
    if self.onPick then self.onPick(self.choices[self.sel]) end
  end
end

local function nodePos(graph, node, sw, sh)
  local marginY = sh * 0.16
  local usableH = sh - marginY * 2
  local ly = sh - marginY - (node.layer / graph.layerCount) * usableH
  local count = node.count
  local spacing = math.min(150, (sw * 0.6) / math.max(count, 1))
  local x = sw / 2 + (node.index - (count + 1) / 2) * spacing
  return x, ly
end

function mapview:draw()
  local sw, sh = love.graphics.getDimensions()
  local run = self.run
  local graph = run.graph

  love.graphics.setColor(0.02, 0.02, 0.05, 0.92)
  love.graphics.rectangle("fill", 0, 0, sw, sh)

  local biome = run:biome()
  local biomeName = locale.content("biomes", biome.id, "name", biome.name)
  local biomeTag = locale.content("biomes", biome.id, "tagline", biome.tagline or "")
  draw.textCentered(biomeName:upper(), sw / 2, sh * 0.05, 24, { 1, 0.92, 0.8, 1 })
  draw.textCentered(biomeTag, sw / 2, sh * 0.05 + 32, 11, { 1, 1, 1, 0.4 })

  local function isChoiceNode(id)
    for i, ch in ipairs(self.choices) do
      if ch.id == id then return i end
    end
    return nil
  end

  -- edges: choices bright, traveled trail visible, the rest readable but calm
  for _, node in pairs(graph.nodes) do
    local x1, y1 = nodePos(graph, node, sw, sh)
    for _, toId in ipairs(node.edges) do
      local to = graph.nodes[toId]
      local x2, y2 = nodePos(graph, to, sw, sh)
      if node.id == run.nodeId and isChoiceNode(toId) then
        -- selectable path: bright, pulsing
        local selected = self.choices[self.sel] and self.choices[self.sel].id == toId
        love.graphics.setLineWidth(selected and 3.5 or 2.5)
        love.graphics.setColor(1, 1, 1, selected and (0.85 + math.sin(self.t * 4) * 0.15) or 0.55)
      elseif node.visited and to.visited then
        -- the road already traveled
        love.graphics.setLineWidth(2)
        love.graphics.setColor(1, 0.8, 0.55, 0.4)
      else
        love.graphics.setLineWidth(1.2)
        love.graphics.setColor(1, 1, 1, 0.26)
      end
      love.graphics.line(x1, y1, x2, y2)
    end
  end
  love.graphics.setLineWidth(1)

  -- nodes
  for _, node in pairs(graph.nodes) do
    local x, y = nodePos(graph, node, sw, sh)
    local style = TYPE_STYLE[node.type] or TYPE_STYLE.traversal
    local c = style.color
    local isCurrent = node.id == run.nodeId
    local choiceIdx = isChoiceNode(node.id)
    local r = node.type == "boss" and 14 or 9

    local alpha
    if isCurrent or choiceIdx then alpha = 1
    elseif node.visited then alpha = 0.8
    else alpha = 0.45 end

    if choiceIdx then
      draw.glow(x, y, 34, c[1], c[2], c[3], choiceIdx == self.sel and 0.8 or 0.35)
    end
    love.graphics.setColor(c[1], c[2], c[3], alpha)
    if node.type == "boss" then
      draw.ngon("fill", x, y, r, 5, -math.pi / 2)
    else
      draw.diamond("fill", x, y, r)
    end
    -- visited checkmark dot
    if node.visited and not isCurrent then
      love.graphics.setColor(0.05, 0.05, 0.08, 0.9)
      love.graphics.circle("fill", x, y, 2.5)
    end

    if isCurrent then
      love.graphics.setColor(1, 1, 1, 0.95)
      love.graphics.setLineWidth(2)
      love.graphics.circle("line", x, y, r + 6 + math.sin(self.t * 3) * 1.5)
      love.graphics.setLineWidth(1)
      draw.textCentered(locale.t("ui.map.current"), x, y + r + 10, 10, { 1, 1, 1, 0.75 })
    end

    -- every selectable choice is labeled; the selected one stands out
    if choiceIdx then
      local selected = choiceIdx == self.sel
      if selected then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineWidth(2)
        draw.diamond("line", x, y, r + 5)
        love.graphics.setLineWidth(1)
      end
      draw.textCentered(typeLabel(node.type), x, y - r - (selected and 26 or 20),
        selected and 13 or 10, { 1, 1, 1, selected and 1 or 0.6 })
    end
  end

  draw.textCentered(locale.t("ui.map.header_hint"), sw / 2, sh - 44, 12, { 1, 1, 1, 0.6 })
  love.graphics.setColor(1, 1, 1, 1)
end

mapview.TYPE_STYLE = TYPE_STYLE
mapview.typeLabel = typeLabel

return mapview
