-- Renders every player's equipped Echoes as small floating companions (purely visual, local).
-- The equipped list comes from the replicated "Echoes" player attribute set by the server.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local EchoModel = require(Shared.EchoModel)

local EchoFollowers = {}

type Follower = { id: string, model: Model, pos: Vector3?, phase: number }

local byPlayer: { [Player]: { followers: { Follower }, key: string } } = {}
local folder: Folder

local lookById: { [string]: any } = {}
for _, e in Config.Echoes do
	lookById[e.id] = e.look
end

local OFFSETS = { Vector3.new(-3.2, 2.6, 3.4), Vector3.new(3.2, 3.2, 3.4), Vector3.new(0, 5.0, 5.4) }

local function clear(player: Player)
	local rec = byPlayer[player]
	if rec then
		for _, f in rec.followers do
			f.model:Destroy()
		end
		byPlayer[player] = nil
	end
end

local function rebuild(player: Player)
	local raw = player:GetAttribute("Echoes")
	local key = if type(raw) == "string" then raw else ""
	local rec = byPlayer[player]
	if rec and rec.key == key then
		return
	end
	clear(player)
	if key == "" then
		return
	end
	local followers = {}
	for i, id in string.split(key, ",") do
		local look = lookById[id]
		if look and i <= 3 then
			local model = EchoModel.build(look, folder)
			model:ScaleTo(0.85)
			table.insert(followers, { id = id, model = model, pos = nil, phase = i * 1.7 })
		end
	end
	byPlayer[player] = { followers = followers, key = key }
end

function EchoFollowers.init()
	folder = Instance.new("Folder")
	folder.Name = "EchoFollowers"
	folder.Parent = Workspace

	local function watch(player: Player)
		rebuild(player)
		player:GetAttributeChangedSignal("Echoes"):Connect(function()
			rebuild(player)
		end)
	end
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clear)

	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		local cam = Workspace.CurrentCamera
		for player, rec in byPlayer do
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp and cam and (hrp.Position - cam.CFrame.Position).Magnitude < 160 then
				local cf = hrp.CFrame
				for i, f in rec.followers do
					local off = OFFSETS[i] or OFFSETS[1]
					local target = (cf * CFrame.new(off.X, off.Y + math.sin(now * 2 + f.phase) * 0.35, off.Z)).Position
					local pos = f.pos or target
					pos = pos:Lerp(target, 1 - math.exp(-dt * 5))
					f.pos = pos
					local lookAt = hrp.Position + cf.LookVector * 30
					f.model:PivotTo(CFrame.lookAt(pos, Vector3.new(lookAt.X, pos.Y, lookAt.Z)))
				end
			end
		end
	end)
end

return EchoFollowers
