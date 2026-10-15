-- Echo Index: all 12 Echoes (silhouettes until discovered), details, how-to-find hints and equip slots.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local EchoModel = require(Shared.EchoModel)
local Remotes = require(Shared.Remotes)
local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)
local Menus = require(script.Parent.Menus)
local Sfx = require(script.Parent.Sfx)
local Feedback = require(script.Parent.Feedback)

local EchoPanel = {}
local T = UIKit.theme

local REASONS = { full = "All Echo slots are in use. Unequip one first.", locked = "You have not discovered that Echo yet.", slow_down = "One moment...", invalid = "Not available.", already = "Already equipped." }

local function viewport(parent: Instance, look: any, silhouette: boolean, size: UDim2, pos: UDim2?): ViewportFrame
	local vp = UIKit.new("ViewportFrame", { Size = size, Position = pos or UDim2.new(), BackgroundTransparency = 1, Ambient = Color3.fromRGB(190, 190, 210), LightColor = Color3.new(1, 1, 1), Parent = parent })
	local cam = Instance.new("Camera")
	cam.FieldOfView = 35
	cam.CFrame = CFrame.lookAt(Vector3.new(1.4, 1.0, -8.2), Vector3.new(0, 0.2, 0))
	cam.Parent = vp
	vp.CurrentCamera = cam
	EchoModel.build(look, vp, silhouette)
	return vp
end

function EchoPanel.create(gui: ScreenGui)
	local frame, content = UIKit.panel(gui, "Echo Index", function()
		Menus.close()
	end)
	local selected = Config.Echoes[1].id
	local sig = ""

	local header = UIKit.label({ Size = UDim2.new(1, -24, 0, UIKit.px(22)), Position = UDim2.fromOffset(12, 0), Text = "", TextSize = UIKit.px(14), Font = T.fontBold, TextColor3 = T.cyan, TextWrapped = false, Parent = content })
	local grid = UIKit.scroll({ Size = UDim2.new(1, -16, 0.5, -UIKit.px(26)), Position = UDim2.fromOffset(8, UIKit.px(26)), Parent = content })
	local cell = UIKit.px(88)
	UIKit.new("UIGridLayout", { CellSize = UDim2.fromOffset(cell, cell + UIKit.px(22)), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	UIKit.pad(4).Parent = grid
	local detail = UIKit.new("Frame", { Size = UDim2.new(1, -16, 0.5, -8), Position = UDim2.new(0, 8, 0.5, 4), BackgroundColor3 = T.panel, BorderSizePixel = 0, Parent = content }, { UIKit.corner(10), UIKit.stroke(T.panel2, 1.5, 0.2) })

	local function act(action: string, id: string)
		local ok, res = pcall(function()
			return Remotes.get("EchoAction"):InvokeServer(action, id)
		end)
		if ok and res and not res.ok then
			Sfx.play("deny")
			Feedback.toast(REASONS[res.reason] or "Could not do that.", "warn")
		else
			Sfx.play("click")
		end
	end

	local function renderDetail()
		local d = State.data
		UIKit.clear(detail)
		local e
		for _, x in Config.Echoes do
			if x.id == selected then
				e = x
			end
		end
		if not e or not d then
			return
		end
		local owned = d.echoes[e.id] == true
		local rar = Config.Rarity[e.rarity]
		viewport(detail, e.look, not owned, UDim2.new(0.28, 0, 1, -16), UDim2.fromOffset(8, 8))
		local x = 0.3
		UIKit.title({ Size = UDim2.new(0.68, 0, 0, UIKit.px(26)), Position = UDim2.new(x, 0, 0, 8), Text = if owned then e.name else "???", TextSize = UIKit.px(22), TextWrapped = false, Parent = detail })
		UIKit.label({ Size = UDim2.new(0.68, 0, 0, UIKit.px(18)), Position = UDim2.new(x, 0, 0, UIKit.px(34)), Text = ("%s  -  %s"):format(rar.name, e.theme), TextSize = UIKit.px(13), Font = T.fontBold, TextColor3 = rar.color, TextWrapped = false, Parent = detail })
		UIKit.label({ Size = UDim2.new(0.68, 0, 0, UIKit.px(36)), Position = UDim2.new(x, 0, 0, UIKit.px(54)), Text = if owned then e.blurb else "An undiscovered Echo.", TextSize = UIKit.px(12), TextColor3 = T.dim, TextYAlignment = Enum.TextYAlignment.Top, Parent = detail })
		UIKit.label({ Size = UDim2.new(0.68, 0, 0, UIKit.px(20)), Position = UDim2.new(x, 0, 0, UIKit.px(92)), Text = if owned then "Bonus: " .. e.bonusText else "Bonus: unknown until discovered", TextSize = UIKit.px(13), Font = T.fontBold, TextColor3 = if owned then T.good else T.dim, TextWrapped = true, Parent = detail })
		UIKit.label({ Size = UDim2.new(0.68, 0, 0, UIKit.px(32)), Position = UDim2.new(x, 0, 0, UIKit.px(114)), Text = (if owned then "Found: " else "How to find: ") .. e.hint, TextSize = UIKit.px(12), TextColor3 = T.cyan, TextYAlignment = Enum.TextYAlignment.Top, Parent = detail })
		if owned then
			local equipped = table.find(d.equipped, e.id) ~= nil
			UIKit.button({
				Size = UDim2.new(0.68, 0, 0, UIKit.px(32)), Position = UDim2.new(x, 0, 1, -UIKit.px(40)),
				Text = if equipped then "Unequip" else ("Equip (%d/%d slots)"):format(#d.equipped, d.stats.echoSlots), style = if equipped then "ghost" else "primary", Parent = detail,
			}, function()
				act(if equipped then "unequip" else "equip", e.id)
			end)
		end
	end

	local function renderGrid()
		local d = State.data
		if not d then
			return
		end
		UIKit.clear(grid)
		local count = 0
		for _ in d.echoes do
			count += 1
		end
		header.Text = ("Discovered %d / %d     Slots %d / %d (more at ranks 5 and 12)"):format(count, #Config.Echoes, #d.equipped, d.stats.echoSlots)
		for i, e in Config.Echoes do
			local owned = d.echoes[e.id] == true
			local rar = Config.Rarity[e.rarity]
			local btn = UIKit.new("TextButton", {
				LayoutOrder = i, Text = "", AutoButtonColor = false, BackgroundColor3 = if e.id == selected then T.panel2 else T.panel, BorderSizePixel = 0, Parent = grid,
			}, { UIKit.corner(10), UIKit.stroke(if owned then rar.color else T.panel2, if e.id == selected then 3 else 1.5, 0.1) })
			viewport(btn, e.look, not owned, UDim2.new(1, -8, 0, cell - 8), UDim2.fromOffset(4, 4))
			UIKit.label({ Size = UDim2.new(1, -6, 0, UIKit.px(18)), Position = UDim2.new(0, 3, 1, -UIKit.px(20)), Text = if owned then e.name else "???", TextSize = UIKit.px(12), Font = T.fontBold, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, TextColor3 = if owned then T.text else T.dim, Parent = btn })
			if table.find(d.equipped, e.id) then
				UIKit.label({ Size = UDim2.fromOffset(UIKit.px(18), UIKit.px(16)), Position = UDim2.fromOffset(4, 4), Text = "E", TextSize = UIKit.px(11), Font = T.fontBold, TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0, BackgroundColor3 = T.good, TextColor3 = Color3.fromRGB(14, 12, 28), Parent = btn }).ZIndex = 5
			end
			btn.Activated:Connect(function()
				selected = e.id
				Sfx.play("click")
				renderGrid()
				renderDetail()
			end)
		end
	end

	local function signature(): string
		local d = State.data
		if not d then
			return ""
		end
		local ids = {}
		for id in d.echoes do
			table.insert(ids, id)
		end
		table.sort(ids)
		return table.concat(ids, ",") .. "|" .. table.concat(d.equipped, ",") .. "|" .. d.stats.echoSlots .. "|" .. selected
	end

	local function render()
		sig = signature()
		renderGrid()
		renderDetail()
	end
	Menus.register("echoes", frame, render)
	State.changed:Connect(function()
		if frame.Visible and signature() ~= sig then
			render()
		end
	end)
end

return EchoPanel
