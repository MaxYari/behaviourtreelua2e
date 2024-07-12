local _PACKAGE          = (...):match("^(.+)[%./][^%./]+"):gsub("[%./]?node_types", "")
local class             = require(_PACKAGE .. '/middleclass')
local Decorator         = require(_PACKAGE .. '/node_types/decorator')
local RepeaterDecorator = class('RepeaterDecorator', Decorator)
local g                 = _BehaviourTreeGlobals

function RepeaterDecorator:initialize(config)
  Decorator.initialize(self, config)

  self.untilSuccess = config.untilSuccess
  self.untilFailure = config.untilFailure
end

function RepeaterDecorator:start()
  self.currentLoop = 1
  self.nodeStartFrameNumber = self.tree.frameNumber

  if self.maxLoop == nil then self.maxLoop = -1 end
  if self.p.maxLoop then self.maxLoop = self.p.maxLoop() end
  if type(self.maxLoop) ~= "number" then error("REPEATER maxLoop property resolved in a non-numeric value.") end

  Decorator.start(self)
end

function RepeaterDecorator:tryRestartChild()
  if self.tree.frameNumber > self.nodeStartFrameNumber then
    self.nodeStartFrameNumber = self.tree.frameNumber
    self.childNode:start()
    return true
  else
    -- We finished same frame we started, to prevent infinite loop delay childNode start until the next run()
    self.tree:print((self.name or self.name or "NONAME_NODE") ..
      ' REPEAT DELAYED until the next frame to avoid stack overflow.')

    self.delayChildStart = true
    self.tree:setActiveNode(self)

    return false
  end
end

function RepeaterDecorator:run()
  if self.delayChildStart then
    self.delayChildStart = false
    self.tree:removeActiveNode(self)
    if self:tryRestartChild() then
      Decorator.run(self)
    end
  else
    error("Repeater run() was triggered without 'delayChildStart'. This should never happen!")
  end
end

function RepeaterDecorator:success()
  self.currentLoop = self.currentLoop + 1
  if self.untilSuccess then
    return Decorator.success(self)
  elseif self.maxLoop ~= -1 and self.currentLoop > self.maxLoop then
    -- Out of repetitions
    if self.untilFailure then
      self.tree:print("REPEATER maxLoop REACHED")
      return Decorator.success(self) -- We were hoping to repeat until failure, but finished without a failure.
    else
      self.tree:print("REPEATER maxLoop REACHED")
      return Decorator.success(self) -- We were not waiting untilSuccess or untilFailure, whatever was the outcome of repititions - we did them all, this is considered a success.
    end
  else
    self.tree:print((self.name or self.name or "NONAME_NODE") .. ' REPEAT')
    self:tryRestartChild()
  end
end

function RepeaterDecorator:fail()
  self.currentLoop = self.currentLoop + 1
  if self.untilFailure then
    return Decorator.fail(self)
  elseif self.maxLoop ~= -1 and self.currentLoop > self.maxLoop then
    -- Out of repetitions
    if self.untilSuccess then
      self.tree:print("REPEATER maxLoop REACHED")
      return Decorator.fail(self) -- We were hoping to repeat until success, but failed at success.
    else
      self.tree:print("REPEATER maxLoop REACHED")
      return Decorator.success(self) -- We were not waiting untilSuccess or untilFailure, whatever was the outcome of repititions - we did them all, this is considered a success.
    end
  else
    self.tree:print((self.name or self.name or "NONAME_NODE") .. ' REPEAT')
    self:tryRestartChild()
  end
end

return RepeaterDecorator
