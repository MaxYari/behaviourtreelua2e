local _PACKAGE                = (...):match("^(.+)[%./][^%./]+"):gsub("[%./]?node_types", "")
local class                   = require(_PACKAGE .. '/middleclass')
local Decorator               = require(_PACKAGE .. '/node_types/decorator')
local RunTimeOutcomeDecorator = class('RunTimeOutcomeDecorator', Decorator)
local g                       = _BehaviourTreeGlobals

function RunTimeOutcomeDecorator:initialize(config)
  Decorator.initialize(self, config)
end

function RunTimeOutcomeDecorator:start()
  Decorator.start(self)

  self.duration = 0
  if self.p.duration then self.duration = self.p.duration() end
  if type(self.duration) ~= "number" then error("RUN TIME OUTCOME duration property resolved in a non-numeric value.") end

  self.startTime = g.clock()
end

function RunTimeOutcomeDecorator:_decideOutcome()
  local now = g.clock()
  if now - self.startTime <= self.duration then
    Decorator.success(self)
  else
    Decorator.fail(self)
  end
end

function RunTimeOutcomeDecorator:success()
  self:_decideOutcome()
end

function RunTimeOutcomeDecorator:fail()
  self:_decideOutcome()
end

return RunTimeOutcomeDecorator
