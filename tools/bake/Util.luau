-- Baker utilities. The baker never creates Roblox Instances: it records plain tables and serialises them to an
-- .rbxmx model (Serialize.luau). CFrame/Vector3 math comes from the engine (or the test mock).
local Util = {}

Util.count = 0
Util.byName = {} -- name prefix -> count (for the report)

function Util.root(name: string)
	return { c = "Folder", n = name, kids = {} }
end

function Util.folder(parent, name: string)
	local f = { c = "Folder", n = name, kids = {} }
	table.insert(parent.kids, f)
	return f
end

-- spec: n name, s {x,y,z}, cf CFrame, col {r,g,b}, mat "Neon", shape "Block"|"Ball"|"Cylinder", tr transparency,
--       ref reflectance, collide, touch, query
function Util.part(parent, spec)
	local p = {
		c = "Part", n = spec.n or "Part", s = spec.s, cf = spec.cf, col = spec.col or { 200, 200, 200 }, mat = spec.mat or "SmoothPlastic",
		shape = spec.shape or "Block", tr = spec.tr or 0, ref = spec.ref or 0, collide = spec.collide == true, touch = spec.touch == true,
		query = spec.query == true or spec.collide == true,
	}
	table.insert(parent.kids, p)
	Util.count += 1
	local key = p.n:match("^[^:|]+") or p.n
	Util.byName[key] = (Util.byName[key] or 0) + 1
	return p
end

-- deterministic PRNG (same on every platform)
function Util.rng(seed: number)
	local s = seed % 2147483647
	if s <= 0 then
		s += 2147483646
	end
	local r = {}
	function r.next(): number
		s = (s * 48271) % 2147483647
		return s / 2147483647
	end
	function r.range(a: number, b: number): number
		return a + r.next() * (b - a)
	end
	function r.int(a: number, b: number): number
		return a + math.floor(r.next() * (b - a + 1))
	end
	function r.pick(list)
		return list[r.int(1, #list)]
	end
	return r
end

function Util.shade(col, k: number)
	return { math.clamp(col[1] * k, 0, 255), math.clamp(col[2] * k, 0, 255), math.clamp(col[3] * k, 0, 255) }
end

function Util.mix(a, b, t: number)
	return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end

return Util
