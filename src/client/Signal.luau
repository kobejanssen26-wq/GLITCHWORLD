-- Minimal signal: Connect(fn) -> disconnect function, Fire(...).
local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ handlers = {} :: { [number]: (...any) -> () }, nextId = 0 }, Signal)
end

function Signal:Connect(fn: (...any) -> ()): () -> ()
	self.nextId += 1
	local id = self.nextId
	self.handlers[id] = fn
	return function()
		self.handlers[id] = nil
	end
end

function Signal:Fire(...)
	for _, fn in table.clone(self.handlers) do
		task.spawn(fn, ...)
	end
end

return Signal
