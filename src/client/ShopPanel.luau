-- Shop: Overdrive (prestige), perks and floor skips. Every purchase is a server request.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)
local Menus = require(script.Parent.Menus)
local Sfx = require(script.Parent.Sfx)

local ShopPanel = {}
local T = UIKit.theme

local REASONS = {
	funds = "Not enough cash yet.", owned = "You already own that.", invalid = "Not available.", slow_down = "One moment...",
	locked = "Not available yet.", top = "You are already at the top floor.", no_session = "Still loading...",
}

function ShopPanel.create(gui: ScreenGui, toast: (string, string?) -> ())
	local frame, content = UIKit.panel(gui, "Shop", function()
		Menus.close()
	end)
	local list = UIKit.scroll({ Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4), Parent = content })
	UIKit.list(list, 8)
	UIKit.pad(4).Parent = list
	local busy = false

	local function request(remote: string, ...)
		if busy then
			return
		end
		busy = true
		local args = { ... }
		local ok, res = pcall(function()
			return Remotes.get(remote):InvokeServer(table.unpack(args))
		end)
		busy = false
		if not ok or not res then
			toast("Could not reach the server.", "warn")
		elseif not res.ok then
			Sfx.play("deny")
			toast(REASONS[res.reason] or "Not possible right now.", "warn")
		end
	end

	local function card(order: number, height: number, accent: Color3): Frame
		return UIKit.new("Frame", { Size = UDim2.new(1, -8, 0, height), BackgroundColor3 = T.panel, BorderSizePixel = 0, LayoutOrder = order, Parent = list }, { UIKit.corner(12), UIKit.stroke(accent, 1.5, 0.3) })
	end

	local function render()
		local d = State.data
		if not d then
			return
		end
		UIKit.clear(list)
		local order = 0
		-- Overdrive
		order += 1
		local od = card(order, UIKit.px(96), T.magenta)
		UIKit.title({ Size = UDim2.new(1, -20, 0, UIKit.px(26)), Position = UDim2.fromOffset(12, 6), Text = "OVERDRIVE", TextSize = UIKit.px(20), TextColor3 = T.magenta, TextWrapped = false, Parent = od })
		UIKit.label({
			Size = UDim2.new(1, -24, 0, UIKit.px(32)), Position = UDim2.fromOffset(12, UIKit.px(32)),
			Text = ("Reset your factory for +%d%% cash forever (now x%d). Keeps crowns, floors, perks and cosmetics. Factory pieces cost %d%% more each time."):format(Config.Tycoon.OVERDRIVE_BONUS * 100, d.overdrive, Config.Tycoon.OVERDRIVE_COST_GROWTH * 100),
			TextSize = UIKit.px(12), TextColor3 = T.dim, TextYAlignment = Enum.TextYAlignment.Top, Parent = od,
		})
		UIKit.button({
			Size = UDim2.new(1, -24, 0, UIKit.px(28)), Position = UDim2.new(0, 12, 1, -UIKit.px(34)),
			Text = if d.canOverdrive then "TRIGGER OVERDRIVE" else "Build the Overdrive Reactor in your factory first", style = if d.canOverdrive then "gold" else "disabled", Parent = od,
		}, function()
			if d.canOverdrive then
				request("Overdrive")
			else
				Sfx.play("deny")
			end
		end)
		-- perks
		for _, perk in Config.Perks do
			order += 1
			local owned = d.perks[perk.id] == true
			local c = card(order, UIKit.px(70), if owned then T.good else T.cyan)
			UIKit.title({ Size = UDim2.new(0.6, 0, 0, UIKit.px(24)), Position = UDim2.fromOffset(12, 6), Text = perk.name, TextSize = UIKit.px(17), TextWrapped = false, Parent = c })
			UIKit.label({ Size = UDim2.new(1, -UIKit.px(150), 0, UIKit.px(30)), Position = UDim2.fromOffset(12, UIKit.px(32)), Text = perk.desc, TextSize = UIKit.px(12), TextColor3 = T.dim, TextYAlignment = Enum.TextYAlignment.Top, Parent = c })
			local afford = d.cash >= perk.cost
			UIKit.button({
				Size = UDim2.fromOffset(UIKit.px(130), UIKit.px(34)), Position = UDim2.new(1, -UIKit.px(138), 0.5, -UIKit.px(17)),
				Text = if owned then "OWNED" else ("$" .. UIKit.fmt(perk.cost)), style = if owned then "disabled" elseif afford then "primary" else "ghost", Parent = c,
			}, function()
				if not owned then
					request("BuyPerk", perk.id)
				end
			end)
		end
		-- skip
		order += 1
		local sk = card(order, UIKit.px(70), T.warn)
		UIKit.title({ Size = UDim2.new(0.6, 0, 0, UIKit.px(24)), Position = UDim2.fromOffset(12, 6), Text = "Skip Floor", TextSize = UIKit.px(17), TextWrapped = false, Parent = sk })
		UIKit.label({
			Size = UDim2.new(1, -UIKit.px(150), 0, UIKit.px(30)), Position = UDim2.fromOffset(12, UIKit.px(32)),
			Text = "Move your checkpoint up one floor without rewards. You can still climb the floor yourself later.", TextSize = UIKit.px(12), TextColor3 = T.dim, TextYAlignment = Enum.TextYAlignment.Top, Parent = sk,
		})
		local cost = d.skipCost
		UIKit.button({
			Size = UDim2.fromOffset(UIKit.px(130), UIKit.px(34)), Position = UDim2.new(1, -UIKit.px(138), 0.5, -UIKit.px(17)),
			Text = if cost then ("$" .. UIKit.fmt(cost)) else "TOP", style = if cost and d.cash >= cost then "primary" else "ghost", Parent = sk,
		}, function()
			if cost then
				request("Skip")
			end
		end)
	end

	Menus.register("shop", frame, render)
	State.changed:Connect(function()
		if frame.Visible then
			render()
		end
	end)
end

return ShopPanel
