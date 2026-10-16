-- Save schema + defensive reconcile of whatever the DataStore returned.
local Config = require(script.Parent.Config)

local Profile = {}

local function num(v: any, default: number, lo: number?, hi: number?): number
	if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
		return default
	end
	return math.clamp(v, lo or -1e300, hi or 1e300)
end

local function idSet(src: any, valid: { [string]: boolean }): { [string]: boolean }
	local out = {}
	if type(src) == "table" then
		for k, v in src do
			if type(k) == "string" and v == true and valid[k] then
				out[k] = true
			end
		end
	end
	return out
end

local function ids(list: { { id: string } }): { [string]: boolean }
	local o = {}
	for _, e in list do
		o[e.id] = true
	end
	return o
end

Profile.validItems = ids(Config.Items)
Profile.validPerks = ids(Config.Perks)
Profile.validTrails = ids(Config.Trails)
Profile.validAuras = ids(Config.Auras)
Profile.validTitles = ids(Config.Titles)

function Profile.default()
	local items = {}
	for _, it in Config.Items do
		if it.free then
			items[it.id] = true
		end
	end
	return {
		v = Config.DATA_VERSION,
		cash = 0,
		crowns = 0,
		overdrive = 0,
		items = items,
		floors = {}, -- ["1"] = true once cleared (string keys keep DataStore tables dictionaries)
		reached = 1, -- highest floor whose checkpoint was reached
		checkpoint = 1, -- floor checkpoint used for respawning
		perks = {},
		trails = {},
		auras = {},
		trail = "",
		aura = "",
		title = "Newcomer",
		stats = { deaths = 0, coins = 0, floorsCleared = 0, playSeconds = 0, cashEarned = 0, skips = 0, ores = 0 },
		settings = { music = true, sfx = true, shake = true },
	}
end

function Profile.reconcile(raw: any)
	local p = Profile.default()
	if type(raw) ~= "table" then
		return p
	end
	p.cash = math.floor(num(raw.cash, 0, 0))
	p.crowns = math.floor(num(raw.crowns, 0, 0, 100000))
	p.overdrive = math.floor(num(raw.overdrive, 0, 0, 10000))
	p.items = idSet(raw.items, Profile.validItems)
	for _, it in Config.Items do
		if it.free then
			p.items[it.id] = true
		end
	end
	if type(raw.floors) == "table" then
		for k, v in raw.floors do
			local n = tonumber(k)
			if v == true and n and n >= 1 and n <= Config.Tower.FLOORS and n == math.floor(n) then
				p.floors[tostring(n)] = true
			end
		end
	end
	p.reached = math.floor(num(raw.reached, 1, 1, Config.Tower.FLOORS))
	p.checkpoint = math.floor(num(raw.checkpoint, 1, 1, p.reached))
	p.perks = idSet(raw.perks, Profile.validPerks)
	p.trails = idSet(raw.trails, Profile.validTrails)
	p.auras = idSet(raw.auras, Profile.validAuras)
	if type(raw.trail) == "string" and p.trails[raw.trail] then
		p.trail = raw.trail
	end
	if type(raw.aura) == "string" and p.auras[raw.aura] then
		p.aura = raw.aura
	end
	if type(raw.title) == "string" and Profile.validTitles[raw.title] then
		p.title = raw.title
	end
	if type(raw.stats) == "table" then
		for k in p.stats do
			p.stats[k] = math.floor(num(raw.stats[k], 0, 0))
		end
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
