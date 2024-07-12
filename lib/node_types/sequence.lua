local _PACKAGE   = (...):match("^(.+)[%./][^%./]+"):gsub("[%./]?node_types", "")
local class      = require(_PACKAGE .. '/middleclass')
local BranchNode = require(_PACKAGE .. '/node_types/branch_node')
local Node       = require(_PACKAGE .. '/node_types/node')
local Sequence   = class('Sequence', BranchNode)

local function ShuffleInPlace(t)
  for i = #t, 2, -1 do
    local j = math.random(i)
    t[i], t[j] = t[j], t[i]
  end
end

function Sequence:switchToNextChild()
  local index = self.childNode.indexInParent

  -- This should support looping around if we started from the middle
  while true do
    index = index + 1
    if index > #self.childNodes then index = 1 end
    if index == self.startIndex then break end
    self.childNode = self.childNodes[index]
    if not self.childNode.isStealthy then
      return
    end
  end

  self.childNode = nil
end

function Sequence:initialize(config)
  BranchNode.initialize(self, config)
end

function Sequence:childSwitch(node)
  -- Usually called by a child interrupt to notify the branch node that the interrupt node is a currently active child
  self.childIndex = node.indexInParent
  self.childNode = node
end

function Sequence:start()
  BranchNode.start(self)

  if #self.usableChildNodes == 0 then
    return self:fail()
  end

  if self.p.shuffle and self.p.shuffle() then
    ShuffleInPlace(self.usableChildNodes)
  end

  self.startIndex = 1
  if self.p.randomStart and self.p.randomStart() then
    self.startIndex = math.random(1, #self.usableChildNodes)
  end

  self.childNode = self.usableChildNodes[self.startIndex]
  self.childNode:start()
end

function Sequence:success()
  self:switchToNextChild()
  if self.childNode then
    self.childNode:start()
  else
    -- Out of children, we are done
    BranchNode.success(self)
  end
end

function Sequence:fail()
  self:switchToNextChild()
  if self.childNode then
    self.childNode:start()
  else
    -- Out of children, we are done
    BranchNode.success(self)
  end
end

return Sequence
