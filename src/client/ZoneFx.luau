-- Each floor has its own sky, light, haze, falling particles and music. Everything blends smoothly as you climb.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Sfx = require(script.Parent.Sfx)
local UIKit = require(script.Parent.UIKit)
local Feedback = require(script.Parent.Feedback)

local ZoneFx = {}
local T = Config.Tower

local HUB = { top = { 170, 110, 255 }, haze = { 190, 140, 255 }, ambient = { 90, 70, 140 }, brightness = 2.2, clock = 20.5, particles = "sparkle" }
local PER_FLOOR = T.MODULES_PER_FLOOR * T.RISE_PER_MODULE

local function zoneOf(pos: Vector3): number
	local horiz = math.sqrt(pos.X * pos.X + pos.Z * pos.Z)
	if horiz > 175 or pos.Y < T.BASE_Y - 2 then
		return 0
	end
	return math.clamp(math.floor((pos.Y - T.BASE_Y + 3) / PER_FLOOR) + 1, 1, T.FLOORS)
end
ZoneFx.zoneOf = zoneOf

local cur = { top = Vector3.new(170, 110, 255), haze = Vector3.new(190, 140, 255), ambient = Vector3.new(90, 70, 140), brightness = 2.2, clock = 20.5 }
local function v3(c: { number }): Vector3
	return Vector3.new(c[1], c[2], c[3])
end
local function col(v: Vector3): Color3
	return Color3.fromRGB(math.clamp(v.X, 0, 255), math.clamp(v.Y, 0, 255), math.clamp(v.Z, 0, 255))
end

local emitterPart: Part, emitter: ParticleEmitter
local zone, lastBanner = -1, -1

local function recipe(kind: string, glow: { number }, accent: { number })
	emitter.Color = ColorSequence.new(UIKit.rgb(glow), UIKit.rgb(accent))
	emitter.Acceleration = Vector3.zero
	emitter.Rate = 30
	emitter.Lifetime = NumberRange.new(4, 8)
	emitter.Speed = NumberRange.new(0.5, 2)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.8), NumberSequenceKeypoint.new(1, 0) })
	emitter.LightEmission = 0.8
	if kind == "ember" then
		emitter.Acceleration = Vector3.new(0, 5, 0)
		emitter.Speed = NumberRange.new(2, 5)
	elseif kind == "snow" or kind == "petal" or kind == "leaf" then
		emitter.Acceleration = Vector3.new(0, -3, 0)
		emitter.Rate = 45
		emitter.Size = NumberSequence.new(0.55)
	elseif kind == "rain" then
		emitter.Acceleration = Vector3.new(0, -70, 0)
		emitter.Rate = 160
		emitter.Lifetime = NumberRange.new(0.5, 0.8)
		emitter.Size = NumberSequence.new(0.18)
		emitter.Speed = NumberRange.new(0, 0)
	elseif kind == "void" then
		emitter.Speed = NumberRange.new(4, 9)
		emitter.LightEmission = 1
	elseif kind == "star" then
		emitter.Rate = 50
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 1.3), NumberSequenceKeypoint.new(1, 0) })
	end
end

function ZoneFx.init()
	local player = Players.LocalPlayer
	emitterPart = Instance.new("Part")
	emitterPart.Name = "ZoneFxVolume"
	emitterPart.Anchored, emitterPart.CanCollide, emitterPart.CanTouch, emitterPart.CanQuery = true, false, false, false
	emitterPart.Transparency = 1
	emitterPart.Size = Vector3.new(70, 36, 70)
	emitterPart.Parent = Workspace
	emitter = Instance.new("ParticleEmitter")
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.2), NumberSequenceKeypoint.new(1, 1) })
	emitter.Parent = emitterPart
	recipe("sparkle", { 255, 120, 220 }, { 120, 240, 255 })

	local target = { top = v3(HUB.top), haze = v3(HUB.haze), ambient = v3(HUB.ambient), brightness = HUB.brightness, clock = HUB.clock }
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			emitterPart.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 12, 0))
		end
		acc += dt
		if acc >= 0.3 and hrp then
			acc = 0
			local z = zoneOf(hrp.Position)
			if z ~= zone then
				zone = z
				local theme = if z == 0 then nil else Config.Floors[z]
				local s = if theme then theme.sky else HUB
				target = { top = v3(s.top), haze = v3(s.haze), ambient = v3(s.ambient), brightness = s.brightness, clock = s.clock }
				if theme then
					recipe(s.particles, theme.glow, theme.accent)
					Sfx.music(theme.music)
					if z ~= lastBanner then
						lastBanner = z
						Feedback.toast(("Floor %d: %s"):format(z, theme.name), "good")
					end
				else
					recipe("sparkle", { 255, 120, 220 }, { 120, 240, 255 })
					Sfx.music("hub")
				end
			end
		end
		-- ease the sky toward the target (about a second and a half)
		local k = 1 - math.exp(-dt * 1.6)
		cur.top = cur.top:Lerp(target.top, k)
		cur.haze = cur.haze:Lerp(target.haze, k)
		cur.ambient = cur.ambient:Lerp(target.ambient, k)
		cur.brightness += (target.brightness - cur.brightness) * k
		cur.clock += (target.clock - cur.clock) * k
		Lighting.ColorShift_Top = col(cur.top)
		Lighting.Ambient = col(cur.ambient)
		Lighting.OutdoorAmbient = col(cur.ambient:Lerp(cur.top, 0.35))
		Lighting.Brightness = cur.brightness
		Lighting.ClockTime = cur.clock
		local atm = Lighting:FindFirstChild("NfAtmosphere") :: Atmosphere?
		if atm then
			atm.Color = col(cur.haze)
		end
		local cc = Lighting:FindFirstChild("NfColor") :: ColorCorrectionEffect?
		if cc then
			cc.TintColor = col(Vector3.new(255, 255, 255):Lerp(cur.haze, 0.18))
		end
	end)
end

return ZoneFx
