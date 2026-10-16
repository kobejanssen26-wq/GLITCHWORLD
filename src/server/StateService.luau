-- Builds and pushes the profile snapshot the HUD/menus render, and delivers one-off Notify events.
-- The client never computes economy values: everything it shows comes from here.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)
local Remotes = require(Shared.Remotes)
local Sessions = require(script.Parent.Sessions)

local RunService = game:GetService("RunService")

local StateService = {}

local stateEvent: RemoteEvent, notifyEvent: RemoteEvent
local dirty: { [any]: boolean } = {}

function StateService.snapshot(session: Sessions.Session)
	local p = session.profile
	local nxt = Rules.nextItem(p)
	local nextInfo = nil
	if nxt then
		local ok, reason, cost = Rules.canBuyItem(p, nxt.id)
		nextInfo = { id = nxt.id, name = nxt.name, cost = cost, kind = nxt.kind, affordable = ok, reason = reason }
	end
	local titles = {}
	return {
		cash = p.cash, crowns = p.crowns, overdrive = p.overdrive, reached = p.reached, checkpoint = p.checkpoint,
		floors = table.clone(p.floors), items = table.clone(p.items), perks = table.clone(p.perks), trails = table.clone(p.trails),
		auras = table.clone(p.auras), trail = p.trail, aura = p.aura, title = p.title, titles = titles,
		counters = table.clone(p.stats), settings = table.clone(p.settings),
		income = Rules.income(p), mult = Rules.cashMult(p), movement = Rules.movement(p),
		nextItem = nextInfo, canOverdrive = Rules.canOverdrive(p),
		skipCost = if p.checkpoint < Config.Tower.FLOORS then Rules.skipCost(p.checkpoint) else nil,
		objective = Rules.nextObjective(p), plot = session.plot, inTower = session.inTower,
	}
end

function StateService.markDirty(session: Sessions.Session)
	dirty[session] = true
end

function StateService.pushNow(session: Sessions.Session)
	if not session.player.Parent or not session.ready then
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
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for session in dirty do
			if now - session.lastSent >= 0.15 then
				StateService.pushNow(session)
			end
		end
	end)
end

return StateService
