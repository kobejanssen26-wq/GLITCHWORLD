-- Per-player runtime state that lives only on this server (the persistent part is session.profile).
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules = require(Shared.Rules)

local Sessions = {}

export type Session = {
	player: Player,
	profile: any,
	statsCache: any?,
	absorb: { id: string }?, -- what the player is currently holding the absorb button on
	progress: { [string]: { hp: number, last: number } }, -- partial absorption per target (this player only)
	cooling: { [string]: number }, -- renewable target id -> os.clock() when it regrows
	boostUntil: number,
	gadgetReadyAt: number,
	lastSent: number, -- last State push
	lastProgressSent: number,
	lastFullWarn: number,
	busy: boolean, -- purchase / sell lock: one mutation at a time per player
	deniedTier: { [string]: boolean }, -- targets we already told the player they cannot absorb yet
}

local byPlayer: { [Player]: Session } = {}

function Sessions.create(player: Player, profile: any): Session
	local s: Session = {
		player = player,
		profile = profile,
		statsCache = nil,
		absorb = nil,
		progress = {},
		cooling = {},
		boostUntil = 0,
		gadgetReadyAt = 0,
		lastSent = 0,
		lastProgressSent = 0,
		lastFullWarn = 0,
		busy = false,
		deniedTier = {},
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

function Sessions.stats(session: Session)
	if not session.statsCache then
		session.statsCache = Rules.computeStats(session.profile)
	end
	return session.statsCache
end

function Sessions.invalidate(session: Session)
	session.statsCache = nil
end

return Sessions
