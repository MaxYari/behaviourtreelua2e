-- Global interface----------
-- Not meant to be used the end-user directly, here mostly for the easy of access from another .lua files of this package
_BehaviourTreeGlobals                 = {}
_BehaviourTreeImports                 = _BehaviourTreeImports or {}
----------------------------

local _PACKAGE                        = (...):match("^(.+)[%./][^%./]+") or ""
local class                           = require(_PACKAGE .. '/middleclass')
local Registry                        = require(_PACKAGE .. '/registry')
local Node                            = require(_PACKAGE .. '/node_types/node')
local RegisterPremadeNodes            = require(_PACKAGE .. '/nodes/nodes')
local ParseBehavior3Project           = require(_PACKAGE .. '/behavior3_parser')
local BehaviourTree                   = class('BehaviourTree', Node)
local g                               = _BehaviourTreeGlobals
local imports                         = _BehaviourTreeImports

BehaviourTree.Node                    = Node
BehaviourTree.Registry                = Registry
BehaviourTree.Task                    = Node
BehaviourTree.BranchNode              = require(_PACKAGE .. '/node_types/branch_node')
BehaviourTree.RunRandom               = require(_PACKAGE .. '/node_types/run_random')
BehaviourTree.Parallel                = require(_PACKAGE .. '/node_types/parallel')
BehaviourTree.Sequence                = require(_PACKAGE .. '/node_types/sequence')
BehaviourTree.SequenceUntilFailure    = require(_PACKAGE .. '/node_types/sequence_until_failure')
BehaviourTree.SequenceUntilSuccess    = require(_PACKAGE .. '/node_types/sequence_until_success')
BehaviourTree.Decorator               = require(_PACKAGE .. '/node_types/decorator')
BehaviourTree.InvertDecorator         = require(_PACKAGE .. '/node_types/invert_decorator')
BehaviourTree.AlwaysFailDecorator     = require(_PACKAGE .. '/node_types/always_fail_decorator')
BehaviourTree.AlwaysSucceedDecorator  = require(_PACKAGE .. '/node_types/always_succeed_decorator')
BehaviourTree.RepeaterDecorator       = require(_PACKAGE .. '/node_types/repeater_decorator')
BehaviourTree.RunTimeOutcomeDecorator = require(_PACKAGE .. '/node_types/run_time_outcome_decorator')
BehaviourTree.InterruptDecorator      = require(_PACKAGE .. '/node_types/interrupt_decorator')

BehaviourTree.register                = Registry.register

local STATUSES                        = {
  NOT_STARTED = 0,
  RUNNING = 1,
  FINISHED_SUCCESS = 2,
  FINISHED_FAIL = 3,
  FINISHED_ABORT = 4
}
BehaviourTree.STATUSES                = STATUSES


-- IMPORTANT NOTES TO SELF:
-- Dont forget to change readme, now "node" is a "childNode" and "nodes" are "childNodes"
-- BehaviourTree.register now registers node type, not node by name

-- Getting a hold on important environment methods
-- Code parsing method -------------------------
---@diagnostic disable-next-line: deprecated
local loadCodeHere = _G.load or _G.loadstring or imports.loadCodeHere
g.loadCodeInScope  = imports.loadCodeInScope or function(code, scope)
  local func, err = loadCodeHere(code)
  if func then
    ---@diagnostic disable-next-line: deprecated
    setfenv(func, scope) -- Set the environment to the provided scope
    return func
  else
    return nil, err
  end
end
-- Time measuring method -----------------------
g.clock            = os.clock or imports.clock
------------------------------------------------

-- Utility methods ------
local function shallowTableCopy(orig)
  -- Source: http://lua-users.org/wiki/CopyTable
  local orig_type = type(orig)
  local copy
  if orig_type == 'table' then
    copy = {}
    for orig_key, orig_value in pairs(orig) do
      copy[orig_key] = orig_value
    end
  else -- number, string, boolean, etc
    copy = orig
  end
  return copy
end
----------------------


-- Registering premade nodes -------------------
RegisterPremadeNodes(Registry)
Registry.register('Sequence', BehaviourTree.Sequence)
Registry.register('SequenceUntilFailure', BehaviourTree.SequenceUntilFailure)
Registry.register('SequenceUntilSuccess', BehaviourTree.SequenceUntilSuccess)
Registry.register('RunRandom', BehaviourTree.RunRandom)
Registry.register('Parallel', BehaviourTree.Parallel)
Registry.register('Repeater', BehaviourTree.RepeaterDecorator)
Registry.register('Inverter', BehaviourTree.InvertDecorator)
Registry.register('AlwaysSucceed', BehaviourTree.AlwaysSucceedDecorator)
Registry.register('AlwaysFail', BehaviourTree.AlwaysFailDecorator)
Registry.register('RunTimeOutcome', BehaviourTree.RunTimeOutcomeDecorator)
------------------------------------------------



-- Behaviour tree methods --------------------------------------------------
----------------------------------------------------------------------------
-- BehaviourTree is essentially a Node class extension that represents a root node and the tree itself
function BehaviourTree:initialize(config)
  Node.initialize(self, config)

  self.childNode = config.root

  -- Walking the tree and setting up important properties
  local function process(node, address)
    node.tree = self
    node.address = address
    --print("Node " .. node.name .. " address: ", table.concat(node.address, ","))

    if node.childNode then
      node.childNode.parentNode = node

      local childAddress = shallowTableCopy(address)
      table.insert(childAddress, 1)

      process(node.childNode, childAddress)
    end
    if node.childNodes then
      for i, childNode in pairs(node.childNodes) do
        childNode.parentNode = node

        local childAddress = shallowTableCopy(address)
        table.insert(childAddress, i)

        process(childNode, childAddress)
      end
    end
  end
  process(self, { 1 })

  -- Interrupts
  self.interrupts = {}

  -- A list of active nodes, most often should consist of a single node, unless parallel execution compound nodes are used
  self.activeNodes = {}

  -- Useful info
  self.frameNumber = 0

  -- Debugging variables
  self.debugLevel = 0
  self.branchString = ""
  self.lastPrint = ""

  self:print("Behaviour Tree " .. config.name .. " INITIALIZED!")
end

function BehaviourTree:registerInterrupt(interruptNode)
  if self.interrupts[interruptNode] then
    error(
      interruptNode.name ..
      " was already registered, but an attempt to register it again was detected. This should never happen. A bug?", 2)
  end
  self.interrupts[interruptNode] = interruptNode
  interruptNode:registered()
end

function BehaviourTree:deregisterInterrupt(interruptNode)
  if self.interrupts[interruptNode] then
    self.interrupts[interruptNode] = nil
    interruptNode:deregistered()
  end
end

function BehaviourTree:setStateObject(obj)
  self.stateObject = obj
end

function BehaviourTree:setActiveNode(node)
  if self == node then return end
  if self.activeNodes[node.parentNode] then
    self:removeActiveNode(node.parentNode)
  end
  --print("Adding active node " .. node.name)
  self.activeNodes[node] = node
end

function BehaviourTree:removeActiveNode(node)
  if self == node then return end
  --print("Removing active node " .. node.name)
  self.activeNodes[node] = nil
end

function BehaviourTree:run()
  self.frameNumber = self.frameNumber + 1

  if self.status ~= STATUSES.RUNNING then
    self.status = STATUSES.RUNNING
    self:start()
    self.childNode:start()
    if self.finished then return end
  end

  -- check interrupts
  -- as of right now topmost interrupts first
  for _, interrupt in pairs(self.interrupts) do
    local should = interrupt:shouldRun()
    if interrupt.finished and should then
      -- If interrupted, need to walk the brunch all the way up to the same level as the interrupt, and call finish on everything.
      -- but what if interrupt will interrupt itself? Good question! Probably should be handled by the node developer.

      -- ChildNode on a branch node is a currently active child branch. So we abort currently active child branch.
      interrupt.parentNode.childNode:abort()

      interrupt:interruptOthers()
      break
    elseif not interrupt.finished and not should then
      -- interrupt will abort itself
      interrupt:interruptSelf()
      break
    end
  end

  --self:print("Running all active nodes:")
  local activeNodesStatic = shallowTableCopy(self.activeNodes)
  for _, node in pairs(activeNodesStatic) do
    if not node.finished then node:run() end
  end
end

function BehaviourTree:success()
  -- Behaviour tree is essentially an infinite repeater, it will start its child again on next run()
  Node.success(self)

  self.status = STATUSES.FINISHED_SUCCESS
end

function BehaviourTree:fail()
  -- Behaviour tree is essentially an infinite repeater, it will start its child again on next run()
  Node.fail(self)

  self.status = STATUSES.FINISHED_FAIL
end

function BehaviourTree:abort()
  Node.abort(self)

  if self.childNode and not self.childNode.finished then
    self.childNode:abort()
  end

  self.status = STATUSES.FINISHED_ABORT
end

-- Debugging functions ----------------------------------------
BehaviourTree.debugLevel = 0
BehaviourTree.branchString = ""
BehaviourTree.lastPrint = ""

function BehaviourTree:setDebugLevel(val)
  self.debugLevel = val
end

function BehaviourTree:print(msg, lvl)
  if lvl == nil then lvl = 1 end

  if lvl <= self.debugLevel then
    print("[" .. tostring(self.name) .. " DEBUG]:", msg)
    self.lastPrint = msg
  end
end

function BehaviourTree:printLazy(msg, lvl)
  if self.lastPrint ~= msg then
    self:print(msg, lvl)
  end
end

----------------------------------------------------------------
----------------------------------------------------------------


-- Json data loading method ------------------------------------
----------------------------------------------------------------
BehaviourTree.LoadBehavior3Project = function(jsonTable, state, parsedDataCb)
  local roots = ParseBehavior3Project(jsonTable, state, parsedDataCb)
  for title, root in pairs(roots) do
    roots[title] = BehaviourTree:new({ root = root, name = title })
    roots[title]:setStateObject(state)
  end

  return roots
end
------------------------------------------------------------------
------------------------------------------------------------------

return BehaviourTree
