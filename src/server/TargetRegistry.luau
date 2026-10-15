-- Maps target ids to the anchored Root part of the built model (filled in by the world builder).
-- The server measures range against these parts, never against anything the client reports.
local TargetRegistry = {}

local roots: { [string]: BasePart } = {}

function TargetRegistry.register(id: string, root: BasePart)
	roots[id] = root
end

function TargetRegistry.get(id: string): BasePart?
	local r = roots[id]
	if r and r.Parent then
		return r
	end
	return nil
end

function TargetRegistry.all(): { [string]: BasePart }
	return roots
end

return TargetRegistry
