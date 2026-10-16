-- Tower: the twelve floors with their status; jump to any floor you reached.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)
local Menus = require(script.Parent.Menus)
local Sfx = require(script.Parent.Sfx)

local TowerPanel = {}
local T = UIKit.theme

function TowerPanel.create(gui: ScreenGui, toast: (string, string?) -> ())
	local frame, content = UIKit.panel(gui, "Tower", function()
		Menus.close()
	end)
	local header = UIKit.label({ Size = UDim2.new(1, -24, 0, UIKit.px(34)), Position = UDim2.fromOffset(12, 0), Text = "", TextSize = UIKit.px(13), Font = T.fontBold, TextColor3 = T.cyan, Parent = content })
	local list = UIKit.scroll({ Size = UDim2.new(1, -16, 1, -UIKit.px(40)), Position = UDim2.fromOffset(8, UIKit.px(38)), Parent = content })
	UIKit.list(list, 6)
	UIKit.pad(4).Parent = list

	local function render()
		local d = State.data
		if not d then
			return
		end
		UIKit.clear(list)
		header.Text = ("Deaths %d    Coins %d    Floors cleared %d/%d    Checkpoint: floor %d"):format(d.counters.deaths, d.counters.coins, d.counters.floorsCleared, Config.Tower.FLOORS, d.checkpoint)
		for _, fl in Config.Floors do
			local cleared = d.floors[tostring(fl.id)] == true
			local reachable = fl.id <= d.reached
			local c = UIKit.new("Frame", {
				Size = UDim2.new(1, -8, 0, UIKit.px(54)), LayoutOrder = fl.id, BackgroundColor3 = T.panel, BorderSizePixel = 0, Parent = list,
			}, { UIKit.corner(10), UIKit.stroke(UIKit.rgb(fl.glow), if fl.id == d.checkpoint then 3 else 1.2, if reachable then 0.1 else 0.7) })
			UIKit.new("Frame", { Size = UDim2.fromOffset(8, UIKit.px(54)), BackgroundColor3 = UIKit.rgb(fl.main), BorderSizePixel = 0, Parent = c }, { UIKit.corner(4) })
			UIKit.title({ Size = UDim2.new(1, -UIKit.px(190), 0, UIKit.px(22)), Position = UDim2.fromOffset(18, 6), Text = ("%d. %s"):format(fl.id, fl.name), TextSize = UIKit.px(16), TextColor3 = if reachable then UIKit.rgb(fl.glow) else T.dim, TextWrapped = false, Parent = c })
			UIKit.label({
				Size = UDim2.new(1, -UIKit.px(190), 0, UIKit.px(18)), Position = UDim2.fromOffset(18, UIKit.px(30)),
				Text = if cleared then "Cleared" elseif reachable then "Reached - not cleared yet" else "Locked", TextSize = UIKit.px(12), TextColor3 = if cleared then T.good else T.dim, TextWrapped = false, Parent = c,
			})
			UIKit.button({
				Size = UDim2.fromOffset(UIKit.px(110), UIKit.px(32)), Position = UDim2.new(1, -UIKit.px(118), 0.5, -UIKit.px(16)),
				Text = if reachable then "GO" else "LOCKED", style = if reachable then "primary" else "disabled", Parent = c,
			}, function()
				if reachable then
					local ok, res = pcall(function()
						return Remotes.get("GotoFloor"):InvokeServer(fl.id)
					end)
					if ok and res and res.ok then
						Menus.close()
					elseif ok and res and res.reason == "cooldown" then
						toast("Wait a moment before travelling again.", "warn")
					end
				else
					Sfx.play("deny")
				end
			end)
		end
	end

	Menus.register("tower", frame, render)
	State.changed:Connect(function()
		if frame.Visible then
			render()
		end
	end)
end

return TowerPanel
