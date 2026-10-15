-- Research tree: four branches (Efficiency / Capacity / Exploration / Discovery), each a chain of four nodes
-- bought with Research Points (1 per rank + milestone rewards). Choices matter early; the full tree takes long.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)
local Menus = require(script.Parent.Menus)
local Sfx = require(script.Parent.Sfx)
local Feedback = require(script.Parent.Feedback)

local ResearchPanel = {}
local T = UIKit.theme

local REASONS = { funds = "Not enough Research Points.", order = "Research the previous node first.", owned = "Already researched.", slow_down = "One moment...", invalid = "Not available." }

function ResearchPanel.create(gui: ScreenGui)
	local frame, content = UIKit.panel(gui, "Research", function()
		Menus.close()
	end)
	local header = UIKit.label({ Size = UDim2.new(1, -24, 0, UIKit.px(22)), Position = UDim2.fromOffset(12, 0), Text = "", TextSize = UIKit.px(14), Font = T.fontBold, TextColor3 = T.cyan, TextWrapped = false, Parent = content })
	local scroller = UIKit.new("ScrollingFrame", {
		Size = UDim2.new(1, -16, 1, -UIKit.px(30)), Position = UDim2.fromOffset(8, UIKit.px(28)), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 5, ScrollBarImageColor3 = T.purple, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.XY, Parent = content,
	})
	UIKit.list(scroller, 8, true)

	local busy = false
	local function research(id: string)
		if busy then
			return
		end
		busy = true
		local ok, res = pcall(function()
			return Remotes.get("Research"):InvokeServer(id)
		end)
		busy = false
		if ok and res and not res.ok then
			Sfx.play("deny")
			Feedback.toast(REASONS[res.reason] or "Could not research that.", "warn")
		end
	end

	local function render()
		local d = State.data
		if not d then
			return
		end
		UIKit.clear(scroller)
		header.Text = ("Research Points: %d     (1 per Rank, more from milestones)"):format(d.rp)
		local colW = UIKit.px(200)
		for bi, branch in Config.Research.branches do
			local col = UIKit.new("Frame", { Size = UDim2.new(0, colW, 1, -6), BackgroundColor3 = T.bg, BorderSizePixel = 0, LayoutOrder = bi, Parent = scroller }, { UIKit.corner(10), UIKit.stroke(branch.color, 2, 0.3) })
			UIKit.title({ Size = UDim2.new(1, -16, 0, UIKit.px(24)), Position = UDim2.fromOffset(8, 6), Text = branch.name, TextSize = UIKit.px(18), TextColor3 = branch.color, TextWrapped = false, Parent = col })
			UIKit.label({ Size = UDim2.new(1, -16, 0, UIKit.px(16)), Position = UDim2.fromOffset(8, UIKit.px(30)), Text = branch.blurb, TextSize = UIKit.px(11), TextColor3 = T.dim, TextWrapped = false, Parent = col })
			local nodesFrame = UIKit.scroll({ Size = UDim2.new(1, -8, 1, -UIKit.px(54)), Position = UDim2.fromOffset(4, UIKit.px(52)), Parent = col })
			UIKit.list(nodesFrame, 6)
			local prevOwned = true
			local n = 0
			for _, node in Config.Research.nodes do
				if node.branch == branch.id then
					n += 1
					local owned = d.research[node.id] == true
					local available = not owned and prevOwned
					local canAfford = d.rp >= node.cost
					local card = UIKit.new("Frame", { Size = UDim2.new(1, -8, 0, UIKit.px(96)), BackgroundColor3 = if owned then T.panel2 else T.panel, BorderSizePixel = 0, LayoutOrder = n, Parent = nodesFrame },
						{ UIKit.corner(8), UIKit.stroke(if owned then T.good elseif available then branch.color else T.panel2, 1.5, 0.3) })
					UIKit.label({ Size = UDim2.new(1, -12, 0, UIKit.px(18)), Position = UDim2.fromOffset(8, 4), Text = ("%d. %s"):format(n, node.name), TextSize = UIKit.px(14), Font = T.fontBold, TextColor3 = if owned or available then T.text else T.dim, TextWrapped = false, Parent = card })
					UIKit.label({ Size = UDim2.new(1, -12, 0, UIKit.px(30)), Position = UDim2.fromOffset(8, UIKit.px(22)), Text = node.text, TextSize = UIKit.px(12), TextColor3 = T.dim, TextYAlignment = Enum.TextYAlignment.Top, Parent = card })
					local text, style
					if owned then
						text, style = "Researched", "disabled"
					elseif not available then
						text, style = "Locked", "disabled"
					elseif canAfford then
						text, style = ("Research (%d RP)"):format(node.cost), "primary"
					else
						text, style = ("Need %d RP"):format(node.cost), "disabled"
					end
					UIKit.button({ Size = UDim2.new(1, -16, 0, UIKit.px(26)), Position = UDim2.new(0, 8, 1, -UIKit.px(32)), Text = text, style = style, TextSize = UIKit.px(12), Parent = card }, function()
						if style == "primary" then
							research(node.id)
						end
					end)
					prevOwned = owned
				end
			end
		end
	end
	Menus.register("research", frame, render)
	State.changed:Connect(function()
		if frame.Visible then
			render()
		end
	end)
end

return ResearchPanel
