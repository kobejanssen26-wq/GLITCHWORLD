-- NEONFORGE server entry point. Boot: remotes -> world dressing -> services -> players.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Server = script.Parent
local DataService = require(Server.DataService)
local Sessions = require(Server.Sessions)
local StateService = require(Server.StateService)
local ProgressService = require(Server.ProgressService)
local PlotService = require(Server.PlotService)
local TycoonService = require(Server.TycoonService)
local ObbyService = require(Server.ObbyService)
local ShopService = require(Server.ShopService)
local WorldSetup = require(Server.WorldSetup)
local RateLimit = require(Server.RateLimit)

Players.RespawnTime = 2.5

Remotes.create()
local world = Workspace:WaitForChild("World", 30)
if not world then
	error("[Neonforge] Workspace.World is missing: build the place with Rojo (world/World.rbxm)")
end
WorldSetup.run(world)
PlotService.init(world)
StateService.start()
TycoonService.start()
ShopService.start()
local counts = ObbyService.start(world)
print(("[Neonforge] tower behaviours: %d movers, %d spinners, %d lasers, %d vanish, %d bounce, %d speed, %d belts, %d coins"):format(
	counts.mover, counts.spinner, counts.laser, counts.vanish, counts.bounce, counts.speed, counts.belt, counts.coin))
DataService.startAutosave(60)

-- Remote events fired before the client connected a handler are lost, so the initial state is sent only once BOTH the
-- session exists (data loaded) and the client said it is ready.
local clientReady: { [Player]: boolean } = {}

Remotes.get("ClientReady").OnServerEvent:Connect(function(player: Player)
	if not RateLimit.allow(player, "ready", 0.5, 3) then
		return
	end
	clientReady[player] = true
	local session = Sessions.get(player)
	if session then
		session.ready = true
		StateService.pushNow(session)
	end
end)

local function onPlayerAdded(player: Player)
	local profile, err = DataService.load(player)
	if not profile then
		if player.Parent then
			player:Kick("Could not load your save data (" .. tostring(err) .. "). Your progress is safe - please rejoin in a minute.")
		end
		return
	end
	if not player.Parent then
		DataService.save(player, true) -- left while loading: free the session lock, never touch the data
		DataService.release(player)
		return
	end
	local session = Sessions.create(player, profile)
	session.ready = clientReady[player] == true
	if not PlotService.claim(session) then
		StateService.notify(player, { kind = "msg", text = "All plots are taken on this server. You can still climb the tower!", tone = "warn" })
	end
	player.CharacterAdded:Connect(function(char)
		ObbyService.onCharacter(session, char)
	end)
	if player.Character then
		task.spawn(ObbyService.onCharacter, session, player.Character)
	end
	ProgressService.commit(session)
	StateService.pushNow(session)
end

local function onPlayerRemoving(player: Player)
	local session = Sessions.get(player)
	if session then
		PlotService.release(session)
		StateService.forget(session)
		session.profile.stats.playSeconds += math.floor(os.clock() - session.loadedAt)
	end
	clientReady[player] = nil
	DataService.save(player, true) -- final save; clears the session lock
	DataService.release(player)
	Sessions.remove(player)
	RateLimit.forget(player)
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(onPlayerAdded, player)
end)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

game:BindToClose(function()
	if RunService:IsStudio() then
		task.wait(0.5)
	end
	DataService.saveAllBlocking()
end)
