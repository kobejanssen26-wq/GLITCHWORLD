-- Authoritative absorption: the client only says "I am holding the absorb button on target X"; the server decides
-- whether that is allowed (range, tier, availability), accumulates progress with the player's real stats,
-- pays out exactly once and tells that player's client what changed.
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local WorldData = require(Shared.WorldData)
local Rules = require(Shared.Rules)
local Remotes = require(Shared.Remotes)
local Sessions = require(script.Parent.Sessions)
local StateService = require(script.Parent.StateService)
local ProgressService = require(script.Parent.ProgressService)
local TargetRegistry = require(script.Parent.TargetRegistry)
local RateLimit = require(script.Parent.RateLimit)
local Stations = require(script.Parent.Stations)

local RestorationService = {}

local E = Config.Economy
local progressEvent: RemoteEvent, updateEvent: RemoteEvent

local function isAvailable(session: Sessions.Session, id: string, now: number): boolean
	local placement = WorldData.ById[id]
	if not placement then
		return false
	end
	local def = Config.Targets[placement.type]
	if def.permanent then
		return not session.profile.restored[id]
	end
	return (session.cooling[id] or 0) <= now
end

local function sendProgress(session: Sessions.Session, id: string?, fraction: number, boosted: boolean)
	progressEvent:FireClient(session.player, id, fraction, boosted)
end

local function stopAbsorb(session: Sessions.Session)
	if session.absorb then
		session.absorb = nil
		sendProgress(session, nil, 0, false)
	end
end

-- Completes a target for this player. Safe against duplicates: Rules.restoreTarget returns nil if the permanent
-- target is already restored, and the cooldown check guards renewables. No yields between check and write.
local function complete(session: Sessions.Session, id: string)
	local now = os.clock()
	local placement = WorldData.ById[id]
	if not placement or not isAvailable(session, id, now) then
		return
	end
	local def = Config.Targets[placement.type]
	local stats = Sessions.stats(session)
	local events = {}
	local result = Rules.restoreTarget(session.profile, stats, id, events)
	if not result then
		return
	end
	session.progress[id] = nil
	if session.absorb and session.absorb.id == id then
		session.absorb = nil
		sendProgress(session, nil, 0, false)
	end
	if def.permanent then
		updateEvent:FireClient(session.player, id, "restored")
	else
		local secs = def.renew * stats.respawnMult
		session.cooling[id] = now + secs
		updateEvent:FireClient(session.player, id, "cooling", secs)
	end
	StateService.notify(session.player, {
		kind = "restored", id = id, type = placement.type, fragments = result.fragments, stored = result.stored,
		overflowCredits = result.overflowCredits, xp = result.xp, echo = result.echo,
	})
	ProgressService.commit(session, events)
end

local function addProgress(session: Sessions.Session, id: string, amount: number, now: number)
	local placement = WorldData.ById[id]
	local def = Config.Targets[placement.type]
	local prog = session.progress[id]
	if not prog then
		prog = { hp = 0, last = now }
		session.progress[id] = prog
	end
	prog.hp += amount
	prog.last = now
	if prog.hp >= def.hp then
		complete(session, id)
	end
end

local function step(session: Sessions.Session, dt: number, now: number)
	local absorb = session.absorb
	if absorb then
		local id = absorb.id
		local placement = WorldData.ById[id]
		local def = Config.Targets[placement.type]
		local root = TargetRegistry.get(id)
		local pos = Stations.rootPosition(session.player)
		local stats = Sessions.stats(session)
		if not root or not pos or not isAvailable(session, id, now) then
			stopAbsorb(session)
		elseif (pos - root.Position).Magnitude - def.radius > stats.range + E.RANGE_SLACK then
			stopAbsorb(session)
		elseif def.minTier > stats.absorberTier then
			if not session.deniedTier[id] then
				session.deniedTier[id] = true
				local need = Config.Absorber[def.minTier]
				StateService.notify(session.player, { kind = "msg", text = ("%s needs the %s."):format(def.name, need.name), tone = "warn" })
			end
			stopAbsorb(session)
		else
			local boost = 1
			if now < session.boostUntil and stats.overcharge then
				boost = stats.overcharge.boost
			end
			local rate = Rules.dps(stats, def.category, boost)
			if def.frag > 0 and session.profile.fragments >= stats.capacity and now - session.lastFullWarn > 8 then
				session.lastFullWarn = now
				StateService.notify(session.player, { kind = "msg", text = ("Backpack full! Extra fragments auto-sell at %d%%."):format(math.floor(stats.overflowRate * 100 + 0.5)), tone = "warn" })
			end
			-- Area Siphon: nearby corrupted objects also drain at reduced strength
			if stats.siphon then
				for otherId, otherRoot in TargetRegistry.all() do
					if otherId ~= id and otherRoot.Parent and (otherRoot.Position - root.Position).Magnitude <= stats.siphon.radius and isAvailable(session, otherId, now) then
						local op = WorldData.ById[otherId]
						local od = Config.Targets[op.type]
						if od.minTier <= stats.absorberTier then
							addProgress(session, otherId, Rules.dps(stats, od.category, boost) * stats.siphon.strength * dt, now)
						end
					end
				end
			end
			if session.absorb and session.absorb.id == id then
				addProgress(session, id, rate * dt, now)
			end
			if session.absorb and now - session.lastProgressSent >= 0.1 then
				local prog = session.progress[id]
				sendProgress(session, id, if prog then math.clamp(prog.hp / def.hp, 0, 1) else 0, boost > 1)
				session.lastProgressSent = now
			end
		end
	end
	-- partial corruption grows back when nobody is absorbing it
	for id, prog in session.progress do
		if now - prog.last > E.ABSORB_PROGRESS_DECAY_DELAY then
			local def = Config.Targets[WorldData.ById[id].type]
			prog.hp -= def.hp * E.ABSORB_PROGRESS_DECAY_RATE * dt
			if prog.hp <= 0 then
				session.progress[id] = nil
			end
		end
	end
end

function RestorationService.start()
	progressEvent = Remotes.get("AbsorbProgress")
	ProgressService.onChange(function(session)
		session.deniedTier = {} -- tier requirements may have changed
	end)
	updateEvent = Remotes.get("TargetUpdate")

	Remotes.get("AbsorbControl").OnServerEvent:Connect(function(player: Player, action: any, id: any)
		if not RateLimit.allow(player, "absorb", 20, 20) then
			return
		end
		local session = Sessions.get(player)
		if not session then
			return
		end
		if action == "stop" then
			stopAbsorb(session)
			return
		end
		if action ~= "start" or type(id) ~= "string" or #id > 64 then
			return
		end
		local now = os.clock()
		local placement = WorldData.ById[id]
		if not placement or not TargetRegistry.get(id) then
			return -- missing / deleted target
		end
		if not isAvailable(session, id, now) then
			-- client is out of sync: tell it the truth instead of silently ignoring
			local def = Config.Targets[placement.type]
			if def.permanent then
				updateEvent:FireClient(player, id, "restored")
			else
				updateEvent:FireClient(player, id, "cooling", (session.cooling[id] or now) - now)
			end
			stopAbsorb(session)
			return
		end
		session.absorb = { id = id }
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		dt = math.min(dt, 0.2)
		local now = os.clock()
		for _, session in Sessions.all() do
			if session.player.Parent then
				step(session, dt, now)
			end
		end
		-- renewable regrowth notifications (cheap, twice a second)
		acc += dt
		if acc >= 0.5 then
			acc = 0
			for _, session in Sessions.all() do
				for id, readyAt in session.cooling do
					if now >= readyAt then
						session.cooling[id] = nil
						updateEvent:FireClient(session.player, id, "ready")
					end
				end
			end
		end
	end)
end

function RestorationService.forget(session: Sessions.Session)
	session.absorb = nil
	session.progress = {}
	session.cooling = {}
end

return RestorationService
