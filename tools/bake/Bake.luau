-- Builds the whole world as records. Entry point for tools/bake.sh and the geometry tests.
local Util = require(script.Parent.Util)
local Tower = require(script.Parent.Tower)
local Scenery = require(script.Parent.Scenery)

local Bake = {}

function Bake.build()
	Util.count = 0
	Util.byName = {}
	local root = Util.root("World")
	local info = Tower.build(root)
	Scenery.hub(root)
	Scenery.plots(root)
	Scenery.sky(root)
	return root, info
end

return Bake
