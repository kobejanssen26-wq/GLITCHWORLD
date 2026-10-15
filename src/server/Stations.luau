-- Server-side proximity checks for station-bound actions (selling, buying). Never trust the client's claim that
-- it is "at" a station.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local WorldData = require(Shared.WorldData)

local Stations = {}

function Stations.rootPosition(player: Player): Vector3?
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or hum.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil
	end
	return root.Position
end

function Stations.near(player: Player, stationId: string, radius: number?): boolean
	local s = WorldData.Stations[stationId]
	local pos = Stations.rootPosition(player)
	if not s or not pos then
		return false
	end
	local dx, dz = pos.X - s.x, pos.Z - s.z
	return dx * dx + dz * dz <= (radius or Config.Economy.STATION_RADIUS) ^ 2
end

return Stations
