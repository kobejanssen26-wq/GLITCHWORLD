-- Objective guidance: a light pillar + a thin guide beam toward the current objective (client-only parts).
-- The objective itself is chosen by the server (Rules.nextObjective); the client only resolves "where".
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local WorldData = require(Shared.WorldData)
local State = require(script.Parent.State)
local TargetVisuals = require(script.Parent.TargetVisuals)
local Hud = require(script.Parent.Hud)

local Beacon = {}

local player = Players.LocalPlayer
local pillar: Part, anchor: Part, beam: Beam, a0: Attachment, a1: Attachment

local function rootPos(): Vector3?
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
	return hrp and hrp.Position
end

local function nearest(from: Vector3, filter: (any) -> boolean): Vector3?
	local best, bestD = nil, math.huge
	for id, e in TargetVisuals.entries do
		if State.isAvailable(id, e.permanent) and filter(e) then
			local d = (e.root.Position - from).Magnitude
			if d < bestD then
				best, bestD = e.root.Position, d
			end
		end
	end
	return best
end

local function resolve(spec: string, from: Vector3): Vector3?
	local d = State.data
	if spec:sub(1, 8) == "station:" then
		local s = WorldData.Stations[spec:sub(9)]
		return s and Vector3.new(s.x, WorldData.heightAt(s.x, s.z) + 2, s.z)
	elseif spec == "gateway" then
		local g = WorldData.GATEWAY
		return Vector3.new(g.x, WorldData.heightAt(g.x, g.z) + 2, g.z)
	elseif spec:sub(1, 8) == "nearest:" then
		local what = spec:sub(9)
		local tier = d.tiers.absorber
		if what == "capsule" then
			return nearest(from, function(e)
				return e.def.category == "echo" and e.def.minTier <= tier
			end)
		elseif what == "restorable" then
			return nearest(from, function(e)
				return e.permanent and (e.def.weight or 0) > 0 and e.def.minTier <= tier
			end) or nearest(from, function(e)
				return e.permanent and e.def.minTier <= tier
			end)
		else
			return nearest(from, function(e)
				return e.model:GetAttribute("TypeId") == what and e.permanent
			end) or nearest(from, function(e)
				return e.permanent and (e.def.weight or 0) > 0 and e.def.minTier <= tier
			end)
		end
	end
	return nil
end

function Beacon.init()
	pillar = Instance.new("Part")
	pillar.Name = "ObjectiveBeacon"
	pillar.Anchored, pillar.CanCollide, pillar.CanQuery, pillar.CanTouch, pillar.CastShadow = true, false, false, false, false
	pillar.Size = Vector3.new(1.2, 70, 1.2)
	pillar.Material = Enum.Material.Neon
	pillar.Color = Config.Colors.glitchCyan
	pillar.Transparency = 1
	pillar.Parent = Workspace
	anchor = Instance.new("Part")
	anchor.Name = "ObjectiveAnchor"
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch, anchor.CastShadow = true, false, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.Parent = Workspace
	a0 = Instance.new("Attachment")
	a1 = Instance.new("Attachment")
	a1.Parent = anchor
	beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(Config.Colors.glitchCyan)
	beam.Width0 = 0.25
	beam.Width1 = 0.25
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Transparency = NumberSequence.new(0.55)
	beam.Segments = 1
	beam.Enabled = false
	beam.Parent = Workspace.Terrain

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.3 then
			return
		end
		acc = 0
		local d = State.data
		local from = rootPos()
		if not d or not from or d.settings.hints == false then
			pillar.Transparency = 1
			beam.Enabled = false
			Hud.setObjectiveDistance("")
			return
		end
		local target = resolve(d.objective.beacon or "", from)
		if not target then
			pillar.Transparency = 1
			beam.Enabled = false
			Hud.setObjectiveDistance("")
			return
		end
		local dist = (target - from).Magnitude
		Hud.setObjectiveDistance(("%d m"):format(math.floor(dist)))
		pillar.CFrame = CFrame.new(target + Vector3.new(0, 30, 0))
		pillar.Transparency = if dist < 14 then 1 else 0.72
		anchor.Position = target + Vector3.new(0, 1, 0)
		local c = player.Character
		local hrp = c and c:FindFirstChild("HumanoidRootPart")
		if hrp then
			a0.Parent = hrp
			beam.Enabled = dist > 10 and dist < 260
		end
	end)
end

return Beacon
