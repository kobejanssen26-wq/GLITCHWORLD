-- Compact HUD: credits / backpack / rank (top-left), objective (top-centre), valley % (top-right),
-- menu buttons (right), contextual hint + mobile buttons (bottom). Everything is read from the server snapshot.
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)
local Menus = require(script.Parent.Menus)

local Hud = {}
local T = UIKit.theme

local refs: { [string]: any } = {}
local menuButtons: { [string]: TextButton } = {}
local dots: { [string]: Frame } = {}

local function card(parent: Instance, size: UDim2, pos: UDim2?, anchor: Vector2?): Frame
	return UIKit.new("Frame", {
		Size = size, Position = pos or UDim2.new(), AnchorPoint = anchor or Vector2.new(0, 0),
		BackgroundColor3 = T.bg, BackgroundTransparency = 0.18, BorderSizePixel = 0, Active = true, Parent = parent,
	}, { UIKit.corner(10), UIKit.stroke(T.panel2, 1.5, 0.2) })
end

function Hud.build(gui: ScreenGui)
	local touch = UIKit.isTouch()
	local f = UIKit.factor()

	-- ===== top-left: credits, backpack, rank =====
	local tl = card(gui, UDim2.fromOffset(math.floor(210 * f), math.floor(104 * f)), UDim2.fromOffset(10, 10))
	tl.Name = "StatsCard"
	UIKit.pad(8).Parent = tl
	local row1 = UIKit.new("Frame", { Size = UDim2.new(1, 0, 0, math.floor(30 * f)), BackgroundTransparency = 1, Parent = tl })
	UIKit.label({ Size = UDim2.new(0.42, 0, 1, 0), Text = "CREDITS", TextSize = UIKit.px(11), TextColor3 = T.dim, Font = T.fontBold, Parent = row1 })
	refs.credits = UIKit.title({ Size = UDim2.new(0.58, 0, 1, 0), Position = UDim2.fromScale(0.42, 0), Text = "0", TextSize = UIKit.px(24), TextColor3 = T.cyan, TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false, Parent = row1 })
	local bagBar, bagSet = UIKit.bar({ Size = UDim2.new(1, 0, 0, math.floor(18 * f)), Position = UDim2.new(0, 0, 0, math.floor(34 * f)), Parent = tl }, T.purple)
	refs.bag, refs.bagBar = bagSet, bagBar
	local _, rankSet = UIKit.bar({ Size = UDim2.new(1, 0, 0, math.floor(18 * f)), Position = UDim2.new(0, 0, 0, math.floor(58 * f)), Parent = tl }, T.good)
	refs.rank = rankSet

	-- ===== top-centre: objective =====
	local obj = card(gui, UDim2.fromOffset(math.floor(340 * f), math.floor(76 * f)), UDim2.new(0.5, 0, 0, 10), Vector2.new(0.5, 0))
	obj.Name = "ObjectiveCard"
	local oc = obj:FindFirstChildOfClass("UIStroke") :: UIStroke
	oc.Color = T.cyan
	oc.Transparency = 0.45
	UIKit.pad(8).Parent = obj
	refs.objTag = UIKit.label({ Size = UDim2.new(1, 0, 0, UIKit.px(12)), Text = "OBJECTIVE", TextSize = UIKit.px(10), TextColor3 = T.cyan, Font = T.fontBold, TextWrapped = false, Parent = obj })
	refs.objTitle = UIKit.title({ Size = UDim2.new(0.75, 0, 0, UIKit.px(20)), Position = UDim2.fromOffset(0, UIKit.px(12)), Text = "", TextSize = UIKit.px(17), TextWrapped = false, Parent = obj })
	refs.objDist = UIKit.label({ Size = UDim2.new(0.25, 0, 0, UIKit.px(20)), Position = UDim2.new(0.75, 0, 0, UIKit.px(12)), Text = "", TextSize = UIKit.px(13), TextColor3 = T.cyan, Font = T.fontBold, TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false, Parent = obj })
	refs.objText = UIKit.label({ Size = UDim2.new(1, 0, 0, UIKit.px(30)), Position = UDim2.fromOffset(0, UIKit.px(32)), Text = "", TextSize = UIKit.px(12), TextColor3 = T.dim, TextYAlignment = Enum.TextYAlignment.Top, Parent = obj })
	refs.objCard = obj
	local objBar, objSet = UIKit.bar({ Size = UDim2.new(1, 0, 0, 6), Position = UDim2.new(0, 0, 1, -6), Parent = obj }, T.cyan)
	refs.objBar, refs.objBarSet = objBar, objSet

	-- ===== top-right: valley restoration =====
	local tr = card(gui, UDim2.fromOffset(math.floor(190 * f), math.floor(66 * f)), UDim2.new(1, -10, 0, 10), Vector2.new(1, 0))
	tr.Name = "ValleyCard"
	UIKit.pad(8).Parent = tr
	refs.valleyTitle = UIKit.label({ Size = UDim2.new(1, 0, 0, UIKit.px(14)), Text = "THE GREEN VALLEY", TextSize = UIKit.px(11), TextColor3 = T.dim, Font = T.fontBold, TextWrapped = false, Parent = tr })
	local _, vSet = UIKit.bar({ Size = UDim2.new(1, 0, 0, math.floor(18 * f)), Position = UDim2.fromOffset(0, UIKit.px(18)), Parent = tr }, T.good)
	refs.valley = vSet
	refs.valleyNext = UIKit.label({ Size = UDim2.new(1, 0, 0, UIKit.px(14)), Position = UDim2.new(0, 0, 1, -UIKit.px(14)), Text = "", TextSize = UIKit.px(10), TextColor3 = T.dim, TextWrapped = false, Parent = tr })

	-- ===== menu buttons: right column on desktop, compact bar under the valley card on touch =====
	local defs = {
		{ "equipment", "Upgrades" }, { "echoes", "Echoes" }, { "research", "Research" }, { "goals", "Goals" }, { "settings", "Settings" },
	}
	local col
	if touch then
		col = UIKit.new("Frame", {
			Name = "MenuBar", Size = UDim2.fromOffset(5 * math.floor(64 * f) + 4 * 4, math.floor(30 * f)), Position = UDim2.new(1, -10, 0, 10 + math.floor(78 * f) + 4),
			AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1, Parent = gui,
		})
		UIKit.list(col, 4, true)
	else
		col = UIKit.new("Frame", { Name = "MenuColumn", Size = UDim2.fromOffset(math.floor(120 * f), 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), BackgroundTransparency = 1, Parent = gui })
		UIKit.list(col, 6)
	end
	for i, d in defs do
		local b = UIKit.button({
			Size = if touch then UDim2.fromOffset(math.floor(64 * f), math.floor(30 * f)) else UDim2.new(1, 0, 0, math.floor(34 * f)), Text = d[2], LayoutOrder = i,
			style = "ghost", BackgroundTransparency = 0.12, TextSize = if touch then 11 else UIKit.px(14), Parent = col,
		}, function()
			Menus.toggle(d[1])
		end)
		UIKit.stroke(T.panel2, 1.2, 0.2).Parent = b
		menuButtons[d[1]] = b
		dots[d[1]] = UIKit.new("Frame", { Size = UDim2.fromOffset(12, 12), Position = UDim2.new(1, -2, 0, 2), AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = T.warn, Visible = false, ZIndex = 5, Parent = b }, { UIKit.corner(6) })
	end

	-- ===== bottom-centre: contextual hint =====
	refs.hint = UIKit.label({
		Size = UDim2.fromOffset(math.floor((if touch then 280 else 420) * f), UIKit.px(22)), Position = UDim2.new(0.5, 0, 1, -math.floor((if touch then 92 else 78) * f)), AnchorPoint = Vector2.new(0.5, 1),
		Text = "", TextSize = UIKit.px(14), TextXAlignment = Enum.TextXAlignment.Center, Font = T.fontBold, TextStrokeTransparency = 0.5, TextWrapped = false, Parent = gui,
	})

	-- ===== touch buttons (absorb / overcharge); desktop gets key hints instead =====
	refs.absorbBtn = UIKit.new("TextButton", {
		Name = "AbsorbButton", Size = UDim2.fromOffset(math.floor(104 * f), math.floor(104 * f)), Position = UDim2.new(1, -math.floor(150 * f), 1, -math.floor(40 * f)), AnchorPoint = Vector2.new(1, 1),
		BackgroundColor3 = T.cyan, BackgroundTransparency = 0.15, Text = "ABSORB", Font = T.fontTitle, TextSize = UIKit.px(18), TextColor3 = Color3.fromRGB(14, 12, 28),
		AutoButtonColor = false, Visible = UserInputService.TouchEnabled, Parent = gui, -- also on touch laptops / hybrids
	}, { UIKit.corner(60), UIKit.stroke(Color3.new(1, 1, 1), 2, 0.4) })
	refs.boostBtn = UIKit.button({
		Name = "BoostButton", Size = UDim2.fromOffset(math.floor((if touch then 80 else 120) * f), math.floor((if touch then 80 else 38) * f)),
		Position = if touch then UDim2.new(1, -math.floor(150 * f), 1, -math.floor(160 * f)) else UDim2.new(0.5, math.floor(150 * f), 1, -math.floor(14 * f)),
		AnchorPoint = if touch then Vector2.new(1, 1) else Vector2.new(0.5, 1), Text = "OVERCHARGE", style = "primary", BackgroundColor3 = T.purple, TextColor3 = Color3.new(1, 1, 1),
		TextSize = UIKit.px(12), Visible = false, Parent = gui,
	}, function()
		Remotes.get("UseGadget"):FireServer("overcharge")
	end)
	if touch then
		(refs.boostBtn :: TextButton).Size = UDim2.fromOffset(math.floor(84 * f), math.floor(84 * f))
		UIKit.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = refs.boostBtn })
	end

	Hud.refresh()
	State.changed:Connect(Hud.refresh)
end

function Hud.setHint(text: string, color: Color3?)
	if refs.hint then
		refs.hint.Text = text
		refs.hint.TextColor3 = color or T.text
	end
end

function Hud.setObjectiveDistance(text: string)
	if refs.objDist then
		refs.objDist.Text = text
	end
end

function Hud.absorbButton(): TextButton?
	return refs.absorbBtn
end

local function nextMilestone(d: any): any?
	for _, m in Config.Milestones do
		if m.kind == "percent" and not d.milestones[m.id] then
			return m
		end
	end
	return nil
end

function Hud.refresh()
	local d = State.data
	if not d or not refs.credits then
		return
	end
	refs.credits.Text = UIKit.fmt(d.credits)
	local full = d.fragments >= d.stats.capacity
	refs.bag(d.fragments / d.stats.capacity, ("Backpack %s / %s%s"):format(UIKit.fmt(d.fragments), UIKit.fmt(d.stats.capacity), if full then "  FULL" else ""))
	refs.bagBar.UIStroke.Color = if d.fragments >= d.stats.capacity * 0.9 then T.warn else T.panel2
	if d.rankNeed > 0 then
		refs.rank(d.rankInto / d.rankNeed, ("Rank %d  %s"):format(d.rank, d.title))
	else
		refs.rank(1, ("Rank %d MAX  %s"):format(d.rank, d.title))
	end
	refs.valley(d.percent / 100, ("%.0f%% restored"):format(d.percent))
	local nm = nextMilestone(d)
	refs.valleyNext.Text = if nm then ("Next: %s (%d%%)"):format(nm.name, nm.value) else "Valley fully restored!"

	local o = d.objective
	refs.objTitle.Text = o.title
	refs.objText.Text = o.text
	if o.goal then
		refs.objBar.Visible = true
		refs.objBarSet(o.progress / o.goal)
	else
		refs.objBar.Visible = false
	end
	refs.objCard.Visible = d.settings.hints ~= false

	-- notification dots: affordable upgrade, spendable research, new unlockable echo slot
	local nextAb = Config.Absorber[d.tiers.absorber + 1]
	local nextBp = Config.Backpack[d.tiers.backpack + 1]
	local nextBt = Config.Boots[d.tiers.boots + 1]
	local canBuy = (nextAb and d.credits >= nextAb.price) or (nextBp and d.credits >= nextBp.price) or (nextBt and d.credits >= nextBt.price)
	dots.equipment.Visible = canBuy == true
	dots.research.Visible = d.rp > 0
	dots.goals.Visible = false
	local hasFreeSlot = #d.equipped < d.stats.echoSlots
	local hasOwned = false
	for id in d.echoes do
		if not table.find(d.equipped, id) then
			hasOwned = true
		end
	end
	dots.echoes.Visible = hasFreeSlot and hasOwned

	Hud.tick()
end

-- cheap per-0.25s update for values that count down locally (overcharge)
function Hud.tick()
	local d = State.data
	if not d or not refs.boostBtn then
		return
	end
	local owns = d.gadgets.overcharge == true
	refs.boostBtn.Visible = owns
	if owns then
		local elapsed = os.clock() - d._at
		local boost, cd = d.boostLeft - elapsed, d.gadgetCooldown - elapsed
		local touch = UIKit.isTouch()
		refs.boostBtn.Text = if boost > 0 then ("%ds"):format(math.ceil(boost)) elseif cd > 0 then ("%ds"):format(math.ceil(cd)) elseif touch then "BOOST" else "OVERCHARGE [Q]"
	end
end

return Hud
