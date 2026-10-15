-- Procedural Echo creatures built from primitives (no external assets). Used by the client for followers /
-- index previews and by the server for the creature shown inside Glitch Capsules.
-- Facing: the model's front is its -Z (LookVector) side. Pivot = body centre.
local EchoModel = {}

local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Massless = true
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = cf
	p.Parent = parent
	return p
end

local function ball(parent: Instance, d: number, cf: CFrame, color: Color3, material: Enum.Material?): Part
	return part(parent, Vector3.new(d, d, d), cf, color, material, Enum.PartType.Ball)
end

local NEON = Enum.Material.Neon

-- shape builders: (model, origin CFrame, s = size scale, look)
local FEATURES: { [string]: (Model, CFrame, number, any) -> () } = {
	leaf = function(m, o, s, look)
		for i = -1, 1, 2 do
			part(m, Vector3.new(0.9, 0.1, 0.5) * s, o * CFrame.new(0.35 * i * s, 1.25 * s, 0) * CFrame.Angles(0, 0, math.rad(-35 * i)), look.accent, Enum.Material.Grass)
		end
		part(m, Vector3.new(0.12, 0.5, 0.12) * s, o * CFrame.new(0, 1.15 * s, 0), look.accent)
	end,
	rocks = function(m, o, s, look)
		ball(m, 0.7 * s, o * CFrame.new(-0.5 * s, 0.95 * s, 0.3 * s), look.accent, Enum.Material.Slate)
		ball(m, 0.55 * s, o * CFrame.new(0.45 * s, 1.0 * s, 0.2 * s), look.accent, Enum.Material.Slate)
		ball(m, 0.45 * s, o * CFrame.new(0, 1.15 * s, 0.55 * s), look.accent, Enum.Material.Slate)
	end,
	bolt = function(m, o, s, look)
		part(m, Vector3.new(0.18, 0.7, 0.18) * s, o * CFrame.new(0.1 * s, 1.35 * s, 0) * CFrame.Angles(0, 0, math.rad(25)), look.accent, NEON)
		part(m, Vector3.new(0.18, 0.55, 0.18) * s, o * CFrame.new(-0.1 * s, 1.8 * s, 0) * CFrame.Angles(0, 0, math.rad(-25)), look.accent, NEON)
		part(m, Vector3.new(0.18, 0.5, 0.18) * s, o * CFrame.new(0.12 * s, 2.2 * s, 0) * CFrame.Angles(0, 0, math.rad(25)), look.accent, NEON)
	end,
	spikes = function(m, o, s, look)
		for i = 0, 4 do
			local a = i / 5 * math.pi * 2
			part(m, Vector3.new(0.4, 1.1, 0.4) * s, o * CFrame.new(math.cos(a) * 0.55 * s, 0.95 * s, math.sin(a) * 0.55 * s + 0.2 * s) * CFrame.Angles(math.sin(a) * 0.5, math.rad(45), -math.cos(a) * 0.5), look.accent, Enum.Material.Glass)
		end
	end,
	wisp = function(m, o, s, look)
		for i = 1, 3 do
			ball(m, (1.3 - i * 0.28) * s, o * CFrame.new(0, (-0.2 - i * 0.45) * s, (0.3 + i * 0.4) * s), look.accent, Enum.Material.Neon).Transparency = 0.3 + i * 0.15
		end
	end,
	ring = function(m, o, s, look)
		part(m, Vector3.new(0.14, 3.0 * s, 3.0 * s), o * CFrame.new(0, -0.5 * s, 0) * CFrame.Angles(0, 0, math.pi / 2), look.accent, NEON, Enum.PartType.Cylinder)
		for i = 0, 2 do
			local a = i / 3 * math.pi * 2
			ball(m, 0.22 * s, o * CFrame.new(math.cos(a) * 1.5 * s, -0.5 * s, math.sin(a) * 1.5 * s), Color3.new(1, 1, 1), NEON)
		end
	end,
	fin = function(m, o, s, look)
		part(m, Vector3.new(0.12, 1.0, 0.9) * s, o * CFrame.new(0, 1.2 * s, 0.1 * s) * CFrame.Angles(math.rad(-20), 0, 0), look.accent, NEON)
		for i = -1, 1, 2 do
			part(m, Vector3.new(0.9, 0.1, 0.6) * s, o * CFrame.new(1.1 * s * i, -0.1 * s, 0.1 * s) * CFrame.Angles(0, 0, math.rad(20 * i)), look.accent, NEON)
		end
	end,
	gear = function(m, o, s, look)
		part(m, Vector3.new(0.45, 2.7 * s, 2.7 * s), o * CFrame.new(0, 0.1 * s, 0.75 * s) * CFrame.Angles(0, math.pi / 2, 0), look.accent, Enum.Material.Metal, Enum.PartType.Cylinder)
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2
			part(m, Vector3.new(0.5, 0.5, 0.45) * s, o * CFrame.new(math.cos(a) * 1.4 * s, 0.1 * s + math.sin(a) * 1.4 * s, 0.75 * s) * CFrame.Angles(0, 0, a), look.accent, Enum.Material.Metal)
		end
	end,
	horns = function(m, o, s, look)
		for i = -1, 1, 2 do
			part(m, Vector3.new(0.14, 1.2, 0.14) * s, o * CFrame.new(0.5 * s * i, 1.5 * s, 0) * CFrame.Angles(0, 0, math.rad(-25 * i)), look.accent)
			ball(m, 0.4 * s, o * CFrame.new(0.78 * s * i, 2.05 * s, 0), Color3.fromRGB(255, 120, 170), Enum.Material.Neon)
		end
	end,
	owl = function(m, o, s, look)
		for i = -1, 1, 2 do
			part(m, Vector3.new(0.3, 0.7, 0.3) * s, o * CFrame.new(0.65 * s * i, 1.15 * s, 0) * CFrame.Angles(0, 0, math.rad(-20 * i)), look.body)
		end
		part(m, Vector3.new(0.5, 0.5, 0.1) * s, o * CFrame.new(0, -0.1 * s, -1.05 * s) * CFrame.Angles(0, 0, math.rad(45)), look.accent, NEON)
	end,
	tail = function(m, o, s, look)
		for i = 1, 4 do
			ball(m, (1.1 - i * 0.2) * s, o * CFrame.new(0, 0.1 * s * i, (0.9 + i * 0.55) * s), look.accent, NEON).Transparency = 0.15 * i
		end
	end,
	halo = function(m, o, s, look)
		part(m, Vector3.new(0.12, 1.6 * s, 1.6 * s), o * CFrame.new(0, 1.65 * s, 0) * CFrame.Angles(0, 0, math.pi / 2), look.accent, NEON, Enum.PartType.Cylinder)
		for i = -1, 1, 2 do
			part(m, Vector3.new(1.0, 0.1, 0.6) * s, o * CFrame.new(1.2 * s * i, 0.5 * s, 0.4 * s) * CFrame.Angles(0, 0, math.rad(30 * i)), look.accent, NEON)
		end
	end,
}

-- look = { body, accent, shape, size }.  Returns a Model whose PrimaryPart is the Body.
function EchoModel.build(look: any, parent: Instance?, silhouette: boolean?): Model
	local s = look.size or 1
	local model = Instance.new("Model")
	model.Name = "Echo"
	local origin = CFrame.new()
	local bodyColor = if silhouette then Color3.fromRGB(30, 26, 40) else look.body
	local body = ball(model, 2.0 * s, origin, bodyColor, if look.shape == "wisp" then Enum.Material.Neon else Enum.Material.SmoothPlastic)
	body.Name = "Body"
	model.PrimaryPart = body
	if not silhouette then
		for i = -1, 1, 2 do
			ball(model, 0.42 * s, origin * CFrame.new(0.42 * s * i, 0.2 * s, -0.88 * s), Color3.fromRGB(20, 18, 28))
			ball(model, 0.14 * s, origin * CFrame.new(0.46 * s * i, 0.3 * s, -1.06 * s), Color3.new(1, 1, 1), Enum.Material.Neon)
			ball(model, 0.3 * s, origin * CFrame.new(0.78 * s * i, -0.25 * s, -0.72 * s), Color3.fromRGB(255, 150, 170)).Transparency = 0.55
		end
	end
	local feature = FEATURES[look.shape]
	if feature then
		feature(model, origin, s, if silhouette then { body = bodyColor, accent = bodyColor } else look)
	end
	if parent then
		model.Parent = parent
	end
	return model
end

return EchoModel
