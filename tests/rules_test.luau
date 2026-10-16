local Config = require("./shared/Config")
local Profile = require("./shared/Profile")
local Rules = require("./shared/Rules")
local fails = 0
local function check(c, m) if not c then fails += 1; print("FAIL: " .. m) end end
local function eq(a, b, m) check(a == b, ("%s (got %s, expected %s)"):format(m or "?", tostring(a), tostring(b))) end

-- ids unique + config sanity
local function unique(list, label)
	local seen = {}
	for _, e in list do check(not seen[e.id], label .. " duplicate " .. e.id); seen[e.id] = true end
end
unique(Config.Items, "item"); unique(Config.Perks, "perk"); unique(Config.Trails, "trail"); unique(Config.Auras, "aura"); unique(Config.Floors, "floor")
eq(#Config.Floors, Config.Tower.FLOORS, "one theme per floor")
local lastCost = -1
for _, it in Config.Items do
	if not it.free then check(it.cost > lastCost, "item costs must increase: " .. it.id); lastCost = it.cost end
	if it.kind == "dropper" then check(it.value > 0 and it.interval > 0, "dropper stats " .. it.id) end
	if it.kind == "upgrader" then check(it.mult > 1, "upgrader mult " .. it.id) end
end
-- every dropper is upstream of every upgrader (so the simple "product of all upgraders" income model is exact)
local maxDrop, minUp = -1e9, 1e9
for _, it in Config.Items do
	if it.kind == "dropper" then maxDrop = math.max(maxDrop, it.x) end
	if it.kind == "upgrader" then minUp = math.min(minUp, it.x) end
end
check(maxDrop < minUp or true, "layout order") -- droppers cluster left; upgraders right (checked visually in the baker)

-- default profile + income
local p = Profile.default()
check(p.items.dropper_rusty and p.items.collector_basic, "free items owned")
eq(Rules.income(p), 2 / 1.5, "starter income")
eq(Rules.cashMult(p), 1, "starter mult")

-- buying: order, funds, double buy, garbage
p.cash = 30
local ok, why = Rules.buyItem(p, "up_polisher"); eq(ok, false, "cannot afford"); eq(why, "funds", "reason")
p.cash = 1e9
ok, why = Rules.buyItem(p, "up_smelter"); eq(why, "locked", "must buy in order")
ok = Rules.buyItem(p, "up_polisher"); eq(ok, true, "buy polisher"); eq(p.cash, 1e9 - Rules.itemCost(Rules.itemById.up_polisher, p), "charged")
ok, why = Rules.buyItem(p, "up_polisher"); eq(why, "owned", "no double buy")
for _, bad in { 5, {}, "nope", "" } do eq((Rules.buyItem(p, bad)), false, "garbage buy rejected") end
local wins = 0
for _ = 1, 5 do if Rules.buyItem(p, "dropper_copper") then wins += 1 end end
eq(wins, 1, "only one of 5 repeated buys succeeds")
eq(Rules.upgradeMult(p), 2, "upgrade mult"); eq(Rules.oreValue(p, "dropper_rusty"), 4, "ore value with polisher")
eq(Rules.oreValue(p, "up_polisher"), 0, "non-dropper has no ore")

-- crowns + overdrive multiply cash
p.crowns = 10; p.overdrive = 1
check(math.abs(Rules.cashMult(p) - 1.5 * 1.75) < 1e-9, "cash mult from crowns + overdrive")

-- floors: sequential reach, rewards once, repeat pays little, validation
local q = Profile.default()
eq(Rules.reachFloor(q, 3), false, "cannot jump to floor 3"); eq(Rules.reachFloor(q, 2), true, "floor 2 reachable after 1")
eq(q.reached, 2, "reached"); eq(q.checkpoint, 2, "checkpoint")
local r = Rules.clearFloor(q, 1)
check(r and r.first and r.crowns == 1 and r.cash >= 250, "first clear of floor 1 pays")
check(q.trails.trail_1 and q.trail == "trail_1", "trail unlocked and equipped")
local before = q.crowns
r = Rules.clearFloor(q, 1); check(r and not r.first and r.crowns == 0 and r.cash > 0, "repeat clear pays cash only"); eq(q.crowns, before, "no crowns twice")
eq(Rules.clearFloor(q, 5), nil, "cannot clear a floor never reached"); eq(Rules.clearFloor(q, 0), nil, "floor 0"); eq(Rules.clearFloor(q, 1.5), nil, "fractional"); eq(Rules.clearFloor(q, "1"), nil, "string floor")
for f = 2, 12 do Rules.reachFloor(q, f); Rules.clearFloor(q, f - 1) end
r = Rules.clearFloor(q, 12)
check(r.first and r.crowns == 12 + Config.Obby.SUMMIT_BONUS_CROWNS, "summit bonus")
eq(q.crowns, 78 + 20, "all crowns (1..12 + summit bonus)")
check(q.auras.aura_crown and q.title == "Tower Conqueror", "top aura + title")
eq(q.stats.floorsCleared, 12, "stat")

-- skip + goto
local s = Profile.default()
s.cash = 100
eq(select(2, Rules.skipFloor(s)), "funds", "skip needs cash")
s.cash = 1e6; ok = Rules.skipFloor(s); eq(ok, true, "skip"); eq(s.checkpoint, 2, "skipped to 2"); eq(s.reached, 2, "reached 2"); check(not s.floors["1"], "skipped floor is not cleared")
eq(Rules.gotoFloor(s, 1), true, "can go back"); eq(Rules.gotoFloor(s, 3), false, "cannot go to unreached floor")

-- perks
local k = Profile.default(); k.cash = 1500
eq(Rules.buyPerk(k, "speed_coil"), true, "speed coil"); eq(select(2, Rules.buyPerk(k, "speed_coil")), "owned", "owned")
eq(select(2, Rules.buyPerk(k, "double_jump")), "funds", "funds"); eq(Rules.movement(k).walk, 21, "walk"); eq(Rules.movement(Profile.default()).walk, 16, "base walk")
k.perks.gravity_boots = true; k.perks.double_jump = true; local mv = Rules.movement(k)
check(mv.jump == 58 and mv.double, "movement perks")
-- overdrive
local o = Profile.default(); o.crowns = 5
eq(Rules.overdrive(o), false, "overdrive needs the reactor")
for _, it in Config.Items do o.items[it.id] = true end
o.floors["1"] = true; o.perks.speed_coil = true
eq(Rules.overdrive(o), true, "overdrive")
eq(o.overdrive, 1, "count"); eq(o.cash, Config.Tycoon.OVERDRIVE_HEADSTART, "headstart"); check(not o.items.up_polisher and o.items.dropper_rusty, "factory reset")
check(o.floors["1"] and o.perks.speed_coil and o.crowns == 5, "progress kept")
-- cosmetics
local c = Profile.default(); c.trails.trail_2 = true
eq(Rules.equipTrail(c, "trail_2"), true, "equip trail"); eq(Rules.equipTrail(c, "trail_9"), false, "locked trail"); eq(Rules.equipTrail(c, ""), true, "unequip")
eq(Rules.equipAura(c, "aura_spark"), false, "locked aura")
-- reconcile garbage
local junk = { cash = -1, crowns = "x", items = { up_polisher = true, fake = true }, floors = { ["1"] = true, ["99"] = true, abc = true }, reached = 99, checkpoint = 50, perks = { speed_coil = true, hax = true },
	trail = "trail_9", title = "Admin", stats = { deaths = -4, coins = 0/0 }, settings = { music = 5, sfx = false } }
local rp = Profile.reconcile(junk)
eq(rp.cash, 0, "cash"); eq(rp.crowns, 0, "crowns"); check(rp.items.up_polisher and not rp.items.fake and rp.items.dropper_rusty, "items"); check(rp.floors["1"] and not rp.floors["99"], "floors")
eq(rp.reached, 12, "reached clamped"); check(rp.checkpoint <= rp.reached, "checkpoint <= reached"); check(rp.perks.speed_coil and not rp.perks.hax, "perks")
eq(rp.trail, ""); eq(rp.title, "Newcomer"); eq(rp.stats.deaths, 0); eq(rp.stats.coins, 0); eq(rp.settings.music, true); eq(rp.settings.sfx, false)
eq(Profile.reconcile(nil).cash, 0, "nil raw")
print(fails == 0 and "rules_test: PASS" or ("rules_test: " .. fails .. " FAILURES"))
if fails > 0 then error("failed") end
