-- Reaction to server Notify events: toasts, milestone banners, world-space effects (bounded) and sounds.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local UIKit = require(script.Parent.UIKit)
local Sfx = require(script.Parent.Sfx)
local TargetVisuals = require(script.Parent.TargetVisuals)

local Feedback = {}
local T = UIKit.theme

local MAX_FLYERS = 24
local activeFlyers = 0

local toastHolder: Frame, bannerHolder: Frame
local bannerQueue: { { title: string, sub: string, color: Color3 } } = {}
local bannerBusy = false
local toasts: { Frame } = {}

local function itemName(category: string, id: string): string
	local lists = { absorber = Config.Absorber, backpack = Config.Backpack, boots = Config.Boots, gadget = Config.Gadgets }
	for _, it in lists[category] or {} do
		if it.id == id then
			return it.name
		end
	end
	return id
end

local function echoName(id: string): (string, string)
	for _, e in Config.Echoes do
		if e.id == id then
			return e.name, e.rarity
		end
	end
	return id, "common"
end

function Feedback.toast(text: string, tone: string?)
	local color = if tone == "good" then T.good elseif tone == "warn" then T.warn elseif tone == "bad" then T.bad else T.cyan
	local f = UIKit.new("Frame", {
		Size = UDim2.new(1, 0, 0, UIKit.px(34)), BackgroundColor3 = T.bg, BackgroundTransparency = 0.12, BorderSizePixel = 0, LayoutOrder = math.floor(os.clock() * 100), Parent = toastHolder,
	}, { UIKit.corner(8), UIKit.stroke(color, 1.5, 0.15) })
	UIKit.label({ Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0), Text = text, TextSize = UIKit.px(14), Font = T.fontBold, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, Parent = f })
	table.insert(toasts, f)
	while #toasts > 3 do
		local old = table.remove(toasts, 1)
		if old then
			old:Destroy()
		end
	end
	task.delay(3.6, function()
		if f.Parent then
			TweenService:Create(f, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
			for _, d in f:GetDescendants() do
				if d:IsA("TextLabel") then
					TweenService:Create(d, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
				elseif d:IsA("UIStroke") then
					TweenService:Create(d, TweenInfo.new(0.35), { Transparency = 1 }):Play()
				end
			end
			task.delay(0.4, function()
				local i = table.find(toasts, f)
				if i then
					table.remove(toasts, i)
				end
				f:Destroy()
			end)
		end
	end)
end

local function runBanner()
	if bannerBusy then
		return
	end
	bannerBusy = true
	task.spawn(function()
		while #bannerQueue > 0 do
			local b = table.remove(bannerQueue, 1) :: any
			local f = UIKit.new("Frame", {
				Size = UDim2.fromOffset(math.floor(380 * UIKit.factor()), UIKit.px(92)), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -90), BackgroundColor3 = T.bg,
				BackgroundTransparency = 0.05, BorderSizePixel = 0, Parent = bannerHolder,
			}, { UIKit.corner(12), UIKit.stroke(b.color, 2.5, 0) })
			UIKit.title({ Size = UDim2.new(1, -16, 0, UIKit.px(34)), Position = UDim2.fromOffset(8, 6), Text = b.title, TextSize = UIKit.px(22), TextColor3 = b.color, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, Parent = f })
			UIKit.label({ Size = UDim2.new(1, -16, 0, UIKit.px(44)), Position = UDim2.new(0, 8, 0, UIKit.px(40)), Text = b.sub, TextSize = UIKit.px(13), TextColor3 = T.text, TextXAlignment = Enum.TextXAlignment.Center, Parent = f })
			TweenService:Create(f, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0.2, 0) }):Play()
			task.wait(if #bannerQueue > 0 then 2.0 else 3.0)
			TweenService:Create(f, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0, -90) }):Play()
			task.wait(0.35)
			f:Destroy()
		end
		bannerBusy = false
	end)
end

function Feedback.banner(title: string, sub: string, color: Color3?)
	if #bannerQueue >= 4 then
		table.remove(bannerQueue, 1) -- never build a long backlog of pop-ups
	end
	table.insert(bannerQueue, { title = title, sub = sub, color = color or T.cyan })
	runBanner()
end

local function rewardText(r: any): string
	local parts = {}
	if r.credits then
		table.insert(parts, ("+%s Credits"):format(UIKit.fmt(r.credits)))
	end
	if r.xp then
		table.insert(parts, ("+%d XP"):format(r.xp))
	end
	if r.rp then
		table.insert(parts, ("+%d Research Point%s"):format(r.rp, if r.rp > 1 then "s" else ""))
	end
	if r.echo then
		table.insert(parts, "Echo: " .. echoName(r.echo))
	end
	if r.title then
		table.insert(parts, ("Title: %s"):format(r.title))
	end
	return table.concat(parts, "   ")
end

-- ===== world-space effects (bounded) =====
local function localRoot(): BasePart?
	local c = Players.LocalPlayer.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function burst(position: Vector3, color: Color3)
	local ring = Instance.new("Part")
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch, ring.CastShadow = true, false, false, false, false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.25
	ring.Size = Vector3.new(0.3, 2, 2)
	ring.CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = Workspace
	TweenService:Create(ring, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.3, 16, 16), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.8)
end

local function flyFragments(from: Vector3, count: number)
	local hrp = localRoot()
	if not hrp then
		return
	end
	for i = 1, math.min(count, 6) do
		if activeFlyers >= MAX_FLYERS then
			return
		end
		activeFlyers += 1
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Size = Vector3.new(0.5, 0.5, 0.5)
		p.Material = Enum.Material.Neon
		p.Color = if i % 2 == 0 then Config.Colors.glitchCyan else Config.Colors.glitchPurple
		local start = from + Vector3.new((math.random() - 0.5) * 3, 1 + math.random() * 3, (math.random() - 0.5) * 3)
		p.CFrame = CFrame.new(start)
		p.Parent = Workspace
		local tween = TweenService:Create(p, TweenInfo.new(0.55 + math.random() * 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(hrp.Position + Vector3.new(0, 1, 0)), Size = Vector3.new(0.1, 0.1, 0.1) })
		tween.Completed:Once(function()
			p:Destroy()
			activeFlyers -= 1
		end)
		tween:Play()
	end
end

local function floatText(position: Vector3, text: string, color: Color3)
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.Position = position + Vector3.new(0, 3, 0)
	anchor.Parent = Workspace
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 40)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = anchor
	local l = UIKit.title({ Size = UDim2.fromScale(1, 1), Text = text, TextSize = UIKit.px(22), TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, Parent = gui })
	l.TextStrokeTransparency = 0.3
	TweenService:Create(anchor, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = anchor.Position + Vector3.new(0, 5, 0) }):Play()
	TweenService:Create(l, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, 1.2)
end

local handlers: { [string]: (any) -> () } = {}

handlers.restored = function(n)
	local entry = TargetVisuals.entries[n.id]
	local def = Config.Targets[n.type]
	local hrp = localRoot()
	local pos = if entry then entry.root.Position elseif hrp then hrp.Position else Vector3.zero
	burst(pos, if def and def.category == "echo" then Config.Colors.glitchCyan else Color3.fromRGB(120, 255, 150))
	Sfx.play("restored")
	if n.fragments > 0 then
		flyFragments(pos, math.ceil(math.min(6, n.fragments / 4)))
		floatText(pos, ("+%d fragments"):format(n.fragments), T.cyan)
	elseif n.xp then
		floatText(pos, ("+%d XP"):format(n.xp), T.good)
	end
	if n.overflowCredits and n.overflowCredits > 0 then
		Feedback.toast(("Backpack full: %d fragments auto-sold for %d Credits"):format(n.fragments - n.stored, n.overflowCredits), "warn")
	end
end

handlers.sold = function(n)
	Sfx.play("sell")
	Feedback.toast(("Sold %s fragments for %s Credits"):format(UIKit.fmt(n.fragments), UIKit.fmt(n.credits)), "good")
end

handlers.bought = function(n)
	Sfx.play("buy")
	Feedback.toast("Purchased: " .. itemName(n.category, n.id), "good")
end

handlers.researched = function(n)
	Sfx.play("buy")
	for _, node in Config.Research.nodes do
		if node.id == n.id then
			Feedback.toast("Research complete: " .. node.name, "good")
		end
	end
end

handlers.secret = function(n)
	Sfx.play("collect", 1.3)
	Feedback.toast(("Hidden fragment found!  +%d Credits  +%d XP"):format(n.credits, n.xp), "good")
end

handlers.quest = function(n)
	Sfx.play("milestone", 1.3)
	Feedback.banner("Objective complete", n.title .. "   " .. rewardText(n.reward), T.good)
end

handlers.milestone = function(n)
	Sfx.play("milestone")
	Feedback.banner("Milestone: " .. n.name, rewardText(n.reward), T.warn)
end

handlers.echo = function(n)
	Sfx.play("echo")
	local name, rarity = echoName(n.id)
	Feedback.banner("Echo discovered: " .. name, Config.Rarity[rarity].name .. " Echo. Open the Echo Index to equip it.", Config.Rarity[rarity].color)
end

handlers.rank = function(n)
	Sfx.play("milestone", 1.15)
	Feedback.banner("Rank " .. n.rank, ("%s   +%d Credits  +%d Research Point"):format(n.title, n.credits, n.rp), T.purple)
end

handlers.unlock = function(n)
	Sfx.play("milestone", 0.8)
	local area = Config.Areas[n.id]
	Feedback.banner("Gateway awakened", (area and area.name or n.id) .. " is now reachable. Walk north.", T.cyan)
end

handlers.msg = function(n)
	if n.tone == "warn" then
		Sfx.play("deny")
	end
	Feedback.toast(n.text, n.tone)
end

function Feedback.init(gui: ScreenGui)
	local f = UIKit.factor()
	-- toasts stack upward from the bottom centre, above the contextual hint line
	toastHolder = UIKit.new("Frame", {
		Name = "Toasts", Size = UDim2.fromOffset(math.floor((if UIKit.isTouch() then 280 else 360) * f), 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(0.5, 0, 1, -math.floor(120 * f)),
		AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, Parent = gui,
	})
	UIKit.list(toastHolder, 4).VerticalAlignment = Enum.VerticalAlignment.Bottom
	bannerHolder = UIKit.new("Frame", { Name = "Banners", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	Remotes.get("Notify").OnClientEvent:Connect(function(n)
		local h = type(n) == "table" and handlers[n.kind]
		if h then
			h(n)
		end
	end)
end

return Feedback
