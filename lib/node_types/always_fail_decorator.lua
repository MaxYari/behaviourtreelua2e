local _PACKAGE            = (...):match("^(.+)[%./][^%./]+"):gsub("[%./]?node_types", "")
local class               = require(_PACKAGE .. '/middleclass')
local Decorator           = require(_PACKAGE .. '/node_types/decorator')
local AlwaysFailDecorator = class('AlwaysFailDecorator', Decorator)

function AlwaysFailDecorator:success()
  self:fail()
end

return AlwaysFailDecorator
