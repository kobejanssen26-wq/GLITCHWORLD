-- Remotes under ReplicatedStorage.Remotes. Client -> server calls are untrusted input: every handler validates
-- types, ids, ownership, distance and rate.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local EVENTS = {
	"State", -- server -> client: profile snapshot
	"Notify", -- server -> client: one-off feedback ({kind=...})
	"CashTick", -- server -> client: (amount, ores) batched factory income
	"Launch", -- server -> client: (upSpeed) bounce pad impulse applied by the client to its own character
	"ClientReady", -- client -> server
	"Jumped2", -- client -> server: used a double jump (only to play effects for others)
}
local FUNCTIONS = {
	"Buy", -- (itemId)
	"BuyPerk", -- (perkId)
	"Skip", -- ()
	"GotoFloor", -- (floor)
	"Overdrive", -- ()
	"Equip", -- (kind, id)
	"SetSetting", -- (key, boolean)
	"Teleport", -- ("tower" | "home")
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
	return ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(name)
end

return Remotes
