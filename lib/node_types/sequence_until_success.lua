local _PACKAGE             = (...):match("^(.+)[%./][^%./]+"):gsub("[%./]?node_types", "")
local class                = require(_PACKAGE .. '/middleclass')
local Sequence             = require(_PACKAGE .. '/node_types/sequence')
local BranchNode           = require(_PACKAGE .. '/node_types/branch_node')
local SequenceUntilSuccess = class('SequenceUntilSuccess', Sequence)

function SequenceUntilSuccess:fail()
  self:switchToNextChild()
  if self.childNode then
    self.childNode:start()
  else
    -- Out of children, we are done
    BranchNode.fail(self)
  end
end

function SequenceUntilSuccess:success()
  BranchNode.success(self)
end

return SequenceUntilSuccess
