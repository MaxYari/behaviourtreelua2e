local _PACKAGE = (...):match("^(.+)[%./][^%./]+"):gsub("[%./]?node_types", "")
local class    = require(_PACKAGE .. '/middleclass')
local Node     = class('Node')
local g        = _BehaviourTreeGlobals

function Node:initialize(config)
  self._initData = config or {}
  if not config.properties then config.properties = {} end
  self.properties = self._initData.properties
  self.p = self.properties
  self.name = self._initData.name or "NoName"
  self.finished = true
end

-- All the node:fn functions can be overriden in child classes to implement new node types. If you want to call the
-- original child function from the override - do Parent.fn(self, otherArguments)
function Node:initApiObject()
  self.api = {
    -- Functions provided by the module user
    start = function(self, stateObject) end,
    run = function(self, stateObject) end,
    finish = function(self, stateObject) end,
    shouldRun = function(self, stateObject) end,    --Interrupts only
    registered = function(self, stateObject) end,   --Interrupts only
    deregistered = function(self, stateObject) end, --Interrupts only
  }

  for k, v in pairs(self._initData) do
    self.api[k] = v
  end
end

function Node:registerApiStatusFunctions()
  self.api.success = function() self:success() end
  self.api.fail = function() self:fail() end
  -- running is as needed inside the run() function
end

function Node:deregisterApiStatusFunctions()
  if not self.api then return end
  self.api.success = nil
  self.api.fail = nil
  self.api.running = nil
end

function Node:start()
  self.tree:print(self.name .. " STARTED")
  -- Api is repopulated anew after every start
  self:initApiObject()
  self:registerApiStatusFunctions()
  self.finished = false

  self.tree:setActiveNode(self)

  self.api:start(self.tree.stateObject)
end

function Node:run()
  self.tree:printLazy(self.name .. " RUN")
  self.api.running = function() self:running() end
  self.api:run(self.tree.stateObject)
  self.api.running = nil --deregister so it can not be called outside the run function
end

function Node:abort() -- Should rename to abort
  -- Call user-facing finish callback
  self.tree:print(self.name .. " ABORTED")
  self:finish()
end

-- TASK STATUSES - triggered by the module user, bubble up from childrent to parents
function Node:running()
  if self.finished then
    error("'Running' status was reported on a node after the node was finished. Either an API misuse or a bug.", 2)
  end
end

function Node:success()
  if self.finished then
    error("'Success' status was reported on a node after the node was finished. Either an API misuse or a bug.", 2)
  end
  self.tree:print(self.name .. ' SUCCESS')

  self:finish()
  if self.parentNode then
    self.parentNode:success()
  end
end

function Node:fail()
  if self.finished then
    error("'Fail' status was reported on a node after the node was finished. Either an API misuse or a bug.", 2)
  end
  self.tree:print(self.name .. ' FAIL')

  if self.finished then
    error(
      tostring(self.name) ..
      " node error. Fail state was called after node was finished. This should never happen, the node was probably not implemented properly.",
      2)
  end

  self:finish()
  if self.parentNode then
    self.parentNode:fail()
  end
end

-- Finish is not a task status and shouldn't be used as such, it should only be used for a final cleanup, never to report a status.
function Node:finish()
  self.tree:print((self.name or "NONAME_NODE") .. ' FINISH', 2)

  self:deregisterApiStatusFunctions()
  self.finished = true
  self.tree:removeActiveNode(self)

  self.api:finish(self.tree.stateObject)
end

return Node
