-- Research tree purchases (spent with Research Points).
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules = require(Shared.Rules)
local Remotes = require(Shared.Remotes)
local Sessions = require(script.Parent.Sessions)
local ProgressService = require(script.Parent.ProgressService)
local RateLimit = require(script.Parent.RateLimit)

local ResearchService = {}

function ResearchService.start()
	Remotes.get("Research").OnServerInvoke = function(player: Player, nodeId: any)
		if not RateLimit.allow(player, "research", 3, 4) then
			return { ok = false, reason = "slow_down" }
		end
		local session = Sessions.get(player)
		if not session or type(nodeId) ~= "string" or #nodeId > 40 then
			return { ok = false, reason = "invalid" }
		end
		local ok, reason = Rules.buyResearch(session.profile, nodeId)
		if ok then
			ProgressService.commit(session, { { kind = "researched", id = nodeId } })
		end
		return { ok = ok, reason = reason }
	end
end

return ResearchService
