-- Creates (server) / fetches (client) every remote under ReplicatedStorage.Remotes.
-- Client -> server remotes are ALWAYS treated as untrusted input: handlers validate types, ids, distance and rate.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

-- server -> client
local EVENTS = {
	"State", -- full profile snapshot (throttled)
	"Notify", -- one-off feedback events (restored, reward, milestone, echo, ...)
	"TargetUpdate", -- (id, state, seconds?) state = "restored" | "cooling" | "ready" | "corrupted"
	"TargetSnapshot", -- { restored = {id,...}, secrets = {id,...} } once after join
	"AbsorbProgress", -- (targetId?, fraction, boosted)
	"OpenMenu", -- (menuName)
	-- client -> server
	"AbsorbControl", -- ("start", targetId) / ("stop")
	"UseGadget", -- (gadgetId)
	"ClientReady", -- () the client connected its handlers; the server may now send the initial state
}
local FUNCTIONS = {
	"Buy", -- (category, id) -> result
	"Sell", -- () -> result
	"EchoAction", -- ("equip"|"unequip", id) -> result
	"Research", -- (nodeId) -> result
	"SetSetting", -- (key, boolean) -> result
	"SetTitle", -- (title) -> result
}

function Remotes.create()
	assert(RunService:IsServer())
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in EVENTS do
		local e = Instance.new("RemoteEvent")
		e.Name = name
		e.Parent = folder
	end
	for _, name in FUNCTIONS do
		local f = Instance.new("RemoteFunction")
		f.Name = name
		f.Parent = folder
	end
	folder.Parent = ReplicatedStorage
end

function Remotes.get(name: string): any
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	return folder:WaitForChild(name)
end

return Remotes
