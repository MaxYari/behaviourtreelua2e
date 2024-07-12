-- This is for Löve so I can just require the folder
local _PACKAGE = string.gsub(..., "%.", "/") or ""
return require(_PACKAGE .. '/behaviour_tree')
