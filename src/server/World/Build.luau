-- Tiny construction helpers for the procedural world. Everything is anchored; collidable parts are tagged with the
-- "Solid" attribute so the client can switch collision per corrupted/restored state.
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local WorldData = require(Shared.WorldData)

local Build = {}

local terrainParams = RaycastParams.new()
terrainParams.FilterType = Enum.RaycastFilterType.Include
terrainParams.FilterDescendantsInstances = { Workspace.Terrain }

-- True ground height under (x, z): raycast against the generated terrain, falling back to the analytic height.
function Build.groundY(x: number, z: number): number
	local hit = Workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), terrainParams)
	if hit then
		return hit.Position.Y
	end
	return WorldData.heightAt(x, z)
end

export type PartProps = {
	size: Vector3?,
	cf: CFrame?,
	color: Color3?,
	material: Enum.Material?,
	shape: Enum.PartType?,
	transparency: number?,
	solid: boolean?,
	query: boolean?,
	name: string?,
	reflectance: number?,
}

function Build.part(parent: Instance, p: PartProps): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = p.solid == true
	part.CanTouch = false
	part.CanQuery = p.solid == true or p.query == true -- only walkable/collidable parts need to be spatially queryable (humanoid floor detection)
	part.CastShadow = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Shape = p.shape or Enum.PartType.Block
	part.Size = p.size or Vector3.new(1, 1, 1)
	part.Color = p.color or Color3.new(1, 1, 1)
	part.Material = p.material or Enum.Material.SmoothPlastic
	part.Transparency = p.transparency or 0
	part.Reflectance = p.reflectance or 0
	if p.solid then
		part:SetAttribute("Solid", true)
		part.CastShadow = true
	end
	part.CFrame = p.cf or CFrame.new()
	if p.name then
		part.Name = p.name
	end
	part.Parent = parent
	return part
end

function Build.ball(parent: Instance, diameter: number, cf: CFrame, color: Color3, material: Enum.Material?, extra: PartProps?): Part
	local props: PartProps = extra or {}
	props.size = Vector3.new(diameter, diameter, diameter)
	props.cf = cf
	props.color = color
	props.material = material
	props.shape = Enum.PartType.Ball
	return Build.part(parent, props)
end

-- Vertical cylinder (Roblox cylinders run along X, so rotate to stand them up).
function Build.cyl(parent: Instance, height: number, diameter: number, cf: CFrame, color: Color3, material: Enum.Material?, extra: PartProps?): Part
	local props: PartProps = extra or {}
	props.size = Vector3.new(height, diameter, diameter)
	props.cf = cf * CFrame.Angles(0, 0, math.pi / 2)
	props.color = color
	props.material = material
	props.shape = Enum.PartType.Cylinder
	return Build.part(parent, props)
end

function Build.box(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, extra: PartProps?): Part
	local props: PartProps = extra or {}
	props.size = size
	props.cf = cf
	props.color = color
	props.material = material
	return Build.part(parent, props)
end

function Build.model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

function Build.label(parent: BasePart, text: string, offsetY: number, maxDist: number?, size: UDim2?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Nameplate"
	gui.Size = size or UDim2.fromOffset(190, 34)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = maxDist or 70
	gui.LightInfluence = 0
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundColor3 = Color3.fromRGB(24, 20, 40)
	l.BackgroundTransparency = 0.25
	l.TextColor3 = Color3.fromRGB(255, 255, 255)
	l.Font = Enum.Font.GothamBold
	l.TextSize = 15
	l.Text = text
	l.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = l
	gui.Parent = parent
	return gui
end

function Build.glow(parent: Instance, color: Color3, range: number, brightness: number): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = parent
	return light
end

-- Low-rate ambient emitter used on corrupted objects (client disables it when the object is restored).
function Build.sparkle(parent: BasePart, color: Color3, rate: number, size: number?)
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(color)
	pe.LightEmission = 1
	pe.Rate = rate
	pe.Lifetime = NumberRange.new(1.2, 2.2)
	pe.Speed = NumberRange.new(0.5, 2)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size or 0.35), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Parent = parent
	return pe
end

function Build.prompt(parent: BasePart, action: string, objectText: string, actionText: string, dist: number?, hold: number?): ProximityPrompt
	local pp = Instance.new("ProximityPrompt")
	pp.ObjectText = objectText
	pp.ActionText = actionText
	pp.MaxActivationDistance = dist or 10
	pp.HoldDuration = hold or 0
	pp.RequiresLineOfSight = false
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp:SetAttribute("Action", action)
	pp.Parent = parent
	return pp
end

return Build
