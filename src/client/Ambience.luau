-- The world visibly heals: lighting, atmosphere, terrain colours and ambient motes blend from the corrupted
-- look to the restored look as THIS player's restoration percentage grows. Client-local, eased, no per-frame
-- allocations (terrain colours only update when the blend changes noticeably).
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local State = require(script.Parent.State)

local Ambience = {}

local C = Color3.fromRGB
local LIGHT = {
	bright = { 1.6, 2.6 }, clock = { 16.5, 14.2 }, ambient = { C(70, 62, 96), C(118, 128, 150) }, outdoor = { C(96, 88, 128), C(150, 165, 185) },
	shift = { C(120, 90, 200), C(255, 240, 200) },
}
local ATM = { density = { 0.38, 0.26 }, color = { C(130, 100, 190), C(190, 215, 255) }, decay = { C(90, 70, 140), C(255, 230, 190) }, haze = { 1.6, 0.35 }, glare = { 0.2, 0.08 } }
local GRADE = { sat = { -0.3, 0.22 }, tint = { C(235, 220, 255), C(255, 252, 240) }, bloom = { 0.5, 0.3 } }
local TERRAIN = {
	{ Enum.Material.Grass, C(96, 92, 112), C(86, 168, 64) },
	{ Enum.Material.Ground, C(78, 70, 92), C(112, 88, 60) },
	{ Enum.Material.Rock, C(104, 98, 120), C(132, 126, 120) },
	{ Enum.Material.Sand, C(176, 160, 150), C(226, 205, 150) },
}
local WATER = { C(110, 90, 190), C(64, 160, 225) }

local shown = -1 -- eased blend currently applied (0..1)
local lastTerrain = -1
local motes: ParticleEmitter? = nil

local function lerp(pair: { number }, k: number): number
	return pair[1] + (pair[2] - pair[1]) * k
end
local function lerpC(pair: { Color3 }, k: number): Color3
	return pair[1]:Lerp(pair[2], k)
end

local function apply(k: number)
	Lighting.Brightness = lerp(LIGHT.bright, k)
	Lighting.ClockTime = lerp(LIGHT.clock, k)
	Lighting.Ambient = lerpC(LIGHT.ambient, k)
	Lighting.OutdoorAmbient = lerpC(LIGHT.outdoor, k)
	Lighting.ColorShift_Top = lerpC(LIGHT.shift, k)
	local atm = Lighting:FindFirstChild("GlitchAtmosphere") :: Atmosphere?
	if atm then
		atm.Density = lerp(ATM.density, k)
		atm.Color = lerpC(ATM.color, k)
		atm.Decay = lerpC(ATM.decay, k)
		atm.Haze = lerp(ATM.haze, k)
		atm.Glare = lerp(ATM.glare, k)
	end
	local cc = Lighting:FindFirstChild("GlitchColor") :: ColorCorrectionEffect?
	if cc then
		cc.Saturation = lerp(GRADE.sat, k)
		cc.TintColor = lerpC(GRADE.tint, k)
	end
	local bloom = Lighting:FindFirstChild("GlitchBloom") :: BloomEffect?
	if bloom then
		bloom.Intensity = lerp(GRADE.bloom, k)
	end
	if math.abs(k - lastTerrain) > 0.01 then
		lastTerrain = k
		local terrain = Workspace.Terrain
		for _, t in TERRAIN do
			terrain:SetMaterialColor(t[1], t[2]:Lerp(t[3], k))
		end
		terrain.WaterColor = WATER[1]:Lerp(WATER[2], k)
		terrain.WaterTransparency = 0.75 - 0.25 * k
	end
	if motes then
		motes.Color = ColorSequence.new(C(160, 100, 255):Lerp(C(255, 235, 150), k), C(60, 235, 255):Lerp(C(150, 255, 150), k))
		motes.Rate = 6 + 10 * k
	end
end

local function ensureMotes(character: Model)
	local hrp = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not hrp then
		return
	end
	local att = Instance.new("Attachment")
	att.Name = "AmbientMotes"
	att.Parent = hrp
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Motes"
	pe.LightEmission = 1
	pe.Lifetime = NumberRange.new(4, 7)
	pe.Speed = NumberRange.new(0.3, 1.2)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.22), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.2), NumberSequenceKeypoint.new(1, 1) })
	pe.Shape = Enum.ParticleEmitterShape.Sphere
	pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	pe.Acceleration = Vector3.new(0, 0.3, 0)
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Parent = att
	motes = pe
end

function Ambience.init()
	local player = Players.LocalPlayer
	if player.Character then
		task.spawn(ensureMotes, player.Character)
	end
	player.CharacterAdded:Connect(function(c)
		task.spawn(ensureMotes, c)
	end)
	apply(0)
	shown = 0
	RunService.RenderStepped:Connect(function(dt)
		local d = State.data
		if not d then
			return
		end
		-- ease toward the saved restoration percent (smoothstep so early progress is already visible)
		local p = math.clamp(d.percent / 100, 0, 1)
		local target = p * p * (3 - 2 * p) * 0.35 + p * 0.65
		if math.abs(target - shown) > 0.0005 then
			shown += (target - shown) * (1 - math.exp(-dt * 1.2))
			apply(shown)
		end
	end)
end

return Ambience
