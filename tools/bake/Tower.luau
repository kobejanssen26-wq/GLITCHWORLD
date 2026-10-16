-- Assembles the tower: 85 path modules spiralling up around a decorated core, joined by round corner plates.
local Util = require(script.Parent.Util)
local Modules = require(script.Parent.Modules)
local Props = require(script.Parent.Props)
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Tower = {}
local T = Config.Tower
local PI = math.pi

local R, L = T.PATH_RADIUS, T.MODULE_LENGTH
Tower.DELTA = 2 * math.atan((L / 2) / R)
Tower.MODULES = T.FLOORS * T.MODULES_PER_FLOOR + 1 -- 85 (the last one is the summit plaza)

function Tower.surfaceY(i: number): number
	return T.BASE_Y + i * T.RISE_PER_MODULE
end

function Tower.frame(i: number)
	local th = i * Tower.DELTA
	local P = Vector3.new(R * math.cos(th), Tower.surfaceY(i), R * math.sin(th))
	local Tg = Vector3.new(-math.sin(th), 0, math.cos(th))
	return CFrame.lookAt(P, P + Tg)
end

local function theme(floor: number)
	local f = Config.Floors[floor]
	return { main = f.main, accent = f.accent, glow = f.glow, mat = f.material, floor = floor }
end

-- plaza (checkpoint / summit) module
local function plaza(c, floor: number, summit: boolean)
	c.slab("Plaza", -10, 10, -22, 22, 0, 2, { trimCol = c.accent })
	c.foot(-22, 22, -10, 10, 0)
	-- concentric glow rings + checkpoint pad
	c.cyl("PlazaRing", 0.1, 17, 0, 0.06, 0, { col = c.glow, mat = "Neon", tr = 0.35 })
	c.cyl("PlazaRing", 0.12, 13.5, 0, 0.08, 0, { col = c.main, mat = c.mat })
	local padName = summit and "Summit" or ("Checkpoint:" .. floor)
	c.box(padName, 11, 0.5, 11, 0, 0.25, 0, { col = c.glow, mat = "Neon", collide = true, touch = true })
	c.box("PadInlay", 9, 0.12, 9, 0, 0.56, 0, { col = c.accent, mat = "Neon", tr = 0.2 })
	-- arch over the exit
	for _, x in { -9.2, 9.2 } do
		c.box("ArchPillar", 1.6, 15, 1.6, x, 7.5, 12, { col = c.main, collide = true })
		c.box("ArchGlow", 0.4, 15, 0.4, x * 0.93, 7.5, 12 - 0.9, { col = c.glow, mat = "Neon" })
		c.ball("ArchOrb", 2, x, 15.5, 12, { col = c.accent, mat = "Neon" })
	end
	c.box("ArchBeam", 21, 1.6, 1.8, 0, 14.6, 12, { col = c.main })
	c.box("ArchStrip", 21, 0.35, 1.9, 0, 15.5, 12, { col = c.glow, mat = "Neon" })
	-- banner anchor + effects anchor (the server turns these markers into floor names / particles / lights)
	local label = summit and (T.FLOORS + 1) or floor -- 13 = the summit
	c.box("Marker:Banner:" .. label, 1, 1, 1, 0, 19, 12, { col = c.glow, mat = "Neon", tr = 1 })
	c.box("Marker:FX:" .. label, 1, 1, 1, 0, 6, 0, { col = c.glow, mat = "Neon", tr = 1 })
	-- benches + lamps
	for _, u in { -17, 17 } do
		c.box("Bench", 6, 1, 1.4, -7.5, 0.5, u, { col = c.main, collide = true })
		c.box("BenchBack", 6, 1.4, 0.3, -7.5, 1.3, u - (u < 0 and 0.8 or -0.8), { col = c.accent })
		c.box("LampPost", 0.5, 7, 0.5, 8.6, 3.5, u, { col = c.main })
		c.ball("LampBulb", 1.6, 8.6, 7.4, u, { col = c.glow, mat = "Neon" })
	end
	if summit then
		-- the crown of the tower: golden spikes around a glowing ring, and a beam into the sky
		c.cyl("CrownRing", 1.5, 16, 0, 22, 0, { col = c.main, mat = "Foil", ref = 0.3 })
		c.cyl("CrownGlow", 0.5, 17.5, 0, 22.9, 0, { col = c.glow, mat = "Neon" })
		for k = 0, 11 do
			local a = k / 12 * PI * 2
			local h = (k % 2 == 0) and 9 or 6
			c.box("CrownSpike", 1.8, h, 1.8, math.cos(a) * 7.6, 22 + h / 2 + 0.7, math.sin(a) * 7.6, { col = c.main, mat = "Foil", ref = 0.3, rot = CFrame.Angles(0, -a, 0) })
			c.ball("CrownJewel", 1.5, math.cos(a) * 7.6, 22 + h + 1.2, math.sin(a) * 7.6, { col = k % 3 == 0 and { 255, 80, 120 } or { 90, 220, 255 }, mat = "Neon" })
		end
		c.cyl("SummitBeam", 260, 3, 0, 150, 0, { col = c.glow, mat = "Neon", tr = 0.8 })
		for k = 1, 4 do
			c.box("SummitPlinth", 5, 5 - k, 5, 0, 1 + k * 0.8, 0, { col = c.accent, mat = "Foil" })
		end
	end
end

local function decorate(c, i: number, floor: number)
	local rng = c.rng
	-- struts to the core
	for _, u in { -10, 10 } do
		local p0 = c.F * Vector3.new(10, -3, -u)
		local horiz = math.sqrt(p0.X * p0.X + p0.Z * p0.Z)
		local dist = horiz - T.CORE_RADIUS + 1
		local dir = Vector3.new(-p0.X, 0, -p0.Z).Unit
		local mid = p0 + dir * (dist / 2)
		Util.part(c.parent, { n = "Strut", s = { 2.4, 2.4, dist }, cf = CFrame.lookAt(mid, mid + dir), col = Util.shade(c.main, 0.6), mat = c.mat })
		Util.part(c.parent, { n = "StrutGlow", s = { 0.5, 0.5, dist - 1 }, cf = CFrame.lookAt(mid + Vector3.new(0, 1.4, 0), mid + Vector3.new(0, 1.4, 0) + dir), col = c.glow, mat = "Neon" })
	end
	-- underside glow
	c.box("Underglow", 16, 0.3, 30, 0, -2.6, 0, { col = c.glow, mat = "Neon", tr = 0.3 })
	-- outer lamp posts
	for _, u in { -15, 15 } do
		c.box("LampPost", 0.5, 6, 0.5, -10.4, 3, u, { col = c.main })
		c.ball("LampBulb", 1.3, -10.4, 6.3, u, { col = c.glow, mat = "Neon" })
	end
	-- floating islets with themed props
	local fam = Props.byFloor[floor]
	for k = 1, 6 do
		local outer = k <= 3
		local x = outer and -rng.range(18, 34) or rng.range(18, 30)
		local u = rng.range(-18, 18)
		local y = rng.range(-6, 6)
		c.cyl("Islet", 2, 9 + rng.next() * 3, x, y - 1, u, { col = Util.shade(c.main, 0.75), mat = "Slate" })
		c.cyl("IsletTop", 0.4, 8.4, x, y + 0.2, u, { col = c.accent, mat = "Grass" })
		c.box("IsletRock", 3 + rng.next() * 2, 4, 3 + rng.next() * 2, x, y - 4, u, { col = Util.shade(c.main, 0.5), mat = "Slate", rot = CFrame.Angles(rng.range(-0.3, 0.3), rng.range(0, 3), rng.range(-0.3, 0.3)) })
		local prop = fam[rng.int(1, #fam)]
		prop(c, x, y + 0.4, u, 0.8 + rng.next() * 0.5)
	end
end

local function core(root)
	local f = Util.folder(root, "Core")
	local span = T.MODULES_PER_FLOOR * T.RISE_PER_MODULE
	for floor = 1, T.FLOORS do
		local th = theme(floor)
		local y0 = Tower.surfaceY((floor - 1) * T.MODULES_PER_FLOOR) - 3
		local mid = y0 + span / 2
		Util.part(f, { n = "CoreSection", s = { span, 2 * T.CORE_RADIUS, 2 * T.CORE_RADIUS }, cf = CFrame.new(0, mid, 0) * CFrame.Angles(0, 0, PI / 2), shape = "Cylinder", col = Util.shade(th.main, 0.45), mat = th.mat, collide = true })
		Util.part(f, { n = "CoreBand", s = { 1.2, 2 * T.CORE_RADIUS + 3, 2 * T.CORE_RADIUS + 3 }, cf = CFrame.new(0, y0 + 0.6, 0) * CFrame.Angles(0, 0, PI / 2), shape = "Cylinder", col = th.glow, mat = "Neon" })
		Util.part(f, { n = "CoreBand", s = { 0.8, 2 * T.CORE_RADIUS + 2, 2 * T.CORE_RADIUS + 2 }, cf = CFrame.new(0, y0 + span - 0.4, 0) * CFrame.Angles(0, 0, PI / 2), shape = "Cylinder", col = th.accent, mat = "Neon" })
		for k = 0, 15 do
			local a = k / 16 * PI * 2
			Util.part(f, { n = "CoreRib", s = { 2.6, span, 2.6 }, cf = CFrame.new(math.cos(a) * (T.CORE_RADIUS + 0.8), mid, math.sin(a) * (T.CORE_RADIUS + 0.8)) * CFrame.Angles(0, -a, 0), col = Util.shade(th.main, 0.8), mat = th.mat })
		end
		for k = 0, 11 do
			local a = (k + 0.5) / 12 * PI * 2
			local rad = T.CORE_RADIUS + 0.7
			Util.part(f, { n = "CoreWindow", s = { 8, 5, 0.6 }, cf = CFrame.lookAt(Vector3.new(math.cos(a) * rad, mid + 1, math.sin(a) * rad), Vector3.new(0, mid + 1, 0)) , col = (k % 2 == 0) and th.glow or th.accent, mat = "Neon", tr = 0.1 })
		end
	end
	-- the tower's spire above the summit
	local topY = Tower.surfaceY(Tower.MODULES - 1) + 14
	Util.part(f, { n = "CoreCap", s = { 6, 2 * T.CORE_RADIUS - 6, 2 * T.CORE_RADIUS - 6 }, cf = CFrame.new(0, topY, 0) * CFrame.Angles(0, 0, PI / 2), shape = "Cylinder", col = { 255, 216, 104 }, mat = "Foil", ref = 0.3 })
	for k = 1, 6 do
		Util.part(f, { n = "Spire", s = { 12 + (6 - k) * 6, 2 * (T.CORE_RADIUS - 10) * (7 - k) / 7, 2 * (T.CORE_RADIUS - 10) * (7 - k) / 7 }, cf = CFrame.new(0, topY + 5 + k * 7, 0) * CFrame.Angles(0, 0, PI / 2), shape = "Cylinder", col = { 255, 216, 104 }, mat = k % 2 == 0 and "Foil" or "Neon", ref = 0.2 })
	end
end

-- returns { modules = { {frame, foots, kind, floor, index}... } }
function Tower.build(root)
	local f = Util.folder(root, "Tower")
	local info = { modules = {}, plazas = {} }
	for i = 0, Tower.MODULES - 1 do
		local floor = math.min(math.floor(i / T.MODULES_PER_FLOOR) + 1, T.FLOORS)
		local within = i % T.MODULES_PER_FLOOR
		local isSummit = i == Tower.MODULES - 1
		local kind
		local rng = Util.rng(floor * 7919 + 13)
		if within == 0 then
			kind = isSummit and "summit" or "plaza"
		else
			local picks = Modules.pickForFloor(floor, rng)
			kind = picks[within]
		end
		local mf = Util.folder(f, ("M%02d_%s"):format(i, kind))
		local F = Tower.frame(i)
		local d = math.clamp((floor - 1) / 11 * 0.8 + (within / 6) * 0.2, 0, 1)
		local c = Modules.context(mf, F, theme(floor), d, Util.rng(i * 104729 + 7), i)
		if kind == "plaza" or kind == "summit" then
			plaza(c, floor, isSummit)
			info.plazas[floor] = F
			if isSummit then
				info.plazas[T.FLOORS + 1] = F
			end
		else
			-- connectors at both ends, then the obstacle
			c.slab("Connector", -10, 10, -22, -11, 0, 2)
			c.slab("Connector", -10, 10, 11, 22, 0, 2)
			c.foot(-22, -11, -10, 10, 0)
			c.foot(11, 22, -10, 10, 0)
			Modules.generators[kind](c)
			-- three collectible coins above the route
			for k, u in { -7, 0, 7 } do
				c.ball("Coin", 1.7, (k - 2) * 0.8, 2.6 + (k == 2 and 0.6 or 0), u, { col = { 255, 215, 60 }, mat = "Neon", touch = true })
			end
		end
		decorate(c, i, floor)
		-- corner plate to the next module
		if i < Tower.MODULES - 1 then
			local J = F * CFrame.new(0, 0, -L / 2)
			Util.part(mf, { n = "Joint", s = { 2, 2 * T.JOINT_RADIUS, 2 * T.JOINT_RADIUS }, cf = CFrame.new(J.X, Tower.surfaceY(i) + T.RISE_PER_MODULE / 2 - 1, J.Z) * CFrame.Angles(0, 0, PI / 2), shape = "Cylinder", col = Util.shade(c.main, 0.9), mat = c.mat, collide = true })
			Util.part(mf, { n = "JointTrim", s = { 0.2, 2 * T.JOINT_RADIUS - 0.8, 2 * T.JOINT_RADIUS - 0.8 }, cf = CFrame.new(J.X, Tower.surfaceY(i) + T.RISE_PER_MODULE / 2 + 0.1, J.Z) * CFrame.Angles(0, 0, PI / 2), shape = "Cylinder", col = c.glow, mat = "Neon", tr = 0.2 })
		end
		table.insert(info.modules, { index = i, floor = floor, kind = kind, frame = F, foots = c.foots })
	end
	core(f)
	return info
end

return Tower
