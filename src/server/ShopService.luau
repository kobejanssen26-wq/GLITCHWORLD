-- Perks, cosmetics and settings (all whitelisted; every remote validates its input).
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules = require(Shared.Rules)
local Remotes = require(Shared.Remotes)
local Sessions = require(script.Parent.Sessions)
local StateService = require(script.Parent.StateService)
local ProgressService = require(script.Parent.ProgressService)
local RateLimit = require(script.Parent.RateLimit)

local ShopService = {}

function ShopService.start()
	Remotes.get("BuyPerk").OnServerInvoke = function(player: Player, id: any)
		if not RateLimit.allow(player, "perk", 3, 5) then
			return { ok = false, reason = "slow_down" }
		end
		local session = Sessions.get(player)
		if not session or type(id) ~= "string" or #id > 40 then
			return { ok = false, reason = "invalid" }
		end
		local ok, reason = Rules.buyPerk(session.profile, id)
		if ok then
			ProgressService.commit(session, { { kind = "perk", id = id } })
		end
		return { ok = ok, reason = reason }
	end

	Remotes.get("Equip").OnServerInvoke = function(player: Player, kind: any, id: any)
		if not RateLimit.allow(player, "equip", 4, 6) then
			return { ok = false }
		end
		local session = Sessions.get(player)
		if not session or type(kind) ~= "string" or type(id) ~= "string" or #id > 40 then
			return { ok = false }
		end
		local ok = false
		if kind == "trail" then
			ok = Rules.equipTrail(session.profile, id)
		elseif kind == "aura" then
			ok = Rules.equipAura(session.profile, id)
		elseif kind == "title" then
			local Profile = require(Shared.Profile)
			if Profile.validTitles[id] and Rules.titleFor(session.profile.crowns) ~= nil then
				-- a title can be worn once the crowns for it were earned
				local cfg = require(Shared.Config)
				for _, t in cfg.Titles do
					if t.id == id and session.profile.crowns >= t.crowns then
						session.profile.title = id
						ok = true
					end
				end
			end
		end
		if ok then
			ProgressService.commit(session)
		end
		return { ok = ok }
	end

	Remotes.get("SetSetting").OnServerInvoke = function(player: Player, key: any, value: any)
		if not RateLimit.allow(player, "settings", 4, 6) then
			return { ok = false }
		end
		local session = Sessions.get(player)
		if not session or type(key) ~= "string" or type(value) ~= "boolean" then
			return { ok = false }
		end
		if session.profile.settings[key] == nil then
			return { ok = false } -- unknown keys are rejected, never created
		end
		session.profile.settings[key] = value
		StateService.markDirty(session)
		return { ok = true }
	end
end

return ShopService
