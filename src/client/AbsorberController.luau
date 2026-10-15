-- Input + aiming for the Restoration Absorber.
--   PC: hold left mouse (aim with the cursor). Touch: hold the ABSORB button (auto-targets the nearest target in front).
--   Gamepad: hold R2 / R1 (auto-target). Q / button = Overcharge gadget.
-- The client only reports "I am holding on target X"; the server validates range, tier and progress.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)
local TargetVisuals = require(script.Parent.TargetVisuals)
local Sfx = require(script.Parent.Sfx)
local Hud = require(script.Parent.Hud)

local AbsorberController = {}
local T = UIKit.theme

local player = Players.LocalPlayer
local control: RemoteEvent
local holding = false
local current: string? = nil -- target id we told the server about
local lastInputKind = "mouse"
local hoverHighlight: Highlight
local progressGui: BillboardGui, progressSet: (number, string?) -> ()
local beam: Beam, beamA0: Attachment, beamA1: Attachment
local progressHideAt = 0
local looping = false

local function rootPart(): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- distance from point to the ray (origin, dir unit)
local function rayDistance(origin: Vector3, dir: Vector3, point: Vector3): number
	local v = point - origin
	local t = math.max(0, v:Dot(dir))
	return (v - dir * t).Magnitude
end

-- best target for the current input. returns id, entry, reason (when something is aimed at but unusable)
local function pickTarget(): (string?, any?, string?)
	local d = State.data
	local hrp = rootPart()
	local cam = Workspace.CurrentCamera
	if not d or not hrp or not cam then
		return nil, nil, nil
	end
	local range = d.stats.range
	local bestId, bestEntry, bestScore = nil, nil, math.huge
	local blockedEntry, blockedReason, blockedScore = nil, nil, math.huge

	local useCursor = lastInputKind == "mouse" and UserInputService.MouseEnabled
	local ray = nil
	if useCursor then
		local mp = UserInputService:GetMouseLocation()
		ray = cam:ViewportPointToRay(mp.X, mp.Y)
	end
	local look = cam.CFrame.LookVector

	for id, e in TargetVisuals.entries do
		if State.isAvailable(id, e.permanent) then
			local pos = e.root.Position + Vector3.new(0, 2, 0)
			local dist = (hrp.Position - e.root.Position).Magnitude - e.def.radius
			local score
			if ray then
				local rd = rayDistance(ray.Origin, ray.Direction, pos)
				if rd <= e.def.radius + 3.5 then
					score = rd
				end
			else
				local to = (e.root.Position - hrp.Position)
				if to.Magnitude > 0.1 and to.Unit:Dot(Vector3.new(look.X, 0, look.Z).Unit) > 0.35 then
					score = dist
				end
			end
			if score then
				if dist > range then
					if score < blockedScore then
						blockedEntry, blockedReason, blockedScore = e, "far", score
					end
				elseif e.def.minTier > d.tiers.absorber then
					if score < blockedScore then
						blockedEntry, blockedReason, blockedScore = e, "tier", score
					end
				elseif score < bestScore then
					bestId, bestEntry, bestScore = id, e, score
				end
			end
		end
	end
	if bestId then
		return bestId, bestEntry, nil
	end
	return nil, blockedEntry, blockedReason
end

local function setBeam(entry: any?)
	local hrp = rootPart()
	if entry and hrp then
		beamA0.Parent = hrp
		beamA1.Parent = entry.root
		beamA1.Position = Vector3.new(0, 2, 0)
		beam.Enabled = true
	else
		beam.Enabled = false
	end
end

local function showProgress(entry: any?, fraction: number, boosted: boolean)
	if entry then
		progressGui.Adornee = entry.root
		progressGui.StudsOffset = Vector3.new(0, 6, 0)
		progressGui.Enabled = true
		progressSet(fraction, if boosted then "OVERCHARGED" else entry.def.name)
		progressHideAt = os.clock() + 0.6
	else
		progressGui.Enabled = false
	end
end

local function sendStart(id: string?)
	if id == current then
		return
	end
	current = id
	if id then
		control:FireServer("start", id)
	else
		control:FireServer("stop")
	end
end

local function evaluate()
	if not holding then
		return
	end
	local id, entry, reason = pickTarget()
	sendStart(id)
	if id and entry then
		setBeam(entry)
		Sfx.startLoop("absorbLoop")
		hoverHighlight.Adornee = entry.model:FindFirstChild("Corrupted") :: Instance?
		Hud.setHint(entry.def.name, T.cyan)
	else
		setBeam(nil)
		Sfx.stopLoop("absorbLoop")
		if entry and reason == "far" then
			Hud.setHint("Move closer to " .. entry.def.name, T.warn)
		elseif entry and reason == "tier" then
			Hud.setHint(("%s needs the %s"):format(entry.def.name, Config.Absorber[entry.def.minTier].name), T.warn)
		else
			Hud.setHint("Aim at glowing purple corruption", T.dim)
		end
	end
end

local function setHolding(on: boolean)
	if holding == on then
		return
	end
	holding = on
	if on then
		evaluate()
	else
		sendStart(nil)
		setBeam(nil)
		Sfx.stopLoop("absorbLoop")
		hoverHighlight.Adornee = nil
		Hud.setHint("", nil)
	end
end

local function buildEffects()
	hoverHighlight = Instance.new("Highlight")
	hoverHighlight.FillColor = Config.Colors.glitchCyan
	hoverHighlight.FillTransparency = 0.82
	hoverHighlight.OutlineColor = Color3.new(1, 1, 1)
	hoverHighlight.OutlineTransparency = 0.2
	hoverHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
	hoverHighlight.Parent = Workspace

	beamA0 = Instance.new("Attachment")
	beamA0.Name = "AbsorbA0"
	beamA1 = Instance.new("Attachment")
	beamA1.Name = "AbsorbA1"
	beam = Instance.new("Beam")
	beam.Attachment0 = beamA0
	beam.Attachment1 = beamA1
	beam.Color = ColorSequence.new(Config.Colors.glitchCyan, Config.Colors.glitchPurple)
	beam.Width0 = 0.5
	beam.Width1 = 1.4
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Segments = 12
	beam.CurveSize0 = 2
	beam.CurveSize1 = -2
	beam.Transparency = NumberSequence.new(0.2)
	beam.Enabled = false
	beam.Parent = Workspace.Terrain

	progressGui = Instance.new("BillboardGui")
	progressGui.Size = UDim2.fromOffset(150, 30)
	progressGui.AlwaysOnTop = true
	progressGui.LightInfluence = 0
	progressGui.Enabled = false
	progressGui.Parent = player:WaitForChild("PlayerGui")
	local bar, set = UIKit.bar({ Size = UDim2.fromScale(1, 1), TextSize = UIKit.px(12), Parent = progressGui }, T.cyan)
	progressSet = set
	bar.Name = "ProgressBar"
end

function AbsorberController.init()
	control = Remotes.get("AbsorbControl")
	buildEffects()

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			lastInputKind = "mouse"
			if not processed then
				setHolding(true)
			end
		elseif input.UserInputType == Enum.UserInputType.Gamepad1 then
			lastInputKind = "pad"
			if input.KeyCode == Enum.KeyCode.ButtonR2 or input.KeyCode == Enum.KeyCode.ButtonR1 then
				setHolding(true)
			elseif input.KeyCode == Enum.KeyCode.ButtonL2 or input.KeyCode == Enum.KeyCode.ButtonY then
				Remotes.get("UseGadget"):FireServer("overcharge")
			end
		elseif input.UserInputType == Enum.UserInputType.Touch then
			lastInputKind = "touch"
		elseif input.UserInputType == Enum.UserInputType.Keyboard then
			lastInputKind = if lastInputKind == "pad" then "mouse" else lastInputKind
			if input.KeyCode == Enum.KeyCode.Q and not processed then
				Remotes.get("UseGadget"):FireServer("overcharge")
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			setHolding(false)
		elseif input.UserInputType == Enum.UserInputType.Gamepad1 and (input.KeyCode == Enum.KeyCode.ButtonR2 or input.KeyCode == Enum.KeyCode.ButtonR1) then
			setHolding(false)
		end
	end)

	local btn = Hud.absorbButton()
	if btn then
		btn.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				lastInputKind = "touch"
				setHolding(true)
			end
		end)
		btn.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				setHolding(false)
			end
		end)
	end

	Remotes.get("AbsorbProgress").OnClientEvent:Connect(function(id: string?, fraction: number, boosted: boolean)
		if id then
			showProgress(TargetVisuals.entries[id], fraction, boosted)
			Sfx.setLoopPitch("absorbLoop", 1 + fraction * 0.8)
		else
			progressGui.Enabled = false
			current = nil -- server stopped absorbing (done / out of range): re-evaluate on the next tick
		end
	end)

	-- hover preview + target re-evaluation while holding (10 Hz is plenty)
	if not looping then
		looping = true
		local acc = 0
		RunService.Heartbeat:Connect(function(dt)
			acc += dt
			if acc < 0.1 then
				return
			end
			acc = 0
			if progressGui.Enabled and os.clock() > progressHideAt then
				progressGui.Enabled = false
			end
			if holding then
				evaluate()
			elseif lastInputKind == "mouse" and UserInputService.MouseEnabled then
				local _, entry = pickTarget()
				hoverHighlight.Adornee = if entry then entry.model:FindFirstChild("Corrupted") :: Instance? else nil
			end
		end)
	end

	-- release everything when the character dies / respawns
	player.CharacterAdded:Connect(function()
		holding = false
		current = nil
		setBeam(nil)
		Sfx.stopLoop("absorbLoop")
	end)
end

return AbsorberController
