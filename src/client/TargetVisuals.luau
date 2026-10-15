-- Applies this player's restoration state to the shared world:
--   * each target shows its Corrupted or Restored model (LocalTransparencyModifier, collisions, emitters, lights)
--   * hidden fragments / obelisks / capsules update when found
--   * glitch bits bob and spin (only near the camera), shards glimmer when the player can sense them
-- All changes are local to this client; the server world is never modified.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local State = require(script.Parent.State)
local Signal = require(script.Parent.Signal)

local TargetVisuals = {}

export type Entry = {
	id: string,
	model: Model,
	root: BasePart,
	def: any,
	permanent: boolean,
	corrupted: { BasePart },
	restored: { BasePart },
	cFx: { Instance }, -- emitters / lights inside Corrupted
	rFx: { Instance },
	shown: string, -- "corrupted" | "restored"
	fade: number, -- 0..1 transition progress
}

TargetVisuals.entries = {} :: { [string]: Entry }
TargetVisuals.ready = Signal.new()
local shards: { [string]: { model: Model, parts: { BasePart }, fx: { Instance }, prompt: ProximityPrompt?, sparkle: ParticleEmitter?, pillar: Part? } } = {}
local anim: { { part: BasePart, base: CFrame, amp: number, spin: number, phase: number, entry: Entry?, group: string?, shardId: string? } } = {}
local transitions: { [Entry]: { from: number, t0: number } } = {}

local FADE_TIME = 0.5

local function collect(folder: Instance?): ({ BasePart }, { Instance })
	local parts, fx = {}, {}
	if folder then
		for _, d in folder:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(parts, d)
			elseif d:IsA("ParticleEmitter") or d:IsA("PointLight") then
				table.insert(fx, d)
			end
		end
	end
	return parts, fx
end

local function setFx(list: { Instance }, on: boolean)
	for _, f in list do
		(f :: any).Enabled = on
	end
end

local function applyFlags(entry: Entry, state: string)
	local cVis = state == "corrupted"
	for _, p in entry.corrupted do
		if p:GetAttribute("Solid") then
			p.CanCollide = cVis
		end
	end
	for _, p in entry.restored do
		if p:GetAttribute("Solid") then
			p.CanCollide = not cVis
		end
	end
	setFx(entry.cFx, cVis)
	setFx(entry.rFx, not cVis)
end

local function setAlpha(entry: Entry, restoredAmount: number)
	-- restoredAmount: 0 = fully corrupted look, 1 = fully restored look
	local cMod = math.clamp(restoredAmount * 2, 0, 1) -- corrupted fades out in the first half
	local rMod = math.clamp(1 - (restoredAmount - 0.35) / 0.65, 0, 1) -- restored fades in after a small delay
	for _, p in entry.corrupted do
		p.LocalTransparencyModifier = cMod
	end
	for _, p in entry.restored do
		p.LocalTransparencyModifier = rMod
	end
end

-- instant = no fade (initial setup)
function TargetVisuals.apply(id: string, state: string, instant: boolean?)
	local entry = TargetVisuals.entries[id]
	if not entry then
		return
	end
	local want = if state == "corrupted" or state == "ready" then "corrupted" else "restored"
	if entry.shown == want and not instant then
		return
	end
	entry.shown = want
	applyFlags(entry, want)
	if instant then
		entry.fade = if want == "restored" then 1 else 0
		setAlpha(entry, entry.fade)
		transitions[entry] = nil
	else
		transitions[entry] = { from = entry.fade, t0 = os.clock() }
	end
end

local function register(model: Model)
	local id = model:GetAttribute("TargetId")
	local typeId = model:GetAttribute("TypeId")
	if type(id) ~= "string" or type(typeId) ~= "string" then
		return
	end
	local def = Config.Targets[typeId]
	local root = model:FindFirstChild("Root")
	if not def or not root then
		return
	end
	local cParts, cFx = collect(model:FindFirstChild("Corrupted"))
	local rParts, rFx = collect(model:FindFirstChild("Restored"))
	local entry: Entry = {
		id = id, model = model, root = root :: BasePart, def = def, permanent = def.permanent == true,
		corrupted = cParts, restored = rParts, cFx = cFx, rFx = rFx, shown = "corrupted", fade = 0,
	}
	TargetVisuals.entries[id] = entry
	applyFlags(entry, "corrupted") -- until the server snapshot arrives every target shows only its corrupted look
	setAlpha(entry, 0)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and (d:GetAttribute("Bob") or d:GetAttribute("Spin")) then
			local group = nil
			local f = d:FindFirstAncestorOfClass("Model")
			if f and f.Name == "Corrupted" then
				group = "corrupted"
			elseif f and f.Name == "Restored" then
				group = "restored"
			end
			table.insert(anim, {
				part = d, base = d.CFrame, amp = (d:GetAttribute("Bob") or 0) :: number, spin = (d:GetAttribute("Spin") or 0) :: number,
				phase = math.random() * 6.28, entry = entry, group = group,
			})
		end
	end
end

local function registerShard(model: Model)
	local id = model:GetAttribute("SecretId")
	if type(id) ~= "string" then
		return
	end
	local parts, fx = collect(model)
	local core = model:FindFirstChild("Core") :: BasePart?
	local s = { model = model, parts = parts, fx = fx, prompt = core and core:FindFirstChildOfClass("ProximityPrompt"), sparkle = core and core:FindFirstChild("ShardSparkle") :: ParticleEmitter?, pillar = nil }
	shards[id] = s
	for _, p in parts do
		if p:GetAttribute("Bob") or p:GetAttribute("Spin") then
			table.insert(anim, { part = p, base = p.CFrame, amp = (p:GetAttribute("Bob") or 0) :: number, spin = (p:GetAttribute("Spin") or 0) :: number, phase = math.random() * 6.28, shardId = id })
		end
	end
end

local function applyShard(id: string)
	local s = shards[id]
	if not s then
		return
	end
	local found = State.restored[id] == true
	for _, p in s.parts do
		p.LocalTransparencyModifier = if found then 1 else 0
	end
	setFx(s.fx, not found)
	if s.prompt then
		s.prompt.Enabled = not found
	end
	if found and s.pillar then
		s.pillar:Destroy()
		s.pillar = nil
	end
end

local function registerWorldAnimations(world: Instance)
	-- stations / landmarks: bob + spin always visible
	for _, d in world:GetDescendants() do
		if d:IsA("BasePart") and (d:GetAttribute("Bob") or d:GetAttribute("Spin")) then
			local inTarget = d:FindFirstAncestor("Targets") ~= nil
			local inShard = d.Parent and d.Parent:GetAttribute("SecretId") ~= nil
			if not inTarget and not inShard then
				table.insert(anim, { part = d, base = d.CFrame, amp = (d:GetAttribute("Bob") or 0) :: number, spin = (d:GetAttribute("Spin") or 0) :: number, phase = math.random() * 6.28 })
			end
		end
	end
end

local function openGate(world: Instance)
	-- the gateway barrier opens locally once this player has unlocked Frostlight
	local gateway = world:FindFirstChild("Gateway", true)
	local barrier = gateway and gateway:FindFirstChild("Barrier") :: BasePart?
	if not barrier then
		return
	end
	local function refresh()
		local open = State.data ~= nil and State.data.unlocked.frostlight == true
		barrier.LocalTransparencyModifier = if open then 1 else 0
		barrier.CanCollide = not open
		local prompt = barrier:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.ActionText = if open then "Look Beyond" else "Inspect Gateway"
		end
	end
	State.changed:Connect(refresh)
	refresh()
end

function TargetVisuals.init()
	local world = Workspace:WaitForChild("World")
	while not world:GetAttribute("Ready") do
		world:GetAttributeChangedSignal("Ready"):Wait()
	end
	local targets = world:WaitForChild("Targets")
	for _, m in targets:GetChildren() do
		if m:IsA("Model") then
			register(m)
		end
	end
	local landmarks = world:WaitForChild("Landmarks")
	for _, m in landmarks:GetChildren() do
		if m:IsA("Model") then
			registerShard(m)
		end
	end
	registerWorldAnimations(world)
	openGate(world)

	Remotes.get("TargetSnapshot").OnClientEvent:Connect(function(snap)
		for _, id in snap.restored do
			State.restored[id] = true
		end
		for _, id in snap.secrets do
			State.restored[id] = true
		end
		for id, entry in TargetVisuals.entries do
			TargetVisuals.apply(id, if entry.permanent and State.restored[id] then "restored" else "corrupted", true)
		end
		for id in shards do
			applyShard(id)
		end
		TargetVisuals.ready:Fire()
	end)

	Remotes.get("TargetUpdate").OnClientEvent:Connect(function(id: string, state: string, seconds: number?)
		State.setTarget(id, state, seconds)
		if shards[id] then
			applyShard(id)
		else
			TargetVisuals.apply(id, state)
		end
	end)

	local player = Players.LocalPlayer
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		-- fades
		for entry, tr in transitions do
			local k = math.clamp((now - tr.t0) / FADE_TIME, 0, 1)
			local target = if entry.shown == "restored" then 1 else 0
			entry.fade = tr.from + (target - tr.from) * k
			setAlpha(entry, entry.fade)
			if k >= 1 then
				transitions[entry] = nil
			end
		end
		-- bob/spin for animated parts that are visible and near the camera
		local cam = Workspace.CurrentCamera
		if cam then
			local camPos = cam.CFrame.Position
			for _, a in anim do
				local p = a.part
				if p.Parent then
					local visible = true
					if a.entry and a.group then
						visible = a.entry.shown == a.group
					elseif a.shardId then
						visible = not State.restored[a.shardId]
					end
					if visible and (p.Position - camPos).Magnitude < 110 then
						local off = if a.amp > 0 then math.sin(now * 2 + a.phase) * a.amp else 0
						p.CFrame = CFrame.new(0, off, 0) * a.base * CFrame.Angles(0, a.spin * now, 0)
					end
				end
			end
		end
		-- shard senses (discovery radius from Runeowl / research)
		acc += dt
		if acc >= 0.4 then
			acc = 0
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			local radius = if State.data then State.data.stats.discoveryRadius else 0
			for id, s in shards do
				if not State.restored[id] and hrp and s.sparkle then
					local core = s.model:FindFirstChild("Core") :: BasePart?
					local near = core ~= nil and radius > 0 and (core.Position - hrp.Position).Magnitude <= radius
					s.sparkle.Rate = if near then 14 else 2
					if near and not s.pillar and core then
						local pillar = Instance.new("Part")
						pillar.Anchored, pillar.CanCollide, pillar.CanQuery, pillar.CanTouch, pillar.CastShadow = true, false, false, false, false
						pillar.Size = Vector3.new(0.35, 40, 0.35)
						pillar.Material = Enum.Material.Neon
						pillar.Color = Color3.fromRGB(255, 230, 130)
						pillar.Transparency = 0.55
						pillar.CFrame = CFrame.new(core.Position + Vector3.new(0, 20, 0))
						pillar.Parent = s.model
						s.pillar = pillar
					elseif not near and s.pillar then
						s.pillar:Destroy()
						s.pillar = nil
					end
				end
			end
		end
	end)
end

return TargetVisuals
