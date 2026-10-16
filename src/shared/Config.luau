-- NEONFORGE: Tower Tycoon - central configuration.
-- Every number that affects progression lives here. Ids are save keys: never rename, only add.
local Config = {}

Config.NAME = "NEONFORGE"
Config.DATA_VERSION = 1

-- ===== tower geometry (shared by the baker, the server and the tests) =====
Config.Tower = {
	FLOORS = 12,
	MODULES_PER_FLOOR = 7, -- 1 checkpoint plaza + 6 obstacle modules
	PATH_RADIUS = 90, -- distance of the path centreline from the tower axis
	PATH_WIDTH = 20,
	MODULE_LENGTH = 44,
	CONNECTOR = 11, -- solid walkway at each end of an obstacle module (obstacles live in the 22 studs between)
	JOINT_RADIUS = 10.5, -- round plate that fills the corner between two modules
	RISE_PER_MODULE = 3.5,
	BASE_Y = 6, -- height of the first checkpoint plaza surface
	CORE_RADIUS = 55,
	MIN_FLOOR_SECONDS = 18, -- anti-teleport: a floor can never be cleared faster than this
	FALL_MARGIN = 70, -- falling this far below the checkpoint returns you to it
}

-- the ring of tycoon plots around the hub island (plot-local: +X along the belt, -Z towards the tower)
Config.Plots = {
	COUNT = 8,
	RING_RADIUS = 330,
	SIZE = 110,
	BUTTON_Z = 24, -- where the buy button stands (behind the factory)
	BELT_Y = 2.2,
}

-- ===== themes: one per floor =====
-- main/accent/glow colours, terrain-free materials, lighting + ambience used by the client per floor
Config.Floors = {
	{ id = 1, name = "Candy Foundry", main = { 255, 150, 205 }, accent = { 255, 236, 130 }, glow = { 255, 70, 160 }, material = "SmoothPlastic",
		sky = { top = { 255, 190, 230 }, haze = { 255, 150, 210 }, ambient = { 190, 130, 170 }, brightness = 2.6, clock = 15.5, particles = "sparkle" }, music = "zone_a" },
	{ id = 2, name = "Mossy Ruins", main = { 96, 150, 96 }, accent = { 210, 196, 140 }, glow = { 120, 255, 150 }, material = "Cobblestone",
		sky = { top = { 170, 235, 190 }, haze = { 140, 200, 150 }, ambient = { 120, 160, 120 }, brightness = 2.3, clock = 13, particles = "leaf" }, music = "zone_a" },
	{ id = 3, name = "Lava Forge", main = { 74, 52, 52 }, accent = { 255, 120, 40 }, glow = { 255, 90, 20 }, material = "Basalt",
		sky = { top = { 255, 130, 60 }, haze = { 200, 70, 30 }, ambient = { 150, 80, 60 }, brightness = 2.0, clock = 18, particles = "ember" }, music = "zone_b" },
	{ id = 4, name = "Frost Vault", main = { 190, 230, 255 }, accent = { 120, 190, 255 }, glow = { 150, 230, 255 }, material = "Ice",
		sky = { top = { 190, 225, 255 }, haze = { 200, 235, 255 }, ambient = { 150, 180, 220 }, brightness = 2.8, clock = 12, particles = "snow" }, music = "zone_b" },
	{ id = 5, name = "Neon Arcade", main = { 34, 22, 66 }, accent = { 255, 60, 200 }, glow = { 60, 255, 240 }, material = "SmoothPlastic",
		sky = { top = { 60, 20, 110 }, haze = { 120, 40, 170 }, ambient = { 80, 50, 140 }, brightness = 1.6, clock = 22, particles = "sparkle" }, music = "zone_c" },
	{ id = 6, name = "Toxic Labs", main = { 64, 92, 74 }, accent = { 186, 255, 70 }, glow = { 120, 255, 40 }, material = "Metal",
		sky = { top = { 170, 255, 120 }, haze = { 110, 190, 70 }, ambient = { 100, 150, 90 }, brightness = 2.0, clock = 17, particles = "bubble" }, music = "zone_c" },
	{ id = 7, name = "Clockwork Heights", main = { 150, 110, 64 }, accent = { 242, 202, 104 }, glow = { 255, 224, 130 }, material = "DiamondPlate",
		sky = { top = { 255, 220, 150 }, haze = { 220, 170, 100 }, ambient = { 170, 140, 100 }, brightness = 2.4, clock = 16.5, particles = "dust" }, music = "zone_d" },
	{ id = 8, name = "Crystal Caverns", main = { 92, 72, 164 }, accent = { 204, 124, 255 }, glow = { 124, 204, 255 }, material = "Marble",
		sky = { top = { 140, 110, 230 }, haze = { 100, 70, 190 }, ambient = { 100, 90, 170 }, brightness = 1.8, clock = 21, particles = "sparkle" }, music = "zone_d" },
	{ id = 9, name = "Cloud Garden", main = { 250, 250, 255 }, accent = { 255, 204, 224 }, glow = { 255, 242, 166 }, material = "SmoothPlastic",
		sky = { top = { 160, 215, 255 }, haze = { 230, 240, 255 }, ambient = { 200, 210, 235 }, brightness = 3.0, clock = 11, particles = "petal" }, music = "zone_e" },
	{ id = 10, name = "Storm Spire", main = { 60, 72, 102 }, accent = { 204, 224, 255 }, glow = { 150, 200, 255 }, material = "Concrete",
		sky = { top = { 70, 85, 130 }, haze = { 60, 70, 100 }, ambient = { 90, 100, 140 }, brightness = 1.7, clock = 19, particles = "rain" }, music = "zone_e" },
	{ id = 11, name = "Void Rift", main = { 16, 10, 32 }, accent = { 150, 60, 255 }, glow = { 255, 60, 120 }, material = "Slate",
		sky = { top = { 20, 8, 50 }, haze = { 70, 20, 120 }, ambient = { 70, 40, 110 }, brightness = 1.3, clock = 0, particles = "void" }, music = "zone_f" },
	{ id = 12, name = "Starcrown Summit", main = { 255, 216, 104 }, accent = { 255, 255, 255 }, glow = { 255, 240, 170 }, material = "Foil",
		sky = { top = { 30, 20, 80 }, haze = { 255, 200, 120 }, ambient = { 200, 170, 140 }, brightness = 2.6, clock = 5.8, particles = "star" }, music = "zone_f" },
}

-- ===== tycoon =====
Config.Tycoon = {
	PLOTS = 8,
	ORE_LIFETIME = 18,
	MAX_ORE_PER_PLOT = 36,
	CROWN_BONUS = 0.05, -- cash multiplier per crown
	OVERDRIVE_BONUS = 0.75, -- cash multiplier per Overdrive
	OVERDRIVE_HEADSTART = 400, -- starting cash after an Overdrive, per Overdrive count
	COST_RAMP = 0.32, -- every purchase in the list is this much pricier than the one before it (x(1 + RAMP*n)) on top of the listed cost
	OVERDRIVE_COST_GROWTH = 0.6, -- factory pieces cost this much more per Overdrive (keeps repeat cycles meaningful)
	BELT_SPEED = 9,
}

-- kind: dropper (spawns ore worth `value` every `interval`s), upgrader (x`mult` to every ore), generator (+`rate` cash/s),
-- collector (`bonus` x cash from ore), decor (cosmetic), overdrive (unlocks Overdrive).  x = position along the belt.
-- Items marked free are owned at the start of every cycle.
Config.Items = {
	{ id = "dropper_rusty", name = "Rusty Dropper", kind = "dropper", cost = 0, free = true, x = -32, value = 2, interval = 1.5, color = { 220, 130, 70 } },
	{ id = "collector_basic", name = "Collector", kind = "collector", cost = 0, free = true, x = 34, bonus = 1 },
	{ id = "up_polisher", name = "Polisher x2", kind = "upgrader", cost = 40, x = -10, mult = 2, color = { 255, 200, 90 } },
	{ id = "dropper_copper", name = "Copper Dropper", kind = "dropper", cost = 120, x = -26, value = 5, interval = 1.5, color = { 255, 140, 90 } },
	{ id = "up_smelter", name = "Smelter x2", kind = "upgrader", cost = 400, x = 0, mult = 2, color = { 255, 110, 60 } },
	{ id = "dropper_silver", name = "Silver Dropper", kind = "dropper", cost = 1100, x = -20, value = 12, interval = 1.5, color = { 210, 225, 245 } },
	{ id = "gen_spark", name = "Spark Generator", kind = "generator", cost = 2400, x = 8, rate = 14, color = { 255, 240, 120 } },
	{ id = "up_quantum", name = "Quantum Gate x3", kind = "upgrader", cost = 7000, x = 10, mult = 3, color = { 120, 200, 255 } },
	{ id = "decor_lights", name = "Neon Roof Lights", kind = "decor", cost = 9000, x = 0, color = { 255, 90, 200 } },
	{ id = "dropper_gold", name = "Gold Dropper", kind = "dropper", cost = 20000, x = -14, value = 30, interval = 1.5, color = { 255, 215, 80 } },
	{ id = "up_prism", name = "Prism Press x3", kind = "upgrader", cost = 60000, x = 20, mult = 3, color = { 255, 120, 220 } },
	{ id = "dropper_diamond", name = "Diamond Dropper", kind = "dropper", cost = 160000, x = -8, value = 90, interval = 1.5, color = { 150, 240, 255 } },
	{ id = "gen_reactor", name = "Fusion Reactor", kind = "generator", cost = 380000, x = 14, rate = 300, color = { 120, 255, 200 } },
	{ id = "decor_fans", name = "Turbine Fans", kind = "decor", cost = 500000, x = 0, color = { 180, 200, 255 } },
	{ id = "up_singularity", name = "Singularity x4", kind = "upgrader", cost = 1000000, x = 28, mult = 4, color = { 170, 90, 255 } },
	{ id = "dropper_neon", name = "Neon Core Dropper", kind = "dropper", cost = 3000000, x = -2, value = 300, interval = 1.5, color = { 80, 255, 220 } },
	{ id = "dropper_void", name = "Void Dropper", kind = "dropper", cost = 10000000, x = 4, value = 1000, interval = 1.5, color = { 190, 80, 255 } },
	{ id = "collector_mega", name = "Mega Collector x1.5", kind = "collector", cost = 30000000, x = 34, bonus = 1.5 },
	{ id = "overdrive_reactor", name = "Overdrive Reactor", kind = "overdrive", cost = 80000000, x = 0, color = { 255, 80, 120 } },
}

-- ===== obby rewards / perks / cosmetics =====
Config.Obby = {
	FIRST_CLEAR_CASH_BASE = 250, -- x floor^2, or INCOME_SECONDS of income x floor, whichever is larger
	INCOME_SECONDS = 25,
	REPEAT_FRACTION = 0.15,
	SUMMIT_BONUS_CROWNS = 20,
	COIN_CASH = 6, -- x floor
	SKIP_BASE = 2500, -- x floor^2
	CHECKPOINT_REACH_RADIUS = 34,
}

Config.Perks = {
	{ id = "speed_coil", name = "Speed Coil", cost = 1500, desc = "Walk speed 16 -> 21.", walk = 21 },
	{ id = "coin_magnet", name = "Coin Magnet", cost = 6000, desc = "Coins fly to you from 22 studs.", magnet = 22 },
	{ id = "gravity_boots", name = "Gravity Boots", cost = 25000, desc = "Jump power 50 -> 58.", jump = 58 },
	{ id = "double_jump", name = "Double Jump", cost = 150000, desc = "Jump again in mid-air.", double = true },
}

-- trails unlock on the first clear of their floor; auras unlock at crown totals
Config.Trails = {}
for _, f in Config.Floors do
	table.insert(Config.Trails, { id = "trail_" .. f.id, name = f.name .. " Trail", floor = f.id, color = f.glow, accent = f.accent })
end
Config.Auras = {
	{ id = "aura_spark", name = "Spark Aura", crowns = 10, color = { 255, 240, 120 } },
	{ id = "aura_flame", name = "Inferno Aura", crowns = 25, color = { 255, 110, 40 } },
	{ id = "aura_galaxy", name = "Galaxy Aura", crowns = 50, color = { 170, 100, 255 } },
	{ id = "aura_crown", name = "Starcrown Aura", crowns = 90, color = { 255, 220, 120 } },
}

Config.Titles = {
	{ id = "Newcomer", crowns = 0 }, { id = "Apprentice Smith", crowns = 3 }, { id = "Forge Runner", crowns = 10 },
	{ id = "Tower Climber", crowns = 30 }, { id = "Neon Master", crowns = 60 }, { id = "Tower Conqueror", crowns = 98 },
}

-- ===== audio (see audio/README.md: upload the files, paste the asset ids into AudioIds.luau) =====
-- engine fallbacks are used while an id is empty so the game is never silent in Studio
Config.Sfx = {
	click = { fallback = "rbxasset://sounds/button.wav", volume = 0.25, pitch = 1.0 },
	buy = { fallback = "rbxasset://sounds/victory.wav", volume = 0.4, pitch = 1.2 },
	deny = { fallback = "rbxasset://sounds/button.wav", volume = 0.35, pitch = 0.6 },
	cash = { fallback = "rbxasset://sounds/electronicpingshort.wav", volume = 0.3, pitch = 1.6 },
	coin = { fallback = "rbxasset://sounds/electronicpingshort.wav", volume = 0.4, pitch = 2.0 },
	checkpoint = { fallback = "rbxasset://sounds/victory.wav", volume = 0.45, pitch = 1.5 },
	floor_clear = { fallback = "rbxasset://sounds/victory.wav", volume = 0.6, pitch = 1.0 },
	death = { fallback = "rbxasset://sounds/uuhhh.mp3", volume = 0.4, pitch = 1.0 },
	bounce = { fallback = "rbxasset://sounds/electronicpingshort.wav", volume = 0.4, pitch = 0.8 },
	speed = { fallback = "rbxasset://sounds/electronicpingshort.wav", volume = 0.4, pitch = 2.4 },
	overdrive = { fallback = "rbxasset://sounds/victory.wav", volume = 0.7, pitch = 0.7 },
	unlock = { fallback = "rbxasset://sounds/victory.wav", volume = 0.5, pitch = 1.8 },
	jump2 = { fallback = "rbxasset://sounds/switch.wav", volume = 0.35, pitch = 1.6 },
}

Config.Colors = {
	cyan = { 70, 240, 255 }, magenta = { 255, 70, 200 }, gold = { 255, 215, 90 }, dark = { 18, 14, 36 }, panel = { 30, 24, 58 },
}

return Config
