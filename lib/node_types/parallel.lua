local _PACKAGE   = (...):match("^(.+)[%./][^%./]+"):gsub("[%./]?node_types", "")
local class      = require(_PACKAGE .. '/middleclass')
local BranchNode = require(_PACKAGE .. '/node_types/branch_node')
local Node       = require(_PACKAGE .. '/node_types/node')
local Parallel   = class('Parallel', BranchNode)


function Parallel:initialize(config)
  BranchNode.initialize(self, config)

  for _, node in ipairs(self.childNodes) do
    if node.isStealthy then
      error(
        "Stealthy interrupt nodes (node: " .. node.name .. ") are not allowed as direct children of a parallel node.",
        2)
    end
  end
end

function Parallel:start()
  BranchNode.start(self)

  if #self.usableChildNodes == 0 then
    return self:fail()
  end

  for _, node in ipairs(self.usableChildNodes) do
    node:start()
  end
end

function Parallel:propagateStatus(status)
  if self.p.waitForAll and self.p.waitForAll() then
    local allDone = true
    for _, node in ipairs(self.usableChildNodes) do
      if node.finished == false then allDone = false end
    end

    if allDone then return BranchNode:success(self) end
  else
    for _, node in ipairs(self.usableChildNodes) do
      if node.finished == false then node:abort() end
    end

    if status == "success" then
      return BranchNode.success(self)
    else
      return BranchNode.fail(self)
    end
  end
end

function Parallel:success()
  self:propagateStatus("success")
end

function Parallel:fail()
  self:propagateStatus("fail")
end

function Parallel:abort()
  for _, node in ipairs(self.usableChildNodes) do
    if node.finished == false then node:abort() end
  end

  BranchNode.abort(self)
end

return Parallel
