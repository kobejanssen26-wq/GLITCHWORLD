-- Client mirror of the server snapshot.
local Signal = require(script.Parent.Signal)

local State = {}

State.data = nil :: any
State.changed = Signal.new()

function State.set(snapshot: any)
	snapshot._at = os.clock()
	State.data = snapshot
	State.changed:Fire(snapshot)
end

return State
