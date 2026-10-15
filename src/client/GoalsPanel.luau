-- Goals: the guided journey (tutorial chain), long-term milestones with progress, and secrets/discoveries.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local WorldData = require(Shared.WorldData)
local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)
local Menus = require(script.Parent.Menus)

local GoalsPanel = {}
local T = UIKit.theme

local function rewardText(r: any): string
	local p = {}
	if r.credits then table.insert(p, UIKit.fmt(r.credits) .. " Credits") end
	if r.xp then table.insert(p, r.xp .. " XP") end
	if r.rp then table.insert(p, r.rp .. " RP") end
	if r.echo then
		for _, e in Config.Echoes do
			if e.id == r.echo then table.insert(p, "Echo: " .. e.name) end
		end
	end
	if r.title then table.insert(p, 'Title "' .. r.title .. '"') end
	if r.unlock then table.insert(p, "Opens " .. Config.Areas[r.unlock].name) end
	return table.concat(p, "  -  ")
end

local function count(t: { [string]: boolean }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

function GoalsPanel.create(gui: ScreenGui)
	local frame, content = UIKit.panel(gui, "Goals", function()
		Menus.close()
	end)
	local tab = "journey"
	local tabRow = UIKit.new("Frame", { Size = UDim2.new(1, -24, 0, UIKit.px(34)), Position = UDim2.fromOffset(12, 0), BackgroundTransparency = 1, Parent = content })
	UIKit.list(tabRow, 6, true)
	local list = UIKit.scroll({ Size = UDim2.new(1, -16, 1, -UIKit.px(44)), Position = UDim2.fromOffset(8, UIKit.px(40)), Parent = content })
	UIKit.list(list, 8)
	UIKit.pad(4).Parent = list
	local buttons = {}

	local function row(order: number, title: string, sub: string, color: Color3, fraction: number?, done: boolean?)
		local h = UIKit.px(if fraction then 74 else 58)
		local card = UIKit.new("Frame", { Size = UDim2.new(1, -8, 0, h), BackgroundColor3 = T.panel, BorderSizePixel = 0, LayoutOrder = order, Parent = list }, { UIKit.corner(10), UIKit.stroke(color, 1.5, 0.35) })
		UIKit.label({ Size = UDim2.new(1, -20, 0, UIKit.px(20)), Position = UDim2.fromOffset(10, 6), Text = (if done then "[done] " else "") .. title, TextSize = UIKit.px(15), Font = T.fontBold, TextColor3 = if done then T.good else T.text, TextWrapped = false, Parent = card })
		UIKit.label({ Size = UDim2.new(1, -20, 0, UIKit.px(30)), Position = UDim2.fromOffset(10, UIKit.px(26)), Text = sub, TextSize = UIKit.px(12), TextColor3 = T.dim, TextYAlignment = Enum.TextYAlignment.Top, Parent = card })
		if fraction then
			local _, set = UIKit.bar({ Size = UDim2.new(1, -20, 0, UIKit.px(12)), Position = UDim2.new(0, 10, 1, -UIKit.px(18)), Parent = card }, color)
			set(fraction)
		end
	end

	local function render()
		local d = State.data
		if not d then
			return
		end
		UIKit.clear(list)
		for _, b in buttons do
			b.btn.BackgroundColor3 = if b.id == tab then T.cyan else T.panel2
			b.btn.TextColor3 = if b.id == tab then Color3.fromRGB(14, 12, 28) else T.text
		end
		if tab == "journey" then
			local activeShown = false
			for i, q in Config.Quests do
				local done = d.quests[q.id] == true
				if done then
					row(i, q.title, "Reward: " .. rewardText(q.reward), T.good, nil, true)
				elseif not activeShown then
					activeShown = true
					local cur = math.min(q.stat == "percent" and d.percent or (d.counters[q.stat] or 0), q.goal)
					row(i, q.title, q.text .. "\nReward: " .. rewardText(q.reward), T.cyan, cur / q.goal)
				else
					row(i, q.title, "Reward: " .. rewardText(q.reward), T.panel2)
				end
			end
			if not activeShown then
				row(99, "Journey complete", "You know the basics. Keep restoring, collecting Echoes and chasing milestones.", T.good, nil, true)
			end
		elseif tab == "milestones" then
			for i, m in Config.Milestones do
				local prog = if m.kind == "percent" then d.percent elseif m.kind == "echoes" then count(d.echoes) else (d.counters.secretsFound or 0)
				local done = d.milestones[m.id] == true
				local what = if m.kind == "percent" then ("Restore %d%% of the valley"):format(m.value) elseif m.kind == "echoes" then ("Discover %d Echoes"):format(m.value) else ("Find %d hidden fragments"):format(m.value)
				row(i, m.name, what .. "\nReward: " .. rewardText(m.reward), if done then T.good else T.purple, math.min(prog / m.value, 1), done)
			end
		else
			local found = d.counters.secretsFound or 0
			row(1, ("Hidden fragments: %d / %d"):format(found, #WorldData.Secrets), "Glinting shards hide behind knolls, rocks and cliffs. Echoes and research can reveal them from afar.", T.warn, found / #WorldData.Secrets)
			for i, s in WorldData.Secrets do
				local got = d.counters.secretsFound > 0 and State.restored[s.id] == true
				row(10 + i, if got then "Found: " .. s.id:gsub("shard_", "Shard ") else "Undiscovered shard", if got then s.hint else "Explore off the path. Clue signs around the valley hint at where to look.", if got then T.good else T.panel2, nil, got)
			end
			local ob, ot, cap, ct = 0, 0, 0, 0
			for _, t in WorldData.Targets do
				if t.type == "anomaly" then
					ot += 1
					if State.restored[t.id] then ob += 1 end
				elseif t.type == "capsule" then
					ct += 1
					if State.restored[t.id] then cap += 1 end
				end
			end
			row(30, ("Glitch Obelisks: %d / %d"):format(ob, ot), "Unusual corrupted monuments far from the paths. Big payouts. Needs an Advanced Absorber.", T.purple, ob / ot)
			row(31, ("Glitch Capsules opened: %d / %d"):format(cap, ct), "Each capsule traps an Echo. Open them all and check the Echo Index for hints.", T.cyan, cap / ct)
		end
	end

	for _, t in { { "journey", "Journey" }, { "milestones", "Milestones" }, { "secrets", "Secrets" } } do
		local b = UIKit.button({ Size = UDim2.new(1 / 3, -5, 1, 0), Text = t[2], style = "ghost", TextSize = UIKit.px(14), Parent = tabRow }, function()
			tab = t[1]
			render()
		end)
		table.insert(buttons, { id = t[1], btn = b })
	end
	Menus.register("goals", frame, render)
	State.changed:Connect(function()
		if frame.Visible then
			render()
		end
	end)
end

return GoalsPanel
