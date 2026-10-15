-- All game rules as pure functions over a profile table. No Roblox instances, no yielding: the server calls these
-- (so every mutation is atomic w.r.t. other server threads) and the unit tests exercise them directly.
local Config = require(script.Parent.Config)
local WorldData = require(script.Parent.WorldData)
local Profile = require(script.Parent.Profile)

local Rules = {}

local CAPS = Config.Economy.CAPS

-- ===== rank / xp =====
function Rules.xpForRank(rank: number): number
	if rank <= 1 then
		return 0
	end
	return math.floor(Config.Rank.BASE * (rank - 1) ^ Config.Rank.POWER)
end

-- returns rank, xp gained inside the rank, xp needed for the next rank (0 at max rank)
function Rules.rankInfo(xp: number): (number, number, number)
	local rank = 1
	while rank < Config.Rank.MAX and xp >= Rules.xpForRank(rank + 1) do
		rank += 1
	end
	if rank >= Config.Rank.MAX then
		return rank, xp - Rules.xpForRank(rank), 0
	end
	local base = Rules.xpForRank(rank)
	return rank, xp - base, Rules.xpForRank(rank + 1) - base
end

function Rules.rankOf(profile): number
	return (Rules.rankInfo(profile.xp))
end

function Rules.echoSlots(rank: number): number
	local slots = 1
	for _, e in Config.Rank.EchoSlots do
		if rank >= e.rank then
			slots = e.slots
		end
	end
	return slots
end

function Rules.titleForRank(rank: number): string
	local t = Config.Rank.Titles[1].title
	for _, e in Config.Rank.Titles do
		if rank >= e.rank then
			t = e.title
		end
	end
	return t
end

-- ===== stats =====
-- Final player stats = equipment base value, scaled ONCE by (1 + capped sum of echo + research bonuses).
function Rules.computeStats(profile)
	local sums: { [string]: number } = {}
	local function addBonuses(list)
		for _, b in list do
			sums[b[1]] = (sums[b[1]] or 0) + b[2]
		end
	end
	for _, id in profile.equipped do
		local e = Profile.echoById[id]
		if e and profile.echoes[id] then
			addBonuses(e.bonuses)
		end
	end
	for id in profile.research do
		local n = Profile.researchById[id]
		if n then
			addBonuses(n.bonuses)
		end
	end
	local function b(stat: string): number
		local v = sums[stat] or 0
		local cap = CAPS[stat]
		if cap then
			v = math.min(v, cap)
		end
		return v
	end
	local ab = Config.Absorber[profile.tiers.absorber]
	local bp = Config.Backpack[profile.tiers.backpack]
	local bt = Config.Boots[profile.tiers.boots]
	local lens = { plant = 0, crystal = 0, energy = 0, structure = 0 }
	local siphon, overcharge = nil, nil
	for id in profile.gadgets do
		local g = Profile.gadgetById[id]
		if g then
			if g.power then
				for cat, v in g.power do
					lens[cat] = (lens[cat] or 0) + v
				end
			end
			if g.radius then
				siphon = { radius = g.radius, strength = g.strength }
			end
			if g.boost then
				overcharge = { boost = g.boost, duration = g.duration, cooldown = g.cooldown }
			end
		end
	end
	local rank = Rules.rankOf(profile)
	return {
		absorberTier = profile.tiers.absorber,
		power = ab.power * (1 + b("powerBonus")),
		speed = ab.speed * (1 + b("speedBonus")),
		range = ab.range + b("rangeBonus"),
		capacity = math.floor(bp.capacity * (1 + b("capBonus"))),
		walk = bt.walk + b("walkBonus"),
		jump = bt.jump,
		sellMult = 1 + b("sellBonus"),
		xpMult = 1 + b("xpBonus"),
		overflowRate = math.min(1, Config.Economy.OVERFLOW_RATE + (sums.overflowRate or 0)),
		respawnMult = 1 - b("respawnBonus"),
		discoveryRadius = b("discoveryRadius"),
		secretMult = if (sums.secretMult or 0) > 0 then 2 else 1,
		frag = { plant = b("plantFrag"), crystal = b("crystalFrag"), structure = b("structureFrag") },
		lens = lens,
		siphon = siphon,
		overcharge = overcharge,
		echoSlots = Rules.echoSlots(rank),
		rank = rank,
	}
end

-- absorption per second against a target category (boost = temporary overcharge multiplier)
function Rules.dps(stats, category: string, boost: number?): number
	return stats.power * stats.speed * (1 + (stats.lens[category] or 0)) * (boost or 1)
end

-- ===== rewards =====
function Rules.rewardFor(stats, typeId: string)
	local t = Config.Targets[typeId]
	local fragBonus = 0
	if t.category == "plant" then
		fragBonus = stats.frag.plant
	elseif t.category == "crystal" then
		fragBonus = stats.frag.crystal
	elseif t.category == "structure" then
		fragBonus = stats.frag.structure
	end
	local frags = if t.frag > 0 then math.max(1, math.floor(t.frag * (1 + fragBonus) + 0.5)) else 0
	local xp = math.max(1, math.floor(t.xp * stats.xpMult + 0.5))
	return frags, xp
end

-- Adds fragments to the backpack; anything that does not fit is auto-sold at the overflow rate.
-- returns stored, overflowCredits
function Rules.addFragments(profile, stats, amount: number): (number, number)
	amount = math.floor(amount)
	if amount <= 0 then
		return 0, 0
	end
	local space = math.max(0, stats.capacity - profile.fragments)
	local stored = math.min(space, amount)
	local overflow = amount - stored
	profile.fragments += stored
	profile.stats.fragmentsCollected += amount
	local credits = math.floor(overflow * Config.Economy.SELL_RATE * stats.sellMult * stats.overflowRate)
	if credits > 0 then
		profile.credits += credits
		profile.stats.lifetimeCredits += credits
	end
	return stored, credits
end

-- Converts the whole backpack to credits. returns credits earned, fragments sold
function Rules.sellAll(profile, stats): (number, number)
	local n = profile.fragments
	if n <= 0 then
		return 0, 0
	end
	local credits = math.floor(n * Config.Economy.SELL_RATE * stats.sellMult)
	profile.fragments = 0
	profile.credits += credits
	profile.stats.lifetimeCredits += credits
	profile.stats.salesMade += 1
	return credits, n
end

-- ===== area restoration =====
local totalWeight = 0
for _, t in WorldData.Targets do
	totalWeight += Config.Targets[t.type].weight or 0
end
Rules.totalWeight = totalWeight

function Rules.restoredWeight(profile): number
	local w = 0
	for _, t in WorldData.Targets do
		if profile.restored[t.id] then
			w += Config.Targets[t.type].weight or 0
		end
	end
	return w
end

-- 0..100 (one decimal)
function Rules.percent(profile): number
	return math.floor(Rules.restoredWeight(profile) / totalWeight * 1000 + 1e-6) / 10
end

function Rules.echoCount(profile): number
	local n = 0
	for _ in profile.echoes do
		n += 1
	end
	return n
end

function Rules.getStat(profile, key: string): number
	if key == "percent" then
		return Rules.percent(profile)
	end
	return profile.stats[key] or 0
end

-- ===== equipment =====
local function tierList(category: string)
	if category == "absorber" then
		return Config.Absorber
	elseif category == "backpack" then
		return Config.Backpack
	elseif category == "boots" then
		return Config.Boots
	end
	return nil
end

-- Validates and describes a purchase. returns ok, reasonCode, price
function Rules.canBuy(profile, category: any, id: any): (boolean, string, number)
	if type(category) ~= "string" or type(id) ~= "string" then
		return false, "invalid", 0
	end
	if category == "gadget" then
		local g = Profile.gadgetById[id]
		if not g then
			return false, "invalid", 0
		end
		if profile.gadgets[id] then
			return false, "owned", g.price
		end
		if profile.tiers.absorber < g.minAbsorber then
			return false, "needs_absorber", g.price
		end
		if profile.credits < g.price then
			return false, "funds", g.price
		end
		return true, "ok", g.price
	end
	local list = tierList(category)
	if not list then
		return false, "invalid", 0
	end
	local idx
	for i, item in list do
		if item.id == id then
			idx = i
		end
	end
	if not idx then
		return false, "invalid", 0
	end
	local owned = profile.tiers[category]
	if idx <= owned then
		return false, "owned", list[idx].price
	end
	if idx ~= owned + 1 then
		return false, "order", list[idx].price
	end
	if profile.credits < list[idx].price then
		return false, "funds", list[idx].price
	end
	return true, "ok", list[idx].price
end

-- Applies a purchase (call canBuy first - this re-validates so it can never double-charge).
function Rules.buy(profile, category: any, id: any): (boolean, string)
	local ok, reason, price = Rules.canBuy(profile, category, id)
	if not ok then
		return false, reason
	end
	profile.credits -= price
	if category == "gadget" then
		profile.gadgets[id] = true
	else
		profile.tiers[category] += 1
	end
	profile.stats.upgradesBought += 1
	return true, "ok"
end

-- ===== echoes =====
function Rules.unlockEcho(profile, id: string): boolean
	if profile.echoes[id] or not Profile.echoById[id] then
		return false
	end
	profile.echoes[id] = true
	local slots = Rules.echoSlots(Rules.rankOf(profile))
	if #profile.equipped < slots then
		table.insert(profile.equipped, id) -- first echoes equip themselves
	end
	return true
end

function Rules.equipEcho(profile, id: any): (boolean, string)
	if type(id) ~= "string" or not Profile.echoById[id] then
		return false, "invalid"
	end
	if not profile.echoes[id] then
		return false, "locked"
	end
	if table.find(profile.equipped, id) then
		return false, "already"
	end
	if #profile.equipped >= Rules.echoSlots(Rules.rankOf(profile)) then
		return false, "full"
	end
	table.insert(profile.equipped, id)
	return true, "ok"
end

function Rules.unequipEcho(profile, id: any): (boolean, string)
	if type(id) ~= "string" then
		return false, "invalid"
	end
	local i = table.find(profile.equipped, id)
	if not i then
		return false, "not_equipped"
	end
	table.remove(profile.equipped, i)
	return true, "ok"
end

-- ===== research =====
function Rules.canResearch(profile, nodeId: any): (boolean, string)
	if type(nodeId) ~= "string" then
		return false, "invalid"
	end
	local node = Profile.researchById[nodeId]
	if not node then
		return false, "invalid"
	end
	if profile.research[nodeId] then
		return false, "owned"
	end
	-- previous node of the same branch must be owned
	local prev
	for _, n in Config.Research.nodes do
		if n.id == nodeId then
			break
		end
		if n.branch == node.branch then
			prev = n
		end
	end
	if prev and not profile.research[prev.id] then
		return false, "order"
	end
	if profile.rp < node.cost then
		return false, "funds"
	end
	return true, "ok"
end

function Rules.buyResearch(profile, nodeId: any): (boolean, string)
	local ok, reason = Rules.canResearch(profile, nodeId)
	if not ok then
		return false, reason
	end
	local node = Profile.researchById[nodeId]
	profile.rp -= node.cost
	profile.research[nodeId] = true
	return true, "ok"
end

-- ===== progression events =====
-- Every mutating function appends to `events` so the server can show exactly one toast per thing that happened.
type Events = { { [string]: any } }

function Rules.addXp(profile, amount: number, events: Events?)
	if amount <= 0 then
		return
	end
	local before = Rules.rankOf(profile)
	profile.xp += math.floor(amount)
	local after = Rules.rankOf(profile)
	for r = before + 1, after do
		profile.credits += Config.Rank.CREDITS_PER_RANK * r
		profile.stats.lifetimeCredits += Config.Rank.CREDITS_PER_RANK * r
		profile.rp += Config.Rank.RP_PER_RANK
		local title = Rules.titleForRank(r)
		if not profile.titles[title] then
			profile.titles[title] = true
			profile.title = title
		end
		if events then
			table.insert(events, { kind = "rank", rank = r, credits = Config.Rank.CREDITS_PER_RANK * r, rp = Config.Rank.RP_PER_RANK, title = title })
		end
	end
end

local function grant(profile, reward, events: Events?)
	if reward.credits then
		profile.credits += reward.credits
		profile.stats.lifetimeCredits += reward.credits
	end
	if reward.rp then
		profile.rp += reward.rp
	end
	if reward.title then
		profile.titles[reward.title] = true
		profile.title = reward.title
	end
	if reward.xp then
		Rules.addXp(profile, reward.xp, events)
	end
end
Rules.grantReward = grant

function Rules.milestoneProgress(profile, m): number
	if m.kind == "percent" then
		return Rules.percent(profile)
	elseif m.kind == "echoes" then
		return Rules.echoCount(profile)
	elseif m.kind == "secrets" then
		return profile.stats.secretsFound
	end
	return 0
end

function Rules.areaUnlockMet(profile, areaId: string): boolean
	local a = Config.Areas[areaId]
	if not a or not a.requires then
		return true
	end
	if a.requires.milestone and not profile.milestones[a.requires.milestone] then
		return false
	end
	if a.requires.absorberTier and profile.tiers.absorber < a.requires.absorberTier then
		return false
	end
	return true
end

local function echoUnlockMet(profile, e): boolean
	local u = e.unlock
	if u.kind == "quest" then
		return profile.quests[u.id] == true
	elseif u.kind == "milestone" then
		return profile.milestones[u.id] == true
	elseif u.kind == "rank" then
		return Rules.rankOf(profile) >= u.rank
	elseif u.kind == "secrets" then
		return profile.stats.secretsFound >= u.count
	end
	return false -- capsule echoes are unlocked by restoring their capsule
end

-- Runs every derived-progress check until nothing changes. Idempotent: calling it twice grants nothing twice.
function Rules.process(profile, eventsIn: Events?): Events
	local events: Events = eventsIn or {}
	local changed = true
	local guard = 0
	while changed and guard < 50 do
		changed = false
		guard += 1
		-- tutorial chain: strictly sequential
		for _, q in Config.Quests do
			if not profile.quests[q.id] then
				if Rules.getStat(profile, q.stat) >= q.goal then
					profile.quests[q.id] = true
					grant(profile, q.reward, events)
					table.insert(events, { kind = "quest", id = q.id, title = q.title, reward = q.reward })
					changed = true
				else
					break
				end
			end
		end
		for _, m in Config.Milestones do
			if not profile.milestones[m.id] and Rules.milestoneProgress(profile, m) >= m.value then
				profile.milestones[m.id] = true
				grant(profile, m.reward, events)
				table.insert(events, { kind = "milestone", id = m.id, name = m.name, reward = m.reward })
				changed = true
			end
		end
		for _, e in Config.Echoes do
			if not profile.echoes[e.id] and echoUnlockMet(profile, e) then
				Rules.unlockEcho(profile, e.id)
				table.insert(events, { kind = "echo", id = e.id })
				changed = true
			end
		end
		for areaId, a in Config.Areas do
			if a.requires and not profile.unlocked[areaId] and Rules.areaUnlockMet(profile, areaId) then
				profile.unlocked[areaId] = true
				table.insert(events, { kind = "unlock", id = areaId })
				changed = true
			end
		end
	end
	return events
end

-- Restoring a permanent target. Returns nil if it was already restored (duplicate / race protection), else a
-- result table. The check and the write happen with no yield in between.
function Rules.restoreTarget(profile, stats, targetId: string, events: Events?)
	local placement = WorldData.ById[targetId]
	if not placement then
		return nil
	end
	local t = Config.Targets[placement.type]
	if t.permanent then
		if profile.restored[targetId] then
			return nil
		end
		profile.restored[targetId] = true
		profile.stats.targetsRestored += 1
	end
	local frags, xp = Rules.rewardFor(stats, placement.type)
	local stored, overflowCredits = Rules.addFragments(profile, stats, frags)
	Rules.addXp(profile, xp, events)
	local echoId = nil
	if placement.echo and Rules.unlockEcho(profile, placement.echo) then
		profile.stats.echoesFreed += 1
		echoId = placement.echo
		if events then
			table.insert(events, { kind = "echo", id = placement.echo })
		end
	end
	return { fragments = frags, stored = stored, overflowCredits = overflowCredits, xp = xp, echo = echoId }
end

-- Hidden shard pickup. nil when already found.
function Rules.collectSecret(profile, stats, secretId: string, events: Events?)
	if profile.secrets[secretId] then
		return nil
	end
	local found = false
	for _, s in WorldData.Secrets do
		if s.id == secretId then
			found = true
		end
	end
	if not found then
		return nil
	end
	profile.secrets[secretId] = true
	profile.stats.secretsFound += 1
	local r = Config.Secrets.shardReward
	local credits = r.credits * stats.secretMult
	profile.credits += credits
	profile.stats.lifetimeCredits += credits
	Rules.addXp(profile, math.floor(r.xp * stats.xpMult * stats.secretMult), events)
	return { credits = credits, xp = math.floor(r.xp * stats.xpMult * stats.secretMult) }
end

-- ===== objective hints =====
-- Always returns something to do next: the tutorial chain first, then context-aware suggestions.
function Rules.nextObjective(profile, stats)
	for _, q in Config.Quests do
		if not profile.quests[q.id] then
			local cur = math.min(Rules.getStat(profile, q.stat), q.goal)
			return { kind = "quest", id = q.id, title = q.title, text = q.text, progress = cur, goal = q.goal, beacon = q.beacon }
		end
	end
	if profile.rp > 0 then
		return { kind = "research", title = "Spend Research Points", text = ("You have %d research point(s) to spend."):format(profile.rp), beacon = "station:research" }
	end
	if profile.fragments >= stats.capacity * 0.8 then
		return { kind = "sell", title = "Backpack almost full", text = "Convert your fragments into Credits at the Restoration Station.", beacon = "station:sell" }
	end
	local nextAb = Config.Absorber[profile.tiers.absorber + 1]
	if nextAb and profile.credits >= nextAb.price then
		return { kind = "buy", title = "Upgrade available", text = ("You can afford the %s."):format(nextAb.name), beacon = "station:upgrade" }
	end
	for _, m in Config.Milestones do
		if not profile.milestones[m.id] and m.kind == "percent" then
			return { kind = "milestone", title = m.name, text = ("Restore the valley to %d%% (now %.0f%%)."):format(m.value, Rules.percent(profile)), progress = Rules.percent(profile), goal = m.value, beacon = "nearest:restorable" }
		end
	end
	if Rules.echoCount(profile) < #Config.Echoes then
		return { kind = "echo", title = "Complete the Echo Index", text = ("%d of %d Echoes discovered. Open the Echo Index for hints."):format(Rules.echoCount(profile), #Config.Echoes), beacon = "nearest:capsule" }
	end
	return { kind = "done", title = "Valley restored", text = "The Green Valley is whole again. Frostlight Peaks awaits beyond the gateway.", beacon = "gateway" }
end

return Rules
