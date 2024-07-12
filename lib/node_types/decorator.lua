local _PACKAGE  = (...):match("^(.+)[%./][^%./]+"):gsub("[%./]?node_types", "")
local class     = require(_PACKAGE .. '/middleclass')
local Node      = require(_PACKAGE .. '/node_types/node')
local Decorator = class('Decorator', Node)

function Decorator:initialize(config)
  if config.childNode then
    self.childNode = config.childNode
  end
  Node.initialize(self, config)
end

function Decorator:start()
  Node.start(self)

  --Its possible that .start resulted in a Node reporting a success/fail task and finishing, in that case we should terminate. Reporting a success/fail state was supposedly
  --already done, since finished flag is set after that
  if self.finished then return end
  -- TODO: if this happens - decorator will try and unregister an interrupt, although it was never registered - will throw error

  --Register all interrupts
  if self.childNode.isInterrupt then
    self.tree:registerInterrupt(self.childNode)
  end

  --The only child is an interrupt (or another node) that doesnt want to be called directly, so can't do much of anything here but fail
  if self.childNode.isStealthy then
    error("Stealthy interrupt (node: " ..
      self.childNode.name .. ") can not be a direct child of a decorator (node: " .. self.name .. ")")
  end

  self.childNode:start()
end

function Decorator:abort()
  self.childNode:abort()
  Node.abort(self)
end

function Decorator:run()
  Node.run(self)
  if not self.childNode.finished then
    self.childNode:run()
  end
end

function Decorator:finish()
  -- Deregister interrupts on the level below
  if self.childNode.isInterrupt then
    self.tree:deregisterInterrupt(self.childNode)
  end
  Node.finish(self)
end

return Decorator
