-- Full-stack smoke test: real server + real client under the mock, one player. Drives the UI and the absorber
-- through input events and checks what the client built / reacted to.
local M = __M
local Shared = game.ReplicatedStorage.Shared
local WorldData = require(Shared.WorldData)
local Config = require(Shared.Config)
M.heightFn = WorldData.heightAt

local fails = 0
local function check(c, msg) if not c then fails += 1; print("FAIL: " .. msg) end end
local function eq(a, b, msg) check(a == b, ("%s (got %s, expected %s)"):format(msg, tostring(a), tostring(b))) end

task.spawn(require(game.ServerScriptService.Server.Main))
M.advance(8)
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
check(State.data ~= nil, "client received the first snapshot")
eq(#M.errors, 0, "no errors during client boot: " .. table.concat(M.errors, "\n"))
local gui = P.PlayerGui:FindFirstChild("GlitchWorldUI")
check(gui ~= nil, "UI root built")

-- HUD content comes from the server snapshot
local function findText(root, pred)
	for _, d in root:GetDescendants() do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and pred(d.Text) then return d end
	end
end
check(findText(gui, function(t) return t == "0" end) ~= nil, "credits label shows 0")
check(findText(gui, function(t) return t:find("Backpack 0 / 40") ~= nil end) ~= nil, "backpack bar text")
check(findText(gui, function(t) return t == "Collect Glitch Fragments" end) ~= nil, "objective card shows the first quest")
check(findText(gui, function(t) return t:find("0%% restored") ~= nil end) ~= nil, "valley percent")
check(workspace:FindFirstChild("ObjectiveBeacon") ~= nil, "objective beacon created")

-- every menu opens and renders in a fresh state
for _, name in { "equipment", "echoes", "research", "goals", "settings" } do
	Menus.open(name)
	M.advance(0.3)
	check(Menus.current() == name, "menu opens: " .. name)
end
Menus.close()
eq(#M.errors, 0, "menus render without errors: " .. table.concat(M.errors, "\n"))

-- input -> absorb -> server -> client visuals, end to end
local g = WorldData.ById.start_grass_1
M.teleport(P, g.x + 3, 6, g.z)
local cam = workspace.CurrentCamera
local root = M.methods.FindFirstChild(workspace.World.Targets, "T_start_grass_1")
local rootPos = root.Root.Position
cam.CFrame = CFrame.lookAt(rootPos + Vector3.new(8, 8, 8), rootPos + Vector3.new(0, 2, 0))
local UIS = game:GetService("UserInputService")
local TV = require(Client.TargetVisuals)
check(TV.entries.start_grass_1 ~= nil, "target visuals registered the grass")
local corrupted = TV.entries.start_grass_1.corrupted
check(corrupted[1].LocalTransparencyModifier == 0, "grass starts corrupted-visible")
local function input(kind, code)
	return { UserInputType = Enum.UserInputType[kind], KeyCode = Enum.KeyCode[code or "Unknown"] }
end
local mouseDown = input("MouseButton1")
M.getSignal(UIS, "InputBegan"):Fire(mouseDown, false)
M.advance(2)
check(S.absorb ~= nil and S.absorb.id == "start_grass_1", "server received start from the client aim")
M.advance(6)
check(S.profile.restored.start_grass_1 == true, "server restored the grass")
M.advance(1)
M.getSignal(UIS, "InputEnded"):Fire(mouseDown, false)
M.advance(1)
check(State.restored.start_grass_1 == true, "client state shows restored")
check(corrupted[1].LocalTransparencyModifier == 1, "corrupted look hidden after restoration")
local restoredParts = TV.entries.start_grass_1.restored
check(restoredParts[1].LocalTransparencyModifier == 0, "restored look visible after restoration")
check(State.data.counters.targetsRestored == 1, "snapshot updated")
-- feedback was produced
local toastCount = 0
local holder = gui:FindFirstChild("Toasts")
check(holder ~= nil, "toast holder exists")

-- sell + buy through the UI paths
S.profile.fragments, S.profile.stats.fragmentsCollected = 60, 60
require(Server.ProgressService).commit(S)
M.teleport(P, WorldData.Stations.sell.x, 6, WorldData.Stations.sell.z + 4)
local prompt
for _, d in workspace.World.Stations:GetDescendants() do
	if d:IsA("ProximityPrompt") and d:GetAttribute("Action") == "sell" then prompt = d end
end
M.advance(1)
M.getSignal(prompt, "Triggered"):Fire(P)
M.advance(1)
eq(S.profile.fragments, 0, "sell prompt converts fragments")
check(State.data.credits > 0 and findText(gui, function(t) return t == UIKit.fmt(State.data.credits) end) ~= nil, "HUD shows the new credits")

-- gamepad/touch absorb input path does not error
M.getSignal(UIS, "InputBegan"):Fire(input("Gamepad1", "ButtonR2"), false)
M.advance(1)
M.getSignal(UIS, "InputEnded"):Fire(input("Gamepad1", "ButtonR2"), false)
M.advance(1)

-- echo followers render for equipped echoes
S.profile.echoes.mossbit = true; S.profile.equipped = { "mossbit" }
require(Server.ProgressService).commit(S)
M.advance(1)
local ef = workspace:FindFirstChild("EchoFollowers")
check(ef ~= nil and #ef:GetChildren() == 1, "echo follower model created")
S.profile.equipped = {}
require(Server.ProgressService).commit(S); M.advance(0.5)
eq(#ef:GetChildren(), 0, "follower removed when unequipped")

-- ambience eases toward the saved restoration percent
local Lighting = game:GetService("Lighting")
local b0 = Lighting.Brightness
for _, t in WorldData.Targets do if (Config.Targets[t.type].weight or 0) > 0 and t.type ~= "ruin" then S.profile.restored[t.id] = true end end
require(Server.ProgressService).commit(S)
M.advance(8)
check(Lighting.Brightness > b0 + 0.2, "world brightens as restoration grows")
check(M.terrain.colors.Grass and M.terrain.colors.Grass.G > 0.5, "terrain turns green")
-- the panels again with a rich state
for _, name in { "equipment", "echoes", "research", "goals", "settings" } do Menus.open(name); M.advance(0.3) end
Menus.close()

print(fails == 0 and "client_test: PASS" or ("client_test: " .. fails .. " FAILURES"))
if #M.errors > 0 then print("script errors:\n" .. table.concat(M.errors, "\n")); fails += 1 end
if fails > 0 then error("failed") end
