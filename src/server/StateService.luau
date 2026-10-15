-- Builds and pushes the profile snapshot the HUD/menus render, and delivers one-off Notify events.
-- The client never computes economy values: everything it shows (stats, objective, progress) comes from here.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules = require(Shared.Rules)
local Remotes = require(Shared.Remotes)
local Sessions = require(script.Parent.Sessions)

local RunService = game:GetService("RunService")

local StateService = {}

local stateEvent: RemoteEvent, notifyEvent: RemoteEvent
local dirty: { [any]: boolean } = {}

local function setOf(t: { [string]: boolean }): { [string]: boolean }
	return table.clone(t)
end

function StateService.snapshot(session: Sessions.Session)
	local p = session.profile
	local stats = Sessions.stats(session)
	local rank, into, need = Rules.rankInfo(p.xp)
	local now = os.clock()
	local titles = {}
	for t in p.titles do
		table.insert(titles, t)
	end
	table.sort(titles)
	return {
		credits = p.credits,
		fragments = p.fragments,
		xp = p.xp,
		rank = rank,
		rankInto = into,
		rankNeed = need,
		title = p.title,
		titles = titles,
		rp = p.rp,
		tiers = table.clone(p.tiers),
		gadgets = setOf(p.gadgets),
		stats = {
			power = stats.power, speed = stats.speed, range = stats.range, capacity = stats.capacity, walk = stats.walk,
			sellMult = stats.sellMult, xpMult = stats.xpMult, respawnMult = stats.respawnMult, echoSlots = stats.echoSlots,
			overflowRate = stats.overflowRate, discoveryRadius = stats.discoveryRadius, secretMult = stats.secretMult,
			lens = stats.lens, siphon = stats.siphon, overcharge = stats.overcharge, frag = stats.frag,
		},
		equipped = table.clone(p.equipped),
		echoes = setOf(p.echoes),
		research = setOf(p.research),
		quests = setOf(p.quests),
		milestones = setOf(p.milestones),
		unlocked = setOf(p.unlocked),
		counters = table.clone(p.stats),
		percent = Rules.percent(p),
		settings = table.clone(p.settings),
		objective = Rules.nextObjective(p, stats),
		boostLeft = math.max(0, session.boostUntil - now),
		gadgetCooldown = math.max(0, session.gadgetReadyAt - now),
	}
end

function StateService.markDirty(session: Sessions.Session)
	dirty[session] = true
end

function StateService.pushNow(session: Sessions.Session)
	if not session.player.Parent then
		return
	end
	dirty[session] = nil
	session.lastSent = os.clock()
	stateEvent:FireClient(session.player, StateService.snapshot(session))
end

function StateService.notify(player: Player, payload: { [string]: any })
	if player.Parent then
		notifyEvent:FireClient(player, payload)
	end
end

function StateService.forget(session: Sessions.Session)
	dirty[session] = nil
end

function StateService.start()
	stateEvent = Remotes.get("State")
	notifyEvent = Remotes.get("Notify")
	-- flush dirty sessions at most ~8x per second each
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for session in dirty do
			if now - session.lastSent >= 0.12 then
				StateService.pushNow(session)
			end
		end
	end)
end

return StateService
