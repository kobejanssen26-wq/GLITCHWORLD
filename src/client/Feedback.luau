-- Reaction to server Notify events: toasts, banners, floating numbers, screen flashes, confetti and sounds.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local UIKit = require(script.Parent.UIKit)
local Sfx = require(script.Parent.Sfx)
local State = require(script.Parent.State)

local Feedback = {}
local T = UIKit.theme

local toastHolder: Frame, bannerHolder: Frame, flash: Frame
local bannerQueue: { { title: string, sub: string, color: Color3 } } = {}
local bannerBusy = false
local toasts: { Frame } = {}
local shakeFn: ((number, number) -> ())? = nil
local confettiFn: (() -> ())? = nil
local lastCoin, coinCombo = 0, 0

-- other modules plug their effects in here (avoids circular requires)
function Feedback.setEffects(shake: (number, number) -> (), confetti: () -> ())
	shakeFn, confettiFn = shake, confetti
end

local function localRoot(): BasePart?
	local c = Players.LocalPlayer.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Feedback.toast(text: string, tone: string?)
	local color = if tone == "good" then T.good elseif tone == "warn" then T.warn elseif tone == "bad" then T.bad else T.cyan
	local f = UIKit.new("Frame", {
		Size = UDim2.new(1, 0, 0, UIKit.px(34)), BackgroundColor3 = T.bg, BackgroundTransparency = 0.1, BorderSizePixel = 0, LayoutOrder = math.floor(os.clock() * 100), Parent = toastHolder,
	}, { UIKit.corner(10), UIKit.stroke(color, 1.5, 0.1) })
	UIKit.label({ Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0), Text = text, TextSize = UIKit.px(13), Font = T.fontBold, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, Parent = f })
	table.insert(toasts, f)
	while #toasts > 3 do
		local old = table.remove(toasts, 1)
		if old then
			old:Destroy()
		end
	end
	task.delay(3.4, function()
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
				Size = UDim2.fromOffset(math.floor(400 * UIKit.factor()), UIKit.px(96)), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -140),
				BackgroundColor3 = T.bg, BackgroundTransparency = 0.04, BorderSizePixel = 0, Parent = bannerHolder,
			}, { UIKit.corner(14), UIKit.stroke(b.color, 3, 0) })
			UIKit.title({ Size = UDim2.new(1, -16, 0, UIKit.px(38)), Position = UDim2.fromOffset(8, 6), Text = b.title, TextSize = UIKit.px(26), TextColor3 = b.color, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, Parent = f })
			UIKit.label({ Size = UDim2.new(1, -16, 0, UIKit.px(44)), Position = UDim2.fromOffset(8, UIKit.px(44)), Text = b.sub, TextSize = UIKit.px(13), TextXAlignment = Enum.TextXAlignment.Center, Parent = f })
			TweenService:Create(f, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0.2, 0) }):Play()
			task.wait(if #bannerQueue > 0 then 1.9 else 3.2)
			TweenService:Create(f, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0, -140) }):Play()
			task.wait(0.35)
			f:Destroy()
		end
		bannerBusy = false
	end)
end

function Feedback.banner(title: string, sub: string, color: Color3?)
	if #bannerQueue >= 3 then
		table.remove(bannerQueue, 1)
	end
	table.insert(bannerQueue, { title = title, sub = sub, color = color or T.cyan })
	runBanner()
end

function Feedback.flash(color: Color3, strength: number)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 1 - strength
	TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
end

-- rising number above a world position
function Feedback.floatAt(position: Vector3, text: string, color: Color3, size: number?)
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.Position = position
	anchor.Parent = Workspace
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(240, 50)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = anchor
	local l = UIKit.title({ Size = UDim2.fromScale(1, 1), Text = text, TextSize = size or UIKit.px(24), TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, Parent = gui })
	l.TextStrokeTransparency = 0.3
	TweenService:Create(anchor, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = position + Vector3.new(0, 6, 0) }):Play()
	TweenService:Create(l, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, 1.2)
end

local function rewardLine(n: any): string
	local parts = {}
	if n.crowns and n.crowns > 0 then
		table.insert(parts, ("+%d Crowns"):format(n.crowns))
	end
	if n.cash and n.cash > 0 then
		table.insert(parts, ("+$%s"):format(UIKit.fmt(n.cash)))
	end
	return table.concat(parts, "   ")
end

local handlers: { [string]: (any) -> () } = {}

handlers.bought = function(n)
	Sfx.play("buy")
	Feedback.toast("Machine online: " .. n.name, "good")
	local hrp = localRoot()
	if hrp then
		Feedback.floatAt(hrp.Position + Vector3.new(0, 5, 0), n.name, T.cyan, UIKit.px(20))
	end
end

handlers.perk = function(n)
	Sfx.play("unlock")
	for _, p in Config.Perks do
		if p.id == n.id then
			Feedback.banner("Perk unlocked", p.name .. ": " .. p.desc, T.cyan)
		end
	end
end

handlers.overdrive = function(n)
	Sfx.play("overdrive")
	Feedback.flash(Color3.new(1, 1, 1), 0.85)
	Feedback.banner("OVERDRIVE x" .. n.count, ("Your factory restarts with +%d%% cash forever."):format(Config.Tycoon.OVERDRIVE_BONUS * 100 * n.count), T.magenta)
	if shakeFn then
		shakeFn(0.8, 0.8)
	end
	if confettiFn then
		confettiFn()
	end
end

handlers.floorClear = function(n)
	Sfx.play("floor_clear")
	Feedback.flash(T.gold, 0.35)
	local title = if n.summit then "TOWER CONQUERED!" elseif n.first then ("FLOOR %d CLEARED!"):format(n.floor) else ("Floor %d again"):format(n.floor)
	Feedback.banner(title, n.name .. (if rewardLine(n) ~= "" then "\n" .. rewardLine(n) else ""), T.gold)
	if confettiFn and n.first then
		confettiFn()
	end
end

handlers.checkpoint = function(n)
	Sfx.play("checkpoint")
	Feedback.toast(("Checkpoint saved: floor %d, %s"):format(n.floor, n.name), "good")
end

handlers.coin = function(n)
	local now = os.clock()
	coinCombo = if now - lastCoin < 1.4 then math.min(coinCombo + 1, 10) else 0
	lastCoin = now
	Sfx.play("coin", 1 + coinCombo * 0.06)
	local hrp = localRoot()
	if hrp then
		Feedback.floatAt(hrp.Position + Vector3.new(0, 4, 0), "+$" .. UIKit.fmt(n.cash), T.gold, UIKit.px(18))
	end
end

handlers.death = function()
	Sfx.play("death")
	Feedback.flash(T.bad, 0.4)
	if shakeFn then
		shakeFn(0.5, 0.35)
	end
end

handlers.unlock = function(n)
	Sfx.play("unlock")
	local label = if n.what == "trail" then "New trail unlocked" elseif n.what == "aura" then "New aura unlocked" else "New title earned"
	local name = n.id
	for _, list in { Config.Trails, Config.Auras } do
		for _, e in list do
			if e.id == n.id then
				name = e.name
			end
		end
	end
	Feedback.banner(label, name .. (if n.what ~= "title" then "\nOpen the Style menu to wear it." else ""), T.magenta)
end

handlers.fx = function(n)
	if n.what == "bounce" then
		Sfx.play("bounce")
	elseif n.what == "speed" then
		Sfx.play("speed")
	end
end

handlers.msg = function(n)
	if n.tone == "warn" then
		Sfx.play("deny")
	end
	Feedback.toast(n.text, n.tone)
end

function Feedback.init(gui: ScreenGui)
	local f = UIKit.factor()
	toastHolder = UIKit.new("Frame", {
		Name = "Toasts", Size = UDim2.fromOffset(math.floor((if UIKit.isTouch() then 280 else 380) * f), 0), AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(0.5, 0, 1, -math.floor(64 * f)), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, Parent = gui,
	})
	UIKit.list(toastHolder, 4).VerticalAlignment = Enum.VerticalAlignment.Bottom
	bannerHolder = UIKit.new("Frame", { Name = "Banners", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	flash = UIKit.new("Frame", { Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 50, Active = false, Parent = gui })
	Remotes.get("Notify").OnClientEvent:Connect(function(n)
		local h = type(n) == "table" and handlers[n.kind]
		if h then
			h(n)
		end
	end)
	local lastCashSound = 0
	Remotes.get("CashTick").OnClientEvent:Connect(function(amount: number)
		local now = os.clock()
		if State.data and amount > 0 and now - lastCashSound > 1.1 then
			lastCashSound = now
			Sfx.play("cash", 1 + math.min(amount / 5e6, 0.5))
		end
	end)
end

return Feedback
