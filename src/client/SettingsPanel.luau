-- Settings: sound / music / camera shake toggles (saved on the server) and a controls cheat-sheet.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)
local Menus = require(script.Parent.Menus)
local Sfx = require(script.Parent.Sfx)

local SettingsPanel = {}
local T = UIKit.theme

function SettingsPanel.create(gui: ScreenGui)
	local frame, content = UIKit.panel(gui, "Settings", function()
		Menus.close()
	end)
	local list = UIKit.scroll({ Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4), Parent = content })
	UIKit.list(list, 8)
	UIKit.pad(4).Parent = list

	local function render()
		local d = State.data
		if not d then
			return
		end
		UIKit.clear(list)
		local order = 0
		local function toggle(label: string, key: string)
			order += 1
			local on = d.settings[key] ~= false
			local r = UIKit.new("Frame", { Size = UDim2.new(1, -8, 0, UIKit.px(42)), BackgroundColor3 = T.panel, BorderSizePixel = 0, LayoutOrder = order, Parent = list }, { UIKit.corner(10) })
			UIKit.label({ Size = UDim2.new(1, -UIKit.px(100), 1, 0), Position = UDim2.fromOffset(12, 0), Text = label, TextSize = UIKit.px(14), Parent = r })
			UIKit.button({
				Size = UDim2.fromOffset(UIKit.px(72), UIKit.px(28)), Position = UDim2.new(1, -UIKit.px(80), 0.5, -UIKit.px(14)), Text = if on then "ON" else "OFF", style = if on then "primary" else "ghost", Parent = r,
			}, function()
				pcall(function()
					Remotes.get("SetSetting"):InvokeServer(key, not on)
				end)
			end)
		end
		toggle("Sound effects", "sfx")
		toggle("Music", "music")
		toggle("Camera shake and speed lines", "shake")
		order += 1
		UIKit.label({
			Size = UDim2.new(1, -8, 0, UIKit.px(170)), LayoutOrder = order, TextSize = UIKit.px(13), TextColor3 = T.dim, TextYAlignment = Enum.TextYAlignment.Top, Parent = list,
			Text = "HOW TO PLAY\n"
				.. "1. Your factory makes cash by itself. Walk onto the glowing pad behind it to buy the next machine.\n"
				.. "2. Press TO TOWER to climb the 12-floor tower. Touch checkpoints to save your spot; clearing a floor pays crowns, cash and a trail.\n"
				.. "3. Crowns multiply your factory income. Collect coins, buy perks, and build the Overdrive Reactor to prestige.\n\n"
				.. "PC: WASD + Space (Space again in the air with Double Jump).  Mobile: thumbstick + jump button.\n"
				.. "Progress saves automatically every minute and when you leave.",
		})
	end

	Menus.register("settings", frame, render)
	State.changed:Connect(function()
		if frame.Visible then
			render()
		end
		Sfx.refresh()
	end)
end

return SettingsPanel
