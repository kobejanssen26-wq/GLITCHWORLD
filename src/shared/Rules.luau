-- All game rules as pure functions over a profile table (no Roblox instances, no yielding).
-- The server calls these so every mutation is atomic; the tests drive them directly.
local Config = require(script.Parent.Config)
local Profile = require(script.Parent.Profile)

local Rules = {}

local T = Config.Tycoon

local itemById: { [string]: any } = {}
local itemIndex: { [string]: number } = {}
for i, it in Config.Items do
	itemById[it.id] = it
	itemIndex[it.id] = i
end
Rules.itemById = itemById
local perkById: { [string]: any } = {}
for _, p in Config.Perks do
	perkById[p.id] = p
end
Rules.perkById = perkById

-- ===== multipliers / income =====
function Rules.cashMult(profile): number
	return (1 + T.CROWN_BONUS * profile.crowns) * (1 + T.OVERDRIVE_BONUS * profile.overdrive)
end

local paidOrdinal: { [string]: number } = {}
do
	local n = 0
	for _, it in Config.Items do
		if not it.free then
			n += 1
			paidOrdinal[it.id] = n
		end
	end
end

-- listed cost, ramped up the list, and inflated per Overdrive when a profile is given
function Rules.itemCost(item, profile: any?): number
	local ramp = 1 + T.COST_RAMP * (paidOrdinal[item.id] or 0)
	local od = if profile then 1 + T.OVERDRIVE_COST_GROWTH * profile.overdrive else 1
	return math.floor(item.cost * ramp * od)
end

-- product of every owned upgrader multiplier (all upgraders sit downstream of all droppers by layout)
function Rules.upgradeMult(profile): number
	local m = 1
	for _, it in Config.Items do
		if it.kind == "upgrader" and profile.items[it.id] then
			m *= it.mult
		end
	end
	return m
end

function Rules.collectorBonus(profile): number
	local b = 1
	for _, it in Config.Items do
		if it.kind == "collector" and profile.items[it.id] then
			b = math.max(b, it.bonus)
		end
	end
	return b
end

-- cash value of one ore from `dropperId` when it reaches the collector
function Rules.oreValue(profile, dropperId: string): number
	local d = itemById[dropperId]
	if not d or d.kind ~= "dropper" then
		return 0
	end
	return d.value * Rules.upgradeMult(profile) * Rules.collectorBonus(profile) * Rules.cashMult(profile)
end

-- expected cash per second of the factory (used by objectives, rewards and the economy simulation)
function Rules.income(profile): number
	local total = 0
	local mult = Rules.upgradeMult(profile) * Rules.collectorBonus(profile) * Rules.cashMult(profile)
	for _, it in Config.Items do
		if profile.items[it.id] then
			if it.kind == "dropper" then
				total += it.value / it.interval * mult
			elseif it.kind == "generator" then
				total += it.rate * Rules.cashMult(profile) * Rules.collectorBonus(profile)
			end
		end
	end
	return total
end

-- ===== buying factory pieces =====
-- pieces unlock in the listed order: an item can be bought once the previous non-free item is owned
function Rules.previousItem(id: string): any?
	local idx = itemIndex[id]
	if not idx then
		return nil
	end
	for i = idx - 1, 1, -1 do
		if not Config.Items[i].free then
			return Config.Items[i]
		end
	end
	return nil
end

function Rules.canBuyItem(profile, id: any): (boolean, string, number)
	if type(id) ~= "string" then
		return false, "invalid", 0
	end
	local it = itemById[id]
	if not it then
		return false, "invalid", 0
	end
	local cost = Rules.itemCost(it, profile)
	if profile.items[id] then
		return false, "owned", cost
	end
	local prev = Rules.previousItem(id)
	if prev and not profile.items[prev.id] then
		return false, "locked", cost
	end
	if profile.cash < cost then
		return false, "funds", cost
	end
	return true, "ok", cost
end

function Rules.buyItem(profile, id: any): (boolean, string)
	local ok, reason, cost = Rules.canBuyItem(profile, id)
	if not ok then
		return false, reason
	end
	profile.cash -= cost
	profile.items[id] = true
	return true, "ok"
end

function Rules.nextItem(profile): any?
	for _, it in Config.Items do
		if not profile.items[it.id] then
			return it
		end
	end
	return nil
end

-- ===== cash in =====
function Rules.addCash(profile, amount: number)
	if amount <= 0 then
		return
	end
	profile.cash += amount
	profile.stats.cashEarned += math.floor(amount)
end

-- ===== overdrive (prestige) =====
function Rules.canOverdrive(profile): boolean
	return profile.items.overdrive_reactor == true
end

-- Resets the factory; keeps crowns, floors, perks and cosmetics. Returns false if not allowed.
function Rules.overdrive(profile): boolean
	if not Rules.canOverdrive(profile) then
		return false
	end
	local fresh = Profile.default()
	profile.items = fresh.items
	profile.overdrive += 1
	profile.cash = T.OVERDRIVE_HEADSTART * profile.overdrive
	return true
end

-- ===== obby =====
function Rules.floorReward(profile, floor: number): (number, number)
	local crowns = floor
	local cash = math.max(Config.Obby.FIRST_CLEAR_CASH_BASE * floor * floor, Rules.income(profile) * Config.Obby.INCOME_SECONDS * floor)
	return crowns, math.floor(cash)
end

function Rules.titleFor(crowns: number): string
	local t = Config.Titles[1].id
	for _, e in Config.Titles do
		if crowns >= e.crowns then
			t = e.id
		end
	end
	return t
end

-- Applies derived unlocks (trails, auras, titles). Returns a list of { kind, id } for notifications.
function Rules.unlocks(profile): { { kind: string, id: string } }
	local out = {}
	for _, tr in Config.Trails do
		if profile.floors[tostring(tr.floor)] and not profile.trails[tr.id] then
			profile.trails[tr.id] = true
			if profile.trail == "" then
				profile.trail = tr.id
			end
			table.insert(out, { kind = "trail", id = tr.id })
		end
	end
	for _, au in Config.Auras do
		if profile.crowns >= au.crowns and not profile.auras[au.id] then
			profile.auras[au.id] = true
			if profile.aura == "" then
				profile.aura = au.id
			end
			table.insert(out, { kind = "aura", id = au.id })
		end
	end
	local title = Rules.titleFor(profile.crowns)
	if title ~= profile.title and Profile.validTitles[title] then
		-- only move the title forward automatically
		local cur
		for i, e in Config.Titles do
			if e.id == profile.title then
				cur = i
			end
		end
		for i, e in Config.Titles do
			if e.id == title and (not cur or i > cur) then
				profile.title = title
				table.insert(out, { kind = "title", id = title })
			end
		end
	end
	return out
end

-- Record reaching floor `floor`'s checkpoint. Returns false when the floor is not yet reachable.
function Rules.reachFloor(profile, floor: any): boolean
	if type(floor) ~= "number" or floor ~= math.floor(floor) or floor < 1 or floor > Config.Tower.FLOORS then
		return false
	end
	if floor > profile.reached + 1 then
		return false
	end
	-- checkpoint floor+1 is never accepted before floor is cleared; reaching floor N+1 clears N (see clearFloor)
	profile.reached = math.max(profile.reached, floor)
	profile.checkpoint = floor
	return true
end

-- Clear `floor` (first time pays crowns + cash + trail, repeats pay a small cash amount). Returns result or nil.
function Rules.clearFloor(profile, floor: any)
	if type(floor) ~= "number" or floor ~= math.floor(floor) or floor < 1 or floor > Config.Tower.FLOORS then
		return nil
	end
	if floor > profile.reached then
		return nil
	end
	local key = tostring(floor)
	local crowns, cash = Rules.floorReward(profile, floor)
	local first = not profile.floors[key]
	if first then
		profile.floors[key] = true
		profile.stats.floorsCleared += 1
		if floor == Config.Tower.FLOORS then
			crowns += Config.Obby.SUMMIT_BONUS_CROWNS
		end
		profile.crowns += crowns
	else
		crowns = 0
		cash = math.floor(cash * Config.Obby.REPEAT_FRACTION)
	end
	Rules.addCash(profile, cash)
	return { first = first, crowns = crowns, cash = cash, unlocks = Rules.unlocks(profile) }
end

-- Move the respawn checkpoint to any floor already reached (replaying / returning). Free.
function Rules.gotoFloor(profile, floor: any): boolean
	if type(floor) ~= "number" or floor ~= math.floor(floor) or floor < 1 or floor > profile.reached then
		return false
	end
	profile.checkpoint = floor
	return true
end

function Rules.skipCost(floor: number): number
	return Config.Obby.SKIP_BASE * floor * floor
end

-- Pay to move your checkpoint to the next floor without earning rewards.
function Rules.skipFloor(profile): (boolean, string)
	local floor = profile.checkpoint
	if floor >= Config.Tower.FLOORS then
		return false, "top"
	end
	local cost = Rules.skipCost(floor)
	if profile.cash < cost then
		return false, "funds"
	end
	profile.cash -= cost
	profile.reached = math.max(profile.reached, floor + 1)
	profile.checkpoint = floor + 1
	profile.stats.skips += 1
	return true, "ok"
end

-- ===== perks / cosmetics / stats =====
function Rules.buyPerk(profile, id: any): (boolean, string)
	if type(id) ~= "string" or not perkById[id] then
		return false, "invalid"
	end
	if profile.perks[id] then
		return false, "owned"
	end
	local p = perkById[id]
	if profile.cash < p.cost then
		return false, "funds"
	end
	profile.cash -= p.cost
	profile.perks[id] = true
	return true, "ok"
end

function Rules.equipTrail(profile, id: any): boolean
	if id == "" then
		profile.trail = ""
		return true
	end
	if type(id) ~= "string" or not profile.trails[id] then
		return false
	end
	profile.trail = id
	return true
end

function Rules.equipAura(profile, id: any): boolean
	if id == "" then
		profile.aura = ""
		return true
	end
	if type(id) ~= "string" or not profile.auras[id] then
		return false
	end
	profile.aura = id
	return true
end

-- final movement stats from perks
function Rules.movement(profile)
	local walk, jump, double, magnet = 16, 50, false, 0
	for id in profile.perks do
		local p = perkById[id]
		if p then
			walk = math.max(walk, p.walk or 0)
			jump = math.max(jump, p.jump or 0)
			double = double or p.double == true
			magnet = math.max(magnet, p.magnet or 0)
		end
	end
	return { walk = walk, jump = jump, double = double, magnet = magnet }
end

-- ===== objective hint =====
function Rules.nextObjective(profile)
	local nxt = Rules.nextItem(profile)
	if Rules.canOverdrive(profile) then
		return { kind = "overdrive", text = "Your Overdrive Reactor is ready. Trigger Overdrive for a permanent income boost." }
	end
	local floor = profile.reached
	if not profile.floors[tostring(floor)] then
		if nxt and profile.cash >= Rules.itemCost(nxt, profile) and Rules.canBuyItem(profile, nxt.id) then
			return { kind = "buy", text = ("Buy %s in your factory (%s)."):format(nxt.name, tostring(Rules.itemCost(nxt, profile))) }
		end
		return { kind = "climb", text = ("Climb the tower: clear floor %d (%s)."):format(floor, Config.Floors[floor].name) }
	end
	if floor < Config.Tower.FLOORS then
		return { kind = "climb", text = ("Floor %d cleared! Take the next checkpoint to start floor %d."):format(floor, floor + 1) }
	end
	return { kind = "done", text = "You conquered the tower. Push your factory to Overdrive." }
end

return Rules
