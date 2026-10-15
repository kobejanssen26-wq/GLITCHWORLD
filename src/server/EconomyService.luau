-- Converting fragments into Credits at the Restoration Station.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules = require(Shared.Rules)
local Remotes = require(Shared.Remotes)
local Sessions = require(script.Parent.Sessions)
local StateService = require(script.Parent.StateService)
local ProgressService = require(script.Parent.ProgressService)
local RateLimit = require(script.Parent.RateLimit)
local Stations = require(script.Parent.Stations)

local EconomyService = {}

function EconomyService.sell(player: Player)
	if not RateLimit.allow(player, "sell", 3, 3) then
		return { ok = false, reason = "slow_down" }
	end
	local session = Sessions.get(player)
	if not session then
		return { ok = false, reason = "no_session" }
	end
	if session.busy then
		return { ok = false, reason = "busy" }
	end
	if not Stations.near(player, "sell") then
		return { ok = false, reason = "far" }
	end
	if session.profile.fragments <= 0 then
		StateService.notify(player, { kind = "msg", text = "Your backpack is empty. Absorb some corruption first!", tone = "warn" })
		return { ok = false, reason = "empty" }
	end
	session.busy = true
	local credits, count = Rules.sellAll(session.profile, Sessions.stats(session))
	session.busy = false
	ProgressService.commit(session, { { kind = "sold", credits = credits, fragments = count } })
	return { ok = true, credits = credits, fragments = count }
end

function EconomyService.start()
	Remotes.get("Sell").OnServerInvoke = function(player: Player)
		return EconomyService.sell(player)
	end
end

return EconomyService
