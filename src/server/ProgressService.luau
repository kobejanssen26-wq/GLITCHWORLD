-- Single choke point for "something about this player's progress changed":
-- runs the derived-progress rules (quests, milestones, echo/area unlocks), turns the resulting events into
-- client notifications, invalidates cached stats and informs listeners (character stats, echo followers).
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules = require(Shared.Rules)
local Sessions = require(script.Parent.Sessions)
local StateService = require(script.Parent.StateService)

local ProgressService = {}

local listeners: { (Sessions.Session) -> () } = {}

function ProgressService.onChange(fn: (Sessions.Session) -> ())
	table.insert(listeners, fn)
end

-- events: optional list already produced by a Rules call in the same (yield-free) mutation
function ProgressService.commit(session: Sessions.Session, events: { { [string]: any } }?)
	events = events or {}
	Rules.process(session.profile, events)
	Sessions.invalidate(session)
	for _, e in events :: { { [string]: any } } do
		StateService.notify(session.player, e)
	end
	for _, fn in listeners do
		fn(session)
	end
	StateService.markDirty(session)
end

return ProgressService
