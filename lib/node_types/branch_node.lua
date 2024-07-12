local _PACKAGE   = (...):match("^(.+)[%./][^%./]+"):gsub("[%./]?node_types", "")
local class      = require(_PACKAGE .. '/middleclass')
local Node       = require(_PACKAGE .. '/node_types/node')
local BranchNode = class('BranchNode', Node)

-- Seems to be bugged, needs a rewrite, seem to start nodes multiple times

function BranchNode:initialize(config)
  Node.initialize(self, config)

  if config.childNodes then
    self.childNodes = config.childNodes
    self.usableChildNodes = {}
    self.ignoredChildNodes = {}
    for i, node in pairs(self.childNodes) do
      node.indexInParent = i
      if node.isStealthy then
        table.insert(self.ignoredChildNodes, node)
      else
        table.insert(self.usableChildNodes, node)
      end
    end
  end
end

function BranchNode:start()
  Node.start(self)

  -- Its possible that .start resulted in a Node reporting a success/fail task and finishing, in that case we should terminate. Reporting a success/fail state was supposedly
  -- already done, since finished flag is set after that
  if self.finished then return end

  -- Register all interrupts
  for i, node in pairs(self.childNodes) do
    if node.isInterrupt then
      self.tree:registerInterrupt(node)
    end
  end
end

function BranchNode:abort()
  if self.childNode then self.childNode:abort() end
  Node.abort(self)
end

function BranchNode:finish()
  -- Deregister interrupts
  for i, node in pairs(self.childNodes) do
    if node.isInterrupt then
      self.tree:deregisterInterrupt(node)
    end
  end
  Node.finish(self)
end

return BranchNode
