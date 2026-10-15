-- Orchestrates world generation: terrain -> targets -> decor -> stations -> landmarks -> lighting.
-- Everything lives under Workspace.World so it can be inspected / reorganised in Studio.
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local WorldData = require(Shared.WorldData)
local TerrainBuilder = require(script.Parent.TerrainBuilder)
local TargetBuilder = require(script.Parent.TargetBuilder)
local DecorBuilder = require(script.Parent.DecorBuilder)
local StationBuilder = require(script.Parent.StationBuilder)
local LandmarkBuilder = require(script.Parent.LandmarkBuilder)
local TargetRegistry = require(script.Parent.Parent.TargetRegistry)

local WorldBuilder = {}

-- The corrupted starting look. Each client blends toward the restored look locally as its progress grows
-- (see client/Ambience), so these are only the defaults.
local function setupLighting()
	Lighting.ClockTime = 16.5
	Lighting.Brightness = 1.6
	Lighting.Ambient = Color3.fromRGB(70, 62, 96)
	Lighting.OutdoorAmbient = Color3.fromRGB(96, 88, 128)
	Lighting.ColorShift_Top = Color3.fromRGB(120, 90, 200)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	for _, name in { "GlitchAtmosphere", "GlitchColor", "GlitchBloom", "GlitchSky" } do
		local old = Lighting:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local sky = Instance.new("Sky") -- engine default skybox textures; Rojo-built places have none
	sky.Name = "GlitchSky"
	sky.StarCount = 3000
	sky.Parent = Lighting
	local atm = Instance.new("Atmosphere")
	atm.Name = "GlitchAtmosphere"
	atm.Density = 0.38
	atm.Offset = 0.2
	atm.Color = Color3.fromRGB(130, 100, 190)
	atm.Decay = Color3.fromRGB(90, 70, 140)
	atm.Glare = 0.2
	atm.Haze = 1.6
	atm.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "GlitchColor"
	cc.Saturation = -0.3
	cc.Contrast = 0.08
	cc.TintColor = Color3.fromRGB(235, 220, 255)
	cc.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "GlitchBloom"
	bloom.Intensity = 0.5
	bloom.Size = 28
	bloom.Threshold = 1.0
	bloom.Parent = Lighting
end

function WorldBuilder.build()
	local old = Workspace:FindFirstChild("World")
	if old then
		old:Destroy()
	end
	TerrainBuilder.build()
	local world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = Workspace

	local targets = Instance.new("Folder")
	targets.Name = "Targets"
	targets.Parent = world
	for i, placement in WorldData.Targets do
		local _, root = TargetBuilder.build(placement, targets)
		TargetRegistry.register(placement.id, root)
		if i % 8 == 0 then
			task.wait()
		end
	end
	DecorBuilder.build(world)
	StationBuilder.build(world)
	LandmarkBuilder.build(world)
	setupLighting()
	world:SetAttribute("Ready", true)
	return world
end

return WorldBuilder
