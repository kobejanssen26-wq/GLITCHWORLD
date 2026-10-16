-- Economy simulation: a bot plays the real rules second by second (factory income, buying in order, climbing the
-- tower floor by floor, perks, Overdrive) and the test validates pacing and the absence of dead ends.
local Config = require("./shared/Config")
local Profile = require("./shared/Profile")
local Rules = require("./shared/Rules")
local fails = 0
local function check(c, m) if not c then fails += 1; print("FAIL: " .. m) end end

local function floorSeconds(f) return 100 + 28 * f end -- time a typical player needs for a floor (deaths included)
local function fmt(s) return ("%dh%02dm%02ds"):format(s // 3600, (s % 3600) // 60, s % 60) end

local p = Profile.default()
local t = 0
local floorTimer, floorOn = 0, 1
local events = {}
local lastBuy = 0
local maxGap = 0
local cycleStart = 0
local cycles = {}
local firstBuy
p.reached = 1
local log = {}
while t < 6 * 3600 and #cycles < 3 do
	t += 1
	Rules.addCash(p, Rules.income(p)) -- 1 second of factory income
	-- climb: finishing a floor takes floorSeconds; the next floor checkpoint is reached right away
	floorTimer += 1
	if floorOn <= Config.Tower.FLOORS and floorTimer >= floorSeconds(floorOn) then
		floorTimer = 0
		Rules.reachFloor(p, floorOn + 1 <= 12 and floorOn + 1 or 12)
		local r = Rules.clearFloor(p, floorOn)
		check(r ~= nil, "clear floor " .. floorOn)
		log[#log + 1] = ("%s floor %d cleared (crowns %d)"):format(fmt(t), floorOn, p.crowns)
		floorOn += 1
	end
	-- greedy factory purchases (in the fixed order)
	local nxt = Rules.nextItem(p)
	if nxt and Rules.canBuyItem(p, nxt.id) then
		Rules.buyItem(p, nxt.id)
		firstBuy = firstBuy or t
		maxGap = math.max(maxGap, t - lastBuy)
		lastBuy = t
		if nxt.kind == "overdrive" then
			table.insert(cycles, t - cycleStart)
			Rules.overdrive(p)
			cycleStart = t
			lastBuy = t
		end
	end
	-- perks when comfortably affordable
	for _, perk in Config.Perks do
		if not p.perks[perk.id] and p.cash > perk.cost * 6 then Rules.buyPerk(p, perk.id) end
	end
end
print("-- simulated run --")
print(("first purchase: %ds, longest wait between purchases (first cycle): %s"):format(firstBuy or -1, fmt(maxGap)))
for i, c in cycles do print(("cycle %d (factory complete -> Overdrive): %s"):format(i, fmt(c))) end
for i = 1, math.min(#log, 12) do print("  " .. log[i]) end
print(("final: overdrive %d, crowns %d, perks %d, income %.0f/s"):format(p.overdrive, p.crowns, (function() local n = 0 for _ in p.perks do n += 1 end return n end)(), Rules.income(p)))

check(firstBuy and firstBuy <= 60, "first purchase must come within a minute")
check(#cycles >= 2, "at least two Overdrive cycles within 6 hours (no dead end)")
if #cycles >= 2 then
	check(cycles[1] >= 40 * 60 and cycles[1] <= 150 * 60, "first cycle should take 40-150 min, got " .. fmt(cycles[1]))
	check(cycles[2] < cycles[1] * 0.85, "second cycle must be clearly faster (Overdrive matters)")
	check(cycles[2] > 10 * 60, "second cycle must not be trivial")
end
print(fails == 0 and "economy_test: PASS" or ("economy_test: " .. fails .. " FAILURES"))
if fails > 0 then error("failed") end
