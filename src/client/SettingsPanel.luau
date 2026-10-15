-- Settings: sound / music / objective guidance toggles (saved on the server), title picker and a controls cheat-sheet.
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

	local function setSetting(key: string, value: boolean)
		pcall(function()
			Remotes.get("SetSetting"):InvokeServer(key, value)
		end)
	end

	local function render()
		local d = State.data
		if not d then
			return
		end
		UIKit.clear(list)
		local order = 0
		local function nextOrder()
			order += 1
			return order
		end
		local function section(text: string)
			UIKit.title({ Size = UDim2.new(1, -8, 0, UIKit.px(26)), Text = text, TextSize = UIKit.px(17), TextColor3 = T.cyan, TextWrapped = false, LayoutOrder = nextOrder(), Parent = list })
		end
		local function toggle(label: string, key: string)
			local on = d.settings[key] ~= false
			local r = UIKit.new("Frame", { Size = UDim2.new(1, -8, 0, UIKit.px(40)), BackgroundColor3 = T.panel, BorderSizePixel = 0, LayoutOrder = nextOrder(), Parent = list }, { UIKit.corner(8) })
			UIKit.label({ Size = UDim2.new(0.7, 0, 1, 0), Position = UDim2.fromOffset(12, 0), Text = label, TextSize = UIKit.px(14), Parent = r })
			UIKit.button({ Size = UDim2.new(0, UIKit.px(70), 0, UIKit.px(28)), Position = UDim2.new(1, -UIKit.px(80), 0.5, -UIKit.px(14)), Text = if on then "ON" else "OFF", style = if on then "primary" else "ghost", Parent = r }, function()
				setSetting(key, not on)
			end)
		end
		section("Options")
		toggle("Sound effects", "sfx")
		toggle("Music (needs an audio id in Config)", "music")
		toggle("Objective guidance (beacon and objective card)", "hints")
		section("Title")
		for _, title in d.titles do
			local selected = d.title == title
			local r = UIKit.new("Frame", { Size = UDim2.new(1, -8, 0, UIKit.px(36)), BackgroundColor3 = T.panel, BorderSizePixel = 0, LayoutOrder = nextOrder(), Parent = list }, { UIKit.corner(8) })
			UIKit.label({ Size = UDim2.new(0.65, 0, 1, 0), Position = UDim2.fromOffset(12, 0), Text = title, TextSize = UIKit.px(14), Font = T.fontBold, Parent = r })
			UIKit.button({ Size = UDim2.new(0, UIKit.px(80), 0, UIKit.px(26)), Position = UDim2.new(1, -UIKit.px(90), 0.5, -UIKit.px(13)), Text = if selected then "Active" else "Use", style = if selected then "disabled" else "ghost", Parent = r }, function()
				if not selected then
					pcall(function()
						Remotes.get("SetTitle"):InvokeServer(title)
					end)
				end
			end)
		end
		section("Controls")
		UIKit.label({
			Size = UDim2.new(1, -8, 0, UIKit.px(150)), LayoutOrder = nextOrder(), TextSize = UIKit.px(13), TextColor3 = T.dim, TextYAlignment = Enum.TextYAlignment.Top, Parent = list,
			Text = "PC: hold Left Mouse on glowing corruption to absorb. E uses prompts at stations. Q = Overcharge (after buying it).\n"
				.. "Mobile: hold the ABSORB button while facing a target; tap station prompts. Use the buttons on the right for menus.\n"
				.. "Gamepad: hold R2 to absorb, L2 = Overcharge, A uses prompts.\n\n"
				.. "Progress saves automatically every minute and when you leave.",
		})
	end
	Menus.register("settings", frame, render)
	State.changed:Connect(function()
		if frame.Visible then
			render()
		end
		Sfx.updateMusic()
	end)
end

return SettingsPanel
