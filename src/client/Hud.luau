-- Compact HUD: cash / income / crowns (top-left), floor + objective (top-centre), title / overdrive (top-right),
-- menu buttons (right column on desktop, bar under the title card on touch), travel button (bottom-centre).
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
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
local dots: { [string]: Frame } = {}
local shownCash = 0

local function card(parent: Instance, name: string, size: UDim2, pos: UDim2, anchor: Vector2?): Frame
	return UIKit.new("Frame", {
		Name = name, Size = size, Position = pos, AnchorPoint = anchor or Vector2.new(0, 0), BackgroundColor3 = T.bg, BackgroundTransparency = 0.15,
		BorderSizePixel = 0, Active = true, Parent = parent,
	}, { UIKit.corner(12), UIKit.stroke(T.panel2, 1.5, 0.1) })
end

function Hud.build(gui: ScreenGui)
	local touch = UIKit.isTouch()
	local f = UIKit.factor()

	-- ===== top-left: cash =====
	local tl = card(gui, "StatsCard", UDim2.fromOffset(math.floor(215 * f), math.floor(92 * f)), UDim2.fromOffset(10, 10))
	UIKit.pad(8).Parent = tl
	refs.cash = UIKit.title({ Size = UDim2.new(1, 0, 0, math.floor(36 * f)), Text = "$0", TextSize = UIKit.px(32), TextColor3 = T.gold, TextWrapped = false, Parent = tl })
	refs.income = UIKit.label({
		Size = UDim2.new(1, 0, 0, UIKit.px(16)), Position = UDim2.fromOffset(0, math.floor(38 * f)), Text = "", TextSize = UIKit.px(13), TextColor3 = T.cyan,
		Font = T.fontBold, TextWrapped = false, Parent = tl,
	})
	refs.crowns = UIKit.label({
		Size = UDim2.new(1, 0, 0, UIKit.px(16)), Position = UDim2.fromOffset(0, math.floor(58 * f)), Text = "", TextSize = UIKit.px(13), TextColor3 = T.magenta,
		Font = T.fontBold, TextWrapped = false, Parent = tl,
	})

	-- ===== top-centre: floor + objective =====
	local fc = card(gui, "FloorCard", UDim2.fromOffset(math.floor(300 * f), math.floor(76 * f)), UDim2.new(0.5, 0, 0, 10), Vector2.new(0.5, 0))
	UIKit.pad(8).Parent = fc
	refs.floorCard = fc
	refs.floorTitle = UIKit.title({ Size = UDim2.new(1, 0, 0, UIKit.px(22)), Text = "", TextSize = UIKit.px(18), TextWrapped = false, Parent = fc })
	refs.objective = UIKit.label({
		Size = UDim2.new(1, 0, 0, UIKit.px(30)), Position = UDim2.fromOffset(0, UIKit.px(22)), Text = "", TextSize = UIKit.px(12), TextColor3 = T.dim,
		TextYAlignment = Enum.TextYAlignment.Top, Parent = fc,
	})
	local _, floorSet = UIKit.bar({ Size = UDim2.new(1, 0, 0, 6), Position = UDim2.new(0, 0, 1, -6), Parent = fc }, T.magenta)
	refs.floorBar = floorSet

	-- ===== top-right: title card =====
	local tr = card(gui, "TitleCard", UDim2.fromOffset(math.floor(190 * f), math.floor(66 * f)), UDim2.new(1, -10, 0, 10), Vector2.new(1, 0))
	UIKit.pad(8).Parent = tr
	refs.titleText = UIKit.label({ Size = UDim2.new(1, 0, 0, UIKit.px(18)), Text = "", TextSize = UIKit.px(14), Font = T.fontBold, TextColor3 = T.gold, TextWrapped = false, Parent = tr })
	refs.odText = UIKit.label({ Size = UDim2.new(1, 0, 0, UIKit.px(16)), Position = UDim2.fromOffset(0, UIKit.px(22)), Text = "", TextSize = UIKit.px(12), TextColor3 = T.dim, TextWrapped = false, Parent = tr })

	-- ===== menu buttons =====
	local defs = { { "shop", "Shop" }, { "tower", "Tower" }, { "style", "Style" }, { "settings", "Settings" } }
	local col
	if touch then
		col = UIKit.new("Frame", {
			Name = "MenuBar", Size = UDim2.fromOffset(4 * math.floor(64 * f) + 3 * 4, math.floor(30 * f)), Position = UDim2.new(1, -10, 0, 10 + math.floor(78 * f) + 4),
			AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1, Parent = gui,
		})
		UIKit.list(col, 4, true)
	else
		col = UIKit.new("Frame", {
			Name = "MenuColumn", Size = UDim2.fromOffset(math.floor(120 * f), 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(1, -10, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5), BackgroundTransparency = 1, Parent = gui,
		})
		UIKit.list(col, 6)
	end
	for i, d in defs do
		local b = UIKit.button({
			Size = if touch then UDim2.fromOffset(math.floor(64 * f), math.floor(30 * f)) else UDim2.new(1, 0, 0, math.floor(36 * f)), Text = d[2], LayoutOrder = i,
			style = "ghost", BackgroundTransparency = 0.1, TextSize = if touch then 11 else UIKit.px(14), Parent = col,
		}, function()
			Menus.toggle(d[1])
		end)
		UIKit.stroke(T.panel2, 1.2, 0.1).Parent = b
		dots[d[1]] = UIKit.new("Frame", { Size = UDim2.fromOffset(12, 12), Position = UDim2.new(1, -2, 0, 2), AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = T.warn, Visible = false, ZIndex = 5, Parent = b }, { UIKit.corner(6) })
	end

	-- ===== travel button (bottom-centre) =====
	refs.travel = UIKit.button({
		Name = "TravelButton", Size = UDim2.fromOffset(math.floor(150 * f), math.floor(40 * f)), Position = UDim2.new(0.5, 0, 1, -math.floor(14 * f)), AnchorPoint = Vector2.new(0.5, 1),
		Text = "TO TOWER", style = "primary", TextSize = UIKit.px(15), Parent = gui,
	}, function()
		local d = State.data
		if d then
			pcall(function()
				Remotes.get("Teleport"):InvokeServer(if d.inTower then "home" else "tower")
			end)
		end
	end)

	-- cash counts up smoothly instead of jumping
	RunService.Heartbeat:Connect(function(dt)
		local d = State.data
		if not d or not refs.cash then
			return
		end
		local target = d.cash
		if shownCash ~= target then
			shownCash += (target - shownCash) * (1 - math.exp(-dt * 9))
			if math.abs(target - shownCash) < 1 then
				shownCash = target
			end
			refs.cash.Text = "$" .. UIKit.fmt(shownCash)
		end
	end)

	Hud.refresh()
	State.changed:Connect(Hud.refresh)
end

local lastCash = 0
function Hud.refresh()
	local d = State.data
	if not d or not refs.cash then
		return
	end
	if d.cash > lastCash and refs.cash then
		-- a small pulse whenever money comes in
		TweenService:Create(refs.cash, TweenInfo.new(0.12), { TextSize = UIKit.px(35) }):Play()
		task.delay(0.12, function()
			TweenService:Create(refs.cash, TweenInfo.new(0.2), { TextSize = UIKit.px(32) }):Play()
		end)
	end
	lastCash = d.cash
	refs.income.Text = ("+$%s/s    x%.2f"):format(UIKit.fmt(d.income), d.mult)
	refs.crowns.Text = ("CROWNS %d"):format(d.crowns)
	local floor = d.checkpoint
	local theme = Config.Floors[floor]
	refs.floorTitle.Text = ("FLOOR %d/%d  %s"):format(floor, Config.Tower.FLOORS, theme.name)
	refs.floorTitle.TextColor3 = UIKit.rgb(theme.glow)
	local cleared = 0
	for _ in d.floors do
		cleared += 1
	end
	refs.floorBar(cleared / Config.Tower.FLOORS, nil, UIKit.rgb(theme.glow))
	refs.objective.Text = d.objective.text
	refs.titleText.Text = d.title
	refs.odText.Text = if d.overdrive > 0 then ("Overdrive x%d"):format(d.overdrive) else ("Floors cleared %d/%d"):format(cleared, Config.Tower.FLOORS)
	refs.travel.Text = if d.inTower then "TO PLOT" else "TO TOWER"

	local perkAffordable = false
	for _, p in Config.Perks do
		if not d.perks[p.id] and d.cash >= p.cost then
			perkAffordable = true
		end
	end
	dots.shop.Visible = perkAffordable or d.canOverdrive
	dots.tower.Visible = false
	dots.style.Visible = false
	dots.settings.Visible = false
end

function Hud.isTouchDevice(): boolean
	return UserInputService.TouchEnabled
end

return Hud
