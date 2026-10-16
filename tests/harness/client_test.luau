-- Full-stack smoke test: real server + real client under the mock, one player, driven through remotes / UI events.
local M = __M
local Shared = game.ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)
local Bake = require(game.ServerScriptService.Bake.Bake)
local Instantiate = require(game.ServerScriptService.Bake.Instantiate)

local fails = 0
local function check(c, m) if not c then fails += 1; print("FAIL: " .. m) end end
local function eq(a, b, m) check(a == b, ("%s (got %s, expected %s)"):format(m, tostring(a), tostring(b))) end

Instantiate.build((Bake.build()), workspace)
task.spawn(require(game.ServerScriptService.Server.Main))
M.advance(3)
local Server = game.ServerScriptService.Server
local Sessions = require(Server.Sessions)

local P = M.newPlayer("Dana", 3003)
M.setLocalPlayer(P)
M.deliverToClient = true
local Client = game.StarterPlayer.StarterPlayerScripts.Client
task.spawn(require(Client.Main))
M.advance(1)
M.joinAsServer(P)
M.advance(4)
local S = Sessions.get(P)
local State = require(Client.State)
local Menus = require(Client.Menus)
local UIKit = require(Client.UIKit)
check(State.data ~= nil, "client received the snapshot")
eq(#M.errors, 0, "no errors during boot: " .. table.concat(M.errors, "\n"))
local gui = P.PlayerGui:FindFirstChild("NeonforgeUI")
check(gui ~= nil, "UI root built")
local function findText(root, pred)
	for _, d in root:GetDescendants() do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and pred(d.Text) then return d end
	end
end
check(findText(gui, function(t) return t:find("FLOOR 1/12") ~= nil end), "floor card")
check(findText(gui, function(t) return t == "TO TOWER" end), "travel button says TO TOWER")
check(findText(gui, function(t) return t:find("/s") ~= nil end), "income line")

-- every menu opens and renders
for _, name in { "shop", "tower", "style", "settings" } do
	Menus.open(name); M.advance(0.3)
	eq(Menus.current(), name, "menu opens: " .. name)
end
Menus.close()
eq(#M.errors, 0, "menus render without errors: " .. table.concat(M.errors, "\n"))

-- ores are drawn from the schedule near your plot
local plotFolder = workspace.Factories.Plot1
local origin = plotFolder:GetAttribute("Origin")
workspace.CurrentCamera.CFrame = CFrame.new(origin.Position + Vector3.new(0, 30, 60))
M.advance(8)
local visible = 0
for _, p in workspace:GetChildren() do
	if p.Name == "Ore" and p.Transparency == 0 then
		visible += 1
		local local_ = origin:Inverse() * p.Position
		check(local_.X >= -33 and local_.X <= 36 and math.abs(local_.Z) < 0.5, "ore stays on the belt line")
	end
end
check(visible >= 1 and visible <= 40, "ores are visible on the belt (" .. visible .. ")")

-- the shop through the UI
S.profile.cash = 5000
require(Server.ProgressService).commit(S)
M.advance(0.5)
Menus.open("shop"); M.advance(0.3)
local panel
for _, c in gui:GetChildren() do if c.Name == "Shop" then panel = c end end
local buy
for _, b in panel:GetDescendants() do if b:IsA("TextButton") and b.Text == "$1.5K" or (b:IsA("TextButton") and b.Text == "$1,500") then buy = b end end
check(buy ~= nil, "speed coil price button shown")
M.getSignal(buy, "Activated"):Fire()
M.advance(0.5)
check(S.profile.perks.speed_coil == true, "buying through the UI reaches the server")
Menus.close()

-- tower travel button + floor list
local travel = findText(gui, function(t) return t == "TO TOWER" end)
M.getSignal(travel, "Activated"):Fire()
M.advance(1)
eq(S.inTower, true, "travel button sends you to the tower")
check(State.data.inTower == true and findText(gui, function(t) return t == "TO PLOT" end), "HUD switches to TO PLOT")
Menus.open("tower"); M.advance(0.3)
local goBtns = 0
for _, b in gui["Tower"]:GetDescendants() do if b:IsA("TextButton") and b.Text == "GO" then goBtns += 1 end end
eq(goBtns, 1, "only the reached floor can be entered")
Menus.close()

-- zones: sky + particles follow the floor you stand on
local ZoneFx = require(Client.ZoneFx)
eq(ZoneFx.zoneOf(Vector3.new(0, 1, 0)), 0, "hub zone")
local pad4 = workspace.World.Tower:FindFirstChild("Checkpoint:4", true)
eq(ZoneFx.zoneOf(pad4.Position + Vector3.new(0, 3, 0)), 4, "zone at floor 4")
eq(ZoneFx.zoneOf(workspace.World.Tower:FindFirstChild("Summit", true).Position + Vector3.new(0, 3, 0)), 12, "zone at the summit")
local lighting = game:GetService("Lighting")
local clock0 = lighting.ClockTime
M.teleport(P, pad4.Position.X, pad4.Position.Y + 3, pad4.Position.Z)
M.advance(6)
check(math.abs(lighting.ClockTime - Config.Floors[4].sky.clock) < math.abs(clock0 - Config.Floors[4].sky.clock), "lighting eases towards floor 4's sky")
local vol = workspace:FindFirstChild("ZoneFxVolume")
check(vol and vol:FindFirstChildOfClass("ParticleEmitter").Acceleration.Y < 0, "snow falls on the frost floor")

-- cosmetics for every player
P:SetAttribute("Trail", "trail_3"); P:SetAttribute("Aura", "aura_spark")
M.advance(1)
local hrp = P.Character.HumanoidRootPart
check(hrp:FindFirstChildOfClass("Trail") ~= nil, "trail appears")
check(P.Character:FindFirstChild("NfAura", true) ~= nil, "aura appears")
check(P.Character.Head:FindFirstChild("NfPlate") ~= nil, "name plate appears")
P:SetAttribute("Trail", "")
M.advance(0.5)
check(hrp:FindFirstChildOfClass("Trail") == nil, "trail removed when unequipped")

-- movement: bounce launch + double jump
M.fireServerAs(game.ReplicatedStorage.Remotes.Jumped2, P)
M.getSignal(game.ReplicatedStorage.Remotes.Launch, "OnClientEvent"):Fire(105)
eq(hrp.AssemblyLinearVelocity.Y, 105, "launch pad applies the impulse")
hrp.AssemblyLinearVelocity = Vector3.zero
P:SetAttribute("DoubleJump", true)
local hum = P.Character.Humanoid
local UIS = game:GetService("UserInputService")
M.getSignal(hum, "StateChanged"):Fire(Enum.HumanoidStateType.Running, Enum.HumanoidStateType.Jumping)
M.data[hum].state = "Freefall"
M.getSignal(UIS, "JumpRequest"):Fire(); M.advance(0.1)
check(hrp.AssemblyLinearVelocity.Y > 40, "double jump gives an extra boost")
hrp.AssemblyLinearVelocity = Vector3.zero
M.getSignal(UIS, "JumpRequest"):Fire(); M.advance(0.1)
eq(hrp.AssemblyLinearVelocity.Y, 0, "only one extra jump per air time")

-- feedback
local notify = game.ReplicatedStorage.Remotes.Notify
M.getSignal(notify, "OnClientEvent"):Fire({ kind = "floorClear", floor = 3, name = "Lava Forge", crowns = 3, cash = 1234, first = true })
M.getSignal(notify, "OnClientEvent"):Fire({ kind = "coin", cash = 18 })
M.getSignal(notify, "OnClientEvent"):Fire({ kind = "overdrive", count = 1 })
M.getSignal(notify, "OnClientEvent"):Fire({ kind = "unlock", what = "trail", id = "trail_2" })
M.getSignal(notify, "OnClientEvent"):Fire({ kind = "death" })
M.advance(0.5)
check(findText(gui, function(t) return t:find("FLOOR 3 CLEARED") ~= nil end), "floor clear banner")
M.advance(12)
eq(#M.errors, 0, "feedback runs clean: " .. table.concat(M.errors, "\n"))

-- coins spin (baked parts animated locally)
local coin = workspace.World.Tower:FindFirstChild("Coin", true)
M.teleport(P, coin.Position.X + 5, coin.Position.Y, coin.Position.Z)
workspace.CurrentCamera.CFrame = CFrame.new(coin.Position + Vector3.new(0, 5, 20))
local before = coin.CFrame
M.advance(1)
check(coin.CFrame ~= before, "coins animate locally near the camera")

print(fails == 0 and "client_test: PASS" or ("client_test: " .. fails .. " FAILURES"))
if #M.errors > 0 then print("script errors:\n" .. table.concat(M.errors, "\n")); fails += 1 end
if fails > 0 then error("failed") end
