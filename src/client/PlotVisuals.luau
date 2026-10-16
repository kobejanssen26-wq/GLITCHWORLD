-- Draws the factory ores. Ores are not server parts: each client reproduces the deterministic schedule the server
-- uses for income (dropper phase + interval on the shared server clock), so what you see is what you earn.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local State = require(script.Parent.State)
local UIKit = require(script.Parent.UIKit)
local Feedback = require(script.Parent.Feedback)

local PlotVisuals = {}

local FALL_TIME, COLLECTOR_X = 0.45, 35
local DRAW_RANGE = 340
local BELT_Y = Config.Plots.BELT_Y

local pool: { [Instance]: { BasePart } } = {}
local function ensurePool(folder: Instance, n: number): { BasePart }
	local list = pool[folder]
	if not list then
		list = {}
		pool[folder] = list
	end
	while #list < n do
		local p = Instance.new("Part")
		p.Name = "Ore"
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(1.7, 1.7, 1.7)
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
		p.Material = Enum.Material.Neon
		p.Transparency = 1
		p.Parent = Workspace
		table.insert(list, p)
	end
	return list
end

local function phaseOf(id: string, interval: number): number
	local h = 0
	for i = 1, #id do
		h = (h * 31 + string.byte(id, i)) % 9973
	end
	return (h / 9973) * interval
end

local function updatePlot(folder: Folder, origin: CFrame, now: number)
	local used = 0
	local droppers = {}
	for _, it in Config.Items do
		if it.kind == "dropper" and folder:FindFirstChild(it.id) then
			table.insert(droppers, it)
		end
	end
	local list = ensurePool(folder, 40)
	for _, it in droppers do
		local transit = FALL_TIME + (COLLECTOR_X - it.x) / Config.Tycoon.BELT_SPEED
		local ph = phaseOf(it.id, it.interval)
		local first = math.ceil((now - transit - ph) / it.interval)
		local last = math.floor((now - ph) / it.interval)
		for n = first, last do
			local age = now - (n * it.interval + ph)
			if age >= 0 and age < transit and used < #list then
				used += 1
				local x, y
				if age < FALL_TIME then
					local k = age / FALL_TIME
					x, y = it.x, 10 + BELT_Y - (10 - 1.1) * k * k
				else
					x, y = it.x + (age - FALL_TIME) * Config.Tycoon.BELT_SPEED, BELT_Y + 1.1
				end
				local ore = list[used]
				ore.Color = Color3.fromRGB(it.color[1], it.color[2], it.color[3])
				ore.Transparency = 0
				ore.CFrame = origin * CFrame.new(x, y, 0)
			end
		end
	end
	for i = used + 1, #list do
		if list[i].Transparency ~= 1 then
			list[i].Transparency = 1
		end
	end
end

local function hideAll(folder: Instance)
	local list = pool[folder]
	if list then
		for _, p in list do
			p.Transparency = 1
		end
	end
end

function PlotVisuals.init()
	local factories = Workspace:WaitForChild("Factories")
	local player = Players.LocalPlayer
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc < 1 / 30 then
			return
		end
		acc = 0
		local cam = Workspace.CurrentCamera
		local now = Workspace:GetServerTimeNow()
		for _, folder in factories:GetChildren() do
			local origin = folder:GetAttribute("Origin")
			if typeof(origin) == "CFrame" and cam and (origin.Position - cam.CFrame.Position).Magnitude < DRAW_RANGE and folder:FindFirstChild("Belt") then
				updatePlot(folder :: Folder, origin, now)
			else
				hideAll(folder)
			end
		end
	end)

	-- income feedback at the collector of your own plot
	Remotes.get("CashTick").OnClientEvent:Connect(function(amount: number)
		local d = State.data
		local idx = d and d.plot
		if not idx or amount <= 0 then
			return
		end
		local folder = factories:FindFirstChild("Plot" .. idx)
		local origin = folder and folder:GetAttribute("Origin")
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if typeof(origin) == "CFrame" and hrp then
			local at = (origin * CFrame.new(COLLECTOR_X, BELT_Y + 8, 0)).Position
			if (hrp.Position - at).Magnitude < 130 then
				Feedback.floatAt(at, "+$" .. UIKit.fmt(amount), UIKit.theme.gold, UIKit.px(20))
			end
		end
	end)
end

return PlotVisuals
