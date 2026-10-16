-- Turns baker records into real Instances (used by the integration tests to stand in for world/World.rbxm).
local Instantiate = {}

local SHAPE = { Ball = Enum.PartType.Ball, Block = Enum.PartType.Block, Cylinder = Enum.PartType.Cylinder }

function Instantiate.build(node, parent: Instance): Instance
	if node.c == "Folder" then
		local f = Instance.new("Folder")
		f.Name = node.n
		f.Parent = parent
		for _, k in node.kids do
			Instantiate.build(k, f)
		end
		return f
	end
	local p = Instance.new("Part")
	p.Name = node.n
	p.Anchored = true
	p.CanCollide = node.collide
	p.CanTouch = node.touch
	p.CanQuery = node.query
	p.Size = Vector3.new(node.s[1], node.s[2], node.s[3])
	p.CFrame = node.cf
	p.Color = Color3.fromRGB(node.col[1], node.col[2], node.col[3])
	p.Material = Enum.Material[node.mat]
	p.Shape = SHAPE[node.shape]
	p.Transparency = node.tr
	p.Parent = parent
	return p
end

return Instantiate
