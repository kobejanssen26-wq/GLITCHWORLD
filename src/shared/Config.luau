-- GLITCHWORLD central balance + content configuration.
-- Every number that affects progression lives here (prices, rewards, hp, xp, bonuses, unlock requirements).
-- IDs are stable save keys: never rename an id once players could own it; add new entries instead.
local Config = {}

Config.AREA_ID = "green_valley"
Config.DATA_VERSION = 1

-- ===== economy rules =====
Config.Economy = {
	SELL_RATE = 1.0, -- credits per fragment before bonuses
	OVERFLOW_RATE = 0.5, -- fragments that do not fit in the backpack are auto-sold at this rate
	STATION_RADIUS = 32, -- must be this close to a station (sell / buy) - checked on the server
	-- Bonus caps: bonuses from Echoes + research are ADDITIVE inside one stat, then capped, then applied to the
	-- equipment base value once (no multiplicative chains between sources).
	CAPS = {
		powerBonus = 1.0,
		speedBonus = 0.6,
		sellBonus = 0.5,
		capBonus = 1.5,
		walkBonus = 6,
		rangeBonus = 10,
		xpBonus = 0.6,
		respawnBonus = 0.4,
		plantFrag = 0.6,
		crystalFrag = 0.6,
		structureFrag = 0.6,
		discoveryRadius = 90,
	},
	ABSORB_PROGRESS_DECAY_DELAY = 3, -- seconds before partial corruption grows back
	ABSORB_PROGRESS_DECAY_RATE = 0.25, -- fraction of hp per second once decaying
	RANGE_SLACK = 4, -- network latency allowance when validating range on the server
}

-- ===== equipment =====
-- Four categories. Tier 1 is free and owned from the start.
Config.Absorber = {
	{ id = "absorber_1", name = "Starter Absorber", price = 0, power = 2.0, speed = 1.0, range = 14,
		desc = "A cracked prototype. Slow, but it works." },
	{ id = "absorber_2", name = "Improved Absorber", price = 250, power = 3.0, speed = 1.25, range = 18,
		desc = "Cleaner focus coil. Can crack Prism Veins and crystals." },
	{ id = "absorber_3", name = "Advanced Absorber", price = 1500, power = 4.5, speed = 1.5, range = 22,
		desc = "Dual-lens array. Can break ancient ruin stone and Surge Nodes." },
	{ id = "absorber_4", name = "Professional Absorber", price = 10000, power = 7.0, speed = 1.8, range = 27,
		desc = "Restorer-guild grade. Can open Rift Cores." },
	{ id = "absorber_5", name = "Experimental Absorber", price = 60000, power = 11.0, speed = 2.2, range = 33,
		desc = "Unstable prototype. The fastest absorber in the valley." },
}

Config.Backpack = {
	{ id = "backpack_1", name = "Patchwork Pack", price = 0, capacity = 40 },
	{ id = "backpack_2", name = "Canvas Pack", price = 120, capacity = 100 },
	{ id = "backpack_3", name = "Reinforced Pack", price = 700, capacity = 250 },
	{ id = "backpack_4", name = "Stasis Pack", price = 3500, capacity = 600 },
	{ id = "backpack_5", name = "Pocket-Dimension Pack", price = 25000, capacity = 1400 },
}

Config.Boots = {
	{ id = "boots_1", name = "Worn Sneakers", price = 0, walk = 16, jump = 50 },
	{ id = "boots_2", name = "Trail Shoes", price = 200, walk = 18, jump = 50 },
	{ id = "boots_3", name = "Spring Boots", price = 1000, walk = 20, jump = 54 },
	{ id = "boots_4", name = "Glide Boots", price = 5000, walk = 22, jump = 58 },
	{ id = "boots_5", name = "Phase Boots", price = 40000, walk = 24, jump = 62 },
}

-- Gadgets are independent one-time purchases (some require a minimum absorber tier).
Config.Gadgets = {
	{ id = "verdant_lens", name = "Verdant Lens", price = 1500, minAbsorber = 2,
		desc = "+60% absorb power against plants and grass.", power = { plant = 0.6 } },
	{ id = "overcharge", name = "Overcharge Cell", price = 2500, minAbsorber = 2,
		desc = "Press the Overcharge button: x1.8 absorb power for 15s. 45s cooldown.",
		boost = 1.8, duration = 15, cooldown = 45 },
	{ id = "area_siphon", name = "Area Siphon", price = 4000, minAbsorber = 3,
		desc = "Also drains corrupted objects within 9 studs of your target at 40% strength.",
		radius = 9, strength = 0.4 },
	{ id = "crystal_lens", name = "Crystal Lens", price = 5000, minAbsorber = 3,
		desc = "+60% absorb power against crystals and energy deposits.", power = { crystal = 0.6, energy = 0.6 } },
}

-- ===== targets =====
-- category: used by Echo/lens bonuses. frag/xp are BASE values. hp = absorption required.
-- permanent: restoring it is saved forever and counts toward the area %.  renew: seconds until it regrows (per player).
Config.Targets = {
	grass = { name = "Corrupted Grass", category = "plant", hp = 10, frag = 4, xp = 2, minTier = 1, permanent = true, weight = 1, radius = 3 },
	bush = { name = "Glitched Bush", category = "plant", hp = 26, frag = 10, xp = 4, minTier = 1, permanent = true, weight = 1, radius = 3 },
	tree = { name = "Withered Tree", category = "plant", hp = 70, frag = 28, xp = 8, minTier = 1, permanent = true, weight = 2, radius = 5 },
	crystal = { name = "Dull Crystal", category = "crystal", hp = 220, frag = 90, xp = 20, minTier = 2, permanent = true, weight = 3, radius = 4 },
	ruin = { name = "Broken Ruin", category = "structure", hp = 450, frag = 250, xp = 50, minTier = 3, permanent = true, weight = 6, radius = 7 },
	capsule = { name = "Glitch Capsule", category = "echo", hp = 140, frag = 0, xp = 60, minTier = 1, permanent = true, weight = 0, radius = 4 },
	anomaly = { name = "Glitch Obelisk", category = "energy", hp = 400, frag = 450, xp = 100, minTier = 2, permanent = true, weight = 0, radius = 4 },
	-- renewable fragment sources (tier-gated income scaling)
	bloom = { name = "Glitch Bloom", category = "energy", hp = 14, frag = 14, xp = 1, minTier = 1, renew = 30, radius = 3 },
	prism_vein = { name = "Prism Vein", category = "crystal", hp = 60, frag = 90, xp = 3, minTier = 2, renew = 45, radius = 3 },
	surge_node = { name = "Surge Node", category = "energy", hp = 240, frag = 340, xp = 8, minTier = 3, renew = 60, radius = 4 },
	rift_core = { name = "Rift Core", category = "energy", hp = 900, frag = 1200, xp = 20, minTier = 4, renew = 90, radius = 5 },
}

-- one-off secret pickups (hidden fragment shards): collected by walking up and pressing the prompt
Config.Secrets = {
	shardReward = { credits = 30, xp = 60, rp = 0 },
}

-- ===== rank / xp =====
Config.Rank = {
	MAX = 25,
	-- total xp required to reach rank r:  floor(BASE * (r-1)^POWER)
	BASE = 40,
	POWER = 1.8,
	CREDITS_PER_RANK = 50, -- rank-up bonus = this * new rank
	RP_PER_RANK = 1,
	Titles = {
		{ rank = 1, title = "Fresh Restorer" },
		{ rank = 3, title = "Sprout Keeper" },
		{ rank = 6, title = "Glitch Scout" },
		{ rank = 10, title = "Valley Warden" },
		{ rank = 15, title = "Echo Friend" },
		{ rank = 20, title = "Master Restorer" },
		{ rank = 25, title = "Worldweaver" },
	},
	-- extra echo slots
	EchoSlots = { { rank = 1, slots = 1 }, { rank = 5, slots = 2 }, { rank = 12, slots = 3 } },
}

-- ===== echoes =====
Config.Rarity = {
	common = { name = "Common", order = 1, color = Color3.fromRGB(170, 190, 175) },
	uncommon = { name = "Uncommon", order = 2, color = Color3.fromRGB(110, 220, 120) },
	rare = { name = "Rare", order = 3, color = Color3.fromRGB(80, 160, 255) },
	epic = { name = "Epic", order = 4, color = Color3.fromRGB(190, 110, 255) },
	legendary = { name = "Legendary", order = 5, color = Color3.fromRGB(255, 200, 60) },
}

-- bonuses: list of { stat, value }. stat keys are summed (then capped by Economy.CAPS) in Rules.computeStats.
-- unlock: how it is obtained  (capsule = free it from a Glitch Capsule in the world, quest/milestone/rank/secret).
-- look: parameters for the procedural model (EchoModel.luau).
Config.Echoes = {
	{ id = "mossbit", name = "Mossbit", rarity = "common", theme = "Nature",
		blurb = "A sleepy moss ball that naps on freshly restored lawns.",
		bonuses = { { "plantFrag", 0.15 } }, bonusText = "+15% fragments from plants",
		unlock = { kind = "quest", id = "q2" }, hint = "Restore your first corrupted object.",
		look = { body = Color3.fromRGB(110, 190, 90), accent = Color3.fromRGB(60, 140, 70), shape = "leaf", size = 1.0 } },
	{ id = "pebblit", name = "Pebblit", rarity = "common", theme = "Stone",
		blurb = "Keeps spare fragments in its hollow belly.",
		bonuses = { { "capBonus", 0.10 } }, bonusText = "+10% backpack capacity",
		unlock = { kind = "capsule" }, hint = "Trapped in a Glitch Capsule near the spawn rocks.",
		look = { body = Color3.fromRGB(150, 150, 160), accent = Color3.fromRGB(100, 100, 115), shape = "rocks", size = 1.0 } },
	{ id = "voltling", name = "Voltling", rarity = "uncommon", theme = "Electricity",
		blurb = "Crackles with static whenever the Glitch is near.",
		bonuses = { { "speedBonus", 0.08 } }, bonusText = "+8% absorb speed",
		unlock = { kind = "capsule" }, hint = "Trapped on the far side of the Echo Meadow pond.",
		look = { body = Color3.fromRGB(255, 220, 70), accent = Color3.fromRGB(255, 150, 30), shape = "bolt", size = 0.95 } },
	{ id = "prismoo", name = "Prismoo", rarity = "uncommon", theme = "Crystal",
		blurb = "Refracts light into tiny rainbows. Adores crystals.",
		bonuses = { { "crystalFrag", 0.20 } }, bonusText = "+20% fragments from crystals",
		unlock = { kind = "capsule" }, hint = "Locked inside the Crystal Hollow in the east.",
		look = { body = Color3.fromRGB(120, 230, 255), accent = Color3.fromRGB(255, 130, 230), shape = "spikes", size = 1.0 } },
	{ id = "frostwhisp", name = "Frostwhisp", rarity = "uncommon", theme = "Ice",
		blurb = "A drifting wisp of cold air with a very warm heart.",
		bonuses = { { "walkBonus", 1.5 } }, bonusText = "+1.5 walk speed",
		unlock = { kind = "capsule" }, hint = "Hidden on the windy hilltop in the north-west.",
		look = { body = Color3.fromRGB(200, 240, 255), accent = Color3.fromRGB(120, 190, 255), shape = "wisp", size = 0.95 } },
	{ id = "nullberry", name = "Nullberry", rarity = "rare", theme = "Space",
		blurb = "A berry from a star that never existed. Tastes like static.",
		bonuses = { { "sellBonus", 0.08 } }, bonusText = "+8% credits when selling fragments",
		unlock = { kind = "milestone", id = "m25" }, hint = "Restore 25% of the Green Valley.",
		look = { body = Color3.fromRGB(70, 50, 140), accent = Color3.fromRGB(255, 120, 200), shape = "ring", size = 1.0 } },
	{ id = "sparkfin", name = "Sparkfin", rarity = "rare", theme = "Electricity",
		blurb = "Swims through the air as if it were a pond.",
		bonuses = { { "rangeBonus", 3 } }, bonusText = "+3 studs absorber range",
		unlock = { kind = "capsule" }, hint = "Caged in the Sunken Vault below the ruins.",
		look = { body = Color3.fromRGB(70, 200, 255), accent = Color3.fromRGB(255, 240, 90), shape = "fin", size = 1.0 } },
	{ id = "gearlo", name = "Gearlo", rarity = "rare", theme = "Ancient Tech",
		blurb = "Ticks softly. Remembers who built the ruins.",
		bonuses = { { "structureFrag", 0.25 } }, bonusText = "+25% fragments from ruins",
		unlock = { kind = "capsule" }, hint = "Trapped in the Old Engine Room at the heart of the ruins.",
		look = { body = Color3.fromRGB(190, 150, 90), accent = Color3.fromRGB(120, 95, 60), shape = "gear", size = 1.05 } },
	{ id = "lumifawn", name = "Lumifawn", rarity = "epic", theme = "Nature",
		blurb = "Its antlers bloom with a new flower for every lesson learned.",
		bonuses = { { "xpBonus", 0.12 } }, bonusText = "+12% Restoration XP",
		unlock = { kind = "milestone", id = "m60" }, hint = "Restore 60% of the Green Valley.",
		look = { body = Color3.fromRGB(255, 200, 220), accent = Color3.fromRGB(120, 230, 150), shape = "horns", size = 1.1 } },
	{ id = "cometta", name = "Cometta", rarity = "epic", theme = "Space",
		blurb = "Leaves a trail of cold light. Hates waiting.",
		bonuses = { { "respawnBonus", 0.2 } }, bonusText = "Glitch nodes regrow 20% faster",
		unlock = { kind = "rank", rank = 15 }, hint = "Reach Restoration Rank 15.",
		look = { body = Color3.fromRGB(60, 80, 200), accent = Color3.fromRGB(180, 230, 255), shape = "tail", size = 1.05 } },
	{ id = "runeowl", name = "Runeowl", rarity = "epic", theme = "Ancient Tech",
		blurb = "Sees things that are hidden. Whispers where they are.",
		bonuses = { { "discoveryRadius", 55 } }, bonusText = "Reveals hidden fragments within 55 studs",
		unlock = { kind = "secrets", count = 6 }, hint = "Find all 6 Hidden Fragment shards.",
		look = { body = Color3.fromRGB(90, 70, 130), accent = Color3.fromRGB(100, 255, 220), shape = "owl", size = 1.1 } },
	{ id = "auroxel", name = "Auroxel", rarity = "legendary", theme = "Glitch",
		blurb = "The valley's first Echo. It remembers the world before the Glitch.",
		bonuses = { { "powerBonus", 0.12 }, { "sellBonus", 0.06 } }, bonusText = "+12% absorb power, +6% sell value",
		unlock = { kind = "milestone", id = "m100" }, hint = "Fully restore the Green Valley (100%).",
		look = { body = Color3.fromRGB(255, 215, 90), accent = Color3.fromRGB(120, 255, 255), shape = "halo", size = 1.2 } },
}

-- ===== research =====
-- Spend Research Points (1 per rank, plus milestone rewards). Each branch is a chain: node n needs node n-1.
Config.Research = {
	branches = {
		{ id = "efficiency", name = "Efficiency", blurb = "Absorb corruption faster.", color = Color3.fromRGB(255, 150, 60) },
		{ id = "capacity", name = "Capacity", blurb = "Carry more and sell better.", color = Color3.fromRGB(90, 200, 120) },
		{ id = "exploration", name = "Exploration", blurb = "Move farther, reach farther.", color = Color3.fromRGB(80, 170, 255) },
		{ id = "discovery", name = "Discovery", blurb = "Find secrets, learn faster.", color = Color3.fromRGB(190, 120, 255) },
	},
	nodes = {
		{ id = "eff1", branch = "efficiency", name = "Focused Beam", cost = 1, bonuses = { { "powerBonus", 0.10 } }, text = "+10% absorb power" },
		{ id = "eff2", branch = "efficiency", name = "Rapid Pulse", cost = 1, bonuses = { { "speedBonus", 0.10 } }, text = "+10% absorb speed" },
		{ id = "eff3", branch = "efficiency", name = "Resonance", cost = 2, bonuses = { { "powerBonus", 0.15 } }, text = "+15% absorb power" },
		{ id = "eff4", branch = "efficiency", name = "Perfect Harmony", cost = 3, bonuses = { { "speedBonus", 0.15 } }, text = "+15% absorb speed" },
		{ id = "cap1", branch = "capacity", name = "Deep Pockets", cost = 1, bonuses = { { "capBonus", 0.25 } }, text = "+25% backpack capacity" },
		{ id = "cap2", branch = "capacity", name = "Haggling", cost = 1, bonuses = { { "sellBonus", 0.05 } }, text = "+5% sell value" },
		{ id = "cap3", branch = "capacity", name = "Folded Space", cost = 2, bonuses = { { "capBonus", 0.40 } }, text = "+40% backpack capacity" },
		{ id = "cap4", branch = "capacity", name = "Auto-Sorter", cost = 3, bonuses = { { "sellBonus", 0.05 }, { "overflowRate", 0.25 } }, text = "+5% sell value, overflow sells at 75%" },
		{ id = "exp1", branch = "exploration", name = "Light Steps", cost = 1, bonuses = { { "walkBonus", 1.5 } }, text = "+1.5 walk speed" },
		{ id = "exp2", branch = "exploration", name = "Long Reach", cost = 1, bonuses = { { "rangeBonus", 3 } }, text = "+3 studs absorber range" },
		{ id = "exp3", branch = "exploration", name = "Fleet Feet", cost = 2, bonuses = { { "walkBonus", 2 } }, text = "+2 walk speed" },
		{ id = "exp4", branch = "exploration", name = "Wide Aperture", cost = 3, bonuses = { { "rangeBonus", 5 } }, text = "+5 studs absorber range" },
		{ id = "dis1", branch = "discovery", name = "Glint Sense", cost = 1, bonuses = { { "discoveryRadius", 45 } }, text = "Hidden fragments sparkle within 45 studs" },
		{ id = "dis2", branch = "discovery", name = "Field Notes", cost = 1, bonuses = { { "xpBonus", 0.10 } }, text = "+10% Restoration XP" },
		{ id = "dis3", branch = "discovery", name = "Quick Regrowth", cost = 2, bonuses = { { "respawnBonus", 0.20 } }, text = "Glitch nodes regrow 20% faster" },
		{ id = "dis4", branch = "discovery", name = "Treasure Eye", cost = 3, bonuses = { { "secretMult", 1 }, { "xpBonus", 0.15 } }, text = "Hidden finds pay double, +15% XP" },
	},
}

-- ===== milestones =====
-- Area restoration % milestones plus collection milestones. Claimed automatically (server-side, once).
-- reward: credits / xp / rp / echo / title / unlock (area id)
Config.Milestones = {
	{ id = "m10", kind = "percent", value = 10, name = "First Green", reward = { credits = 200, xp = 100 } },
	{ id = "m25", kind = "percent", value = 25, name = "Quarter Restored", reward = { credits = 300, rp = 1, echo = "nullberry" } },
	{ id = "m40", kind = "percent", value = 40, name = "Taking Shape", reward = { credits = 800, rp = 2 } },
	{ id = "m60", kind = "percent", value = 60, name = "Alive Again", reward = { credits = 1500, rp = 1, echo = "lumifawn" } },
	{ id = "m75", kind = "percent", value = 75, name = "The Gate Awakens", reward = { credits = 3000, rp = 1, unlock = "frostlight" } },
	{ id = "m100", kind = "percent", value = 100, name = "Valley Restored", reward = { credits = 5000, rp = 3, echo = "auroxel", title = "Valley Restorer" } },
	{ id = "e3", kind = "echoes", value = 3, name = "Echo Friend", reward = { credits = 300, xp = 150 } },
	{ id = "e6", kind = "echoes", value = 6, name = "Echo Keeper", reward = { credits = 800, rp = 1 } },
	{ id = "e9", kind = "echoes", value = 9, name = "Echo Warden", reward = { credits = 2000, rp = 1 } },
	{ id = "e12", kind = "echoes", value = 12, name = "Echo Master", reward = { credits = 5000, rp = 2, title = "Echo Master" } },
	{ id = "s3", kind = "secrets", value = 3, name = "Sharp Eyes", reward = { xp = 200, rp = 1 } },
	{ id = "s6", kind = "secrets", value = 6, name = "Secret Seeker", reward = { credits = 300, rp = 1 } },
}

-- Areas. Frostlight Peaks is the planned next region; the valley only contains its gateway and a teaser vista.
Config.Areas = {
	green_valley = { name = "The Green Valley" },
	frostlight = { name = "Frostlight Peaks", requires = { milestone = "m75", absorberTier = 3 },
		teaser = "Cold Corruption freezes everything solid. Warm Glitch Fragments will have to thaw it first." },
}

-- ===== tutorial / quest chain =====
-- stat: key read by Rules.getStat (server-validated numbers only). beacon tells the client where to point.
Config.Quests = {
	{ id = "q1", title = "Collect Glitch Fragments", stat = "fragmentsCollected", goal = 10,
		text = "Hold the absorb button on glowing corrupted grass to collect 10 fragments.",
		beacon = "nearest:grass", reward = { credits = 20, xp = 10 } },
	{ id = "q2", title = "Restore an Object", stat = "targetsRestored", goal = 1,
		text = "Finish absorbing one corrupted object to restore it.",
		beacon = "nearest:restorable", reward = { credits = 30, xp = 20, echo = "mossbit" } },
	{ id = "q3", title = "Visit the Restoration Station", stat = "salesMade", goal = 1,
		text = "Walk to the Restoration Station and press the prompt to turn fragments into Credits.",
		beacon = "station:sell", reward = { credits = 60, xp = 20 } },
	{ id = "q4", title = "Buy an Upgrade", stat = "upgradesBought", goal = 1,
		text = "Open the Upgrade Station and buy your first piece of equipment.",
		beacon = "station:upgrade", reward = { credits = 50, xp = 30 } },
	{ id = "q5", title = "Free an Echo", stat = "echoesFreed", goal = 1,
		text = "A Glitch Capsule traps an Echo near the spawn. Absorb it to free the creature.",
		beacon = "nearest:capsule", reward = { credits = 100, xp = 50 } },
	{ id = "q6", title = "Restore 10% of the Valley", stat = "percent", goal = 10,
		text = "Keep restoring corrupted plants, crystals and ruins. Watch the valley turn green.",
		beacon = "nearest:restorable", reward = { credits = 150, xp = 60 } },
	{ id = "q7", title = "Reach 25% Restoration", stat = "percent", goal = 25,
		text = "Upgrade your absorber to crack crystals, then restore a quarter of the valley.",
		beacon = "nearest:restorable", reward = { credits = 400, xp = 150, rp = 2 } },
}

-- ===== client visuals / audio =====
-- Audio uses built-in rbxasset:// engine sounds only (always available). Swap ids here for custom audio.
Config.Sounds = {
	absorbLoop = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.25, pitch = 0.6, looped = true },
	restored = { id = "rbxasset://sounds/victory.wav", volume = 0.35, pitch = 1.4 },
	collect = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5, pitch = 1.8 },
	sell = { id = "rbxasset://sounds/button.wav", volume = 0.6, pitch = 1.3 },
	buy = { id = "rbxasset://sounds/victory.wav", volume = 0.5, pitch = 1.0 },
	deny = { id = "rbxasset://sounds/button.wav", volume = 0.4, pitch = 0.6 },
	echo = { id = "rbxasset://sounds/victory.wav", volume = 0.5, pitch = 1.8 },
	milestone = { id = "rbxasset://sounds/victory.wav", volume = 0.6, pitch = 0.9 },
	click = { id = "rbxasset://sounds/button.wav", volume = 0.25, pitch = 1.0 },
	music = { id = "", volume = 0.2 }, -- set an audio asset id you own to enable background music
}

Config.Colors = {
	glitchPurple = Color3.fromRGB(150, 70, 255),
	glitchCyan = Color3.fromRGB(60, 235, 255),
	corruptDark = Color3.fromRGB(46, 40, 62),
	corruptGrey = Color3.fromRGB(86, 80, 104),
}

return Config
