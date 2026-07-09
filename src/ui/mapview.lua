-- Run map overlay: the biome's node graph, drawn bottom-up. The player picks
-- the next node among the current node's edges.
local draw = require("src.render.draw")
local input = require("src.core.input")
local sfx = require("src.audio.sfx")

local mapview = {}
mapview.__index = mapview

local TYPE_STYLE = {
  start = { color = { 0.7, 0.7, 0.75 }, label = "entrance" },
  combat = { color = { 1, 0.45, 0.4 }, label = "hunt" },
  platform = { color = { 0.55, 0.95, 0.9 }, label = "traversal" },
  elite = { color = { 1, 0.8, 0.3 }, label = "elite" },
  treasure = { color = { 1, 0.85, 0.4 }, label = "cache" },
  shop = { color = { 0.6, 0.9, 1 }, label = "peddler" },
  rest = { color = { 0.45, 1, 0.55 }, label = "spring" },
  event = { color = { 0.8, 0.55, 1 }, label = "shrine" },
  boss = { color = { 1, 0.3, 0.3 }, label = "warden" },
}

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

  love.graphics.setColor(0.02, 0.02, 0.05, 0.88)
  love.graphics.rectangle("fill", 0, 0, sw, sh)

  local biome = run:biome()
  draw.textCentered(biome.name:upper(), sw / 2, sh * 0.05, 24, { 1, 0.92, 0.8, 1 })
  draw.textCentered(biome.tagline or "", sw / 2, sh * 0.05 + 32, 11, { 1, 1, 1, 0.4 })

  -- edges
  for _, node in pairs(graph.nodes) do
    local x1, y1 = nodePos(graph, node, sw, sh)
    for _, toId in ipairs(node.edges) do
      local x2, y2 = nodePos(graph, graph.nodes[toId], sw, sh)
      local isChoice = node.id == run.nodeId
      love.graphics.setLineWidth(isChoice and 2 or 1)
      love.graphics.setColor(1, 1, 1, isChoice and 0.5 or (node.visited and 0.28 or 0.12))
      love.graphics.line(x1, y1, x2, y2)
    end
  end
  love.graphics.setLineWidth(1)

  -- nodes
  for _, node in pairs(graph.nodes) do
    local x, y = nodePos(graph, node, sw, sh)
    local style = TYPE_STYLE[node.type] or TYPE_STYLE.combat
    local c = style.color
    local isCurrent = node.id == run.nodeId
    local isChoice = false
    local choiceIdx
    for i, ch in ipairs(self.choices) do
      if ch.id == node.id then isChoice = true choiceIdx = i end
    end
    local r = node.type == "boss" and 14 or 9

    if isCurrent then
      love.graphics.setColor(1, 1, 1, 0.9)
      love.graphics.circle("line", x, y, r + 5 + math.sin(self.t * 3) * 1.5)
    end
    local alpha = (node.visited or isCurrent or isChoice) and 1 or 0.4
    if isChoice then
      draw.glow(x, y, 30, c[1], c[2], c[3], choiceIdx == self.sel and 0.7 or 0.3)
    end
    love.graphics.setColor(c[1], c[2], c[3], alpha)
    if node.type == "boss" then
      draw.ngon("fill", x, y, r, 5, -math.pi / 2)
    else
      draw.diamond("fill", x, y, r)
    end
    if isChoice and choiceIdx == self.sel then
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.setLineWidth(2)
      draw.diamond("line", x, y, r + 4)
      love.graphics.setLineWidth(1)
      draw.textCentered(style.label, x, y - r - 22, 12, { 1, 1, 1, 0.95 })
    end
  end

  draw.textCentered("choose your path  ·  <- -> + SPACE",
    sw / 2, sh - 44, 12, { 1, 1, 1, 0.55 })
  love.graphics.setColor(1, 1, 1, 1)
end

mapview.TYPE_STYLE = TYPE_STYLE

return mapview
