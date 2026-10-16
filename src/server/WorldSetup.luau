-- One-time world dressing at server start: lighting, sky, hub spawn, title sign, floor banners and per-floor effects.
-- The baked map only contains invisible Marker parts for these; everything dynamic is created here.
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Mk = require(script.Parent.Mk)

local WorldSetup = {}

local function setupLighting()
	Lighting.ClockTime = 20.5
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(90, 70, 140)
	Lighting.OutdoorAmbient = Color3.fromRGB(110, 90, 170)
	Lighting.ColorShift_Top = Color3.fromRGB(170, 110, 255)
	Lighting.EnvironmentDiffuseScale = 0.7
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.GlobalShadows = true
	for _, name in { "NfAtmosphere", "NfColor", "NfBloom", "NfSky", "NfSunRays", "NfDepth" } do
		local old = Lighting:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local sky = Instance.new("Sky")
	sky.Name = "NfSky"
	sky.StarCount = 4000
	sky.Parent = Lighting
	local atm = Instance.new("Atmosphere")
	atm.Name = "NfAtmosphere"
	atm.Density = 0.3
	atm.Offset = 0.25
	atm.Color = Color3.fromRGB(190, 140, 255)
	atm.Decay = Color3.fromRGB(110, 70, 190)
	atm.Glare = 0.3
	atm.Haze = 1.2
	atm.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "NfColor"
	cc.Saturation = 0.25
	cc.Contrast = 0.12
	cc.TintColor = Color3.fromRGB(245, 235, 255)
	cc.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "NfBloom"
	bloom.Intensity = 0.9
	bloom.Size = 36
	bloom.Threshold = 0.9
	bloom.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Name = "NfSunRays"
	rays.Intensity = 0.12
	rays.Spread = 0.8
	rays.Parent = Lighting
end

local function rgb(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- particle recipes per floor family (matches Config.Floors[n].sky.particles)
local function emitter(kind: string, glow: { number }, accent: { number }): ParticleEmitter
	local pe = Instance.new("ParticleEmitter")
	pe.LightEmission = 0.8
	pe.Rate = 18
	pe.Lifetime = NumberRange.new(4, 8)
	pe.Speed = NumberRange.new(0.5, 2)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(rgb(glow), rgb(accent))
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.7), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.2), NumberSequenceKeypoint.new(1, 1) })
	pe.Shape = Enum.ParticleEmitterShape.Box
	if kind == "ember" then
		pe.Acceleration = Vector3.new(0, 4, 0)
		pe.Speed = NumberRange.new(2, 5)
	elseif kind == "snow" or kind == "petal" or kind == "leaf" then
		pe.Acceleration = Vector3.new(0, -2.5, 0)
		pe.Rate = 24
		pe.Size = NumberSequence.new(0.5)
	elseif kind == "rain" then
		pe.Acceleration = Vector3.new(0, -60, 0)
		pe.Rate = 80
		pe.Lifetime = NumberRange.new(0.6, 1)
		pe.Size = NumberSequence.new(0.2)
		pe.Speed = NumberRange.new(0, 0)
	elseif kind == "bubble" then
		pe.Acceleration = Vector3.new(0, 3, 0)
	elseif kind == "void" then
		pe.Acceleration = Vector3.new(0, 0.5, 0)
		pe.Speed = NumberRange.new(4, 8)
		pe.LightEmission = 1
	elseif kind == "star" then
		pe.Rate = 30
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 1.2), NumberSequenceKeypoint.new(1, 0) })
	end
	return pe
end

function WorldSetup.run(world: Instance)
	setupLighting()
	local hubSpawn = world:FindFirstChild("Marker:HubSpawn", true) :: BasePart?
	if hubSpawn then
		local sp = Instance.new("SpawnLocation")
		sp.Name = "HubSpawn"
		sp.Anchored = true
		sp.CanCollide = false
		sp.Transparency = 1
		sp.Neutral = true
		sp.Duration = 0
		sp.Size = Vector3.new(20, 1, 20)
		sp.CFrame = hubSpawn.CFrame
		sp.Parent = Workspace
	end
	local title = world:FindFirstChild("Marker:Title", true) :: BasePart?
	if title then
		Mk.label(title, "NEONFORGE", 0, Config.Colors.cyan, UDim2.fromOffset(900, 200), 1500)
		Mk.label(title, "TOWER TYCOON", -7, Config.Colors.magenta, UDim2.fromOffset(500, 90), 1200)
	end
	for floor = 1, Config.Tower.FLOORS + 1 do
		local theme = Config.Floors[math.min(floor, Config.Tower.FLOORS)]
		local banner = world:FindFirstChild("Marker:Banner:" .. floor, true) :: BasePart?
		if banner then
			local text = if floor <= Config.Tower.FLOORS then ("FLOOR %d  -  %s"):format(floor, theme.name) else "THE SUMMIT"
			Mk.label(banner, text, 0, theme.glow, UDim2.fromOffset(620, 100), 400)
		end
		local fx = world:FindFirstChild("Marker:FX:" .. floor, true) :: BasePart?
		if fx then
			fx.Size = Vector3.new(44, 26, 60)
			local e = emitter(theme.sky.particles, theme.glow, theme.accent)
			e.Parent = fx
			Mk.light(fx, theme.glow, 55, 2.2)
		end
	end
end

return WorldSetup
