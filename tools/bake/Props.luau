-- Theme props: small decorative scenes placed beside the path. All are non-colliding and non-queryable.
-- Signature: prop(c, x, y, u, s) where (x,y,u) is the base point in module-local coordinates and s a size scale.
local Util = require(script.Parent.Util)

local Props = {}
local PI = math.pi

local function tilt(ax, ay, az) return CFrame.Angles(ax, ay, az) end

local WHITE = { 255, 255, 255 }

-- ===== candy =====
local candyCols = { { 255, 90, 160 }, { 255, 220, 90 }, { 90, 220, 255 }, { 170, 120, 255 }, { 120, 255, 170 } }
local function lollipop(c, x, y, u, s)
	local col = c.rng.pick(candyCols)
	c.cyl("Stick", 7 * s, 0.5 * s, x, y + 3.5 * s, u, { col = WHITE, mat = "SmoothPlastic" })
	c.cyl("Swirl", 0.8 * s, 4.4 * s, x, y + 7.6 * s, u, { col = col, mat = "Neon", rot = tilt(PI / 2, 0, 0) })
	c.cyl("Swirl", 0.9 * s, 3.0 * s, x, y + 7.6 * s, u, { col = WHITE, mat = "SmoothPlastic", rot = tilt(PI / 2, 0, 0) })
	c.cyl("Swirl", 1.0 * s, 1.6 * s, x, y + 7.6 * s, u, { col = col, mat = "Neon", rot = tilt(PI / 2, 0, 0) })
end
local function gumdrops(c, x, y, u, s)
	for i = 1, 4 do
		local col = c.rng.pick(candyCols)
		c.ball("Gumdrop", (2 + c.rng.next() * 2) * s, x + c.rng.range(-3, 3), y + 1, u + c.rng.range(-3, 3), { col = col, mat = "SmoothPlastic", ref = 0.15 })
	end
end
local function candyCane(c, x, y, u, s)
	c.box("Cane", 0.9 * s, 8 * s, 0.9 * s, x, y + 4 * s, u, { col = WHITE })
	for k = 0, 3 do
		c.box("Stripe", 1.0 * s, 0.9 * s, 1.0 * s, x, y + (1 + k * 2) * s, u, { col = { 255, 60, 90 }, mat = "SmoothPlastic" })
	end
	c.box("Hook", 3 * s, 0.9 * s, 0.9 * s, x + 1.4 * s, y + 8 * s, u, { col = WHITE })
	c.ball("Hook", 0.9 * s, x + 2.9 * s, y + 7.5 * s, u, { col = { 255, 60, 90 } })
end

-- ===== mossy ruins =====
local function brokenPillar(c, x, y, u, s)
	local h = (4 + c.rng.next() * 6) * s
	c.cyl("Pillar", h, 2.4 * s, x, y + h / 2, u, { col = Util.shade(c.main, 1.1), mat = "Cobblestone" })
	c.cyl("Cap", 0.8 * s, 3.2 * s, x, y + h, u, { col = Util.shade(c.main, 0.8), mat = "Cobblestone" })
	c.ball("Moss", 2.2 * s, x + 0.8 * s, y + h + 0.4 * s, u, { col = { 70, 160, 70 }, mat = "Grass" })
end
local function ruinArch(c, x, y, u, s)
	c.box("ArchPost", 1.6 * s, 8 * s, 1.6 * s, x - 3 * s, y + 4 * s, u, { col = c.main })
	c.box("ArchPost", 1.6 * s, 8 * s, 1.6 * s, x + 3 * s, y + 4 * s, u, { col = c.main })
	c.box("ArchBeam", 8 * s, 1.5 * s, 1.8 * s, x, y + 8.5 * s, u, { col = Util.shade(c.main, 0.9) })
	c.ball("Glow", 1.2 * s, x, y + 6 * s, u, { col = c.glow, mat = "Neon" })
end
local function mushroom(c, x, y, u, s)
	c.cyl("Stem", 3 * s, 1.1 * s, x, y + 1.5 * s, u, { col = { 240, 230, 210 } })
	c.cyl("Cap", 0.8 * s, 4.4 * s, x, y + 3.2 * s, u, { col = { 230, 70, 70 }, mat = "SmoothPlastic" })
	c.ball("Dot", 0.7 * s, x + 1.1 * s, y + 3.7 * s, u, { col = WHITE })
	c.ball("Dot", 0.7 * s, x - 0.9 * s, y + 3.7 * s, u + 0.8, { col = WHITE })
end

-- ===== lava =====
local function lavaRock(c, x, y, u, s)
	c.ball("Rock", 5 * s, x, y + 1.5 * s, u, { col = { 40, 28, 28 }, mat = "Basalt" })
	for k = 1, 3 do
		c.box("Crack", 0.3 * s, 4 * s, 0.3 * s, x + (k - 2) * 1.2 * s, y + 3 * s, u + 2 * s, { col = c.glow, mat = "Neon", rot = tilt(0.2 * k, k, 0.3) })
	end
end
local function lavaPool(c, x, y, u, s)
	c.cyl("Pool", 0.3, 9 * s, x, y + 0.15, u, { col = c.glow, mat = "Neon" })
	c.cyl("PoolRim", 0.6, 10.5 * s, x, y + 0.2, u, { col = { 40, 28, 28 }, mat = "Basalt" })
	c.ball("Bubble", 1.4 * s, x + 1.5 * s, y + 0.8, u, { col = { 255, 190, 60 }, mat = "Neon" })
end
local function obsidianSpikes(c, x, y, u, s)
	for k = 1, 5 do
		local h = (3 + c.rng.next() * 5) * s
		c.box("Spike", 1.4 * s, h, 1.4 * s, x + c.rng.range(-3, 3), y + h / 2, u + c.rng.range(-3, 3), { col = { 30, 22, 30 }, mat = "Glass", rot = tilt(c.rng.range(-0.3, 0.3), c.rng.range(0, 3), c.rng.range(-0.3, 0.3)), ref = 0.2 })
	end
	c.box("Glow", 5 * s, 0.2, 5 * s, x, y + 0.1, u, { col = c.glow, mat = "Neon", tr = 0.4 })
end

-- ===== ice =====
local function iceSpikes(c, x, y, u, s)
	for k = 1, 6 do
		local h = (3 + c.rng.next() * 7) * s
		c.box("IceSpike", 1.6 * s, h, 1.6 * s, x + c.rng.range(-3.5, 3.5), y + h / 2, u + c.rng.range(-3.5, 3.5), { col = { 190, 235, 255 }, mat = "Ice", tr = 0.15, rot = tilt(c.rng.range(-0.25, 0.25), c.rng.range(0, 3), c.rng.range(-0.25, 0.25)) })
	end
end
local function snowman(c, x, y, u, s)
	c.ball("Snow", 4 * s, x, y + 2 * s, u, { col = WHITE, mat = "Snow" })
	c.ball("Snow", 3 * s, x, y + 5 * s, u, { col = WHITE, mat = "Snow" })
	c.ball("Snow", 2.2 * s, x, y + 7.2 * s, u, { col = WHITE, mat = "Snow" })
	c.ball("Eye", 0.3 * s, x - 0.4 * s, y + 7.4 * s, u - 1.0 * s, { col = { 10, 10, 10 } })
	c.ball("Eye", 0.3 * s, x + 0.4 * s, y + 7.4 * s, u - 1.0 * s, { col = { 10, 10, 10 } })
	c.box("Nose", 0.3 * s, 0.3 * s, 1.2 * s, x, y + 7.1 * s, u - 1.3 * s, { col = { 255, 130, 30 } })
	c.cyl("Hat", 1.4 * s, 1.8 * s, x, y + 8.6 * s, u, { col = { 30, 30, 50 } })
end

-- ===== neon arcade =====
local function arcade(c, x, y, u, s)
	c.box("Cabinet", 3 * s, 6 * s, 2.4 * s, x, y + 3 * s, u, { col = { 30, 22, 60 } })
	c.box("Screen", 2.4 * s, 2.2 * s, 0.2, x, y + 4.4 * s, u - 1.25 * s, { col = c.glow, mat = "Neon" })
	c.box("Panel", 2.6 * s, 0.4 * s, 1.2 * s, x, y + 2.4 * s, u - 1.2 * s, { col = c.accent, mat = "Neon" })
	c.ball("Stick", 0.5 * s, x, y + 2.8 * s, u - 1.2 * s, { col = { 255, 255, 80 }, mat = "Neon" })
	c.box("Marquee", 3 * s, 0.8 * s, 0.3, x, y + 6.4 * s, u - 1.2 * s, { col = c.accent, mat = "Neon" })
end
local function neonCubes(c, x, y, u, s)
	for k = 1, 3 do
		local col = (k % 2 == 0) and c.glow or c.accent
		c.box("NeonCube", 2.4 * s, 2.4 * s, 2.4 * s, x + c.rng.range(-2, 2), y + 3 * k * s, u + c.rng.range(-2, 2), { col = col, mat = "Neon", tr = 0.2, rot = tilt(c.rng.range(0, 3), c.rng.range(0, 3), 0) })
	end
end
local function neonRing(c, x, y, u, s)
	c.cyl("Ring", 0.5, 9 * s, x, y + 7 * s, u, { col = c.glow, mat = "Neon", rot = tilt(0, c.rng.range(0, 3), PI / 2) })
	c.cyl("Ring", 0.5, 6 * s, x, y + 7 * s, u, { col = c.accent, mat = "Neon", rot = tilt(0, c.rng.range(0, 3), PI / 2) })
end

-- ===== toxic labs =====
local function barrels(c, x, y, u, s)
	for k = 1, 3 do
		local bx, bu = x + (k - 2) * 2.4 * s, u + c.rng.range(-1, 1)
		c.cyl("Barrel", 3 * s, 2 * s, bx, y + 1.5 * s, bu, { col = { 90, 110, 90 }, mat = "Metal" })
		c.cyl("BarrelBand", 0.5 * s, 2.1 * s, bx, y + 1.5 * s, bu, { col = c.glow, mat = "Neon" })
	end
end
local function vat(c, x, y, u, s)
	c.cyl("Vat", 6 * s, 5 * s, x, y + 3 * s, u, { col = { 70, 90, 80 }, mat = "Metal" })
	c.cyl("VatGlow", 0.4, 4.4 * s, x, y + 6.05 * s, u, { col = c.glow, mat = "Neon" })
	c.ball("Bubble", 1.2 * s, x + 0.8 * s, y + 6.9 * s, u, { col = c.glow, mat = "Neon", tr = 0.3 })
	c.box("Pipe", 0.8 * s, 0.8 * s, 8 * s, x, y + 7 * s, u + 4 * s, { col = { 90, 100, 90 }, mat = "Metal" })
end
local function hazardSign(c, x, y, u, s)
	c.box("Post", 0.4 * s, 5 * s, 0.4 * s, x, y + 2.5 * s, u, { col = { 80, 80, 80 } })
	c.box("Sign", 3 * s, 3 * s, 0.3, x, y + 5.5 * s, u, { col = { 255, 220, 40 }, rot = tilt(0, 0, PI / 4) })
	c.box("SignMark", 0.5 * s, 1.6 * s, 0.35, x, y + 5.6 * s, u - 0.05, { col = { 20, 20, 20 }, rot = tilt(0, 0, PI / 4) })
end

-- ===== clockwork =====
local function cog(c, x, y, u, s)
	local r = (3 + c.rng.next() * 2.5) * s
	local rot = tilt(PI / 2, c.rng.range(0, 3), 0)
	c.cyl("Cog", 1.2 * s, r * 2, x, y + r + 1, u, { col = c.main, mat = "DiamondPlate", rot = rot })
	c.cyl("CogHub", 1.6 * s, r * 0.6, x, y + r + 1, u, { col = c.accent, mat = "Metal", rot = rot })
	for k = 0, 9 do
		local a = k / 10 * PI * 2
		c.box("Tooth", 1.1 * s, 1.4 * s, 1.2 * s, x + math.cos(a) * (r + 0.4), y + r + 1 + math.sin(a) * (r + 0.4), u, { col = c.main, mat = "DiamondPlate", rot = tilt(0, 0, a) })
	end
end
local function clockTower(c, x, y, u, s)
	c.box("Tower", 3 * s, 11 * s, 3 * s, x, y + 5.5 * s, u, { col = c.main })
	c.cyl("Face", 0.4, 2.6 * s, x, y + 9 * s, u - 1.55 * s, { col = { 255, 245, 220 }, rot = tilt(PI / 2, 0, 0) })
	c.box("Hand", 0.2, 1.1 * s, 0.1, x, y + 9.3 * s, u - 1.8 * s, { col = { 30, 30, 30 } })
	c.box("Roof", 3.8 * s, 0.8 * s, 3.8 * s, x, y + 11.4 * s, u, { col = c.accent, mat = "Metal" })
	c.ball("Bell", 1 * s, x, y + 12.2 * s, u, { col = c.glow, mat = "Neon" })
end

-- ===== crystal caverns / generic crystals =====
local function crystals(c, x, y, u, s)
	for k = 1, 5 do
		local h = (4 + c.rng.next() * 8) * s
		local col = (k % 2 == 0) and c.glow or c.accent
		c.box("Crystal", 1.8 * s, h, 1.8 * s, x + c.rng.range(-3, 3), y + h / 2, u + c.rng.range(-3, 3), { col = col, mat = k % 2 == 0 and "Neon" or "Glass", tr = 0.1, rot = tilt(c.rng.range(-0.3, 0.3), c.rng.range(0, 3), c.rng.range(-0.3, 0.3)) })
	end
end
local function geode(c, x, y, u, s)
	c.ball("Geode", 6 * s, x, y + 2.5 * s, u, { col = Util.shade(c.main, 0.7), mat = "Slate" })
	c.ball("GeodeCore", 4.4 * s, x, y + 3.4 * s, u - 1.2 * s, { col = c.glow, mat = "Neon", tr = 0.1 })
end

-- ===== cloud garden =====
local function cloud(c, x, y, u, s)
	local n = c.rng.int(3, 5)
	for k = 1, n do
		c.ball("Cloud", (4 + c.rng.next() * 3) * s, x + (k - n / 2) * 2.6 * s, y + 6 + c.rng.range(-0.6, 0.8), u + c.rng.range(-1, 1), { col = WHITE, mat = "SmoothPlastic" })
	end
end
local function flower(c, x, y, u, s)
	c.cyl("Stem", 6 * s, 0.5 * s, x, y + 3 * s, u, { col = { 90, 200, 110 } })
	for k = 0, 5 do
		local a = k / 6 * PI * 2
		c.ball("Petal", 1.8 * s, x + math.cos(a) * 1.5 * s, y + 6.2 * s, u + math.sin(a) * 1.5 * s, { col = k % 2 == 0 and c.accent or { 255, 255, 255 } })
	end
	c.ball("Center", 1.5 * s, x, y + 6.3 * s, u, { col = c.glow, mat = "Neon" })
end
local function rainbow(c, x, y, u, s)
	local cols = { { 255, 80, 80 }, { 255, 170, 60 }, { 255, 240, 80 }, { 90, 220, 110 }, { 90, 170, 255 }, { 170, 110, 255 } }
	for i, col in cols do
		local r = (9 - i * 0.8) * s
		for k = 0, 8 do
			local a = k / 8 * PI
			c.ball("Rainbow", 1.4 * s, x + math.cos(a) * r, y + 2 + math.sin(a) * r, u, { col = col, mat = "Neon", tr = 0.1 })
		end
	end
end

-- ===== storm =====
local function lightningRod(c, x, y, u, s)
	c.cyl("Rod", 12 * s, 0.6 * s, x, y + 6 * s, u, { col = { 140, 150, 170 }, mat = "Metal" })
	c.ball("Spark", 1.6 * s, x, y + 12.4 * s, u, { col = c.glow, mat = "Neon" })
	for k = 0, 2 do
		c.box("Bolt", 0.3, 3 * s, 0.3, x + (k - 1) * 0.8, y + 14 * s + k, u, { col = c.glow, mat = "Neon", rot = tilt(0, 0, (k - 1) * 0.6) })
	end
end
local function stormCloud(c, x, y, u, s)
	for k = 1, 4 do
		c.ball("StormCloud", (5 + c.rng.next() * 3) * s, x + (k - 2.5) * 3 * s, y + 8 + c.rng.range(-0.8, 0.8), u + c.rng.range(-1, 1), { col = { 70, 78, 100 }, mat = "SmoothPlastic" })
	end
	c.box("Zap", 0.3, 5 * s, 0.3, x, y + 4, u, { col = c.glow, mat = "Neon", rot = tilt(0, 0, 0.3) })
end

-- ===== void / star =====
local function voidShards(c, x, y, u, s)
	for k = 1, 5 do
		c.box("Shard", 1.2 * s, (3 + c.rng.next() * 5) * s, 1.2 * s, x + c.rng.range(-4, 4), y + 2 + c.rng.range(0, 8), u + c.rng.range(-4, 4), { col = c.accent, mat = "Neon", tr = 0.25, rot = tilt(c.rng.range(0, 3), c.rng.range(0, 3), c.rng.range(0, 3)) })
	end
end
local function voidOrb(c, x, y, u, s)
	c.ball("Orb", 3 * s, x, y + 6 * s, u, { col = { 8, 4, 18 }, mat = "SmoothPlastic" })
	c.cyl("Halo", 0.3, 5.5 * s, x, y + 6 * s, u, { col = c.glow, mat = "Neon", rot = tilt(c.rng.range(0, 1.5), 0, PI / 2) })
end
local function star(c, x, y, u, s)
	c.box("Star", 3 * s, 3 * s, 0.6 * s, x, y + 8 * s, u, { col = c.main, mat = "Neon", rot = tilt(0, 0, PI / 4) })
	c.box("Star", 3 * s, 3 * s, 0.6 * s, x, y + 8 * s, u, { col = c.main, mat = "Neon" })
	c.ball("StarCore", 1.2 * s, x, y + 8 * s, u, { col = { 255, 255, 255 }, mat = "Neon" })
end

-- one prop family per floor (index = floor id)
Props.byFloor = {
	{ lollipop, gumdrops, candyCane }, -- 1 candy
	{ brokenPillar, ruinArch, mushroom }, -- 2 mossy ruins
	{ lavaRock, lavaPool, obsidianSpikes }, -- 3 lava forge
	{ iceSpikes, snowman, crystals }, -- 4 frost vault
	{ arcade, neonCubes, neonRing }, -- 5 neon arcade
	{ barrels, vat, hazardSign }, -- 6 toxic labs
	{ cog, clockTower, cog }, -- 7 clockwork
	{ crystals, geode, crystals }, -- 8 crystal caverns
	{ cloud, flower, rainbow }, -- 9 cloud garden
	{ lightningRod, stormCloud, lightningRod }, -- 10 storm spire
	{ voidShards, voidOrb, voidShards }, -- 11 void rift
	{ star, crystals, star }, -- 12 starcrown
}

return Props
