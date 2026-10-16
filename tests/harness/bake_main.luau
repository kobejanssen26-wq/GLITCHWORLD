-- Not a test: builds the world with the baker and prints the .rbxmx (lines starting with # are statistics).
local Bake = require(game.ServerScriptService.Bake.Bake)
local Util = require(game.ServerScriptService.Bake.Util)
local Serialize = require(game.ServerScriptService.Bake.Serialize)
local root = Bake.build()
print("#parts " .. Util.count)
local names = {}
for k, v in Util.byName do table.insert(names, { k, v }) end
table.sort(names, function(a, b) return a[2] > b[2] end)
for i = 1, math.min(12, #names) do print(("#  %-16s %d"):format(names[i][1], names[i][2])) end
Serialize.write(root, print)
