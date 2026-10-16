-- NEONFORGE client entry point. Every system starts in its own pcall so one failure cannot take the interface down.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Client = script.Parent
local State = require(Client.State)
local UIKit = require(Client.UIKit)
local Sfx = require(Client.Sfx)

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "NeonforgeUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

UIKit.onClickSound = function()
	Sfx.play("click")
end

local function safe(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		warn(("[Neonforge] %s failed to start: %s"):format(name, tostring(err)))
	end
end

task.spawn(function()
	for _ = 1, 10 do -- the default hotbar / health bar are not used by this game
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		end)
		if ok then
			return
		end
		task.wait(0.5)
	end
end)

Remotes.get("State").OnClientEvent:Connect(function(snapshot)
	State.set(snapshot)
end)

safe("HUD", function()
	require(Client.Hud).build(gui)
end)
local Feedback
safe("Feedback", function()
	Feedback = require(Client.Feedback)
	Feedback.init(gui)
end)
local toast = function(text: string, tone: string?)
	if Feedback then
		Feedback.toast(text, tone)
	end
end
safe("Panels", function()
	require(Client.ShopPanel).create(gui, toast)
	require(Client.TowerPanel).create(gui, toast)
	require(Client.StylePanel).create(gui)
	require(Client.SettingsPanel).create(gui)
end)
safe("PlayerFx", function()
	require(Client.PlayerFx).init()
end)
safe("Movement", function()
	require(Client.Movement).init()
end)
safe("PlotVisuals", function()
	require(Client.PlotVisuals).init()
end)
safe("Animator", function()
	require(Client.Animator).init()
end)
safe("ZoneFx", function()
	require(Client.ZoneFx).init()
end)

-- tell the server every handler is connected: only now does it send the initial state
Remotes.get("ClientReady"):FireServer()
