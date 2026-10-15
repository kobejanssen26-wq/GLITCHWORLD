-- Not an assertion test: prints geometry (one sample of every target type in both states, a terrain heightmap and
-- all placements) in a line format that tools/preview.py renders to PNGs, since there is no Studio to look at.
local M = __M
local WorldData = require(game.ReplicatedStorage.Shared.WorldData)
M.heightFn = WorldData.heightAt
require(game.ReplicatedStorage.Shared.Remotes).create()
local world = require(game.ServerScriptService.Server.World.WorldBuilder).build()
M.advance(5)
local seen = {}
for _, m in world.Targets:GetChildren() do
	local typ = m:GetAttribute("TypeId")
	if not seen[typ] then
		seen[typ] = true
		for _, folderName in { "Corrupted", "Restored", "Shared" } do
			for _, p in m[folderName]:GetDescendants() do
				if p:IsA("BasePart") then
					local c = p.CFrame
					local col = p.Color
					local shape = if p.Shape == Enum.PartType.Ball then "ball" elseif p.Shape == Enum.PartType.Cylinder then "cyl" else "box"
					local r = c.r
					print(("PART|%s|%s|%s|%.3f,%.3f,%.3f|%.3f,%.3f,%.3f|%s|%.3f,%.3f,%.3f|%s|%.2f"):format(typ, folderName, shape, p.Size.X, p.Size.Y, p.Size.Z, c.X - m.Root.Position.X, c.Y - m.Root.Position.Y, c.Z - m.Root.Position.Z, table.concat(r, ","), col.R, col.G, col.B, p.Material.Name, p.Transparency))
				end
			end
		end
	end
end
for x = -150, 150, 2 do
	local row = {}
	for z = -150, 150, 2 do table.insert(row, ("%.1f"):format(WorldData.heightAt(x, z))) end
	print("HROW|" .. x .. "|" .. table.concat(row, ","))
end
for _, t in WorldData.Targets do print(("TGT|%s|%s|%d|%d"):format(t.id, t.type, t.x, t.z)) end
for _, s in WorldData.Secrets do print(("SEC|%s|%d|%d"):format(s.id, s.x, s.z)) end
for id, s in WorldData.Stations do print(("STA|%s|%d|%d"):format(id, s.x, s.z)) end
for _, d in WorldData.Decor do print(("DEC|%s|%d|%d"):format(d.kind, d.x, d.z)) end

local EchoModel = require(game.ReplicatedStorage.Shared.EchoModel)
local Config = require(game.ReplicatedStorage.Shared.Config)
for _, e in Config.Echoes do
	local model = EchoModel.build(e.look, nil)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			local c = p.CFrame
			local col = p.Color
			local shape = if p.Shape == Enum.PartType.Ball then "ball" elseif p.Shape == Enum.PartType.Cylinder then "cyl" else "box"
			print(("PART|echo_%s|Echo|%s|%.3f,%.3f,%.3f|%.3f,%.3f,%.3f|%s|%.3f,%.3f,%.3f|%s|%.2f"):format(e.id, shape, p.Size.X, p.Size.Y, p.Size.Z, c.X, c.Y, c.Z, table.concat(c.r, ","), col.R, col.G, col.B, p.Material.Name, p.Transparency))
		end
	end
end
