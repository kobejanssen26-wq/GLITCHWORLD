-- Obstacle modules. Each module lives in a local frame: x = across (+ towards the tower), y = up (0 = walking
-- surface), u = along the path (forward). The path width is 20 (x in -10..10) and the obstacle zone is u in -11..11
-- with solid 11-stud connectors on both sides (added by the caller). Behaviour is encoded in part names and
-- applied at runtime by the server: Kill, Mover:, KillMover:, SpinnerKill:, Turntable:, Vanish:, Bounce:, Speed:,
-- Belt:, Laser:, Piston:  (see src/server/Obby/Behaviors.luau).
local Util = require(script.Parent.Util)

local Modules = {}

local PI = math.pi

-- ===== context =====
function Modules.context(parent, F, theme, d: number, rng, index: number)
	local c = { F = F, theme = theme, d = d, rng = rng, index = index, foots = {}, parent = parent }
	c.main, c.accent, c.glow, c.mat = theme.main, theme.accent, theme.glow, theme.mat

	local function place(x, y, u, rot)
		local cf = F * CFrame.new(x, y, -u)
		if rot then
			cf = cf * rot
		end
		return cf
	end
	c.place = place

	function c.box(name, sx, sy, sz, x, y, u, o)
		o = o or {}
		return Util.part(parent, {
			n = name, s = { sx, sy, sz }, cf = place(x, y, u, o.rot), col = o.col or c.main, mat = o.mat or c.mat, tr = o.tr,
			ref = o.ref, collide = o.collide, touch = o.touch,
		})
	end
	function c.cyl(name, height, diameter, x, y, u, o)
		o = o or {}
		local rot = CFrame.Angles(0, 0, PI / 2)
		if o.rot then
			rot = o.rot * rot
		end
		return Util.part(parent, {
			n = name, s = { height, diameter, diameter }, cf = place(x, y, u, rot), col = o.col or c.main, mat = o.mat or c.mat, shape = "Cylinder",
			tr = o.tr, ref = o.ref, collide = o.collide, touch = o.touch,
		})
	end
	function c.ball(name, diameter, x, y, u, o)
		o = o or {}
		return Util.part(parent, {
			n = name, s = { diameter, diameter, diameter }, cf = place(x, y, u, o.rot), col = o.col or c.main, mat = o.mat or c.mat, shape = "Ball",
			tr = o.tr, ref = o.ref, collide = o.collide, touch = o.touch,
		})
	end
	-- footholds: u0,u1 along the path, x0,x1 across, y surface height, kind static|moving|vanish|boost|bounce
	function c.foot(u0, u1, x0, x1, y, kind)
		table.insert(c.foots, { u0 = u0, u1 = u1, x0 = x0, x1 = x1, y = y, kind = kind or "static" })
	end
	-- world-space vector of a local displacement
	function c.vec(x, y, u)
		local p = F * Vector3.new(x, y, -u)
		local o = F.Position
		return Vector3.new(p.X - o.X, p.Y - o.Y, p.Z - o.Z)
	end
	-- thin neon outline on top of a rectangle (local coordinates)
	function c.trim(x0, x1, u0, u1, y, col)
		col = col or c.glow
		local w, l = x1 - x0, u1 - u0
		local cx, cu = (x0 + x1) / 2, (u0 + u1) / 2
		c.box("Trim", w, 0.15, 0.3, cx, y + 0.08, u0 + 0.15, { col = col, mat = "Neon" })
		c.box("Trim", w, 0.15, 0.3, cx, y + 0.08, u1 - 0.15, { col = col, mat = "Neon" })
		c.box("Trim", 0.3, 0.15, l, x0 + 0.15, y + 0.08, cu, { col = col, mat = "Neon" })
		c.box("Trim", 0.3, 0.15, l, x1 - 0.15, y + 0.08, cu, { col = col, mat = "Neon" })
	end
	-- a solid slab whose top is at y with a glowing outline
	function c.slab(name, x0, x1, u0, u1, y, thick, o)
		o = o or {}
		local p = c.box(name, x1 - x0, thick, u1 - u0, (x0 + x1) / 2, y - thick / 2, (u0 + u1) / 2, { col = o.col, mat = o.mat, collide = true, touch = o.touch })
		if o.trim ~= false then
			c.trim(x0, x1, u0, u1, y, o.trimCol)
		end
		return p
	end
	return c
end

local function dirName(prefix: string, v, ...)
	local extra = { ... }
	local parts = { ("%.3f,%.3f,%.3f"):format(v.X, v.Y, v.Z) }
	for _, e in extra do
		table.insert(parts, tostring(e))
	end
	return prefix .. ":" .. table.concat(parts, ":")
end

-- ===== the twelve obstacle types =====
local M = {}

M.stepping = function(c)
	local d = c.d
	local ell = 4 - 1.6 * d
	local g = (22 - 3 * ell) / 4
	local sign = c.rng.next() < 0.5 and -1 or 1
	for i = 0, 2 do
		local u0 = -11 + g + i * (ell + g)
		local u1 = u0 + ell
		local x = sign * (2 + 3 * d) * (i % 2 == 0 and 1 or -1)
		local w = 6 - 1.5 * d
		c.slab("Tile", x - w / 2, x + w / 2, u0, u1, 0, 1.2, { col = c.accent })
		c.foot(u0, u1, x - w / 2, x + w / 2, 0)
		c.box("Underglow", w * 0.6, 0.2, ell * 0.6, x, -1.4, (u0 + u1) / 2, { col = c.glow, mat = "Neon" })
	end
end

M.movers = function(c)
	local d = c.d
	local amp = 5
	local period = 3.6 - 1.5 * d
	for i, u in { -5.5, 5.5 } do
		c.box(dirName("Mover", c.vec(amp * 2, 0, 0), ("%.2f"):format(period), (i - 1) * 0.5), 6, 1, 6, -amp, -0.5, u, { col = c.accent, collide = true })
		c.box("Trim", 6, 0.15, 0.3, -amp, 0.08, u - 2.85, { col = c.glow, mat = "Neon" })
		c.foot(u - 3, u + 3, -amp - 3, amp + 3, 0, "moving")
	end
end

M.spinner = function(c)
	local d = c.d
	c.slab("Pad", -10, 10, -11, 11, 0, 1.5)
	c.foot(-11, 11, -10, 10, 0)
	c.ball("Hub", 2.2, 0, 1, -5, { col = c.glow, mat = "Neon" })
	c.ball("Hub", 2.2, 0, 1, 5, { col = c.glow, mat = "Neon" })
	local sp = 1.3 + 1.1 * d
	c.box(("SpinnerKill:%.2f"):format(sp), 18, 1.2, 1.2, 0, 1.2, -5, { col = c.glow, mat = "Neon", touch = true })
	c.box(("SpinnerKill:%.2f"):format(-sp), 18, 1.2, 1.2, 0, 1.2, 5, { col = c.glow, mat = "Neon", touch = true })
end

M.lasers = function(c)
	local d = c.d
	c.slab("Pad", -10, 10, -11, 11, 0, 1.5)
	c.foot(-11, 11, -10, 10, 0)
	local on, off = 0.9 + 0.9 * d, 1.4 - 0.5 * d
	for i, u in { -8, -3, 2, 7 } do
		c.box(("Laser:%.2f,%.2f,%.2f"):format(on, off, (i - 1) * 0.55), 20, 0.4, 0.4, 0, 1.3, u, { col = { 255, 40, 70 }, mat = "Neon", touch = true, tr = 0.1 })
		c.box("Emitter", 1.2, 2.2, 1.2, -10.8, 1.1, u, { col = c.main, collide = false })
		c.box("Emitter", 1.2, 2.2, 1.2, 10.8, 1.1, u, { col = c.main, collide = false })
		c.ball("EmitterLens", 0.9, -10.8, 1.3, u, { col = { 255, 40, 70 }, mat = "Neon" })
		c.ball("EmitterLens", 0.9, 10.8, 1.3, u, { col = { 255, 40, 70 }, mat = "Neon" })
	end
end

M.vanish = function(c)
	local d = c.d
	local delay = 1.0 - 0.5 * d
	for r, u in { -8.25, -2.75, 2.75, 8.25 } do
		local missing = c.rng.int(1, 3)
		for col, x in { -6.5, 0, 6.5 } do
			if col ~= missing then
				c.box(("Vanish:%.2f"):format(delay), 6, 1, 4.5, x, -0.5, u, { col = Util.shade(c.accent, 0.85 + 0.15 * ((r + col) % 2)), collide = true, touch = true })
				c.box("Trim", 6, 0.12, 0.25, x, 0.07, u - 2.1, { col = c.glow, mat = "Neon" })
				c.foot(u - 2.25, u + 2.25, x - 3, x + 3, 0, "vanish")
			end
		end
	end
end

M.belt = function(c)
	local d = c.d
	local speed = 5 + 4 * d
	c.box(dirName("Belt", c.vec(0, 0, -speed)), 8, 1, 22, 0, -0.5, 0, { col = Util.shade(c.main, 0.6), mat = "DiamondPlate", collide = true })
	c.foot(-11, 11, -4, 4, 0, "belt")
	for _, x in { -7, 7 } do
		c.box("Kill", 6, 0.5, 22, x, -0.25, 0, { col = { 255, 90, 20 }, mat = "Neon", touch = true })
		c.box("Rail", 0.5, 2.2, 22, x + (x < 0 and -3.2 or 3.2), 1.1, 0, { col = c.main, collide = true })
	end
	for u = -9, 9, 3 do
		c.box("Chevron", 3, 0.1, 0.8, 0, 0.06, u, { col = c.glow, mat = "Neon" })
	end
end

M.bounce = function(c)
	c.slab("Start", -5, 5, -11, -6.5, 0, 1.5)
	c.foot(-11, -6.5, -5, 5, 0)
	c.box("Bounce:105", 4, 0.6, 4, 0, 0.3, -9, { col = { 255, 70, 200 }, mat = "Neon", collide = true, touch = true })
	c.cyl("BouncePad", 0.4, 3.2, 0, 0.75, -9, { col = { 255, 255, 255 }, mat = "Neon" })
	c.slab("Landing", -5, 5, 1, 9, 9, 1.5)
	c.foot(1, 9, -5, 5, 9, "bounce")
	c.box("Pillar", 3, 9, 3, 0, 4.5 - 2, 5, { col = Util.shade(c.main, 0.7), collide = true })
	for _, u in { -8, 0, 8 } do
		c.ball("Orb", 1.2, 0, 14 + u * 0.1, u, { col = c.glow, mat = "Neon" })
	end
end

M.pistons = function(c)
	local d = c.d
	c.slab("Pad", -10, 10, -11, 11, 0, 1.5)
	c.foot(-11, 11, -10, 10, 0)
	local period = 2.6 - 0.6 * d
	for i, u in { -7, 0, 7 } do
		c.box(("Piston:%.2f:%.2f:%.2f"):format(-7.4, period, (i - 1) * period / 3), 20, 3, 3, 0, 9, u, { col = c.glow, mat = "Neon", touch = true })
		c.box("PistonFrame", 1.5, 14, 1.5, -10.5, 7, u, { col = c.main, collide = true })
		c.box("PistonFrame", 1.5, 14, 1.5, 10.5, 7, u, { col = c.main, collide = true })
		c.box("PistonFrame", 22, 1.2, 1.5, 0, 14, u, { col = c.main, collide = false })
	end
end

M.pendulum = function(c)
	local d = c.d
	c.slab("Beam", -2, 2, -11, 11, 0, 1.2, { col = c.accent })
	c.foot(-11, 11, -2, 2, 0)
	local period = 2.6 - 0.7 * d
	for i, u in { -4, 4 } do
		c.ball(dirName("KillMover", c.vec(8, 0, 0), ("%.2f"):format(period), (i - 1) * period / 2), 3, -4, 2.4, u, { col = c.glow, mat = "Neon", touch = true })
		c.box("Rod", 0.3, 9, 0.3, 0, 6.5, u, { col = c.main, mat = "Metal" })
	end
end

M.speedgap = function(c)
	c.slab("Start", -10, 10, -11, -6, 0, 1.5)
	c.foot(-11, -6, -10, 10, 0)
	c.box("Speed:1.9:3.5", 5, 0.4, 4, 0, 0.2, -8.5, { col = { 60, 255, 120 }, mat = "Neon", collide = true, touch = true })
	for k = 0, 2 do
		c.box("Chevron", 3.5, 0.1, 0.6, 0, 0.5, -9.8 + k * 1.2, { col = { 255, 255, 255 }, mat = "Neon" })
	end
	c.slab("Target", -10, 10, 4.5, 11, 0, 1.5)
	c.foot(4.5, 11, -10, 10, 0)
	c.box("Banner", 20, 0.3, 0.3, 0, 7, 4.5, { col = c.glow, mat = "Neon" })
	c.box("BannerPost", 0.8, 7, 0.8, -10, 3.5, 4.5, { col = c.main })
	c.box("BannerPost", 0.8, 7, 0.8, 10, 3.5, 4.5, { col = c.main })
end

M.pillars = function(c)
	local d = c.d
	local size = 3.5 - 1.0 * d
	local tops = { 0, 1.5, 0, 1.5 }
	local sign = c.rng.next() < 0.5 and -1 or 1
	for i, u in { -8, -2.7, 2.7, 8 } do
		local x = sign * (i % 2 == 0 and 1 or -1) * (2 + 2 * d)
		local top = tops[i]
		c.box("Pillar", size, 6, size, x, top - 3, u, { collide = true, col = c.accent })
		c.trim(x - size / 2, x + size / 2, u - size / 2, u + size / 2, top, c.glow)
		c.foot(u - size / 2, u + size / 2, x - size / 2, x + size / 2, top)
	end
end

M.turntable = function(c)
	local d = c.d
	for i, u in { -5.5, 5.5 } do
		local dir = i == 1 and 1 or -1
		c.cyl(("Turntable:%.2f"):format(dir * (0.6 + 0.5 * d)), 1, 9.6, 0, -0.5, u, { col = c.accent, collide = true })
		c.cyl("Cap", 0.2, 9.0, 0, 0.1, u, { col = c.glow, mat = "Neon", tr = 0.3 })
		c.box(("SpinnerKill:%.2f"):format(-dir * (1.4 + 0.8 * d)), 9, 1, 1, 0, 1.5, u, { col = c.glow, mat = "Neon", touch = true })
		c.foot(u - 4.8, u + 4.8, -4.8, 4.8, 0, "moving")
	end
end

Modules.types = {
	-- name, rank (rough difficulty), generator
	{ "stepping", 1 }, { "vanish", 2 }, { "movers", 2 }, { "spinner", 3 }, { "lasers", 3 }, { "pillars", 3 },
	{ "belt", 4 }, { "pendulum", 4 }, { "speedgap", 5 }, { "bounce", 5 }, { "pistons", 6 }, { "turntable", 6 },
}
Modules.generators = M

-- choose the six obstacle modules of a floor: variety, with the allowed rank growing floor by floor
function Modules.pickForFloor(floor: number, rng): { string }
	local allowed = {}
	local maxRank = 1.6 + floor * 0.4
	for _, t in Modules.types do
		if t[2] <= maxRank then
			table.insert(allowed, t[1])
		end
	end
	local picks = {}
	-- every obstacle type must appear somewhere: the two hardest are guaranteed on the last floors
	local forced = ({ [11] = "pistons", [12] = "turntable" })[floor]
	local pool = table.clone(allowed)
	if forced then
		table.insert(picks, forced)
		local at = table.find(pool, forced)
		if at then
			table.remove(pool, at)
		end
	end
	for _ = #picks + 1, 6 do
		if #pool == 0 then
			pool = table.clone(allowed)
		end
		local i = rng.int(1, #pool)
		table.insert(picks, pool[i])
		table.remove(pool, i)
	end
	-- hardest first impression last: sort by rank so each floor ramps up
	local rank = {}
	for _, t in Modules.types do
		rank[t[1]] = t[2]
	end
	table.sort(picks, function(a, b)
		return rank[a] < rank[b]
	end)
	return picks
end

return Modules
