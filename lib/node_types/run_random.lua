local _PACKAGE   = (...):match("^(.+)[%./][^%./]+"):gsub("[%./]?node_types", "")
local class      = require(_PACKAGE .. '/middleclass')
local BranchNode = require(_PACKAGE .. '/node_types/branch_node')
local RunRandom  = class('RunRandom', BranchNode)

-- Helper function to perform weighted random selection
local function weightedRandomChoice(nodes)
  -- Author: ChatGPT 2024
  local totalWeight = 0
  for _, node in ipairs(nodes) do
    totalWeight = totalWeight + (node.weight or 1)
  end

  local randomValue = math.random() * totalWeight
  for _, node in ipairs(nodes) do
    if randomValue < node.weight then
      return node
    end
    randomValue = randomValue - node.weight
  end
end

function RunRandom:start()
  -- Reworked by ChatGPT
  BranchNode.start(self)

  -- Initialize repeats and maxSameRuns
  self.maxSameRuns = self.p.maxSameRuns and self.p.maxSameRuns() or nil
  -- Detecting node weights
  for _, node in ipairs(self.usableChildNodes) do
    if node.p.weight then node.weight = node.p.weight() else node.weight = 1 end
  end

  self.currentRepeats = 0

  if #self.usableChildNodes == 0 then
    return self:fail()
  end

  -- Exclude the ignored node from selection
  local candidates = {}

  for i, node in ipairs(self.usableChildNodes) do
    if node ~= self.ignoredNode then
      table.insert(candidates, node)
    end
  end

  if #candidates == 0 then
    return self:fail()
  end

  -- Select a random child node, using weights if available
  self.childNode = weightedRandomChoice(candidates)

  -- Update repeat logic
  if self.childNode == self.lastSelectedNode then
    self.currentRepeats = self.currentRepeats + 1
  else
    self.currentRepeats = 0
  end

  -- Check if the current child node needs to be ignored next time
  if self.maxSameRuns and self.maxSameRuns > 0 and self.currentRepeats >= self.maxSameRuns then
    self.ignoredNode = self.childNode
  else
    self.ignoredNode = nil
  end

  self.lastSelectedNode = self.childNode

  -- Start the selected child node
  self.childNode:start()
end

return RunRandom
