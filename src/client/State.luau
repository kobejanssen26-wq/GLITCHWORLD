-- Client mirror of server state. The server is authoritative; this only caches the latest snapshot plus the
-- per-player target states used for visuals.
local Signal = require(script.Parent.Signal)

local State = {}

State.data = nil :: any -- latest snapshot from the server (nil until the first push)
State.changed = Signal.new() -- fires with the new snapshot
State.restored = {} :: { [string]: boolean } -- permanent targets / secrets already restored by this player
State.cooling = {} :: { [string]: number } -- renewable id -> os.clock() when it regrows
State.targetChanged = Signal.new() -- fires (id, state)

function State.set(snapshot: any)
	snapshot._at = os.clock() -- receive time, used to count cooldowns down locally
	State.data = snapshot
	State.changed:Fire(snapshot)
end

function State.isAvailable(id: string, permanent: boolean): boolean
	if permanent then
		return not State.restored[id]
	end
	local t = State.cooling[id]
	return t == nil or os.clock() >= t
end

function State.setTarget(id: string, state: string, seconds: number?)
	if state == "restored" then
		State.restored[id] = true
	elseif state == "cooling" then
		State.cooling[id] = os.clock() + (seconds or 30)
	elseif state == "ready" then
		State.cooling[id] = nil
	elseif state == "corrupted" then
		State.restored[id] = nil
	end
	State.targetChanged:Fire(id, state)
end

return State
