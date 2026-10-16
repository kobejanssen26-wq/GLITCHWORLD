-- Runs the real server entry point with the baked world loaded into the mock and exercises the whole journey:
-- plots, factory income, buying (races), tower checkpoints / rewards / anti-cheat, hazards, perks, cosmetics,
-- Overdrive, saving, session locks, failed loads, players leaving.
local M = __M
local Shared = game.ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)
local Bake = require(game.ServerScriptService.Bake.Bake)
local Instantiate = require(game.ServerScriptService.Bake.Instantiate)

local fails = 0
local function check(c, msg) if not c then fails += 1; print("FAIL: " .. msg) end end
local function eq(a, b, msg) check(a == b, ("%s (got %s, expected %s)"):format(msg, tostring(a), tostring(b))) end

-- the baked map stands in for world/World.rbxm
local root = Bake.build()
local worldInst = Instantiate.build(root, workspace)
M.heightFn = function() return 0 end

task.spawn(require(game.ServerScriptService.Server.Main))
M.advance(3)
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
	fire("ClientReady", p)
	M.joinAsServer(p)
	M.advance(3)
	return p
end
local KEY = "Player_1001"
local function find(inst, name) return inst:FindFirstChild(name, true) end
local function hrpOf(p) return p.Character.HumanoidRootPart end
local function touch(part, player) M.getSignal(part, "Touched"):Fire(hrpOf(player)) end
local function pad(floor) return find(workspace.World.Tower, "Checkpoint:" .. floor) end
local summitPad = find(workspace.World.Tower, "Summit")

-- ===== join: plot, factory, snapshot =====
local P = join("Alice", 1001)
local S = Sessions.get(P)
check(S ~= nil, "session created")
eq(S.plot, 1, "first player gets plot 1")
eq(P:GetAttribute("Plot"), 1, "plot attribute")
local plotFolder = workspace.Factories.Plot1
check(plotFolder:FindFirstChild("Belt") and plotFolder:FindFirstChild("dropper_rusty") and plotFolder:FindFirstChild("collector_basic"), "starter factory built")
check(plotFolder:FindFirstChild("BuyPad") ~= nil, "buy pad built")
check(not plotFolder:FindFirstChild("up_polisher"), "unbought machines are not built")
check(P.Character ~= nil, "character spawned")
local origin = find(workspace.World.Plots.Plot1, "Marker:PlotOrigin:1").Position
check((hrpOf(P).Position - origin).Magnitude < 70, "player placed at their plot")
check(#eventsOf(P, "State") >= 1, "state snapshot sent")
local st = eventsOf(P, "State"); st = st[#st].args[1]
eq(st.nextItem.id, "up_polisher", "next item shown"); eq(st.cash, 0, "starts with no cash")
check(P:FindFirstChild("leaderstats") and P.leaderstats:FindFirstChild("Crowns"), "leaderstats")
eq(M.datastore.data[KEY].lock.jobId, "job-A", "session lock taken")
eq(#M.errors, 0, "no script errors on join: " .. table.concat(M.errors, "\n"))

-- ===== factory income follows the schedule =====
M.advance(20)
check(S.profile.cash >= 8 and S.profile.cash <= 30, "income after 20s is in the expected range, cash=" .. S.profile.cash)
local ticks = eventsOf(P, "CashTick")
check(#ticks >= 3, "client receives batched cash ticks")
local c0 = S.profile.cash
M.advance(30)
local gained = S.profile.cash - c0
check(math.abs(gained - 30 * Rules.income(S.profile)) < 6, ("30s income %.1f vs expected %.1f"):format(gained, 30 * Rules.income(S.profile)))

-- ===== buying =====
local function cost(id, prof) return Rules.itemCost(Rules.itemById[id], prof or S.profile) end
S.profile.cash = 10
local r = call("Buy", P, "up_polisher"); eq(r.reason, "funds", "cannot afford")
S.profile.cash = 1e6
r = call("Buy", P, "up_smelter"); eq(r.reason, "locked", "items unlock in order")
for _, bad in { nil, 5, {}, string.rep("x", 100), "nope" } do eq(call("Buy", P, bad).ok, false, "garbage item rejected") end
local before = S.profile.cash
M.advance(1)
local results = {}
for i = 1, 6 do task.spawn(function() results[i] = call("Buy", P, "up_polisher") end) end
M.advance(0.3)
local wins = 0
for _, x in results do if x and x.ok then wins += 1 end end
eq(wins, 1, "exactly one of six simultaneous purchases succeeds")
check(before - S.profile.cash >= cost("up_polisher", Rules.itemById and Profile and S.profile) - 100, "charged once")
check(plotFolder:FindFirstChild("up_polisher") ~= nil, "machine appears in the plot")
eq(S.profile.items.up_polisher, true, "ownership recorded")
local padLabel = plotFolder.BuyPad:FindFirstChild("Label")
check(padLabel and padLabel.Text.Text:find("Copper"), "pad now offers the copper dropper")
-- touching the pad buys the next item too, only for the owner
local Q = join("Bob", 2002)
local SB = Sessions.get(Q)
eq(SB.plot, 2, "second player gets plot 2")
S.profile.cash = 1e6
local copperBefore = S.profile.items.dropper_copper
M.advance(1)
touch(plotFolder.BuyPad, Q)
M.advance(1)
check(not S.profile.items.dropper_copper, "a stranger touching your pad buys nothing")
touch(plotFolder.BuyPad, P)
M.advance(1)
check(S.profile.items.dropper_copper and not copperBefore, "owner touching the pad buys the next item")
-- far from the plot
M.teleport(P, 0, 5, -136)
r = call("Buy", P, "up_smelter"); eq(r.reason, "far", "must be near your plot to buy")
M.teleport(P, origin.X, 5, origin.Z)
-- rate limit
local processed = 0
for _ = 1, 40 do local rr = call("Buy", P, "up_smelter"); if rr.reason ~= "slow_down" then processed += 1 end end
check(processed <= 12, "rate limiter bounds hammering (" .. processed .. " of 40 processed)")
M.advance(3)

-- ===== tower: teleport, checkpoints, rewards, anti-cheat =====
eq(call("Teleport", P, "moon").ok, false, "unknown destination rejected")
eq(call("Teleport", P, "tower").ok, true, "teleport to the tower")
local p1 = pad(1)
check((hrpOf(P).Position - p1.Position).Magnitude < 8, "placed on checkpoint 1")
eq(S.inTower, true, "inTower")
eq(call("Teleport", P, "tower").reason, "cooldown", "teleport cooldown")
M.advance(2)
-- teleporting to checkpoint 4 without climbing is refused
M.teleport(P, pad(4).Position.X, pad(4).Position.Y + 3, pad(4).Position.Z)
touch(pad(4), P)
M.advance(0.2)
eq(S.profile.reached, 1, "cannot skip to floor 4 by teleporting")
-- too fast to floor 2
S.lastCheckpoint = 1; S.checkpointAt = M.now()
M.teleport(P, pad(2).Position.X, pad(2).Position.Y + 3, pad(2).Position.Z)
touch(pad(2), P)
M.advance(0.2)
eq(S.profile.reached, 1, "floor 2 cannot be reached faster than the minimum time")
check(#eventsOf(P, "Notify", "msg") >= 1, "player told why")
M.advance(20)
-- too far from the pad: Touched alone is not enough
M.teleport(P, pad(2).Position.X + 200, pad(2).Position.Y + 3, pad(2).Position.Z)
touch(pad(2), P)
eq(S.profile.reached, 1, "distance is checked")
M.teleport(P, pad(2).Position.X, pad(2).Position.Y + 3, pad(2).Position.Z)
touch(pad(2), P)
M.advance(0.2)
eq(S.profile.reached, 2, "floor 2 reached after enough time")
check(S.profile.floors["1"], "floor 1 cleared")
eq(S.profile.crowns, 1, "first clear pays 1 crown")
check(S.profile.trails.trail_1 and S.profile.trail == "trail_1", "trail unlocked")
local clears = eventsOf(P, "Notify", "floorClear")
eq(#clears, 1, "one floor-clear notification"); eq(clears[1].args[1].first, true, "first clear flagged")
eq(P:GetAttribute("Trail"), "trail_1", "trail published for other players' clients")
local cashAfter, crownsAfter = S.profile.cash, S.profile.crowns
touch(pad(2), P); M.advance(0.2)
eq(S.profile.crowns, crownsAfter, "touching the same checkpoint again pays nothing")
check(S.profile.cash >= cashAfter, "cash never decreases")
eq(P.leaderstats.Floor.Value, 2, "leaderstats follow")
-- the checkpoint is the respawn point
local hum = P.Character.Humanoid
hum.Health = 0
M.getSignal(hum, "Died"):Fire()
eq(S.profile.stats.deaths, 1, "death counted")
M.advance(0.1)
M.getSignal(P, "CharacterAdded") -- (the mock respawns via LoadCharacterAsync in the test below)
P:LoadCharacterAsync(); M.advance(1)
check((hrpOf(P).Position - pad(2).Position).Magnitude < 8, "respawned at checkpoint 2")
-- falling out of the world
M.teleport(P, 0, -400, 0)
M.advance(1.5)
check((hrpOf(P).Position - pad(2).Position).Magnitude < 8, "fall recovery returns to the checkpoint")

-- ===== hazards =====
local killPart
for _, d in workspace.World.Tower:GetDescendants() do if d.Name == "Kill" then killPart = d break end end
P.Character.Humanoid.Health = 100
touch(killPart, P)
eq(P.Character.Humanoid.Health, 0, "kill parts kill")
P:LoadCharacterAsync(); M.advance(1)
local bounce, speed, coin, vanish
for _, d in workspace.World.Tower:GetDescendants() do
	if not bounce and d.Name:sub(1, 7) == "Bounce:" then bounce = d end
	if not speed and d.Name:sub(1, 6) == "Speed:" then speed = d end
	if not coin and d.Name == "Coin" then coin = d end
	if not vanish and d.Name:sub(1, 7) == "Vanish:" then vanish = d end
end
touch(bounce, P)
local launches = eventsOf(P, "Launch")
check(#launches == 1 and launches[1].args[1] == 105, "bounce pad launches the player (client applies the impulse)")
local walkBefore = P.Character.Humanoid.WalkSpeed
touch(speed, P)
check(P.Character.Humanoid.WalkSpeed > walkBefore * 1.5, "speed pad boosts walk speed")
M.advance(4)
eq(P.Character.Humanoid.WalkSpeed, walkBefore, "speed boost wears off")
local cash0 = S.profile.cash
touch(coin, P)
check(S.profile.cash > cash0 and S.profile.stats.coins == 1, "coin pays")
local cash1 = S.profile.cash
touch(coin, P)
eq(S.profile.cash, cash1, "a coin cannot be collected twice")
check(coin.Transparency == 1, "taken coin hides")
M.advance(26)
eq(coin.Transparency, 0, "coin respawns"); 
touch(vanish, P)
M.advance(1.5)
eq(vanish.CanCollide, false, "vanishing tile disappears")
M.advance(4)
eq(vanish.CanCollide, true, "and comes back")
local hinges = 0
for _, d in workspace.World.Tower:GetDescendants() do if d:IsA("HingeConstraint") then hinges += 1 end end
check(hinges >= 10, "spinners got motors: " .. hinges)
local laser
for _, d in workspace.World.Tower:GetDescendants() do if d.Name:sub(1, 6) == "Laser:" then laser = d break end end
local seen = {}
for _ = 1, 40 do M.advance(0.25); seen[laser.Transparency > 0.5] = true end
check(seen[true] and seen[false], "lasers switch on and off")

-- ===== summit + progression to the top =====
S.profile.reached = 12; S.profile.checkpoint = 12; S.lastCheckpoint = 12; S.checkpointAt = M.now() - 60
local crowns0 = S.profile.crowns
M.teleport(P, summitPad.Position.X, summitPad.Position.Y + 3, summitPad.Position.Z)
touch(summitPad, P); M.advance(0.2)
check(S.profile.floors["12"] and S.profile.crowns >= crowns0 + 12 + 20, "summit clears floor 12 with the bonus")
touch(summitPad, P); M.advance(0.2)
local crowns2 = S.profile.crowns
touch(summitPad, P); M.advance(0.2)
eq(S.profile.crowns, crowns2, "summit pays once")

-- ===== skip / goto =====
S.profile.checkpoint = 3; S.profile.reached = 3; S.profile.cash = 10
eq(call("Skip", P).reason, "funds", "skip needs cash")
S.profile.cash = 1e7
eq(call("Skip", P).ok, true, "skip works with cash"); eq(S.profile.checkpoint, 4, "now at floor 4")
M.advance(2)
eq(call("GotoFloor", P, 9).reason, "locked", "cannot go to a floor you have not reached")
eq(call("GotoFloor", P, 2).ok, true, "can go back to a reached floor"); eq(S.profile.checkpoint, 2, "checkpoint moved")
M.advance(2)
eq(call("Teleport", P, "home").ok, true, "home"); check((hrpOf(P).Position - origin).Magnitude < 70, "back at the plot"); M.advance(2)

-- ===== perks / cosmetics / settings =====
S.profile.cash = 1500
eq(call("BuyPerk", P, "speed_coil").ok, true, "buy speed coil")
eq(P.Character.Humanoid.WalkSpeed, 21, "perk applied to the character")
eq(call("BuyPerk", P, "speed_coil").reason, "owned", "no double buy")
eq(call("BuyPerk", P, "hax").reason, "invalid", "unknown perk")
eq(call("BuyPerk", P, 5).ok, false, "garbage perk")
S.profile.perks.double_jump = true
require(Server.ProgressService).commit(S)
eq(P:GetAttribute("DoubleJump"), true, "double jump published for the client")
eq(call("Equip", P, "trail", "trail_9").ok, false, "locked trail"); eq(call("Equip", P, "trail", "trail_1").ok, true, "equip trail")
eq(call("Equip", P, "aura", "aura_crown").ok, false, "locked aura")
eq(call("Equip", P, "title", "Forge Runner").ok, true, "title earned by crowns"); eq(call("Equip", P, "title", "Tower Conqueror").ok, false, "title not yet earned")
eq(call("Equip", P, "title", "Admin").ok, false, "fake title"); eq(call("Equip", P, "wings", "x").ok, false, "unknown cosmetic kind")
eq(call("SetSetting", P, "credits", true).ok, false, "unknown setting"); eq(call("SetSetting", P, "sfx", "x").ok, false, "non-boolean"); eq(call("SetSetting", P, "music", false).ok, true, "valid setting")

-- ===== overdrive =====
eq(call("Overdrive", P).reason, "locked", "needs the reactor")
for _, it in Config.Items do S.profile.items[it.id] = true end
S.profile.cash = 5e9
local crownsKeep = S.profile.crowns
M.advance(3)
eq(call("Overdrive", P).ok, true, "overdrive")
eq(S.profile.overdrive, 1, "count"); check(not S.profile.items.up_polisher and S.profile.items.dropper_rusty, "factory reset")
eq(S.profile.cash, Config.Tycoon.OVERDRIVE_HEADSTART, "headstart cash"); eq(S.profile.crowns, crownsKeep, "crowns kept")
check(plotFolder:FindFirstChild("dropper_rusty") and not plotFolder:FindFirstChild("dropper_void"), "factory rebuilt")
check(S.profile.perks.speed_coil and S.profile.floors["12"], "perks and floors kept")

-- ===== persistence =====
local saved = { cash = S.profile.cash, crowns = S.profile.crowns, overdrive = S.profile.overdrive }
M.leave(P); M.advance(2)
eq(M.datastore.data[KEY].lock, nil, "lock released on leave")
local data = M.datastore.data[KEY].data
check(data.overdrive == 1 and data.floors["12"] and data.perks.speed_coil and data.trails.trail_1, "progress saved")
check(workspace.Factories.Plot1:GetChildren()[1] == nil, "plot freed when the owner leaves")
local P2 = join("Alice", 1001)
local S2 = Sessions.get(P2)
eq(S2.profile.overdrive, 1, "overdrive persists"); eq(S2.profile.crowns, saved.crowns, "crowns persist")
check(S2.profile.perks.speed_coil and S2.profile.floors["12"], "perks + floors persist")
eq(S2.plot, 1, "rejoining player gets a free plot again")
check(workspace.Factories.Plot1:FindFirstChild("dropper_rusty") ~= nil, "factory is rebuilt from the save")
M.leave(P2); M.advance(2)

-- ===== session lock / failed load =====
local snapshotData = M.deepcopy(M.datastore.data[KEY])
M.datastore.data[KEY].lock = { jobId = "job-B", t = M.os.time() }
local cashLocked = M.datastore.data[KEY].data.cash
local P3 = join("Alice", 1001)
M.advance(40)
check(#M.kicks >= 1, "kicked when the profile is locked elsewhere"); check(Sessions.get(P3) == nil, "no session without data")
eq(M.datastore.data[KEY].data.cash, cashLocked, "no write to the profile while another server holds the lock")
M.datastore.data[KEY].lock = { jobId = "job-B", t = M.os.time() - 500 }
local P4 = join("Alice", 1001)
check(Sessions.get(P4) ~= nil and Sessions.get(P4).profile.overdrive == 1, "stale lock is taken over, data intact")
M.leave(P4); M.advance(2)
M.kicks = {}
M.datastore.failNext = 100
local callsBefore = M.datastore.callsByKey[KEY] or 0
local P5 = join("Alice", 1001)
M.advance(60)
check(#M.kicks >= 1 and Sessions.get(P5) == nil, "failed load kicks the player")
check((M.datastore.callsByKey[KEY] or 0) - callsBefore <= 6, "bounded retries")
eq(DataService.save(P5, true), false, "never saves a profile that was not loaded")
M.datastore.failNext = 0
eq(M.datastore.data[KEY].data.overdrive, 1, "stored data survived the failed load")
M.leave(P5); M.advance(1)

-- ===== autosave + shutdown =====
local P6 = join("Alice", 1001)
local S6 = Sessions.get(P6)
local base6 = S6.profile.cash
S6.profile.cash += 777
local w0 = M.datastore.writes
M.datastore.failNext = 2
M.advance(75)
check(M.datastore.writes > w0, "autosave wrote despite two throttled attempts")
check(M.datastore.data[KEY].data.cash >= base6 + 777, "autosave stored the latest cash")
S6.profile.cash += 5
for _, fn in M.bindToClose do fn() end
eq(M.datastore.data[KEY].data.cash, S6.profile.cash, "BindToClose saved the latest state")
check(M.datastore.data[KEY].lock == nil, "BindToClose released the lock")

-- ===== plots run out =====
local extras = {}
for i = 1, 8 do extras[i] = join("Extra" .. i, 3000 + i) end
local noPlot = 0
for _, e in extras do local s = Sessions.get(e); if s and not s.plot then noPlot += 1 end end
check(noPlot >= 1, "players beyond the plot count still play without a plot (" .. noPlot .. ")")
for _, e in extras do M.leave(e) end
M.advance(2)

-- ===== leaving mid-action =====
local P7 = join("Zed", 5005)
M.teleport(P7, 0, 5, 0)
fire("Jumped2", P7)
M.leave(P7)
M.advance(5)
eq(#M.errors, 0, "no script errors anywhere: " .. table.concat(M.errors, "\n"))

print(fails == 0 and "server_test: PASS" or ("server_test: " .. fails .. " FAILURES"))
if fails > 0 then error("failed") end
