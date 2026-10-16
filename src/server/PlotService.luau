-- Plot ownership + factory construction. The baked world contains eight empty plots with marker parts; machines are
-- built here when a player claims a plot and as they buy pieces.
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)
local Mk = require(script.Parent.Mk)
local Factory = require(script.Parent.Plots.Factory)
local Sessions = require(script.Parent.Sessions)

local PlotService = {}
PlotService.onPad = nil :: ((number, BasePart) -> ())? -- set by TycoonService: a part touched the buy pad of plot n
PlotService.onOverdrive = nil :: ((Player) -> ())?

type Plot = { index: number, origin: CFrame, sign: BasePart, spawn: CFrame, folder: Folder, pad: BasePart?, owner: Player?, label: BillboardGui? }
local plots: { Plot } = {}
local factories: Folder

function PlotService.init(world: Instance)
	factories = Instance.new("Folder")
	factories.Name = "Factories"
	factories.Parent = Workspace
	local plotsFolder = world:WaitForChild("Plots")
	for i = 1, Config.Plots.COUNT do
		local pf = plotsFolder:WaitForChild("Plot" .. i)
		local origin = pf:WaitForChild("Marker:PlotOrigin:" .. i) :: BasePart
		local sign = pf:WaitForChild("Marker:PlotSign:" .. i) :: BasePart
		local sp = pf:WaitForChild("Marker:PlotSpawn:" .. i) :: BasePart
		local folder = Instance.new("Folder")
		folder.Name = "Plot" .. i
		folder:SetAttribute("Origin", origin.CFrame) -- the client draws ores relative to this
		folder.Parent = factories
		plots[i] = { index = i, origin = origin.CFrame, sign = sign, spawn = sp.CFrame, folder = folder, pad = nil, owner = nil, label = nil }
	end
end

function PlotService.get(i: number): Plot?
	return plots[i]
end

function PlotService.all(): { Plot }
	return plots
end

local function clear(plot: Plot)
	plot.folder:ClearAllChildren()
	plot.pad = nil
	if plot.label then
		plot.label:Destroy()
		plot.label = nil
	end
end

local function itemList(profile)
	local out = {}
	for _, it in Config.Items do
		if profile.items[it.id] then
			table.insert(out, it)
		end
	end
	return out
end

local function hook(plot: Plot, model: Instance)
	for _, d in model:GetDescendants() do
		if d:IsA("ProximityPrompt") and d:GetAttribute("Action") == "overdrive" then
			d.Triggered:Connect(function(player)
				if plot.owner == player and PlotService.onOverdrive then
					PlotService.onOverdrive(player)
				end
			end)
		end
	end
end

function PlotService.build(plot: Plot, profile: any)
	clear(plot)
	local O = plot.origin
	Factory.buildBelt(plot.folder, O)
	local pad = Factory.buildPad(plot.folder, O)
	plot.pad = pad
	pad.Touched:Connect(function(hit)
		if PlotService.onPad then
			PlotService.onPad(plot.index, hit)
		end
	end)
	for _, it in itemList(profile) do
		hook(plot, Factory.buildItem(plot.folder, O, it))
	end
end

function PlotService.addItem(plot: Plot, item: any)
	hook(plot, Factory.buildItem(plot.folder, plot.origin, item))
end

-- the pad shows what to buy next
function PlotService.updatePad(plot: Plot, profile: any)
	if not plot.pad then
		return
	end
	local old = plot.pad:FindFirstChild("Label")
	if old then
		old:Destroy()
	end
	local nxt = Rules.nextItem(profile)
	local text, color
	if nxt then
		text = ("%s\n$%s"):format(nxt.name, tostring(Rules.itemCost(nxt, profile)))
		color = { 70, 240, 255 }
	else
		text, color = "Factory complete!", { 255, 215, 90 }
	end
	Mk.label(plot.pad, text, 5, color, UDim2.fromOffset(300, 80), 160)
end

function PlotService.claim(session: Sessions.Session): Plot?
	for _, plot in plots do
		if not plot.owner then
			plot.owner = session.player
			session.plot = plot.index
			session.player:SetAttribute("Plot", plot.index)
			PlotService.build(plot, session.profile)
			PlotService.updatePad(plot, session.profile)
			local lbl = Mk.label(plot.sign, ("%s's Factory"):format(session.player.DisplayName), 0, Config.Colors.cyan, UDim2.fromOffset(520, 90), 400)
			plot.label = lbl
			return plot
		end
	end
	return nil
end

function PlotService.release(session: Sessions.Session)
	local i = session.plot
	if i and plots[i] and plots[i].owner == session.player then
		plots[i].owner = nil
		clear(plots[i])
	end
	session.plot = nil
end

function PlotService.spawnCFrame(plotIndex: number): CFrame
	return plots[plotIndex].spawn + Vector3.new(0, 3, 0)
end

return PlotService
