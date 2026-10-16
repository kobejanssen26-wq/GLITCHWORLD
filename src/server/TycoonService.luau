-- Factory economy. Ores are a deterministic schedule: every dropper emits an ore each `interval` seconds on the shared
-- server clock, the ore reaches the collector after a fixed transit time, and cash is credited then using the
-- player's CURRENT multipliers. The client draws the same schedule (see client/PlotVisuals) - no ore parts, no physics.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)
local Remotes = require(Shared.Remotes)
local Sessions = require(script.Parent.Sessions)
local StateService = require(script.Parent.StateService)
local ProgressService = require(script.Parent.ProgressService)
local PlotService = require(script.Parent.PlotService)
local RateLimit = require(script.Parent.RateLimit)

local TycoonService = {}

local COLLECTOR_X = 35
local FALL_TIME = 0.45

local function clock(): number
	return Workspace:GetServerTimeNow()
end

-- stable per-item phase so droppers do not all fire on the same beat
local function phaseOf(id: string, interval: number): number
	local h = 0
	for i = 1, #id do
		h = (h * 31 + string.byte(id, i)) % 9973
	end
	return (h / 9973) * interval
end
TycoonService.phaseOf = phaseOf

function TycoonService.transit(item): number
	return FALL_TIME + (COLLECTOR_X - item.x) / Config.Tycoon.BELT_SPEED
end

-- number of ores `item` emitted in (t0, t1]
function TycoonService.emissions(item, t0: number, t1: number): { number }
	local ph = phaseOf(item.id, item.interval)
	local a = math.floor((t0 - ph) / item.interval)
	local b = math.floor((t1 - ph) / item.interval)
	local out = {}
	for n = a + 1, b do
		table.insert(out, n * item.interval + ph)
	end
	return out
end

local function step(session: Sessions.Session, now: number)
	if not session.plot then
		return
	end
	local p = session.profile
	local last = session.lastTick
	session.lastTick = now
	if last == 0 or now - last > 5 then
		return -- first tick (or a long stall): no catch-up so nothing is credited twice
	end
	-- emit
	for _, it in Config.Items do
		if it.kind == "dropper" and p.items[it.id] then
			for _, t in TycoonService.emissions(it, last, now) do
				if #session.arrivals < Config.Tycoon.MAX_ORE_PER_PLOT * 4 then
					table.insert(session.arrivals, { t = t + TycoonService.transit(it), id = it.id })
				end
			end
		end
	end
	-- arrive
	local credited, ores = 0, 0
	local keep = {}
	for _, a in session.arrivals do
		if a.t <= now then
			if p.items[a.id] then
				credited += Rules.oreValue(p, a.id)
				ores += 1
			end
		else
			table.insert(keep, a)
		end
	end
	session.arrivals = keep
	-- generators: continuous
	local dt = now - last
	local genMult = Rules.cashMult(p) * Rules.collectorBonus(p)
	for _, it in Config.Items do
		if it.kind == "generator" and p.items[it.id] then
			credited += it.rate * genMult * dt
		end
	end
	if credited > 0 then
		credited += session.fraction
		local whole = math.floor(credited)
		session.fraction = credited - whole
		if whole > 0 then
			Rules.addCash(p, whole)
			session.pendingCash += whole
			session.pendingOres += ores
			StateService.markDirty(session)
		end
	end
end

local accum = 0
function TycoonService.start()
	RunService.Heartbeat:Connect(function(dt)
		local now = clock()
		for _, session in Sessions.all() do
			if session.player.Parent then
				step(session, now)
			end
		end
		accum += dt
		if accum >= 0.4 then
			accum = 0
			for _, session in Sessions.all() do
				if session.pendingCash > 0 and session.ready then
					Remotes.get("CashTick"):FireClient(session.player, session.pendingCash, session.pendingOres)
					session.pendingCash, session.pendingOres = 0, 0
				end
			end
		end
	end)

	local lastPad: { [Player]: number } = {}
	PlotService.onPad = function(index: number, hit: BasePart)
		local plot = PlotService.get(index)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not plot or not player or plot.owner ~= player then
			return
		end
		local now = os.clock()
		if now - (lastPad[player] or 0) < 0.7 then
			return
		end
		lastPad[player] = now
		local session = Sessions.get(player)
		local nxt = session and Rules.nextItem(session.profile)
		if session and nxt then
			local res = TycoonService.buy(player, nxt.id)
			if not res.ok and res.reason == "funds" then
				StateService.notify(player, { kind = "msg", text = ("You need $%s for %s."):format(tostring(Rules.itemCost(nxt, session.profile)), nxt.name), tone = "warn" })
			end
		end
	end
	PlotService.onOverdrive = function(player: Player)
		TycoonService.overdrive(player)
	end

	Remotes.get("Buy").OnServerInvoke = function(player: Player, itemId: any)
		return TycoonService.buy(player, itemId)
	end
	Remotes.get("Overdrive").OnServerInvoke = function(player: Player)
		return TycoonService.overdrive(player)
	end
end

local function nearPad(session: Sessions.Session): boolean
	local plot = session.plot and PlotService.get(session.plot)
	local char = session.player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not plot or not hrp then
		return false
	end
	return (hrp.Position - plot.origin.Position).Magnitude <= 90
end

function TycoonService.buy(player: Player, itemId: any)
	if not RateLimit.allow(player, "buy", 5, 8) then
		return { ok = false, reason = "slow_down" }
	end
	local session = Sessions.get(player)
	if not session then
		return { ok = false, reason = "no_session" }
	end
	if type(itemId) ~= "string" or #itemId > 40 then
		return { ok = false, reason = "invalid" }
	end
	if not session.plot then
		return { ok = false, reason = "no_plot" }
	end
	if not nearPad(session) then
		return { ok = false, reason = "far" }
	end
	if session.busy then
		return { ok = false, reason = "busy" }
	end
	session.busy = true
	local ok, reason = Rules.buyItem(session.profile, itemId) -- validates order, funds and ownership; charges atomically
	session.busy = false
	if not ok then
		return { ok = false, reason = reason }
	end
	local plot = PlotService.get(session.plot)
	local item = Rules.itemById[itemId]
	if plot then
		PlotService.addItem(plot, item)
		PlotService.updatePad(plot, session.profile)
	end
	ProgressService.commit(session, { { kind = "bought", id = itemId, name = item.name, itemKind = item.kind } })
	return { ok = true }
end

function TycoonService.overdrive(player: Player)
	if not RateLimit.allow(player, "overdrive", 0.5, 2) then
		return { ok = false, reason = "slow_down" }
	end
	local session = Sessions.get(player)
	if not session or not session.plot then
		return { ok = false, reason = "no_session" }
	end
	if session.busy then
		return { ok = false, reason = "busy" }
	end
	session.busy = true
	local ok = Rules.overdrive(session.profile)
	session.busy = false
	if not ok then
		return { ok = false, reason = "locked" }
	end
	session.arrivals = {}
	session.fraction = 0
	local plot = PlotService.get(session.plot)
	if plot then
		PlotService.build(plot, session.profile)
		PlotService.updatePad(plot, session.profile)
	end
	ProgressService.commit(session, { { kind = "overdrive", count = session.profile.overdrive } })
	return { ok = true, count = session.profile.overdrive }
end

return TycoonService
