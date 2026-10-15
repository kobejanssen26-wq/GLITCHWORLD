-- Runs the real server entry point (Main.server) under the mock and exercises the player journey and the
-- hostile-input / failure paths: absorption, selling, buying (races), echoes, research, saving, session locks,
-- failed loads, players leaving mid-action.
local M = __M
local Shared = game.ReplicatedStorage.Shared
local WorldData = require(Shared.WorldData)
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)
M.heightFn = WorldData.heightAt

local fails = 0
local function check(c, msg) if not c then fails += 1; print("FAIL: " .. msg) end end
local function eq(a, b, msg) check(a == b, ("%s (got %s, expected %s)"):format(msg, tostring(a), tostring(b))) end

-- boot the real server script
task.spawn(require(game.ServerScriptService.Server.Main))
M.advance(8)
local Server = game.ServerScriptService.Server
local Sessions = require(Server.Sessions)
local DataService = require(Server.DataService)
local remotes = game.ReplicatedStorage.Remotes
local function fire(ev, player, ...) M.fireServerAs(remotes[ev], player, ...) end
local function call(fn, player, ...) return M.invokeAs(remotes[fn], player, ...) end
local function eventsOf(player, remote, kind)
	local out = {}
	for _, e in M.clientEvents[player] or {} do
		if e.remote == remote and (kind == nil or (type(e.args[1]) == "table" and e.args[1].kind == kind)) then table.insert(out, e) end
	end
	return out
end
local function join(name, uid)
	local p = M.newPlayer(name, uid)
	M.joinAsServer(p)
	M.advance(3)
	return p
end
local KEY = "Player_1001"

-- ===== join =====
local P = join("Alice", 1001)
local S = Sessions.get(P)
check(S ~= nil, "session created on join")
check(P.Character ~= nil, "character spawned")
eq(P.Character.Humanoid.WalkSpeed, 16, "starter walk speed applied")
eq(P.Character.Humanoid.MaxSlopeAngle, 52, "slope limit applied")
check(#eventsOf(P, "State") >= 1, "state snapshot sent")
check(#eventsOf(P, "TargetSnapshot") == 1, "target snapshot sent")
eq(M.datastore.data[KEY].lock.jobId, "job-A", "session lock taken on load")
eq(#M.errors, 0, "no script errors on join: " .. table.concat(M.errors, "\n"))
local lastState = eventsOf(P, "State")
lastState = lastState[#lastState].args[1]
eq(lastState.objective.id, "q1", "first objective is the tutorial")
eq(lastState.stats.capacity, 40, "snapshot carries capacity")

-- ===== absorb: grass beside the spawn =====
local g = WorldData.ById.start_grass_1
M.teleport(P, g.x + 3, 5, g.z)
fire("AbsorbControl", P, "start", "start_grass_1")
M.advance(2)
check(S.profile.restored.start_grass_1 == nil, "not restored after 2s (hp 10 at 2/s)")
check(S.progress.start_grass_1 ~= nil and S.progress.start_grass_1.hp > 2, "partial progress accumulates")
M.advance(4)
check(S.profile.restored.start_grass_1 == true, "restored after enough time")
eq(S.profile.fragments, 4, "paid exactly the grass reward")
eq(S.profile.stats.targetsRestored, 1, "restore counted once")
check(#eventsOf(P, "TargetUpdate") >= 1, "client told about the new state")
eq(#eventsOf(P, "Notify", "restored"), 1, "one restored notification")
M.advance(3)
eq(S.profile.fragments, 4, "no further reward after completion (absorb stopped)")
-- second start on an already restored target is rejected and the client is re-synced
local before = #eventsOf(P, "TargetUpdate")
fire("AbsorbControl", P, "start", "start_grass_1")
M.advance(3)
eq(S.profile.fragments, 4, "re-absorbing a restored target pays nothing")
check(#eventsOf(P, "TargetUpdate") > before, "stale client is corrected")
-- quest chain advanced by server-validated stats only
check(S.profile.stats.fragmentsCollected == 4 and not S.profile.quests.q1, "q1 needs 10 fragments")

-- ===== hostile / invalid remote input never throws or changes state =====
local snapshotCredits = S.profile.credits
for _, bad in { { nil }, { 42 }, { "start", 42 }, { "start", string.rep("x", 5000) }, { "start", "nonexistent_target" }, { "explode", "start_grass_2" }, { {}, {} }, { "start", {} }, { "stop", "x" } } do
	fire("AbsorbControl", P, table.unpack(bad, 1, 2))
end
fire("UseGadget", P, 123); fire("UseGadget", P, "overcharge"); fire("UseGadget", P, "../../x")
for _, args in { { nil, nil }, { 1, 2 }, { "absorber", {} }, { "hack", "absorber_2" }, { {}, "absorber_2" }, { "gadget", string.rep("y", 300) } } do
	local r = call("Buy", P, table.unpack(args, 1, 2)); eq(r.ok, false, "garbage Buy rejected")
end
for _, args in { { nil }, { 5 }, { {} }, { "no_such_node" } } do eq(call("Research", P, table.unpack(args, 1, 1)).ok, false, "garbage Research rejected") end
for _, args in { { nil, nil }, { "equip", 5 }, { "dance", "mossbit" }, { "equip", "auroxel" }, { "equip", string.rep("z", 100) } } do eq(call("EchoAction", P, table.unpack(args, 1, 2)).ok, false, "garbage EchoAction rejected") end
eq(call("SetSetting", P, "credits", true).ok, false, "unknown setting key rejected"); eq(call("SetSetting", P, "sfx", "yes").ok, false, "non-boolean setting rejected")
eq(call("SetTitle", P, "Admin").ok, false, "unowned title rejected")
M.advance(1)
eq(S.profile.credits, snapshotCredits, "hostile input changed no credits")
eq(S.profile.settings.sfx, true, "settings untouched")
eq(#M.errors, 0, "no script errors from hostile input: " .. table.concat(M.errors, "\n"))

-- ===== range & tier validation =====
local c = WorldData.ById.hollow_crystal_1
M.teleport(P, c.x + 3, 12, c.z)
fire("AbsorbControl", P, "start", "hollow_crystal_1")
M.advance(4)
check(S.profile.restored.hollow_crystal_1 == nil and not S.progress.hollow_crystal_1, "crystal needs a better absorber (tier gate)")
check(#eventsOf(P, "Notify", "msg") >= 1, "player told why")
local g2 = WorldData.ById.start_grass_2
M.teleport(P, g2.x + 80, 5, g2.z) -- far away
fire("AbsorbControl", P, "start", "start_grass_2")
M.advance(8)
check(S.profile.restored.start_grass_2 == nil and (not S.progress.start_grass_2 or S.progress.start_grass_2.hp < 1), "out of range: no progress")

-- ===== selling =====
S.profile.fragments = 40; S.profile.stats.fragmentsCollected = 40 -- as if collected by absorbing
M.teleport(P, 500, 5, 500)
local r = call("Sell", P); eq(r.ok, false, "cannot sell away from the station"); eq(r.reason, "far", "reason far")
eq(S.profile.fragments, 40, "backpack untouched when selling fails")
M.teleport(P, WorldData.Stations.sell.x, 5, WorldData.Stations.sell.z + 4)
M.advance(1)
r = call("Sell", P); eq(r.ok, true, "sold at station"); eq(r.credits, 40, "credits from sale"); check(S.profile.credits >= 40, "credited"); eq(S.profile.fragments, 0, "backpack emptied")
M.advance(1)
r = call("Sell", P); eq(r.ok, false, "empty sell is a no-op")
check(S.profile.quests.q1 and S.profile.quests.q2 and S.profile.quests.q3, "tutorial q1-q3 completed from real actions")
check(S.profile.echoes.mossbit, "mossbit unlocked by quest q2")
eq(P:GetAttribute("Echoes"), "mossbit", "equipped echoes published as attribute")

-- ===== buying: insufficient funds, distance, simultaneous attempts =====
M.teleport(P, WorldData.Stations.upgrade.x, 5, WorldData.Stations.upgrade.z + 4)
S.profile.credits = 100
r = call("Buy", P, "absorber", "absorber_2"); eq(r.reason, "funds", "insufficient credits rejected")
eq(S.profile.credits, 100, "no charge on failure")
M.teleport(P, 0, 5, 118)
S.profile.credits = 1000
local lifetime0 = S.profile.stats.lifetimeCredits
local function spent() return 1000 + (S.profile.stats.lifetimeCredits - lifetime0) - S.profile.credits end
r = call("Buy", P, "absorber", "absorber_2"); eq(r.reason, "far", "must be at the upgrade station")
M.advance(2)
M.teleport(P, WorldData.Stations.upgrade.x, 5, WorldData.Stations.upgrade.z + 4)
local results = {}
for i = 1, 6 do
	task.spawn(function() results[i] = call("Buy", P, "absorber", "absorber_2") end)
end
M.advance(0.5)
local wins = 0
for _, x in results do if x and x.ok then wins += 1 end end
eq(wins, 1, "exactly one of six simultaneous purchases succeeds")
eq(spent(), 250, "charged exactly once (quest rewards excluded)"); eq(S.profile.tiers.absorber, 2, "tier applied")
M.advance(2)
r = call("Buy", P, "absorber", "absorber_4"); eq(r.reason, "order", "cannot skip tiers")
r = call("Buy", P, "backpack", "backpack_2"); eq(r.ok, true, "buy backpack_2 (120)"); eq(spent(), 370, "credits after backpack")
M.advance(1)
local lastS = eventsOf(P, "State"); lastS = lastS[#lastS].args[1]
eq(lastS.stats.capacity, 100, "client snapshot reflects new capacity"); eq(lastS.tiers.absorber, 2, "snapshot tier")
-- rate limit: hammering Buy never lets more than the burst through
local calls = 0
for _ = 1, 40 do local rr = call("Buy", P, "boots", "boots_2"); if rr.reason ~= "slow_down" then calls += 1 end end
check(calls <= 8, "rate limiter bounds hammering (" .. calls .. " calls processed of 40)")
M.advance(3)

-- ===== crystal now allowed (tier 2) + echo capsule =====
M.teleport(P, c.x + 3, 12, c.z)
S.profile.fragments = 0
fire("AbsorbControl", P, "start", "hollow_crystal_1")
M.advance(75)
check(S.profile.restored.hollow_crystal_1 == true, "crystal restored with tier-2 absorber")
local cap = WorldData.ById.start_capsule_pebblit
M.teleport(P, cap.x + 3, 5, cap.z)
fire("AbsorbControl", P, "start", "start_capsule_pebblit")
M.advance(60)
check(S.profile.echoes.pebblit, "capsule frees pebblit")
eq(S.profile.stats.echoesFreed, 1, "echo freed counted")
check(#eventsOf(P, "Notify", "echo") >= 1, "echo discovery notification")

-- ===== echo equip rules + research + settings =====
eq(call("EchoAction", P, "equip", "pebblit").ok, false, "slot limit (1 slot at rank 1)")
eq(call("EchoAction", P, "unequip", "mossbit").ok, true, "unequip")
eq(call("EchoAction", P, "equip", "pebblit").ok, true, "equip the other one")
eq(P:GetAttribute("Echoes"), "pebblit", "attribute follows equip")
S.profile.rp = 3
eq(call("Research", P, "eff2").reason, "order", "research order enforced")
eq(call("Research", P, "eff1").ok, true, "research eff1"); eq(S.profile.rp, 2, "rp spent")
eq(call("SetSetting", P, "sfx", false).ok, true, "valid setting"); eq(S.profile.settings.sfx, false, "setting stored")

-- ===== overcharge gadget =====
S.profile.gadgets.overcharge = true
require(Server.ProgressService).commit(S)
fire("UseGadget", P, "overcharge"); M.advance(0.2)
check(S.boostUntil > M.now(), "overcharge active")
local until1 = S.boostUntil
fire("UseGadget", P, "overcharge"); M.advance(0.2)
eq(S.boostUntil, until1, "cannot re-trigger during cooldown")
M.advance(50)
fire("UseGadget", P, "overcharge"); M.advance(0.2)
check(S.boostUntil > until1, "usable again after cooldown")

-- ===== persistence: leave and rejoin =====
local credits, restoredCount = S.profile.credits, 0
for _ in S.profile.restored do restoredCount += 1 end
M.leave(P)
M.advance(2)
check(M.datastore.data[KEY] ~= nil and M.datastore.data[KEY].lock == nil, "lock released on leave")
local saved = M.datastore.data[KEY].data
eq(saved.credits, credits, "credits saved"); check(saved.restored.start_grass_1 and saved.restored.hollow_crystal_1, "restored targets saved")
check(saved.echoes.pebblit and saved.echoes.mossbit, "echoes saved"); eq(saved.tiers.absorber, 2, "tiers saved"); check(saved.research.eff1, "research saved")
check(Sessions.get(P) == nil and DataService.get(P) == nil, "session & profile released")
local P2 = join("Alice", 1001)
local S2 = Sessions.get(P2)
check(S2 ~= nil, "rejoin creates a session")
eq(S2.profile.credits, credits, "credits restored on rejoin"); eq(S2.profile.tiers.absorber, 2, "tier restored")
local n2 = 0
for _ in S2.profile.restored do n2 += 1 end
eq(n2, restoredCount, "restoration persists")
check(S2.profile.echoes.pebblit, "echoes persist"); eq(S2.profile.settings.sfx, false, "settings persist")
eq(P2:GetAttribute("Echoes"), "pebblit", "equipped echo restored")
local snap2 = eventsOf(P2, "TargetSnapshot")[1].args[1]
check(table.find(snap2.restored, "start_grass_1") ~= nil, "client receives persisted restorations")

-- ===== player leaving mid-absorb / mid-purchase never errors =====
M.teleport(P2, g2.x + 3, 5, g2.z)
fire("AbsorbControl", P2, "start", "start_grass_2")
M.advance(1)
M.leave(P2)
M.advance(5)
eq(#M.errors, 0, "leaving mid-absorb is clean: " .. table.concat(M.errors, "\n"))
check(M.datastore.data[KEY].lock == nil, "lock released after mid-absorb leave")

-- ===== session lock held by another server: no overwrite, no blank profile =====
local snapshotData = M.deepcopy(M.datastore.data[KEY])
M.datastore.data[KEY].lock = { jobId = "job-B", t = M.os.time() }
local writesBefore = M.datastore.writes
local P3 = join("Alice", 1001)
M.advance(40)
check(#M.kicks >= 1 and M.kicks[#M.kicks].player == P3, "player kicked when profile is locked elsewhere")
check(Sessions.get(P3) == nil, "no session without a loaded profile")
eq(M.datastore.writes, writesBefore, "no write happened while another server held the lock")
eq(M.datastore.data[KEY].data.credits, snapshotData.data.credits, "saved credits untouched")
-- stale lock (crashed server) expires
M.datastore.data[KEY].lock = { jobId = "job-B", t = M.os.time() - 500 }
local P4 = join("Alice", 1001)
check(Sessions.get(P4) ~= nil, "stale lock is taken over")
eq(Sessions.get(P4).profile.credits, snapshotData.data.credits, "profile intact after stale takeover")
M.leave(P4); M.advance(2)

-- ===== failed DataStore load: bounded retries, kick, never a blank save =====
M.kicks = {}
M.datastore.failNext = 100
local before = M.datastore.calls
local P5 = join("Alice", 1001)
M.advance(60)
check(#M.kicks >= 1, "kicked after load failure")
check(M.datastore.calls - before <= 6, "bounded retries (" .. (M.datastore.calls - before) .. " calls)")
check(Sessions.get(P5) == nil, "no session after failed load")
eq(DataService.save(P5, true), false, "cannot save a profile that was never loaded")
M.datastore.failNext = 0
eq(M.datastore.data[KEY].data.credits, snapshotData.data.credits, "stored data survived failed load")
M.leave(P5); M.advance(1)

-- ===== transient save failure retries; autosave; BindToClose =====
local P6 = join("Alice", 1001)
local S6 = Sessions.get(P6)
S6.profile.credits += 123
local w0 = M.datastore.writes
M.datastore.failNext = 2
M.advance(75) -- autosave interval is 60s; two throttled attempts then success
check(M.datastore.writes > w0, "autosave eventually wrote despite 2 failures")
eq(M.datastore.data[KEY].data.credits, S6.profile.credits, "autosave stored latest credits")
S6.profile.credits += 7
for _, fn in M.bindToClose do fn() end
eq(M.datastore.data[KEY].data.credits, S6.profile.credits, "BindToClose saved latest state")
check(M.datastore.data[KEY].lock == nil, "BindToClose released the lock")

-- ===== second player isolation (shared world, separate progress) =====
local PB = join("Bob", 2002)
local SB = Sessions.get(PB)
check(SB ~= nil and SB ~= Sessions.get(P6), "separate sessions")
eq(SB.profile.credits, 0, "fresh profile for a new player")
check(not SB.profile.restored.start_grass_1, "Bob's world is independent of Alice's progress")

print(fails == 0 and "server_test: PASS" or ("server_test: " .. fails .. " FAILURES"))
if #M.errors > 0 then print("script errors:\n" .. table.concat(M.errors, "\n")); fails += 1 end
if fails > 0 then error("failed") end
