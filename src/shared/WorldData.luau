-- Deterministic layout of The Green Valley: terrain height function, stations, every target, secrets, decor.
-- Pure data + math (no Roblox instances) so both server (builds the world) and client (beacons) agree, and it can
-- be unit-tested. Target ids are save keys: "<zone>_<index>" - zone generators consume their own PRNG stream, so
-- editing one zone never renumbers another.
local WorldData = {}

WorldData.HALF = 150 -- the valley spans [-150, 150] on x and z
WorldData.WALL = 146 -- invisible boundary wall distance
WorldData.SPAWN = { x = 0, z = 118 }
WorldData.WATER_LEVEL = -1.2

local function smoothstep(a: number, b: number, x: number): number
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

local function dist(ax: number, az: number, bx: number, bz: number): number
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

-- ===== terrain =====
local FLATS = { -- { x, z, radius, height }
	{ 0, 118, 22, 2.0 }, -- spawn glade
	{ 0, 55, 30, 3.0 }, -- restoration plaza
	{ 0, -62, 42, 4.0 }, -- ruins platform
	{ 0, -128, 20, 5.0 }, -- gateway approach
	{ -24, -62, 9, 4.0 },
}
local HILLS = { -- { x, z, radius, height }
	{ -95, -85, 30, 17 }, -- north-west lookout hill
	{ 88, 10, 26, 7 }, -- crystal hollow rise
	{ -45, 85, 12, 3.5 }, -- little knoll (hides a shard)
	{ 45, -52, 14, 5 },
	{ 105, -70, 22, 9 },
}
WorldData.POND = { x = -88, z = 40, r = 16 }
WorldData.PIT = { x = 30, z = -78, r = 11, depth = 7 }

function WorldData.heightAt(x: number, z: number): number
	local h = 2.2 * math.sin(x * 0.031) * math.cos(z * 0.037) + 1.4 * math.sin((x + z) * 0.052) + 0.8 * math.cos(x * 0.09) * math.sin(z * 0.08) + 2.5
	for _, hill in HILLS do
		local d = dist(x, z, hill[1], hill[2])
		if d < hill[3] then
			local t = 1 - d / hill[3]
			h += hill[4] * t * t * (3 - 2 * t)
		end
	end
	for _, f in FLATS do
		local d = dist(x, z, f[1], f[2])
		local w = 1 - smoothstep(f[3], f[3] * 1.7, d)
		h = h * (1 - w) + f[4] * w
	end
	-- pond bowl
	local P = WorldData.POND
	local dp = dist(x, z, P.x, P.z)
	local bowl = 1 - smoothstep(P.r * 0.55, P.r * 1.25, dp)
	h = h * (1 - bowl) + (-5) * bowl
	-- sunken vault pit
	local V = WorldData.PIT
	local dv = dist(x, z, V.x, V.z)
	local pit = 1 - smoothstep(V.r * 0.6, V.r * 1.8, dv)
	h = h * (1 - pit) + (h - V.depth - 4) * pit
	-- cliff ring that forms the readable boundary; the gateway corridor stays open
	local e = math.max(math.abs(x), math.abs(z))
	local ring = smoothstep(126, 150, e) * 40
	if z < -110 then
		local corridor = 1 - smoothstep(12, 20, math.abs(x))
		ring *= (1 - corridor * smoothstep(-110, -126, z))
		-- the corridor ends in rock beyond the teaser vista
		ring += corridor * smoothstep(-150, -162, z) * 40
	end
	return h + ring
end

-- ===== deterministic prng (no dependency on Random) =====
local function rng(seed: number)
	local s = seed % 2147483647
	if s <= 0 then
		s += 2147483646
	end
	return function(): number
		s = (s * 48271) % 2147483647
		return s / 2147483647
	end
end

-- ===== stations =====
WorldData.Stations = {
	sell = { id = "sell", name = "Restoration Station", x = -13, z = 55, prompt = "Convert Fragments" },
	upgrade = { id = "upgrade", name = "Upgrade Station", x = 13, z = 55, prompt = "Open Upgrades" },
	research = { id = "research", name = "Research Terminal", x = -8, z = 42, prompt = "Open Research" },
	echo = { id = "echo", name = "Echo Index Shrine", x = 8, z = 42, prompt = "Open Echo Index" },
}
WorldData.GATEWAY = { x = 0, z = -132 }

-- ===== targets =====
type Placement = { id: string, type: string, x: number, z: number, ry: number, echo: string?, zone: string }
local targets: { Placement } = {}
local placed: { { number } } = {} -- {x, z, clearance} used for rejection sampling

local function free(x: number, z: number, clearance: number): boolean
	if math.max(math.abs(x), math.abs(z)) > 122 then
		return false
	end
	if dist(x, z, WorldData.POND.x, WorldData.POND.z) < WorldData.POND.r + 6 then
		return false
	end
	if dist(x, z, WorldData.PIT.x, WorldData.PIT.z) < WorldData.PIT.r + 4 then
		return false
	end
	if dist(x, z, 0, 55) < 20 then
		return false -- keep the plaza clear
	end
	if math.abs(x) < 3 and z > 62 and z < 124 then
		return false -- tutorial path
	end
	for _, p in placed do
		if dist(x, z, p[1], p[2]) < clearance + p[3] then
			return false
		end
	end
	return true
end

local function add(id: string, typ: string, x: number, z: number, ry: number?, echo: string?, zone: string?)
	table.insert(targets, { id = id, type = typ, x = x, z = z, ry = ry or 0, echo = echo, zone = zone or "" })
	local clearance = ({ ruin = 6, tree = 3.5, crystal = 3, capsule = 3, anomaly = 3 })[typ] or 2
	table.insert(placed, { x, z, clearance })
end

-- zone: scatter `counts` of types inside a circle
local function scatter(zone: string, cx: number, cz: number, r: number, seed: number, counts: { { string | number } })
	local rand = rng(seed)
	for _, entry in counts do
		local typ, n = entry[1] :: string, entry[2] :: number
		local made, tries = 0, 0
		while made < n and tries < 400 do
			tries += 1
			local a = rand() * math.pi * 2
			local d = math.sqrt(rand()) * r
			local x, z = math.floor(cx + math.cos(a) * d), math.floor(cz + math.sin(a) * d)
			if free(x, z, 5) then
				made += 1
				add(("%s_%s_%d"):format(zone, typ, made), typ, x, z, rand() * 360, nil, zone)
			end
		end
	end
end

-- First targets are placed by hand right beside the spawn so the first fragment arrives within seconds.
add("start_grass_1", "grass", -7, 106, 20, nil, "start")
add("start_grass_2", "grass", 7, 103, 60, nil, "start")
add("start_grass_3", "grass", -10, 96, 110, nil, "start")
add("start_bloom_1", "bloom", 10, 92, 0, nil, "start")
add("start_grass_4", "grass", 8, 84, 200, nil, "start")
add("start_bush_1", "bush", -9, 82, 0, nil, "start")
add("start_bloom_2", "bloom", -14, 108, 0, nil, "start")
add("start_capsule_pebblit", "capsule", 36, 110, 30, "pebblit", "start")

-- Ruins: six broken structures on the platform (hand-placed, spaced so nothing intersects)
add("ruin_1", "ruin", -22, -40, 0, nil, "ruins")
add("ruin_2", "ruin", 22, -42, 90, nil, "ruins")
add("ruin_3", "ruin", -34, -78, 180, nil, "ruins")
add("ruin_4", "ruin", 8, -88, 45, nil, "ruins")
add("ruin_5", "ruin", -4, -62, 0, nil, "ruins")
add("ruin_6", "ruin", 44, -66, 270, nil, "ruins")

-- Trapped Echoes (the Glitch Capsule is the "creature trapped in a corrupted object" mechanic)
add("capsule_voltling", "capsule", -112, 30, 0, "voltling", "meadow")
add("capsule_prismoo", "capsule", 98, 6, 90, "prismoo", "hollow")
add("capsule_frostwhisp", "capsule", -95, -85, 0, "frostwhisp", "lookout")
add("capsule_sparkfin", "capsule", 30, -78, 0, "sparkfin", "vault")
add("capsule_gearlo", "capsule", -24, -62, 0, "gearlo", "ruins")

-- Glitch Obelisks: unusual targets for explorers, big fragment payout
add("anomaly_1", "anomaly", -52, -118, 30, nil, "secret")
add("anomaly_2", "anomaly", 116, -92, 0, nil, "secret")
add("anomaly_3", "anomaly", -118, 96, 0, nil, "secret")

-- Zone scatter runs last so it avoids every hand-placed object
scatter("spawn", 0, 112, 30, 101, { { "grass", 3 }, { "bush", 3 }, { "tree", 2 } })
scatter("plaza", 0, 55, 42, 202, { { "grass", 3 }, { "bush", 2 }, { "bloom", 1 }, { "tree", 2 } })
scatter("meadow", -85, 40, 42, 303, { { "grass", 5 }, { "bush", 2 }, { "tree", 2 }, { "bloom", 1 } })
scatter("forestse", 85, 92, 38, 404, { { "tree", 6 }, { "bush", 2 }, { "grass", 3 }, { "bloom", 1 } })
scatter("forestsw", -70, 100, 34, 505, { { "tree", 4 }, { "bush", 2 }, { "grass", 1 } })
scatter("hollow", 88, 12, 22, 606, { { "crystal", 5 }, { "prism_vein", 3 } })
scatter("mideast", 60, -30, 26, 707, { { "crystal", 3 }, { "surge_node", 1 }, { "bush", 1 }, { "tree", 1 } })
scatter("west", -60, -30, 28, 808, { { "tree", 3 }, { "bush", 1 }, { "prism_vein", 2 }, { "grass", 3 } })
scatter("north", 60, -100, 30, 909, { { "rift_core", 1 }, { "surge_node", 1 } })
scatter("lookout", -95, -85, 26, 1010, { { "rift_core", 1 }, { "surge_node", 1 } })
scatter("ruinsring", 0, -62, 45, 1111, { { "surge_node", 2 }, { "prism_vein", 1 } })

WorldData.Targets = targets

-- ===== hidden fragment shards =====
WorldData.Secrets = {
	{ id = "shard_1", x = -48, z = 84, hint = "Behind the little knoll west of the path." },
	{ id = "shard_2", x = 118, z = 40, hint = "Where the east cliff meets the grass." },
	{ id = "shard_3", x = -84, z = 62, hint = "On the pond's southern bank." },
	{ id = "shard_4", x = 46, z = -52, hint = "Behind the crystal knoll." },
	{ id = "shard_5", x = -22, z = -104, hint = "Behind the ruins' back wall." },
	{ id = "shard_6", x = -122, z = -40, hint = "At the foot of the western cliffs." },
}

-- ===== clue signs =====
WorldData.Signs = {
	{ id = "sign_start", x = 4, z = 100, ry = 180, text = "WELCOME, RESTORER\nHold to absorb the glowing purple corruption.\nFollow the beam to the Station." },
	{ id = "sign_meadow", x = -70, z = 55, ry = 90, text = "ECHO MEADOW\nTrapped Echoes sleep inside Glitch Capsules.\nOne is across the pond." },
	{ id = "sign_hidden", x = 40, z = 80, ry = 240, text = "Glinting shards hide behind knolls,\nrocks and cliffs. Six in all.\nSomething will listen for them." },
	{ id = "sign_ruins", x = 0, z = -30, ry = 0, text = "THE OLD RUINS\nStone this old needs an Advanced Absorber.\nListen for ticking below." },
	{ id = "sign_gate", x = 12, z = -118, ry = 0, text = "THE GATEWAY\nRestore 75% of the valley, with an Advanced Absorber,\nand the way opens." },
}

-- ===== static healthy decor (already restored scenery) =====
-- Count is derived so ~65% of visible "elements" start corrupted (target models vs healthy scenery models).
local decor: { { kind: string, x: number, z: number, ry: number, scale: number } } = {}
do
	local rand = rng(777)
	local want = math.ceil(#targets * 0.538)
	local kinds = { "tree", "tree", "flowers", "flowers", "rock", "stump", "flowers" }
	local tries = 0
	while #decor < want and tries < 4000 do
		tries += 1
		local x = math.floor((rand() * 2 - 1) * 120)
		local z = math.floor((rand() * 2 - 1) * 120)
		if free(x, z, 4) then
			table.insert(decor, { kind = kinds[math.floor(rand() * #kinds) + 1], x = x, z = z, ry = rand() * 360, scale = 0.85 + rand() * 0.5 })
			table.insert(placed, { x, z, 2 })
		end
	end
end
WorldData.Decor = decor

-- ===== derived lookups =====
WorldData.ById = {}
for _, t in targets do
	assert(WorldData.ById[t.id] == nil, "duplicate target id " .. t.id)
	WorldData.ById[t.id] = t
end

function WorldData.corruptedShare(): number
	return #targets / (#targets + #decor)
end

return WorldData
