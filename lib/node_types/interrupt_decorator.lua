local _PACKAGE           = (...):match("^(.+)[%./][^%./]+"):gsub("[%./]?node_types", "")
local class              = require(_PACKAGE .. '/middleclass')
local Decorator          = require(_PACKAGE .. '/node_types/decorator')
local InterruptDecorator = class('InterruptDecorator', Decorator)

function InterruptDecorator:initialize(config)
  self.isInterrupt = true
  self.isStealthy = true
  if config.isStealthy ~= nil then self.isStealthy = config.isStealthy end
  Decorator.initialize(self, config)
end

function InterruptDecorator:registered()
  self.tree:print(self.name .. " INTERRUPT REGISTERED")

  self:initApiObject()

  self.api:registered(self.tree.stateObject)
end

function InterruptDecorator:deregistered()
  self.tree:print(self.name .. " INTERRUPT DE-REGISTERED")

  self.api:deregistered(self.tree.stateObject)
end

-- Will be called by the tree root every tree run
function InterruptDecorator:shouldRun()
  local should = self.api:shouldRun(self.tree.stateObject)
  return should
end

function InterruptDecorator:interruptOthers()
  self.tree:print(self.name .. " INTERRUPTED another branch.")
  -- in case parent is a branch_node - should notify it that the child is different now
  if self.parentNode and self.parentNode.childSwitch then
    self.parentNode:childSwitch(self)
  end

  self:start()
end

function InterruptDecorator:interruptSelf()
  self.tree:print(self.name .. " INTERRUPTED self.")

  self.childNode:abort()
  self:fail()
end

return InterruptDecorator
