-- Style: trails (unlocked per floor), auras (unlocked by crowns) and titles.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)
local Menus = require(script.Parent.Menus)
local Sfx = require(script.Parent.Sfx)

local StylePanel = {}
local T = UIKit.theme

function StylePanel.create(gui: ScreenGui)
	local frame, content = UIKit.panel(gui, "Style", function()
		Menus.close()
	end)
	local list = UIKit.scroll({ Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4), Parent = content })
	UIKit.list(list, 6)
	UIKit.pad(4).Parent = list

	local function equip(kind: string, id: string)
		pcall(function()
			Remotes.get("Equip"):InvokeServer(kind, id)
		end)
	end

	local function render()
		local d = State.data
		if not d then
			return
		end
		UIKit.clear(list)
		local order = 0
		local function header(text: string)
			order += 1
			UIKit.title({ Size = UDim2.new(1, -8, 0, UIKit.px(28)), Text = text, TextSize = UIKit.px(18), TextColor3 = T.cyan, TextWrapped = false, LayoutOrder = order, Parent = list })
		end
		local function row(name: string, sub: string, color: Color3, owned: boolean, equipped: boolean, onEquip: () -> ())
			order += 1
			local r = UIKit.new("Frame", { Size = UDim2.new(1, -8, 0, UIKit.px(46)), LayoutOrder = order, BackgroundColor3 = T.panel, BorderSizePixel = 0, Parent = list }, { UIKit.corner(10), UIKit.stroke(color, if equipped then 2.5 else 1, if owned then 0.1 else 0.7) })
			UIKit.new("Frame", { Size = UDim2.fromOffset(12, 12), Position = UDim2.fromOffset(12, UIKit.px(17)), BackgroundColor3 = color, BorderSizePixel = 0, Parent = r }, { UIKit.corner(6) })
			UIKit.label({ Size = UDim2.new(1, -UIKit.px(170), 0, UIKit.px(20)), Position = UDim2.fromOffset(34, 4), Text = name, TextSize = UIKit.px(14), Font = T.fontBold, TextColor3 = if owned then T.text else T.dim, TextWrapped = false, Parent = r })
			UIKit.label({ Size = UDim2.new(1, -UIKit.px(170), 0, UIKit.px(16)), Position = UDim2.fromOffset(34, UIKit.px(24)), Text = sub, TextSize = UIKit.px(11), TextColor3 = T.dim, TextWrapped = false, Parent = r })
			UIKit.button({
				Size = UDim2.fromOffset(UIKit.px(100), UIKit.px(30)), Position = UDim2.new(1, -UIKit.px(108), 0.5, -UIKit.px(15)),
				Text = if equipped then "WORN" elseif owned then "WEAR" else "LOCKED", style = if equipped then "disabled" elseif owned then "primary" else "disabled", Parent = r,
			}, function()
				if owned and not equipped then
					Sfx.play("unlock")
					onEquip()
				end
			end)
		end
		header("Trails")
		row("No trail", "Plain and simple", T.dim, true, d.trail == "", function() equip("trail", "") end)
		for _, tr in Config.Trails do
			row(tr.name, ("Clear floor %d"):format(tr.floor), UIKit.rgb(tr.color), d.trails[tr.id] == true, d.trail == tr.id, function() equip("trail", tr.id) end)
		end
		header("Auras")
		row("No aura", "Keep it clean", T.dim, true, d.aura == "", function() equip("aura", "") end)
		for _, au in Config.Auras do
			row(au.name, ("%d crowns"):format(au.crowns), UIKit.rgb(au.color), d.auras[au.id] == true, d.aura == au.id, function() equip("aura", au.id) end)
		end
		header("Titles")
		for _, ti in Config.Titles do
			local owned = d.crowns >= ti.crowns
			row(ti.id, ("%d crowns"):format(ti.crowns), T.gold, owned, d.title == ti.id, function() equip("title", ti.id) end)
		end
	end

	Menus.register("style", frame, render)
	State.changed:Connect(function()
		if frame.Visible then
			render()
		end
	end)
end

return StylePanel
