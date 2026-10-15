-- Player profile schema: defaults and defensive reconciliation of whatever came out of the DataStore.
-- reconcile() never trusts stored data blindly: unknown ids are dropped, numbers are clamped, tiers bounded.
local Config = require(script.Parent.Config)
local WorldData = require(script.Parent.WorldData)

local Profile = {}

local function num(v: any, default: number, lo: number?, hi: number?): number
	if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
		return default
	end
	return math.clamp(v, lo or -1e15, hi or 1e15)
end

local function idSet(src: any, valid: { [string]: any }): { [string]: boolean }
	local out = {}
	if type(src) == "table" then
		for k, v in src do
			if type(k) == "string" and v == true and valid[k] ~= nil then
				out[k] = true
			end
		end
	end
	return out
end

local echoById: { [string]: any } = {}
for _, e in Config.Echoes do
	echoById[e.id] = e
end
local researchById: { [string]: any } = {}
for _, n in Config.Research.nodes do
	researchById[n.id] = n
end
local gadgetById: { [string]: any } = {}
for _, g in Config.Gadgets do
	gadgetById[g.id] = g
end
local milestoneById: { [string]: any } = {}
for _, m in Config.Milestones do
	milestoneById[m.id] = m
end
local questById: { [string]: any } = {}
for _, q in Config.Quests do
	questById[q.id] = q
end
local secretById: { [string]: any } = {}
for _, s in WorldData.Secrets do
	secretById[s.id] = s
end

Profile.echoById = echoById
Profile.researchById = researchById
Profile.gadgetById = gadgetById

function Profile.default()
	return {
		v = Config.DATA_VERSION,
		credits = 0,
		fragments = 0,
		xp = 0,
		rp = 0,
		tiers = { absorber = 1, backpack = 1, boots = 1 },
		gadgets = {},
		stats = { fragmentsCollected = 0, targetsRestored = 0, salesMade = 0, upgradesBought = 0, echoesFreed = 0, secretsFound = 0, lifetimeCredits = 0 },
		restored = {}, -- permanent targets (incl. capsules / obelisks)
		secrets = {}, -- hidden shards found
		echoes = {},
		equipped = {},
		research = {},
		quests = {}, -- claimed quest ids
		milestones = {},
		unlocked = {},
		title = "Fresh Restorer",
		titles = { ["Fresh Restorer"] = true },
		settings = { music = true, sfx = true, hints = true },
	}
end

function Profile.reconcile(raw: any)
	local p = Profile.default()
	if type(raw) ~= "table" then
		return p
	end
	p.credits = math.floor(num(raw.credits, 0, 0))
	p.fragments = math.floor(num(raw.fragments, 0, 0))
	p.xp = math.floor(num(raw.xp, 0, 0))
	p.rp = math.floor(num(raw.rp, 0, 0))
	if type(raw.tiers) == "table" then
		p.tiers.absorber = math.floor(num(raw.tiers.absorber, 1, 1, #Config.Absorber))
		p.tiers.backpack = math.floor(num(raw.tiers.backpack, 1, 1, #Config.Backpack))
		p.tiers.boots = math.floor(num(raw.tiers.boots, 1, 1, #Config.Boots))
	end
	p.gadgets = idSet(raw.gadgets, gadgetById)
	if type(raw.stats) == "table" then
		for k in p.stats do
			p.stats[k] = math.floor(num(raw.stats[k], 0, 0))
		end
	end
	p.restored = idSet(raw.restored, WorldData.ById)
	p.secrets = idSet(raw.secrets, secretById)
	p.echoes = idSet(raw.echoes, echoById)
	p.research = idSet(raw.research, researchById)
	p.quests = idSet(raw.quests, questById)
	p.milestones = idSet(raw.milestones, milestoneById)
	p.unlocked = idSet(raw.unlocked, Config.Areas)
	if type(raw.equipped) == "table" then
		local seen = {}
		for _, id in raw.equipped do
			if type(id) == "string" and p.echoes[id] and not seen[id] and #p.equipped < 3 then
				seen[id] = true
				table.insert(p.equipped, id)
			end
		end
	end
	if type(raw.titles) == "table" then
		for k, v in raw.titles do
			if type(k) == "string" and v == true and #k <= 40 then
				p.titles[k] = true
			end
		end
	end
	if type(raw.title) == "string" and p.titles[raw.title] then
		p.title = raw.title
	end
	if type(raw.settings) == "table" then
		for k in p.settings do
			if type(raw.settings[k]) == "boolean" then
				p.settings[k] = raw.settings[k]
			end
		end
	end
	return p
end

return Profile
