
local Config = require("./shared/Config")
local WorldData = require("./shared/WorldData")
local Rules = require("./shared/Rules")
local Profile = require("./shared/Profile")

local fails = 0
local function check(cond, msg)
	if not cond then fails += 1; print("FAIL: " .. msg) end
end

-- unique ids
local function unique(list, label, key)
	local seen = {}
	for _, e in list do
		check(not seen[e[key or "id"]], label .. " duplicate id " .. tostring(e[key or "id"]))
		seen[e[key or "id"]] = true
	end
end
unique(Config.Absorber, "absorber"); unique(Config.Backpack, "backpack"); unique(Config.Boots, "boots")
unique(Config.Gadgets, "gadget"); unique(Config.Echoes, "echo"); unique(Config.Research.nodes, "research")
unique(Config.Milestones, "milestone"); unique(Config.Quests, "quest"); unique(WorldData.Targets, "target")

-- every tier line is strictly better and strictly pricier (no pointless upgrades)
for name, list in { absorber = Config.Absorber, backpack = Config.Backpack, boots = Config.Boots } do
	check(list[1].price == 0, name .. " tier 1 must be free")
	for i = 2, #list do
		check(list[i].price > list[i - 1].price, name .. " price must increase at tier " .. i)
	end
end
for i = 2, #Config.Absorber do
	local a, b = Config.Absorber[i - 1], Config.Absorber[i]
	local gain = (b.power * b.speed) / (a.power * a.speed)
	check(gain >= 1.5, ("absorber tier %d dps gain %.2fx is not noticeable"):format(i, gain))
	check(b.range > a.range, "absorber range must grow")
end
for i = 2, #Config.Backpack do
	check(Config.Backpack[i].capacity >= Config.Backpack[i - 1].capacity * 1.8, "backpack gain too small at tier " .. i)
end
for i = 2, #Config.Boots do
	check(Config.Boots[i].walk > Config.Boots[i - 1].walk, "boots speed must grow")
end

-- references resolve
for _, t in WorldData.Targets do check(Config.Targets[t.type] ~= nil, "unknown target type " .. t.type) end
for _, e in Config.Echoes do
	check(Config.Rarity[e.rarity] ~= nil, "bad rarity " .. e.id)
	if e.unlock.kind == "capsule" then
		local n = 0
		for _, t in WorldData.Targets do if t.echo == e.id then n += 1 end end
		check(n == 1, "capsule echo " .. e.id .. " needs exactly one capsule, has " .. n)
	end
	if e.unlock.kind == "milestone" then check(Profile.default() and (function() for _, m in Config.Milestones do if m.id == e.unlock.id then return true end end return false end)(), "milestone missing for " .. e.id) end
end
check(#Config.Echoes == 12, "expected 12 echoes")

-- layout: nothing overlaps, everything stays inside the valley
local all = {}
for _, t in WorldData.Targets do table.insert(all, { t.x, t.z, t.id, Config.Targets[t.type].radius }) end
for i = 1, #all do
	check(math.abs(all[i][1]) < 130 and math.abs(all[i][2]) < 130, "target outside valley " .. all[i][3])
	for j = i + 1, #all do
		local d = math.sqrt((all[i][1] - all[j][1]) ^ 2 + (all[i][2] - all[j][2]) ^ 2)
		check(d >= 3.5, ("targets too close: %s / %s (%.1f)"):format(all[i][3], all[j][3], d))
	end
end
-- no target on the pond or inside the pit bowl
for _, t in WorldData.Targets do
	if t.id ~= "capsule_sparkfin" then
		check(math.sqrt((t.x - WorldData.POND.x) ^ 2 + (t.z - WorldData.POND.z) ^ 2) > WorldData.POND.r + 1, t.id .. " in pond")
	end
end
-- the terrain must be walkable around key sites (slope between neighbours)
local function slope(x, z)
	local h0 = WorldData.heightAt(x, z)
	local m = 0
	for _, d in { { 2, 0 }, { 0, 2 }, { -2, 0 }, { 0, -2 } } do
		m = math.max(m, math.abs(WorldData.heightAt(x + d[1], z + d[2]) - h0) / 2)
	end
	return m
end
for _, s in WorldData.Stations do check(slope(s.x, s.z) < 0.25, "station site too steep " .. s.id) end
check(slope(WorldData.SPAWN.x, WorldData.SPAWN.z) < 0.25, "spawn too steep")
check(WorldData.heightAt(0, 55) > WorldData.WATER_LEVEL + 1, "plaza underwater")
check(WorldData.heightAt(0, 118) > WorldData.WATER_LEVEL + 1, "spawn underwater")
for _, t in WorldData.Targets do
	if t.id ~= "capsule_sparkfin" then check(WorldData.heightAt(t.x, t.z) > WorldData.WATER_LEVEL + 0.3, t.id .. " underwater") end
	check(slope(t.x, t.z) < 0.9, ("%s on a steep slope (%.2f)"):format(t.id, slope(t.x, t.z)))
end
for _, s in WorldData.Secrets do check(WorldData.heightAt(s.x, s.z) > WorldData.WATER_LEVEL, s.id .. " underwater") end
-- boundary: terrain ring is a real wall at the edge, gateway corridor stays open
check(WorldData.heightAt(140, 0) > 25 and WorldData.heightAt(-140, 30) > 25 and WorldData.heightAt(30, 140) > 25, "cliff ring too low")
check(WorldData.heightAt(0, -140) < 12, "gateway corridor blocked by terrain")

-- starting corruption share ~60-70%
local share = WorldData.corruptedShare()
print(("targets=%d decor=%d corrupted share=%.1f%%"):format(#WorldData.Targets, #WorldData.Decor, share * 100))
check(share >= 0.60 and share <= 0.70, "corrupted share out of 60-70%")

-- gateway cannot be opened without ruins (needs tier-3 absorber): weight of non-ruin targets < 75%
local nonRuin, total = 0, 0
for _, t in WorldData.Targets do
	local w = Config.Targets[t.type].weight or 0
	total += w
	if t.type ~= "ruin" then nonRuin += w end
end
print(("area weight total=%d, without ruins max=%.1f%%"):format(total, nonRuin / total * 100))
check(nonRuin / total * 100 < 75, "75% reachable without ruins")
-- minTier of every permanent weight bearing target reachable: crystals need tier 2, ruins tier 3
check(Config.Targets.ruin.minTier == 3 and Config.Targets.crystal.minTier == 2, "tier gating changed")

-- time-to-restore at the tier that unlocks each type must be reasonable (3s..60s)
for id, t in Config.Targets do
	local ab = Config.Absorber[t.minTier]
	local secs = t.hp / (ab.power * ab.speed)
	check(secs >= 2 and secs <= 62, ("%s takes %.1fs at its minimum tier"):format(id, secs))
end

print(fails == 0 and "config_test: PASS" or ("config_test: " .. fails .. " FAILURES"))
if fails > 0 then error("failed") end
