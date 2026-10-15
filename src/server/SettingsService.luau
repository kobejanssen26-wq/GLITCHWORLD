-- Player settings (boolean flags) and title selection. Everything is whitelisted.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Sessions = require(script.Parent.Sessions)
local StateService = require(script.Parent.StateService)
local RateLimit = require(script.Parent.RateLimit)

local SettingsService = {}

function SettingsService.start()
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
	Remotes.get("SetTitle").OnServerInvoke = function(player: Player, title: any)
		if not RateLimit.allow(player, "title", 2, 3) then
			return { ok = false }
		end
		local session = Sessions.get(player)
		if not session or type(title) ~= "string" or #title > 40 or not session.profile.titles[title] then
			return { ok = false }
		end
		session.profile.title = title
		StateService.markDirty(session)
		return { ok = true }
	end
end

return SettingsService
