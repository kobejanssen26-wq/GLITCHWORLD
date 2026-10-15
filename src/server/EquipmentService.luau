-- Equipment purchases (server-validated), character stat application and the Overcharge gadget.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules = require(Shared.Rules)
local Remotes = require(Shared.Remotes)
local Sessions = require(script.Parent.Sessions)
local StateService = require(script.Parent.StateService)
local ProgressService = require(script.Parent.ProgressService)
local RateLimit = require(script.Parent.RateLimit)
local Stations = require(script.Parent.Stations)

local EquipmentService = {}

function EquipmentService.applyToCharacter(session: Sessions.Session)
	local char = session.player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local stats = Sessions.stats(session)
	hum.UseJumpPower = true
	hum.WalkSpeed = stats.walk
	hum.JumpPower = stats.jump
end

local function buy(player: Player, category: any, id: any)
	if not RateLimit.allow(player, "buy", 4, 6) then
		return { ok = false, reason = "slow_down" }
	end
	local session = Sessions.get(player)
	if not session then
		return { ok = false, reason = "no_session" }
	end
	if session.busy then
		return { ok = false, reason = "busy" }
	end
	if type(category) ~= "string" or type(id) ~= "string" or #id > 40 then
		return { ok = false, reason = "invalid" }
	end
	if not Stations.near(player, "upgrade") then
		return { ok = false, reason = "far" }
	end
	session.busy = true
	local ok, reason = Rules.buy(session.profile, category, id) -- validates funds/order/ownership and charges atomically
	session.busy = false
	if ok then
		local events = { { kind = "bought", category = category, id = id } }
		ProgressService.commit(session, events)
	end
	return { ok = ok, reason = reason }
end

function EquipmentService.start()
	ProgressService.onChange(EquipmentService.applyToCharacter)
	Remotes.get("Buy").OnServerInvoke = buy

	-- Overcharge gadget: temporary absorb-power boost with a cooldown
	Remotes.get("UseGadget").OnServerEvent:Connect(function(player: Player, id: any)
		if type(id) ~= "string" or id ~= "overcharge" then
			return
		end
		if not RateLimit.allow(player, "gadget", 2, 2) then
			return
		end
		local session = Sessions.get(player)
		if not session or not session.profile.gadgets.overcharge then
			return
		end
		local now = os.clock()
		if now < session.gadgetReadyAt then
			StateService.notify(player, { kind = "msg", text = "Overcharge is recharging.", tone = "warn" })
			return
		end
		local oc = Sessions.stats(session).overcharge
		if not oc then
			return
		end
		session.boostUntil = now + oc.duration
		session.gadgetReadyAt = now + oc.cooldown
		StateService.notify(player, { kind = "msg", text = "Overcharge active!", tone = "good" })
		StateService.markDirty(session)
	end)
end

return EquipmentService
