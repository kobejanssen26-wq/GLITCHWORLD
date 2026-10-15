-- Equipping / unequipping Echoes and publishing the equipped list so every client can render the followers.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules = require(Shared.Rules)
local Remotes = require(Shared.Remotes)
local Sessions = require(script.Parent.Sessions)
local ProgressService = require(script.Parent.ProgressService)
local RateLimit = require(script.Parent.RateLimit)

local EchoService = {}

function EchoService.publish(session: Sessions.Session)
	-- "mossbit,pebblit": replicated attribute, read by client EchoFollowers for every player
	session.player:SetAttribute("Echoes", table.concat(session.profile.equipped, ","))
end

function EchoService.start()
	ProgressService.onChange(EchoService.publish)
	Remotes.get("EchoAction").OnServerInvoke = function(player: Player, action: any, id: any)
		if not RateLimit.allow(player, "echo", 4, 6) then
			return { ok = false, reason = "slow_down" }
		end
		local session = Sessions.get(player)
		if not session or type(action) ~= "string" or type(id) ~= "string" or #id > 40 then
			return { ok = false, reason = "invalid" }
		end
		local ok, reason
		if action == "equip" then
			ok, reason = Rules.equipEcho(session.profile, id)
		elseif action == "unequip" then
			ok, reason = Rules.unequipEcho(session.profile, id)
		else
			return { ok = false, reason = "invalid" }
		end
		if ok then
			ProgressService.commit(session)
		end
		return { ok = ok, reason = reason }
	end
end

return EchoService
