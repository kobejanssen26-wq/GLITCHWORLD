-- Equipment menu: Absorber / Backpack / Boots tiers and one-off Gadgets with current-vs-new previews.
-- Purchases are requests only; the server re-validates funds, tier order and proximity to the Upgrade Station.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local WorldData = require(Shared.WorldData)
local Remotes = require(Shared.Remotes)
local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)
local Menus = require(script.Parent.Menus)
local Sfx = require(script.Parent.Sfx)
local Feedback = require(script.Parent.Feedback)

local EquipmentPanel = {}
local T = UIKit.theme

local REASONS = {
	funds = "Not enough Credits yet.", far = "Walk to the Upgrade Station to buy.", owned = "You already own that.", order = "Buy the previous tier first.",
	needs_absorber = "Needs a better absorber first.", busy = "One moment...", slow_down = "One moment...", invalid = "That item is not available.", no_session = "Still loading...",
}

local TABS = { { "absorber", "Absorber", Config.Absorber }, { "backpack", "Backpack", Config.Backpack }, { "boots", "Boots", Config.Boots }, { "gadget", "Gadgets", Config.Gadgets } }

local function nearStation(): boolean
	local c = Players.LocalPlayer.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return false
	end
	local s = WorldData.Stations.upgrade
	local dx, dz = hrp.Position.X - s.x, hrp.Position.Z - s.z
	return dx * dx + dz * dz <= (Config.Economy.STATION_RADIUS - 2) ^ 2
end

-- the stat lines shown for an item: { label, currentEffective, newEffective, format }
local function previewLines(category: string, d: any, idx: number): { { string } }
	local lines = {}
	local function line(label: string, cur: number, new: number, fmt: string)
		local pct = if cur > 0 then (new / cur - 1) * 100 else 0
		table.insert(lines, { label, fmt:format(cur), fmt:format(new), if pct > 0.5 then ("+%d%%"):format(math.floor(pct + 0.5)) else "" })
	end
	if category == "absorber" then
		local cur, nxt = Config.Absorber[d.tiers.absorber], Config.Absorber[idx]
		local pr, sr, rr = d.stats.power / cur.power, d.stats.speed / cur.speed, d.stats.range - cur.range
		line("Absorb power", d.stats.power, nxt.power * pr, "%.1f")
		line("Absorb speed (pulses/s)", d.stats.speed, nxt.speed * sr, "%.2f")
		line("Range (studs)", d.stats.range, nxt.range + rr, "%.0f")
		line("Absorb rate / s", d.stats.power * d.stats.speed, nxt.power * pr * nxt.speed * sr, "%.1f")
	elseif category == "backpack" then
		local cur, nxt = Config.Backpack[d.tiers.backpack], Config.Backpack[idx]
		line("Capacity", d.stats.capacity, math.floor(nxt.capacity * (d.stats.capacity / cur.capacity)), "%d")
	elseif category == "boots" then
		local cur, nxt = Config.Boots[d.tiers.boots], Config.Boots[idx]
		line("Walk speed", d.stats.walk, nxt.walk + (d.stats.walk - cur.walk), "%.1f")
		line("Jump power", cur.jump, nxt.jump, "%d")
	end
	return lines
end

function EquipmentPanel.create(gui: ScreenGui)
	local frame, content = UIKit.panel(gui, "Upgrades", function()
		Menus.close()
	end)
	local tab = "absorber"
	local buying = false
	local lastNear = false

	local tabRow = UIKit.new("Frame", { Size = UDim2.new(1, -24, 0, UIKit.px(34)), Position = UDim2.fromOffset(12, 0), BackgroundTransparency = 1, Parent = content })
	UIKit.list(tabRow, 6, true)
	local info = UIKit.label({ Size = UDim2.new(1, -24, 0, UIKit.px(20)), Position = UDim2.fromOffset(12, UIKit.px(38)), Text = "", TextSize = UIKit.px(13), TextColor3 = T.dim, TextWrapped = false, Parent = content })
	local list = UIKit.scroll({ Size = UDim2.new(1, -16, 1, -UIKit.px(64)), Position = UDim2.fromOffset(8, UIKit.px(62)), Parent = content })
	UIKit.list(list, 8)
	UIKit.pad(4).Parent = list

	local tabButtons = {}
	local function buy(category: string, id: string)
		if buying then
			return
		end
		buying = true
		local ok, res = pcall(function()
			return Remotes.get("Buy"):InvokeServer(category, id)
		end)
		buying = false
		if not ok or not res then
			Feedback.toast("Could not reach the server. Try again.", "warn")
		elseif not res.ok then
			Sfx.play("deny")
			Feedback.toast(REASONS[res.reason] or "Purchase failed.", "warn")
		end
	end

	local function statusBadge(parent: Instance, text: string, color: Color3)
		UIKit.label({ Size = UDim2.fromOffset(UIKit.px(140), UIKit.px(22)), Position = UDim2.new(1, -UIKit.px(148), 0, 8), Text = text, TextSize = UIKit.px(12), Font = T.fontBold, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false, Parent = parent })
	end

	local function render()
		local d = State.data
		if not d then
			return
		end
		UIKit.clear(list)
		lastNear = nearStation()
		info.Text = ("Credits: %s     %s"):format(UIKit.fmt(d.credits), if lastNear then "Upgrade Station in range" else "Walk to the Upgrade Station to buy")
		info.TextColor3 = if lastNear then T.good else T.warn
		for _, tb in tabButtons do
			tb.btn.BackgroundColor3 = if tb.id == tab then T.cyan else T.panel2
			tb.btn.TextColor3 = if tb.id == tab then Color3.fromRGB(14, 12, 28) else T.text
		end
		local items
		for _, t in TABS do
			if t[1] == tab then
				items = t[3]
			end
		end
		local owned = if tab == "gadget" then 0 else d.tiers[tab]
		for i, item in items do
			local isGadget = tab == "gadget"
			local isOwned = if isGadget then d.gadgets[item.id] == true else i <= owned
			local isNext = if isGadget then not isOwned else i == owned + 1
			local lines = if isNext and not isGadget then previewLines(tab, d, i) else {}
			local height = UIKit.px(62) + (if isNext then UIKit.px(34) + #lines * UIKit.px(20) else 0)
			local card = UIKit.new("Frame", { Size = UDim2.new(1, -8, 0, height), BackgroundColor3 = if isNext then T.panel else T.bg, BorderSizePixel = 0, LayoutOrder = i, Parent = list }, {
				UIKit.corner(10), UIKit.stroke(if isNext then T.cyan else T.panel2, if isNext then 2 else 1, if isNext then 0.2 else 0.4),
			})
			UIKit.title({ Size = UDim2.new(1, -UIKit.px(170), 0, UIKit.px(24)), Position = UDim2.fromOffset(12, 6), Text = item.name, TextSize = UIKit.px(17), TextWrapped = false, TextColor3 = if isOwned or isNext then T.text else T.dim, Parent = card })
			local sub
			if isGadget then
				sub = item.desc
			elseif tab == "absorber" then
				sub = item.desc
			elseif tab == "backpack" then
				sub = ("Holds %s fragments."):format(UIKit.fmt(item.capacity))
			else
				sub = ("Walk speed %d, jump power %d."):format(item.walk, item.jump)
			end
			UIKit.label({ Size = UDim2.new(1, -24, 0, UIKit.px(30)), Position = UDim2.fromOffset(12, UIKit.px(30)), Text = sub, TextSize = UIKit.px(12), TextColor3 = T.dim, TextYAlignment = Enum.TextYAlignment.Top, Parent = card })
			if isOwned then
				statusBadge(card, if not isGadget and i == owned then "EQUIPPED" else "OWNED", T.good)
			elseif isNext then
				statusBadge(card, UIKit.fmt(item.price) .. " Credits", T.cyan)
				local y = UIKit.px(62)
				for _, ln in lines do
					UIKit.label({ Size = UDim2.new(0.5, 0, 0, UIKit.px(18)), Position = UDim2.fromOffset(12, y), Text = ln[1], TextSize = UIKit.px(13), Parent = card })
					UIKit.label({ Size = UDim2.new(0.5, -12, 0, UIKit.px(18)), Position = UDim2.new(0.5, 0, 0, y), Text = ("%s  >  %s   %s"):format(ln[2], ln[3], ln[4]), TextSize = UIKit.px(13), Font = T.fontBold, TextColor3 = T.good, TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false, Parent = card })
					y += UIKit.px(20)
				end
				local blocked, text
				if isGadget and d.tiers.absorber < item.minAbsorber then
					blocked, text = true, "Needs " .. Config.Absorber[item.minAbsorber].name
				elseif d.credits < item.price then
					blocked, text = true, ("Need %s more"):format(UIKit.fmt(item.price - d.credits))
				elseif not lastNear then
					blocked, text = true, "Visit Upgrade Station"
				else
					blocked, text = false, ("Buy for %s"):format(UIKit.fmt(item.price))
				end
				UIKit.button({
					Size = UDim2.new(1, -24, 0, UIKit.px(30)), Position = UDim2.new(0, 12, 1, -UIKit.px(36)), Text = text,
					style = if blocked then "disabled" else "primary", Parent = card,
				}, function()
					if not blocked then
						buy(tab, item.id)
					else
						Sfx.play("deny")
						Feedback.toast(text .. ".", "warn")
					end
				end)
			else
				statusBadge(card, UIKit.fmt(item.price) .. " Credits", T.dim)
			end
		end
	end

	for _, t in TABS do
		local b = UIKit.button({ Size = UDim2.new(0.25, -5, 1, 0), Text = t[2], style = "ghost", TextSize = UIKit.px(14), Parent = tabRow }, function()
			tab = t[1]
			render()
		end)
		table.insert(tabButtons, { id = t[1], btn = b })
	end

	Menus.register("equipment", frame, render)
	State.changed:Connect(function()
		if frame.Visible then
			render()
		end
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc > 0.5 and frame.Visible then
			acc = 0
			if nearStation() ~= lastNear then
				render()
			end
		end
	end)
end

return EquipmentPanel
