-- Per-player runtime state that lives only on this server (the persistent part is session.profile).
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules = require(Shared.Rules)

local Sessions = {}

export type Session = {
	player: Player,
	profile: any,
	ready: boolean, -- client connected its handlers (events sent earlier would be lost)
	lastSent: number,
	plot: number?, -- plot index owned by this player
	inTower: boolean, -- respawn at the tower checkpoint instead of at the plot
	lastCheckpoint: number, -- last checkpoint floor touched in this life of the session (0 = none)
	checkpointAt: number, -- os.clock() when it was touched
	lastGoto: number,
	dropperClock: number, -- last factory tick (server time)
	arrivals: { { t: number, id: string } },
	pendingCash: number,
	pendingOres: number,
	fraction: number,
	lastTick: number,
	busy: boolean,
	boostToken: number,
	coinsTaken: { [Instance]: boolean },
	loadedAt: number,
	lastSave: number,
}

local byPlayer: { [Player]: Session } = {}

function Sessions.create(player: Player, profile: any): Session
	local s: Session = {
		player = player, profile = profile, ready = false, lastSent = 0, plot = nil, inTower = false, lastCheckpoint = 0,
		checkpointAt = 0, lastGoto = 0, dropperClock = 0, arrivals = {}, pendingCash = 0, pendingOres = 0, fraction = 0,
		lastTick = 0, busy = false, boostToken = 0, coinsTaken = {}, loadedAt = os.clock(), lastSave = os.clock(),
	}
	byPlayer[player] = s
	return s
end

function Sessions.get(player: Player): Session?
	return byPlayer[player]
end

function Sessions.remove(player: Player)
	byPlayer[player] = nil
end

function Sessions.all(): { [Player]: Session }
	return byPlayer
end

function Sessions.movement(session: Session)
	return Rules.movement(session.profile)
end

return Sessions
