-- GLITCHWORLD client entry point. Each system is initialised in its own pcall so one failure cannot take the
-- whole interface down (errors are warned, never swallowed).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Client = script.Parent
local State = require(Client.State)
local UIKit = require(Client.UIKit)
local Menus = require(Client.Menus)
local Sfx = require(Client.Sfx)

local StarterGui = game:GetService("StarterGui")
if not game:IsLoaded() then
	game.Loaded:Wait()
end
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "GlitchWorldUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

UIKit.onClickSound = function()
	Sfx.play("click")
end

local function safe(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		warn(("[GlitchWorld] %s failed to start: %s"):format(name, tostring(err)))
	end
end

-- the default hotbar / health bar are not used by this game
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

-- state first: everything else renders from it
Remotes.get("State").OnClientEvent:Connect(function(snapshot)
	State.set(snapshot)
end)

safe("TargetVisuals", function()
	require(Client.TargetVisuals).init()
end)
safe("HUD", function()
	require(Client.Hud).build(gui)
end)
safe("Feedback", function()
	require(Client.Feedback).init(gui)
end)
safe("Panels", function()
	require(Client.EquipmentPanel).create(gui)
	require(Client.EchoPanel).create(gui)
	require(Client.ResearchPanel).create(gui)
	require(Client.GoalsPanel).create(gui)
	require(Client.SettingsPanel).create(gui)
end)
safe("Absorber", function()
	require(Client.AbsorberController).init()
end)
safe("Beacon", function()
	require(Client.Beacon).init()
end)
safe("EchoFollowers", function()
	require(Client.EchoFollowers).init()
end)
safe("Ambience", function()
	require(Client.Ambience).init()
end)

-- station prompts ask the client to open a menu
Remotes.get("OpenMenu").OnClientEvent:Connect(function(name: string)
	Menus.open(if name == "echo" then "echoes" else name)
end)

-- countdown-driven HUD bits (overcharge button)
local Hud = require(Client.Hud)
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc >= 0.25 then
		acc = 0
		Hud.tick()
	end
end)

-- tell the server every handler is connected: only now does it send the initial state / restoration snapshot
Remotes.get("ClientReady"):FireServer()
