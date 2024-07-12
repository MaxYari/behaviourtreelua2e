local registeredNodes = {}

local NodeTypeRegistry = {}

local function validateNodeValue(name, node)
  if node == nil then
    error("One of the registry node functions was called without a node argument being passed. Node name: " .. name, 3)
  elseif type(node) ~= "function" and (type(node) ~= "table" or not node.new) then
    error("Node " ..
      name ..
      " was supplied to the registry in a wrong format. Node should be either a wrapper function (recommended) returning a node instance, or a table with a function 'new' also returning a node instance. Supplied type: " ..
      type(node) .. " Node name: " .. name, 3)
  end
end

function NodeTypeRegistry.register(name, node)
  validateNodeValue(name, node)
  if registeredNodes[name] ~= nil then
    error(name .. " Node type already rigestered. Please use different name/registry id.", 2)
  else
    registeredNodes[name] = node;
  end
end

function NodeTypeRegistry.replace(name, node)
  validateNodeValue(name, node)
  if registeredNodes[name] == nil then
    error("Can not replace node " .. name .. ", no such node in the registry.")
  else
    registeredNodes[name] = node
  end
end

function NodeTypeRegistry.get(name)
  if type(name) == 'string' and registeredNodes[name] ~= nil then
    return registeredNodes[name]
  else
    return error(
      name ..
      " Node type doesn't exist in the registry, make sure that you've registered a node of that type before attempting to load the behaviour tree file.",
      2)
  end
end

return NodeTypeRegistry
