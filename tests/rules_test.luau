local Config = require("./shared/Config")
local WorldData = require("./shared/WorldData")
local Rules = require("./shared/Rules")
local Profile = require("./shared/Profile")

local fails = 0
local function check(cond, msg)
	if not cond then fails += 1; print("FAIL: " .. msg) end
end
local function eq(a, b, msg) check(a == b, ("%s (got %s, expected %s)"):format(msg, tostring(a), tostring(b))) end

-- ===== ranks =====
eq(Rules.rankInfo(0), 1, "rank at 0xp")
eq(Rules.rankOf({ xp = Rules.xpForRank(5) }), 5, "rank at threshold")
eq(Rules.rankOf({ xp = Rules.xpForRank(5) - 1 }), 4, "rank below threshold")
eq(Rules.rankOf({ xp = 1e9 }), Config.Rank.MAX, "rank capped")
eq(Rules.echoSlots(1), 1, "slots r1"); eq(Rules.echoSlots(5), 2, "slots r5"); eq(Rules.echoSlots(12), 3, "slots r12")

-- ===== stats / stacking / caps =====
local p = Profile.default()
local s = Rules.computeStats(p)
eq(s.power, 2.0, "starter power"); eq(s.capacity, 40, "starter capacity"); eq(s.walk, 16, "starter walk"); eq(s.range, 14, "starter range")
p.tiers.absorber = 3
eq(Rules.computeStats(p).power, 4.5, "tier 3 power")
-- research + echo bonuses are additive inside a stat, applied once
p.research = { eff1 = true, eff3 = true } -- +10% +15%
check(math.abs(Rules.computeStats(p).power - 4.5 * 1.25) < 1e-9, "additive research power")
p.echoes.auroxel = true; p.equipped = { "auroxel" } -- +12%
check(math.abs(Rules.computeStats(p).power - 4.5 * 1.37) < 1e-9, "echo + research additive")
-- caps: stack absurd bonuses
local q = Profile.default()
for _, n in Config.Research.nodes do q.research[n.id] = true end
for _, e in Config.Echoes do q.echoes[e.id] = true end
q.equipped = { "auroxel", "lumifawn", "nullberry" }
q.tiers = { absorber = 5, backpack = 5, boots = 5 }
local qs = Rules.computeStats(q)
check(qs.power <= 11 * 2.0 + 1e-9, "power cap " .. qs.power)
check(qs.speed <= 2.2 * 1.6 + 1e-9, "speed cap")
check(qs.sellMult <= 1.5 + 1e-9, "sell cap " .. qs.sellMult)
check(qs.walk <= 24 + 6 + 1e-9, "walk cap")
check(qs.range <= 33 + 10 + 1e-9, "range cap")
check(qs.respawnMult >= 0.6 - 1e-9, "respawn cap")
check(qs.overflowRate <= 1, "overflow rate cap")
check(qs.secretMult == 2, "treasure eye doubles secrets")

-- lens
p = Profile.default(); p.tiers.absorber = 3
local base = Rules.dps(Rules.computeStats(p), "crystal")
p.gadgets.crystal_lens = true
check(math.abs(Rules.dps(Rules.computeStats(p), "crystal") - base * 1.6) < 1e-9, "crystal lens +60%")
check(Rules.dps(Rules.computeStats(p), "plant") == base, "crystal lens does not boost plants")
check(math.abs(Rules.dps(Rules.computeStats(p), "crystal", 1.8) - base * 1.6 * 1.8) < 1e-9, "overcharge multiplies")

-- ===== purchases =====
p = Profile.default()
local ok, why = Rules.buy(p, "absorber", "absorber_2"); eq(ok, false, "cannot buy broke"); eq(why, "funds", "reason funds")
p.credits = 250
ok = Rules.buy(p, "absorber", "absorber_2"); eq(ok, true, "buy tier 2"); eq(p.credits, 0, "credits deducted"); eq(p.tiers.absorber, 2, "tier set"); eq(p.stats.upgradesBought, 1, "count")
ok, why = Rules.buy(p, "absorber", "absorber_2"); eq(ok, false, "double buy rejected"); eq(why, "owned", "owned")
p.credits = 1e6
ok, why = Rules.buy(p, "absorber", "absorber_4"); eq(ok, false, "skip a tier rejected"); eq(why, "order", "order")
ok, why = Rules.buy(p, "gadget", "area_siphon"); eq(why, "needs_absorber", "gadget needs tier")
-- simultaneous attempts: only one succeeds, credits charged once
p = Profile.default(); p.credits = 250
local wins = 0
for _ = 1, 5 do if Rules.buy(p, "absorber", "absorber_2") then wins += 1 end end
eq(wins, 1, "only one of 5 simultaneous buys wins"); eq(p.credits, 0, "charged once")
-- invalid inputs never error
for _, bad in { { nil, nil }, { 5, "x" }, { "absorber", 12 }, { "hack", "absorber_2" }, { "absorber", "../../x" }, { {}, {} }, { "gadget", "nope" }, { "absorber", "" } } do
	local ok2 = Rules.buy(p, bad[1], bad[2]); eq(ok2, false, "invalid purchase rejected")
end
eq(select(3, Rules.canBuy(Profile.default(), "boots", "boots_2")), 200, "price reported")

-- ===== fragments / backpack / selling =====
p = Profile.default(); s = Rules.computeStats(p)
local stored, extra = Rules.addFragments(p, s, 30); eq(stored, 30, "stored"); eq(extra, 0, "no overflow")
stored, extra = Rules.addFragments(p, s, 30); eq(stored, 10, "fills backpack"); eq(extra, 10, "overflow 20*0.5"); eq(p.fragments, 40, "full")
eq(p.credits, 10, "overflow credits")
eq(p.stats.fragmentsCollected, 60, "collected counts all")
local credits, n = Rules.sellAll(p, s); eq(credits, 40, "sell value"); eq(n, 40, "sold count"); eq(p.fragments, 0, "backpack emptied"); eq(p.stats.salesMade, 1, "sale counted")
credits = Rules.sellAll(p, s); eq(credits, 0, "empty sell gives nothing")
eq(p.stats.salesMade, 1, "empty sale does not count")

-- ===== restoring targets: no duplicate rewards =====
p = Profile.default(); s = Rules.computeStats(p)
local r1 = Rules.restoreTarget(p, s, "start_grass_1"); check(r1 ~= nil, "first restore works")
eq(r1.fragments, 4, "grass reward")
local r2 = Rules.restoreTarget(p, s, "start_grass_1"); check(r2 == nil, "duplicate restore returns nil")
eq(p.stats.targetsRestored, 1, "counted once"); eq(p.fragments, 4, "paid once")
check(Rules.restoreTarget(p, s, "does_not_exist") == nil, "unknown target rejected")
check(Rules.restoreTarget(p, s, "../../") == nil, "garbage target rejected")
-- renewable never marks permanent
local r3 = Rules.restoreTarget(p, s, "start_bloom_1"); check(r3 ~= nil, "bloom works"); check(Rules.restoreTarget(p, s, "start_bloom_1") ~= nil, "bloom renewable"); check(p.restored.start_bloom_1 == nil, "bloom not stored")
-- echo capsule
local r4 = Rules.restoreTarget(p, s, "start_capsule_pebblit"); eq(r4.echo, "pebblit", "capsule frees echo"); check(p.echoes.pebblit, "owned"); eq(p.stats.echoesFreed, 1, "freed count")
check(table.find(p.equipped, "pebblit") ~= nil, "first echo auto-equips")
-- echo bonuses applied to rewards
p.echoes.mossbit = true; p.equipped = { "mossbit" }
s = Rules.computeStats(p)
eq(select(1, Rules.rewardFor(s, "tree")), math.floor(28 * 1.15 + 0.5), "mossbit +15% on plant frags")
eq(select(1, Rules.rewardFor(s, "crystal")), 90, "mossbit does not affect crystals")

-- ===== tutorial chain + milestones (idempotent) =====
p = Profile.default(); s = Rules.computeStats(p)
local ev = Rules.process(p); eq(#ev, 0, "nothing at start")
Rules.addFragments(p, s, 12)
ev = Rules.process(p); eq(#ev, 1, "q1 completes"); eq(ev[1].id, "q1", "q1 id"); eq(p.credits, 20, "q1 credits")
ev = Rules.process(p); eq(#ev, 0, "process is idempotent")
Rules.restoreTarget(p, s, "start_grass_1")
ev = Rules.process(p)
check(p.quests.q2, "q2 done"); check(p.echoes.mossbit, "mossbit from quest q2")
local sawEcho = false for _, e in ev do if e.kind == "echo" and e.id == "mossbit" then sawEcho = true end end
check(sawEcho, "echo event emitted")
-- quest order: stats satisfy later quests only after the earlier ones are claimed
local o = Rules.nextObjective(p, s); eq(o.id, "q3", "next objective is q3")
Rules.sellAll(p, s); Rules.process(p)
o = Rules.nextObjective(p, s); eq(o.id, "q4", "next objective q4")
-- percent milestones
p = Profile.default(); s = Rules.computeStats(p)
for _, t in WorldData.Targets do
	local d = Config.Targets[t.type]
	if (d.weight or 0) > 0 and t.type ~= "ruin" and t.type ~= "capsule" then p.restored[t.id] = true end
end
local pct = Rules.percent(p)
check(pct > 70 and pct < 75, "restoring all non-ruins gives " .. pct)
Rules.process(p)
check(p.milestones.m10 and p.milestones.m25 and p.milestones.m60, "milestones m10/25/60 claimed")
check(not p.milestones.m75, "m75 not claimed without ruins")
check(p.echoes.nullberry and p.echoes.lumifawn, "milestone echoes granted")
local creditsBefore = p.credits
Rules.process(p); eq(p.credits, creditsBefore, "milestone rewards are not repeatable")
check(not p.unlocked.frostlight, "gateway locked")
for _, t in WorldData.Targets do if t.type == "ruin" then p.restored[t.id] = true end end
Rules.process(p)
check(p.milestones.m75, "m75 claimed"); check(not p.unlocked.frostlight, "gateway still needs absorber tier 3")
p.tiers.absorber = 3; Rules.process(p)
check(p.unlocked.frostlight, "gateway unlocks with milestone + tier 3")
eq(Rules.percent(p), 100, "full restore = 100%")
check(p.milestones.m100 and p.echoes.auroxel, "100% grants legendary echo")
check(p.titles["Valley Restorer"], "title granted")

-- ===== rank-up rewards =====
p = Profile.default(); local evs = {}
Rules.addXp(p, Rules.xpForRank(3) + 1, evs)
eq(Rules.rankOf(p), 3, "rank 3"); eq(p.rp, 2, "2 research points"); eq(p.credits, 50 * 2 + 50 * 3, "rank credits")
eq(#evs, 2, "two rank events")
Rules.addXp(p, Rules.xpForRank(15), evs); Rules.process(p)
check(p.echoes.cometta, "cometta at rank 15")

-- ===== echoes equip rules =====
p = Profile.default(); p.echoes = { mossbit = true, pebblit = true, voltling = true }
ok = Rules.equipEcho(p, "mossbit"); eq(ok, true, "equip 1")
ok, why = Rules.equipEcho(p, "pebblit"); eq(ok, false, "slot full"); eq(why, "full", "full reason")
ok, why = Rules.equipEcho(p, "auroxel"); eq(why, "locked", "locked echo cannot be equipped")
ok, why = Rules.equipEcho(p, "mossbit"); eq(why, "already", "double equip")
ok, why = Rules.equipEcho(p, 5); eq(ok, false, "invalid equip input")
Rules.unequipEcho(p, "mossbit"); ok = Rules.equipEcho(p, "pebblit"); eq(ok, true, "swap")
eq(select(2, Rules.unequipEcho(p, "mossbit")), "not_equipped", "unequip missing")

-- ===== research ordering =====
p = Profile.default(); p.rp = 10
ok, why = Rules.buyResearch(p, "eff2"); eq(why, "order", "cannot skip research nodes")
ok = Rules.buyResearch(p, "eff1"); eq(ok, true, "buy eff1"); eq(p.rp, 9, "rp spent")
ok, why = Rules.buyResearch(p, "eff1"); eq(why, "owned", "no double research")
ok = Rules.buyResearch(p, "eff2"); eq(ok, true, "eff2 after eff1")
p.rp = 0; ok, why = Rules.buyResearch(p, "eff3"); eq(why, "funds", "no rp")
ok = Rules.buyResearch(p, "bogus"); eq(ok, false, "bogus node")

-- ===== secrets =====
p = Profile.default(); s = Rules.computeStats(p)
local sec = Rules.collectSecret(p, s, "shard_1"); eq(sec.credits, 150, "shard credits")
check(Rules.collectSecret(p, s, "shard_1") == nil, "shard not collectable twice")
check(Rules.collectSecret(p, s, "nope") == nil, "unknown shard")
for _, sh in WorldData.Secrets do Rules.collectSecret(p, s, sh.id) end
Rules.process(p); check(p.echoes.runeowl, "runeowl for all shards"); check(p.milestones.s6, "s6")

-- ===== reconcile garbage =====
local junk = { credits = -5, fragments = "x", xp = 0/0, tiers = { absorber = 99, backpack = -3, boots = "a" }, restored = { start_grass_1 = true, fake = true, [5] = true },
	echoes = { mossbit = true, ghost = true }, equipped = { "mossbit", "mossbit", "ghost", "auroxel" }, research = { eff1 = true, nope = true }, title = "Hacker",
	settings = { music = "yes", sfx = false }, gadgets = { overcharge = true, laser = true } }
local rp = Profile.reconcile(junk)
eq(rp.credits, 0, "negative credits clamped"); eq(rp.fragments, 0, "bad fragments"); eq(rp.xp, 0, "NaN xp")
eq(rp.tiers.absorber, #Config.Absorber, "tier clamped high"); eq(rp.tiers.backpack, 1, "tier clamped low"); eq(rp.tiers.boots, 1, "tier bad type")
check(rp.restored.start_grass_1 and not rp.restored.fake, "unknown ids dropped")
check(rp.echoes.mossbit and not rp.echoes.ghost, "unknown echo dropped")
eq(#rp.equipped, 1, "equipped deduped & only owned"); check(rp.research.eff1 and not rp.research.nope, "research filtered")
eq(rp.title, "Fresh Restorer", "unowned title rejected"); eq(rp.settings.music, true, "bad setting ignored"); eq(rp.settings.sfx, false, "good setting kept")
check(rp.gadgets.overcharge and not rp.gadgets.laser, "gadgets filtered")
eq(Profile.reconcile(nil).credits, 0, "nil raw -> defaults"); eq(Profile.reconcile("str").credits, 0, "string raw -> defaults")

print(fails == 0 and "rules_test: PASS" or ("rules_test: " .. fails .. " FAILURES"))
if fails > 0 then error("failed") end
