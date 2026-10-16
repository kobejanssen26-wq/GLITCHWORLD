-- Player-facing effects for EVERYONE in the server (driven by replicated attributes): trails, auras, overhead
-- name plates; plus local-only camera effects (shake, speed FOV, confetti) used by Feedback.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local State = require(script.Parent.State)
local UIKit = require(script.Parent.UIKit)
local Feedback = require(script.Parent.Feedback)

local PlayerFx = {}
local T = UIKit.theme

local trailById, auraById = {}, {}
for _, t in Config.Trails do
	trailById[t.id] = t
end
for _, a in Config.Auras do
	auraById[a.id] = a
end

local function shakeEnabled(): boolean
	local d = State.data
	return not d or d.settings.shake ~= false
end

-- ===== camera shake via Humanoid.CameraOffset =====
local shakeUntil, shakePower = 0, 0
function PlayerFx.shake(power: number, seconds: number)
	if not shakeEnabled() then
		return
	end
	shakePower = math.max(shakePower, power)
	shakeUntil = math.max(shakeUntil, os.clock() + seconds)
end

function PlayerFx.fov(target: number, seconds: number)
	local cam = Workspace.CurrentCamera
	if not cam or not shakeEnabled() then
		return
	end
	TweenService:Create(cam, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = target }):Play()
	task.delay(seconds, function()
		TweenService:Create(cam, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { FieldOfView = 70 }):Play()
	end)
end

function PlayerFx.confetti()
	local hrp = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = hrp.Position + Vector3.new(0, 4, 0)
	anchor.Parent = Workspace
	local pe = Instance.new("ParticleEmitter")
	pe.Rate = 0
	pe.Lifetime = NumberRange.new(1.6, 2.6)
	pe.Speed = NumberRange.new(24, 48)
	pe.SpreadAngle = Vector2.new(70, 70)
	pe.Rotation = NumberRange.new(0, 360)
	pe.RotSpeed = NumberRange.new(-300, 300)
	pe.Acceleration = Vector3.new(0, -45, 0)
	pe.LightEmission = 0.4
	pe.Size = NumberSequence.new(0.7)
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 200)), ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 215, 90)),
		ColorSequenceKeypoint.new(0.7, Color3.fromRGB(70, 240, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 120, 255)),
	})
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1) })
	pe.Parent = anchor
	pe:Emit(140)
	Debris:AddItem(anchor, 3)
end

-- ===== per-character visuals =====
local function clearVisuals(char: Model)
	for _, n in { "NfTrail", "NfTrailA", "NfTrailB", "NfAura", "NfPlate" } do
		local x = char:FindFirstChild(n, true)
		if x then
			x:Destroy()
		end
	end
end

local function applyCosmetics(player: Player, char: Model)
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local head = char:FindFirstChild("Head") :: BasePart?
	if not hrp then
		return
	end
	clearVisuals(char)
	local trail = trailById[player:GetAttribute("Trail") or ""]
	if trail then
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Name, a1.Name = "NfTrailA", "NfTrailB"
		a0.Position, a1.Position = Vector3.new(0, 1.4, 0), Vector3.new(0, -1.6, 0)
		a0.Parent, a1.Parent = hrp, hrp
		local tr = Instance.new("Trail")
		tr.Name = "NfTrail"
		tr.Attachment0, tr.Attachment1 = a0, a1
		tr.Lifetime = 0.7
		tr.LightEmission = 1
		tr.FaceCamera = true
		tr.MinLength = 0.1
		tr.Color = ColorSequence.new(UIKit.rgb(trail.color), UIKit.rgb(trail.accent))
		tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		tr.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.1) })
		tr.Parent = hrp
	end
	local aura = auraById[player:GetAttribute("Aura") or ""]
	if aura then
		local att = Instance.new("Attachment")
		att.Name = "NfAura"
		att.Parent = hrp
		local pe = Instance.new("ParticleEmitter")
		pe.Rate = 16
		pe.Lifetime = NumberRange.new(1, 1.8)
		pe.Speed = NumberRange.new(1, 3)
		pe.Shape = Enum.ParticleEmitterShape.Cylinder
		pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		pe.Acceleration = Vector3.new(0, 4, 0)
		pe.LightEmission = 1
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new(UIKit.rgb(aura.color))
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.9), NumberSequenceKeypoint.new(1, 0) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.2), NumberSequenceKeypoint.new(1, 1) })
		pe.Parent = att
	end
	-- name plate: title, name, crowns (replaces the default overhead name)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	if head then
		local gui = Instance.new("BillboardGui")
		gui.Name = "NfPlate"
		gui.Size = UDim2.fromOffset(220, 62)
		gui.StudsOffset = Vector3.new(0, 3.1, 0)
		gui.AlwaysOnTop = false
		gui.MaxDistance = 90
		gui.LightInfluence = 0
		gui.Adornee = head
		local title = UIKit.label({ Size = UDim2.new(1, 0, 0, 16), Text = tostring(player:GetAttribute("TitleText") or ""), TextSize = 13, Font = T.fontBold, TextColor3 = T.gold, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, Parent = gui })
		title.TextStrokeTransparency = 0.4
		local name = UIKit.title({ Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 16), Text = player.DisplayName, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, Parent = gui })
		name.TextStrokeTransparency = 0.3
		local crowns = tonumber(player:GetAttribute("Crowns")) or 0
		local od = tonumber(player:GetAttribute("Overdrive")) or 0
		local stat = UIKit.label({
			Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 41), Text = ("Crowns %d%s"):format(crowns, if od > 0 then ("  -  Overdrive %d"):format(od) else ""), TextSize = 12,
			Font = T.fontBold, TextColor3 = T.magenta, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, Parent = gui,
		})
		stat.TextStrokeTransparency = 0.4
		gui.Parent = head
	end
end

local function watch(player: Player)
	local function refresh()
		local char = player.Character
		if char then
			applyCosmetics(player, char)
		end
	end
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("HumanoidRootPart", 10)
		char:WaitForChild("Head", 10)
		task.wait(0.2)
		applyCosmetics(player, char)
	end)
	for _, attr in { "Trail", "Aura", "TitleText", "Crowns", "Overdrive" } do
		player:GetAttributeChangedSignal(attr):Connect(refresh)
	end
	if player.Character then
		task.defer(refresh)
	end
end

function PlayerFx.init()
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerAdded:Connect(watch)
	local me = Players.LocalPlayer

	Remotes.get("Notify").OnClientEvent:Connect(function(n)
		if type(n) == "table" and n.kind == "fx" then
			if n.what == "speed" then
				PlayerFx.fov(88, n.seconds or 3)
			elseif n.what == "bounce" then
				PlayerFx.fov(82, 0.8)
				PlayerFx.shake(0.25, 0.2)
			end
		end
	end)

	RunService.RenderStepped:Connect(function()
		local char = me.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			local now = os.clock()
			if now < shakeUntil then
				local k = (shakeUntil - now) * shakePower
				hum.CameraOffset = Vector3.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
			elseif hum.CameraOffset ~= Vector3.zero then
				hum.CameraOffset = Vector3.zero
				shakePower = 0
			end
		end
	end)
	Feedback.setEffects(PlayerFx.shake, PlayerFx.confetti)
end

return PlayerFx
