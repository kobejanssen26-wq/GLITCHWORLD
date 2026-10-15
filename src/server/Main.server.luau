-- GLITCHWORLD server entry point. Boot order: remotes -> world -> services -> players.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local WorldData = require(Shared.WorldData)

local Server = script.Parent
local DataService = require(Server.DataService)
local Sessions = require(Server.Sessions)
local StateService = require(Server.StateService)
local ProgressService = require(Server.ProgressService)
local RestorationService = require(Server.RestorationService)
local EconomyService = require(Server.EconomyService)
local EquipmentService = require(Server.EquipmentService)
local EchoService = require(Server.EchoService)
local ResearchService = require(Server.ResearchService)
local SettingsService = require(Server.SettingsService)
local Interactions = require(Server.Interactions)
local RateLimit = require(Server.RateLimit)
local Stations = require(Server.Stations)
local WorldBuilder = require(Server.World.WorldBuilder)

Players.CharacterAutoLoads = false

Remotes.create()
StateService.start()
EquipmentService.start()
EconomyService.start()
EchoService.start()
ResearchService.start()
SettingsService.start()
RestorationService.start()

local world = WorldBuilder.build()
Interactions.bind(world)
DataService.startAutosave(60)

local function loadCharacter(player: Player)
	if player.Parent then
		player:LoadCharacterAsync()
	end
end

local function onCharacter(player: Player, character: Model)
	local session = Sessions.get(player)
	if not session then
		return
	end
	local hum = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hum then
		return
	end
	hum.MaxSlopeAngle = 52 -- the boundary cliffs are too steep to climb
	EquipmentService.applyToCharacter(session)
	hum.Died:Connect(function()
		session.absorb = nil
		task.delay(2.5, loadCharacter, player)
	end)
end

local function onPlayerAdded(player: Player)
	local profile, err = DataService.load(player)
	if not profile then
		if player.Parent then
			player:Kick("Could not load your save data (" .. tostring(err) .. "). Your progress is safe - please rejoin in a minute.")
		end
		return
	end
	if not player.Parent then
		-- left while loading: free the session lock without touching their data
		DataService.save(player, true)
		DataService.release(player)
		return
	end
	local session = Sessions.create(player, profile)
	player.CharacterAdded:Connect(function(char)
		onCharacter(player, char)
	end)
	ProgressService.commit(session) -- derived progress (and publishes equipped echoes)

	local restored, secrets = {}, {}
	for id in profile.restored do
		table.insert(restored, id)
	end
	for id in profile.secrets do
		table.insert(secrets, id)
	end
	Remotes.get("TargetSnapshot"):FireClient(player, { restored = restored, secrets = secrets })
	StateService.pushNow(session)
	loadCharacter(player)
end

local function onPlayerRemoving(player: Player)
	local session = Sessions.get(player)
	if session then
		RestorationService.forget(session)
		StateService.forget(session)
	end
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

-- players who fall out of the world are respawned
task.spawn(function()
	while true do
		task.wait(2)
		for player in Sessions.all() do
			local pos = Stations.rootPosition(player)
			if pos and (pos.Y < -60 or math.abs(pos.X) > WorldData.HALF + 20 or math.abs(pos.Z) > WorldData.HALF + 30) then
				task.spawn(loadCharacter, player)
			end
		end
	end
end)

game:BindToClose(function()
	if RunService:IsStudio() then
		task.wait(0.5)
	end
	DataService.saveAllBlocking()
end)
