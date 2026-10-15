-- Wires the world's ProximityPrompts (tagged with an "Action" attribute by the builders) to server logic.
-- Menu prompts only tell the client which menu to open; sell / secrets / gateway are validated here.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)
local Remotes = require(Shared.Remotes)
local Sessions = require(script.Parent.Sessions)
local StateService = require(script.Parent.StateService)
local ProgressService = require(script.Parent.ProgressService)
local EconomyService = require(script.Parent.EconomyService)
local Stations = require(script.Parent.Stations)
local RateLimit = require(script.Parent.RateLimit)

local Interactions = {}

local SECRET_REACH = 16

local function secretPosition(id: string): Vector3?
	local world = workspace:FindFirstChild("World")
	local model = world and world:FindFirstChild("Shard_" .. id, true)
	local core = model and model:FindFirstChild("Core")
	return core and (core :: BasePart).Position
end

local function collectSecret(player: Player, id: string)
	local session = Sessions.get(player)
	if not session then
		return
	end
	local pos, target = Stations.rootPosition(player), secretPosition(id)
	if not pos or not target or (pos - target).Magnitude > SECRET_REACH then
		return
	end
	local events = {}
	local result = Rules.collectSecret(session.profile, Sessions.stats(session), id, events) -- nil if already found
	if not result then
		Remotes.get("TargetUpdate"):FireClient(player, id, "restored")
		return
	end
	Remotes.get("TargetUpdate"):FireClient(player, id, "restored")
	table.insert(events, 1, { kind = "secret", id = id, credits = result.credits, xp = result.xp })
	ProgressService.commit(session, events)
end

local function gateInfo(player: Player)
	local session = Sessions.get(player)
	if not session then
		return
	end
	local p = session.profile
	local area = Config.Areas.frostlight
	if p.unlocked.frostlight then
		StateService.notify(player, { kind = "msg", text = "The gateway is open. " .. area.teaser .. " (Frostlight Peaks arrives in a future update.)", tone = "good" })
	else
		local m
		for _, mm in Config.Milestones do
			if mm.id == area.requires.milestone then
				m = mm
			end
		end
		StateService.notify(player, {
			kind = "msg",
			tone = "warn",
			text = ("Sealed. Restore %d%% of the valley (now %.0f%%) and own the %s."):format(m.value, Rules.percent(p), Config.Absorber[area.requires.absorberTier].name),
		})
	end
end

local function onTriggered(player: Player, action: string)
	if not RateLimit.allow(player, "prompt", 6, 8) then
		return
	end
	if action == "sell" then
		EconomyService.sell(player)
	elseif action:sub(1, 5) == "menu:" then
		Remotes.get("OpenMenu"):FireClient(player, action:sub(6))
	elseif action:sub(1, 7) == "secret:" then
		collectSecret(player, action:sub(8))
	elseif action == "gate" then
		gateInfo(player)
	end
end

function Interactions.bind(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			local action = d:GetAttribute("Action")
			if type(action) == "string" then
				d.Triggered:Connect(function(player)
					onTriggered(player, action)
				end)
			end
		end
	end
end

return Interactions
