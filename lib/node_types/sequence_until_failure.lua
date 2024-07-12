local _PACKAGE             = (...):match("^(.+)[%./][^%./]+"):gsub("[%./]?node_types", "")
local class                = require(_PACKAGE .. '/middleclass')
local Sequence             = require(_PACKAGE .. '/node_types/sequence')
local BranchNode           = require(_PACKAGE .. '/node_types/branch_node')
local SequenceUntilFailure = class('SequenceUntilFailure', Sequence)

function SequenceUntilFailure:fail()
  BranchNode.fail(self)
end

function SequenceUntilFailure:success()
  self:switchToNextChild()
  if self.childNode then
    self.childNode:start()
  else
    -- Out of children, we are done
    BranchNode.success(self)
  end
end

return SequenceUntilFailure
