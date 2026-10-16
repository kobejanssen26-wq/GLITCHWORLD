-- Single choke point for "this player's profile changed": derived unlocks, character stats / cosmetics attributes,
-- leaderstats, notifications and a state push.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules = require(Shared.Rules)
local Sessions = require(script.Parent.Sessions)
local StateService = require(script.Parent.StateService)

local ProgressService = {}

local function leaderstats(player: Player): Folder
	local f = player:FindFirstChild("leaderstats")
	if not f then
		f = Instance.new("Folder")
		f.Name = "leaderstats"
		f.Parent = player
		for _, n in { "Floor", "Crowns", "Overdrive" } do
			local v = Instance.new("IntValue")
			v.Name = n
			v.Parent = f
		end
	end
	return f :: Folder
end

function ProgressService.applyCharacter(session: Sessions.Session)
	local char = session.player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local mv = Rules.movement(session.profile)
	hum.UseJumpPower = true
	hum.WalkSpeed = mv.walk
	hum.JumpPower = mv.jump
end

function ProgressService.publish(session: Sessions.Session)
	local p, player = session.profile, session.player
	player:SetAttribute("Trail", p.trail)
	player:SetAttribute("Aura", p.aura)
	player:SetAttribute("TitleText", p.title)
	player:SetAttribute("Crowns", p.crowns)
	player:SetAttribute("Overdrive", p.overdrive)
	player:SetAttribute("Floor", p.checkpoint)
	player:SetAttribute("DoubleJump", p.perks.double_jump == true)
	player:SetAttribute("Magnet", Rules.movement(p).magnet)
	local ls = leaderstats(player)
	ls.Floor.Value = p.reached
	ls.Crowns.Value = p.crowns
	ls.Overdrive.Value = p.overdrive
end

-- events: optional notification payloads already produced by the caller's mutation
function ProgressService.commit(session: Sessions.Session, events: { { [string]: any } }?)
	for _, e in Rules.unlocks(session.profile) do
		StateService.notify(session.player, { kind = "unlock", what = e.kind, id = e.id })
	end
	for _, e in (events or {}) :: { { [string]: any } } do
		StateService.notify(session.player, e)
	end
	ProgressService.applyCharacter(session)
	ProgressService.publish(session)
	StateService.markDirty(session)
end

return ProgressService
