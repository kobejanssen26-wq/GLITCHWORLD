-- Economy simulation: a greedy "reasonable player" bot plays the real Rules + real world layout (positions, walk
-- speed, respawns, backpack trips, station visits) and the test reports/validates progression pacing.
local Config = require("./shared/Config")
local WorldData = require("./shared/WorldData")
local Rules = require("./shared/Rules")
local Profile = require("./shared/Profile")

local fails = 0
local function check(cond, msg) if not cond then fails += 1; print("FAIL: " .. msg) end end

local TRACE = false
local PATH_FACTOR = 1.3 -- real paths are not straight lines
local AIM_OVERHEAD = 1.0

local function simulate(maxHours: number)
	local p = Profile.default()
	local t, x, z = 0, WorldData.SPAWN.x, WorldData.SPAWN.z
	local readyAt = {} -- renewable cooldowns
	local marks = {}
	local function mark(name) if not marks[name] then marks[name] = t; if TRACE and t < 400 then print(("   [%.0fs] mark %s"):format(t, name)) end end end
	local credited = 0
	local sellS, upS = WorldData.Stations.sell, WorldData.Stations.upgrade
	local function walkTo(tx, tz, speed)
		t += math.sqrt((tx - x) ^ 2 + (tz - z) ^ 2) * PATH_FACTOR / speed
		x, z = tx, tz
	end
	local function process()
		local ev = Rules.process(p)
		for _, e in ev do
			if e.kind == "milestone" then mark(e.id) end
			if e.kind == "quest" then mark(e.id) end
		end
	end
	local function visitStations()
		local s = Rules.computeStats(p)
		walkTo(sellS.x, sellS.z, s.walk)
		if p.fragments > 0 then
			Rules.sellAll(p, s)
			mark("first_sale")
		end
		walkTo(upS.x, upS.z, s.walk)
		-- buy everything affordable, cheapest first (typical player behaviour)
		local bought = true
		while bought do
			bought = false
			local best
			local function consider(cat, id)
				local ok, _, price = Rules.canBuy(p, cat, id)
				if ok and (not best or price < best.price) then best = { cat = cat, id = id, price = price } end
			end
			consider("absorber", Config.Absorber[p.tiers.absorber + 1] and Config.Absorber[p.tiers.absorber + 1].id)
			consider("backpack", Config.Backpack[p.tiers.backpack + 1] and Config.Backpack[p.tiers.backpack + 1].id)
			consider("boots", Config.Boots[p.tiers.boots + 1] and Config.Boots[p.tiers.boots + 1].id)
			for _, g in Config.Gadgets do consider("gadget", g.id) end
			if best then
				Rules.buy(p, best.cat, best.id)
				bought = true
				mark("first_upgrade")
				if best.cat == "absorber" then mark("absorber_" .. p.tiers.absorber) end
				if best.cat == "backpack" then mark("backpack_" .. p.tiers.backpack) end
				if best.cat == "boots" then mark("boots_" .. p.tiers.boots) end
			end
		end
		-- research: round-robin over branches so the build stays balanced
		local order = { "eff1", "cap1", "exp1", "dis1", "eff2", "cap2", "exp2", "dis2", "eff3", "cap3", "exp3", "dis3", "eff4", "cap4", "exp4", "dis4" }
		for _, id in order do Rules.buyResearch(p, id) end
		-- equip best echoes by simple preference
		process()
	end
	process()
	local limit = maxHours * 3600
	local stuckRounds = 0
	while t < limit do
		local s = Rules.computeStats(p)
		-- choose best source
		local bestScore, best, bestKind = 0, nil, nil
		for _, pl in WorldData.Targets do
			local d = Config.Targets[pl.type]
			local available = d.minTier <= p.tiers.absorber
			if d.permanent then available = available and not p.restored[pl.id] else available = available and (readyAt[pl.id] or 0) <= t end
			if available then
				local frags, xp = Rules.rewardFor(s, pl.type)
				local dist = math.sqrt((pl.x - x) ^ 2 + (pl.z - z) ^ 2) * PATH_FACTOR
				local dur = math.max(0, dist - s.range * 0.6) / s.walk + AIM_OVERHEAD + d.hp / Rules.dps(s, d.category)
				local value = frags * s.sellMult + xp * 0.8 + (pl.echo and 150 or 0)
				-- players value permanent restoration (milestones, visible change): bonus per weight point
				if d.permanent then value += (d.weight or 0) * 400 end
				-- a full backpack wastes half the value
				if p.fragments + frags > s.capacity then value *= 0.8 end
				local score = value / dur
				if score > bestScore then bestScore, best, bestKind = score, pl, "target" end
			end
		end
		for _, sh in WorldData.Secrets do
			if not p.secrets[sh.id] and t >= 120 + 150 * p.stats.secretsFound then -- exploring takes time
				local dist = math.sqrt((sh.x - x) ^ 2 + (sh.z - z) ^ 2) * PATH_FACTOR
				local score = (190 * s.secretMult) / (dist / s.walk + 2)
				if score > bestScore then bestScore, best, bestKind = score, sh, "secret" end
			end
		end
		local full = p.fragments >= s.capacity * 0.9
		if best == nil or full then
			if best == nil and p.fragments == 0 and not full then
				-- nothing available: wait for a respawn (player would idle / explore)
				t += 5
				stuckRounds += 1
				if stuckRounds > 5000 then break end
			else
				visitStations()
			end
		else
			stuckRounds = 0
			if TRACE and t < 300 then print(("t=%.0f frag=%d cr=%d -> %s"):format(t, p.fragments, p.credits, best.id)) end
			if bestKind == "secret" then
				walkTo(best.x, best.z, s.walk); t += 2
				Rules.collectSecret(p, s, best.id)
			else
				local d = Config.Targets[best.type]
				local dist = math.sqrt((best.x - x) ^ 2 + (best.z - z) ^ 2) * PATH_FACTOR
				local walk = math.max(0, dist - s.range * 0.6)
				t += walk / s.walk + AIM_OVERHEAD + d.hp / Rules.dps(s, d.category)
				x, z = best.x, best.z
				Rules.restoreTarget(p, s, best.id)
				if d.renew then readyAt[best.id] = t + d.renew * s.respawnMult end
			end
			-- visit the station when a purchase is possible and worth the trip
			local nextAb = Config.Absorber[p.tiers.absorber + 1]
			if (nextAb and p.credits + p.fragments * s.sellMult >= nextAb.price) or p.fragments > 0 and p.credits < 60 and p.stats.salesMade == 0 and p.fragments >= 12 then
				visitStations()
			end
			process()
			if Rules.percent(p) >= 100 and p.tiers.absorber == #Config.Absorber then mark("done") break end
		end
	end
	mark("end")
	return p, marks, t
end

local p, marks, t = simulate(8)
local function fmt(s: number): string return ("%dm%02ds"):format(s // 60, s % 60) end
local names = { "q1", "q2", "first_sale", "q3", "first_upgrade", "q4", "q5", "q6", "m10", "m25", "q7", "absorber_2", "absorber_3", "m40", "m60", "m75", "absorber_4", "absorber_5", "backpack_5", "boots_5", "m100", "done", "end" }
print("-- progression timeline (greedy bot, simulated play time) --")
for _, n in names do if marks[n] then print(("  %-14s %s"):format(n, fmt(marks[n]))) end end
print(("final: rank %d  percent %.1f  credits %d  lifetime %d  echoes %d/12  secrets %d/6  tiers a%d b%d s%d  gadgets %d  rp unspent %d"):format(
	Rules.rankOf(p), Rules.percent(p), p.credits, p.stats.lifetimeCredits, Rules.echoCount(p), p.stats.secretsFound, p.tiers.absorber, p.tiers.backpack, p.tiers.boots, (function() local n = 0 for _ in p.gadgets do n += 1 end return n end)(), p.rp))

-- ===== pacing assertions =====
check(marks.first_sale and marks.first_sale <= 150, "first sale should happen within 2.5 min")
check(marks.first_upgrade and marks.first_upgrade <= 360, "first upgrade should happen within 6 min")
check(marks.q1 and marks.q1 <= 60, "first fragments within 1 min")
check(marks.absorber_2 and marks.absorber_2 <= 1200, "absorber tier 2 within 20 min")
check(marks.m25 and marks.m25 <= 2400, "25% within 40 min")
check(marks.m75 and marks.m75 <= 4 * 3600, "gateway milestone (75%) is reachable within 4h")
check(marks.done, "full completion reachable within 8h of simulated play (no soft-lock)")
if marks.done then
	check(marks.done >= 1.5 * 3600, ("completion in %s is too fast: the grind must be meaningful"):format(fmt(marks.done)))
	check(marks.done <= 6 * 3600, ("completion in %s is too slow / tedious"):format(fmt(marks.done)))
end
-- inflation: spend should keep up with earnings (no huge unspendable pile before everything is bought)
check(p.credits <= p.stats.lifetimeCredits * 0.15, "credits pile up unspent at completion (inflation)")

print(fails == 0 and "economy_test: PASS" or ("economy_test: " .. fails .. " FAILURES"))
if fails > 0 then error("failed") end
