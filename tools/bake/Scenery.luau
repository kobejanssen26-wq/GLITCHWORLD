-- Hub island, ramp to the tower, ring road, the eight tycoon plots, floating islands, clouds and sky rings.
local Util = require(script.Parent.Util)
local Tower = require(script.Parent.Tower)
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Scenery = {}
local PI = math.pi
local TAU = PI * 2

local function box(parent, name, sx, sy, sz, cf, col, mat, o)
	o = o or {}
	return Util.part(parent, { n = name, s = { sx, sy, sz }, cf = cf, col = col, mat = mat, tr = o.tr, ref = o.ref, collide = o.collide, touch = o.touch })
end
local function cyl(parent, name, h, d, cf, col, mat, o)
	o = o or {}
	return Util.part(parent, { n = name, s = { h, d, d }, cf = cf * CFrame.Angles(0, 0, PI / 2), shape = "Cylinder", col = col, mat = mat, tr = o.tr, ref = o.ref, collide = o.collide })
end
local function ball(parent, name, d, cf, col, mat, o)
	o = o or {}
	return Util.part(parent, { n = name, s = { d, d, d }, cf = cf, shape = "Ball", col = col, mat = mat, tr = o.tr, ref = o.ref, collide = o.collide })
end

local PLOT_HUES = { { 255, 90, 160 }, { 255, 160, 60 }, { 255, 230, 80 }, { 110, 240, 130 }, { 70, 230, 255 }, { 100, 140, 255 }, { 180, 110, 255 }, { 255, 110, 220 } }
Scenery.PLOT_HUES = PLOT_HUES

local function tree(parent, x, y, z, rng, s)
	local cf = CFrame.new(x, y, z)
	cyl(parent, "Trunk", 6 * s, 1.2 * s, cf * CFrame.new(0, 3 * s, 0), { 110, 78, 50 }, "Wood", { collide = true })
	local g = { 70 + rng.next() * 40, 170 + rng.next() * 50, 90 + rng.next() * 40 }
	ball(parent, "Leaves", 6 * s, cf * CFrame.new(0, 7.5 * s, 0), g, "Grass")
	ball(parent, "Leaves", 4.2 * s, cf * CFrame.new(2 * s, 6.5 * s, 1 * s), Util.shade(g, 0.9), "Grass")
	ball(parent, "Leaves", 4 * s, cf * CFrame.new(-1.8 * s, 6.2 * s, -1.2 * s), Util.shade(g, 1.1), "Grass")
end

-- ===== the hub island =====
function Scenery.hub(root)
	local h = Util.folder(root, "Hub")
	local rng = Util.rng(4242)
	-- island top + rocky underside
	cyl(h, "IslandTop", 2, 900, CFrame.new(0, -1, 0), { 70, 190, 150 }, "Grass", { collide = true })
	cyl(h, "IslandEdge", 1, 906, CFrame.new(0, -0.6, 0), { 255, 100, 200 }, "Neon")
	for k = 1, 12 do
		local d = 880 - k * 62
		cyl(h, "IslandRock", 26, d, CFrame.new(0, -2 - 13 - (k - 1) * 24, 0), Util.shade({ 70, 62, 96 }, 1 - k * 0.04), "Slate", { collide = k < 3 })
	end
	for k = 1, 90 do
		local a = rng.next() * TAU
		local r = rng.range(60, 400)
		local len = rng.range(30, 110)
		box(h, "Stalactite", rng.range(8, 20), len, rng.range(8, 20), CFrame.new(math.cos(a) * r, -26 - len / 2, math.sin(a) * r) * CFrame.Angles(rng.range(-0.15, 0.15), rng.range(0, 3), rng.range(-0.15, 0.15)), Util.shade({ 70, 62, 96 }, rng.range(0.6, 1)), "Slate")
	end
	for k = 1, 40 do
		local a = rng.next() * TAU
		local r = rng.range(60, 430)
		ball(h, "UnderGlow", rng.range(3, 7), CFrame.new(math.cos(a) * r, -rng.range(20, 160), math.sin(a) * r), PLOT_HUES[(k % 8) + 1], "Neon", { tr = 0.1 })
	end
	-- central plaza: concentric rings and radial neon lines
	local ringCols = { { 255, 100, 200 }, { 30, 22, 60 }, { 70, 240, 255 }, { 30, 22, 60 }, { 255, 215, 90 }, { 30, 22, 60 } }
	for k, col in ringCols do
		cyl(h, "PlazaRing", 0.3, 300 - (k - 1) * 40, CFrame.new(0, 0.15 + k * 0.02, 0), col, col[1] == 30 and "SmoothPlastic" or "Neon", { collide = col[1] == 30 })
	end
	for k = 0, 35 do
		local a = k / 36 * TAU
		box(h, "PlazaLine", 1, 0.12, 120, CFrame.new(math.cos(a) * 130, 0.5, math.sin(a) * 130) * CFrame.Angles(0, -a + PI / 2, 0), { 70, 240, 255 }, "Neon", { tr = 0.35 })
	end
	-- ramp from the ground up to the first checkpoint plaza
	local F0 = Tower.frame(0)
	local alpha = math.atan2(Config.Tower.BASE_Y, 24)
	local len = math.sqrt(24 * 24 + Config.Tower.BASE_Y ^ 2)
	local ramp = F0 * CFrame.new(0, Config.Tower.BASE_Y / 2 - 1, 34) * CFrame.Angles(alpha, 0, 0)
	box(h, "Ramp", 20, 2, len, ramp, { 255, 120, 200 }, "SmoothPlastic", { collide = true })
	for _, x in { -9.8, 9.8 } do
		box(h, "RampRail", 0.4, 0.4, len, ramp * CFrame.new(x, 1.4, 0), { 70, 240, 255 }, "Neon")
	end
	-- ring road
	local roadR = 215
	for k = 0, 71 do
		local a = (k + 0.5) / 72 * TAU
		box(h, "Road", 16, 0.5, 2 * roadR * math.tan(PI / 72) + 0.6, CFrame.new(math.cos(a) * roadR, 0.25, math.sin(a) * roadR) * CFrame.Angles(0, -a + PI / 2 + PI / 2, 0), { 38, 30, 70 }, "SmoothPlastic", { collide = true })
		if k % 2 == 0 then
			box(h, "RoadDash", 0.5, 0.1, 5, CFrame.new(math.cos(a) * roadR, 0.55, math.sin(a) * roadR) * CFrame.Angles(0, -a + PI, 0), { 255, 215, 90 }, "Neon")
		end
		if k % 3 == 0 then
			local lx, lz = math.cos(a) * (roadR + 11), math.sin(a) * (roadR + 11)
			box(h, "LampPost", 0.6, 9, 0.6, CFrame.new(lx, 4.5, lz), { 60, 52, 90 }, "Metal")
			ball(h, "LampBulb", 2, CFrame.new(lx, 9.4, lz), PLOT_HUES[(k % 8) + 1], "Neon")
		end
	end
	-- roads to every plot, with fountains and trees along the way
	for i = 0, Config.Plots.COUNT - 1 do
		local a = i / Config.Plots.COUNT * TAU + TAU / 16
		local r0, r1 = roadR, Config.Plots.RING_RADIUS - 62
		local mid = (r0 + r1) / 2
		box(h, "PlotRoad", 14, 0.5, r1 - r0, CFrame.new(math.cos(a) * mid, 0.26, math.sin(a) * mid) * CFrame.Angles(0, -a + PI / 2 + PI / 2, 0) * CFrame.Angles(0, PI / 2, 0), { 44, 36, 80 }, "SmoothPlastic", { collide = true })
		for s = -1, 1, 2 do
			local ox, oz = -math.sin(a) * 9 * s, math.cos(a) * 9 * s
			for k = 0, 5 do
				local rr = r0 + 10 + k * ((r1 - r0 - 20) / 5)
				box(h, "RoadEdge", 0.5, 0.2, 7, CFrame.new(math.cos(a) * rr + ox, 0.55, math.sin(a) * rr + oz) * CFrame.Angles(0, PI / 2 - a, 0), PLOT_HUES[i + 1], "Neon")
			end
		end
		local fx, fz = math.cos(a + 0.12) * (r0 + 40), math.sin(a + 0.12) * (r0 + 40)
		cyl(h, "FountainBase", 1.5, 14, CFrame.new(fx, 0.75, fz), { 60, 52, 90 }, "Slate", { collide = true })
		cyl(h, "FountainWater", 0.3, 12.5, CFrame.new(fx, 1.5, fz), { 80, 200, 255 }, "Neon", { tr = 0.3 })
		cyl(h, "FountainPillar", 6, 1.6, CFrame.new(fx, 4, fz), PLOT_HUES[i + 1], "Neon")
		ball(h, "FountainOrb", 3, CFrame.new(fx, 7.5, fz), { 255, 255, 255 }, "Neon")
	end
	for k = 1, 70 do
		local a = rng.next() * TAU
		local r = rng.range(170, 420)
		if math.abs(((a * Config.Plots.COUNT / TAU) % 1) - 0.5) > 0.2 then
			tree(h, math.cos(a) * r, 0, math.sin(a) * r, rng, rng.range(0.9, 1.6))
		end
	end
	-- spawn arch (marker; the server adds the SpawnLocation and the title sign)
	local sx, sz = 0, -150
	for _, x in { -14, 14 } do
		box(h, "SpawnPillar", 3, 22, 3, CFrame.new(sx + x, 11, sz), { 60, 52, 90 }, "Metal", { collide = true })
		box(h, "SpawnGlow", 0.8, 22, 0.8, CFrame.new(sx + x * 0.86, 11, sz - 1.7), { 255, 100, 200 }, "Neon")
	end
	box(h, "SpawnBeam", 32, 3, 3, CFrame.new(sx, 23, sz), { 60, 52, 90 }, "Metal")
	box(h, "SpawnStrip", 32, 0.7, 3.2, CFrame.new(sx, 24.8, sz), { 70, 240, 255 }, "Neon")
	box(h, "Marker:HubSpawn", 1, 1, 1, CFrame.new(sx, 0.5, sz + 14), { 255, 255, 255 }, "Neon", { tr = 1 })
	box(h, "Marker:Title", 1, 1, 1, CFrame.new(sx, 31, sz), { 255, 255, 255 }, "Neon", { tr = 1 })
	cyl(h, "SpawnPad", 0.5, 26, CFrame.new(sx, 0.4, sz + 14), { 30, 22, 60 }, "SmoothPlastic", { collide = true })
	cyl(h, "SpawnPadGlow", 0.2, 24, CFrame.new(sx, 0.7, sz + 14), { 70, 240, 255 }, "Neon", { tr = 0.3 })
end

-- ===== plots =====
function Scenery.plots(root)
	local pf = Util.folder(root, "Plots")
	local N = Config.Plots.COUNT
	local S = Config.Plots.SIZE
	for i = 0, N - 1 do
		local plot = Util.folder(pf, "Plot" .. (i + 1))
		local rng = Util.rng(900 + i)
		local a = i / N * TAU + TAU / 16
		local center = Vector3.new(math.cos(a) * Config.Plots.RING_RADIUS, 0, math.sin(a) * Config.Plots.RING_RADIUS)
		local F = CFrame.lookAt(center, Vector3.new(0, 0, 0))
		local hue = PLOT_HUES[i + 1]
		local dark = Util.shade(hue, 0.18)
		local function L(x, y, z) return F * CFrame.new(x, y, z) end
		box(plot, "PlotBase", S, 1, S, L(0, 0, 0), { 34, 28, 62 }, "SmoothPlastic", { collide = true })
		for gx = -4, 4 do
			for gz = -4, 4 do
				if (gx + gz) % 2 == 0 then
					box(plot, "Tile", 12, 0.15, 12, L(gx * 12, 0.55, gz * 12), Util.shade(hue, 0.3), "SmoothPlastic")
				else
					box(plot, "Tile", 12, 0.15, 12, L(gx * 12, 0.55, gz * 12), { 46, 38, 80 }, "SmoothPlastic")
				end
			end
		end
		-- neon border
		box(plot, "Border", S, 0.4, 0.8, L(0, 0.7, S / 2 - 0.4), hue, "Neon")
		box(plot, "Border", S, 0.4, 0.8, L(0, 0.7, -S / 2 + 0.4), hue, "Neon")
		box(plot, "Border", 0.8, 0.4, S, L(S / 2 - 0.4, 0.7, 0), hue, "Neon")
		box(plot, "Border", 0.8, 0.4, S, L(-S / 2 + 0.4, 0.7, 0), hue, "Neon")
		-- fences on three sides (the entrance faces the tower)
		for k = -9, 9 do
			local p = k * 5.6
			for _, side in { { p, S / 2 - 1 }, { S / 2 - 1, p }, { -S / 2 + 1, p } } do
				box(plot, "FencePost", 0.8, 5, 0.8, L(side[1], 3, side[2]), { 60, 52, 90 }, "Metal", { collide = true })
				ball(plot, "FenceCap", 1.1, L(side[1], 5.8, side[2]), hue, "Neon")
			end
		end
		box(plot, "FenceRail", S, 0.5, 0.5, L(0, 4.2, S / 2 - 1), dark, "Metal", { collide = true })
		box(plot, "FenceRail", 0.5, 0.5, S, L(S / 2 - 1, 4.2, 0), dark, "Metal", { collide = true })
		box(plot, "FenceRail", 0.5, 0.5, S, L(-S / 2 + 1, 4.2, 0), dark, "Metal", { collide = true })
		-- entrance gate
		for _, x in { -12, 12 } do
			box(plot, "GatePillar", 3, 18, 3, L(x, 9, -S / 2 + 1), { 60, 52, 90 }, "Metal", { collide = true })
			box(plot, "GateGlow", 0.7, 18, 0.7, L(x * 0.88, 9, -S / 2 - 0.6), hue, "Neon")
			ball(plot, "GateOrb", 3, L(x, 19.5, -S / 2 + 1), hue, "Neon")
		end
		box(plot, "GateBeam", 27, 2.4, 3, L(0, 17.5, -S / 2 + 1), { 60, 52, 90 }, "Metal")
		box(plot, "GateStrip", 27, 0.5, 3.2, L(0, 19, -S / 2 + 1), hue, "Neon")
		-- trees, planters, benches, lamps
		for k = 1, 8 do
			local tx = (k % 2 == 0 and 1 or -1) * rng.range(36, 50)
			local tz = rng.range(-40, 40)
			local tf = L(tx, 0.5, tz)
			cyl(plot, "Trunk", 6, 1.2, tf * CFrame.new(0, 3, 0), { 110, 78, 50 }, "Wood", { collide = true })
			ball(plot, "Leaves", 6, tf * CFrame.new(0, 7.5, 0), { 80 + rng.next() * 40, 180 + rng.next() * 40, 100 }, "Grass")
			ball(plot, "Leaves", 4, tf * CFrame.new(2, 6.4, 1), { 90, 200, 110 }, "Grass")
		end
		for _, c in { { -50, 50 }, { 50, 50 }, { -50, -50 }, { 50, -50 } } do
			box(plot, "LampPost", 0.7, 12, 0.7, L(c[1], 6.5, c[2]), { 60, 52, 90 }, "Metal")
			ball(plot, "LampBulb", 2.4, L(c[1], 12.8, c[2]), hue, "Neon")
		end
		for _, x in { -30, 30 } do
			box(plot, "Bench", 8, 1.2, 2, L(x, 1.2, 36), { 60, 52, 90 }, "Metal", { collide = true })
			box(plot, "BenchBack", 8, 2, 0.4, L(x, 2.4, 37), hue, "SmoothPlastic")
		end
		-- markers for the server
		box(plot, "Marker:PlotOrigin:" .. (i + 1), 1, 1, 1, L(0, 0.5, 0), hue, "Neon", { tr = 1 })
		box(plot, "Marker:PlotSign:" .. (i + 1), 1, 1, 1, L(0, 23, -S / 2 + 1), hue, "Neon", { tr = 1 })
		box(plot, "Marker:PlotSpawn:" .. (i + 1), 1, 1, 1, L(0, 1.5, -40), hue, "Neon", { tr = 1 })
	end
end

-- ===== sky: floating islands, clouds and rings =====
function Scenery.sky(root)
	local f = Util.folder(root, "Sky")
	local rng = Util.rng(777)
	for k = 1, 60 do
		local a = rng.next() * TAU
		local r = rng.range(520, 1150)
		local y = rng.range(-60, 420)
		local rad = rng.range(14, 42)
		local base = CFrame.new(math.cos(a) * r, y, math.sin(a) * r)
		local col = PLOT_HUES[(k % 8) + 1]
		cyl(f, "SkyIsland", 3, rad * 2, base, Util.mix({ 90, 200, 140 }, col, 0.25), "Grass")
		for s = 1, 4 do
			cyl(f, "SkyRock", rad * 0.7, rad * 2 * (1 - s * 0.2), base * CFrame.new(0, -3 - s * rad * 0.4, 0) * CFrame.Angles(0, 0, 0), { 80, 70, 110 }, "Slate")
		end
		ball(f, "SkyGlow", rad * 0.25, base * CFrame.new(0, -rad * 1.5, 0), col, "Neon", { tr = 0.1 })
		if k % 3 == 0 then
			tree(f, base.X, y + 1.5, base.Z, rng, rad / 14)
		elseif k % 3 == 1 then
			for c = 1, 4 do
				box(f, "SkyCrystal", 2.4, rng.range(6, 14), 2.4, base * CFrame.new(rng.range(-rad * 0.5, rad * 0.5), 6, rng.range(-rad * 0.5, rad * 0.5)) * CFrame.Angles(rng.range(-0.3, 0.3), rng.range(0, 3), rng.range(-0.3, 0.3)), col, "Neon", { tr = 0.15 })
			end
		else
			box(f, "SkyHouse", 10, 7, 10, base * CFrame.new(0, 5, 0), { 240, 235, 250 }, "SmoothPlastic")
			box(f, "SkyRoof", 12, 1.5, 12, base * CFrame.new(0, 9, 0), col, "SmoothPlastic")
			ball(f, "SkyLamp", 2, base * CFrame.new(0, 11, 0), col, "Neon")
		end
	end
	for k = 1, 130 do
		local a = rng.next() * TAU
		local r = rng.range(260, 1500)
		local y = rng.range(120, 560)
		local n = rng.int(4, 7)
		for c = 1, n do
			ball(f, "Cloud", rng.range(18, 36), CFrame.new(math.cos(a) * r + c * 14 - n * 7, y + rng.range(-3, 4), math.sin(a) * r + rng.range(-6, 6)), { 255, 255, 255 }, "SmoothPlastic", { tr = rng.range(0, 0.2) })
		end
	end
	for k = 1, 6 do
		local y = 40 + k * 55
		local rad = 170 + k * 6
		local col = (k % 2 == 0) and { 70, 240, 255 } or { 255, 70, 200 }
		for s = 0, 71 do
			local a = s / 72 * TAU
			box(f, "SkyRing", 4, 2.2, 2 * rad * math.tan(PI / 72) + 0.5, CFrame.new(math.cos(a) * rad, y + math.sin(a * 3 + k) * 6, math.sin(a) * rad) * CFrame.Angles(0, -a + PI, 0), col, "Neon", { tr = 0.15 })
		end
	end
end

return Scenery
