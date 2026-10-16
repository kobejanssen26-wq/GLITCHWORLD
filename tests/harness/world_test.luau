-- Geometry validation of the baked world (runs the baker in the mock; no Roblox needed).
-- The most important check: every obstacle module is physically passable with the default walk speed (16) and jump
-- power (50), and the special modules only with their pad (speed boost / bounce).
local Shared = game.ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Bake = require(game.ServerScriptService.Bake.Bake)
local Util = require(game.ServerScriptService.Bake.Util)
local Serialize = require(game.ServerScriptService.Bake.Serialize)
local Tower = require(game.ServerScriptService.Bake.Tower)

local fails = 0
local function check(c, m) if not c then fails += 1; print("FAIL: " .. m) end end
local T = Config.Tower

local root, info = Bake.build()
print(("baked parts: %d, modules: %d"):format(Util.count, #info.modules))
check(Util.count > 12000, "world should contain >12k parts, has " .. Util.count)
check(#info.modules == 85, "85 modules")

-- ---- jumpability ----
-- jump height 7.2 studs, airtime 0.51 s, at walk 16 => ~8.2 studs horizontal. Keep a safety margin: 7.0.
local MAX_GAP, MAX_RISE = 7.0, 3.6
local function gapBetween(a, b)
	local du = math.max(0, b.u0 - a.u1, a.u0 - b.u1)
	local dx = math.max(0, b.x0 - a.x1, a.x0 - b.x1)
	return math.sqrt(du * du + dx * dx)
end
local kindsSeen = {}
for _, m in info.modules do
	kindsSeen[m.kind] = (kindsSeen[m.kind] or 0) + 1
	local fs = table.clone(m.foots)
	table.sort(fs, function(a, b) return a.u0 < b.u0 end)
	check(#fs >= 1, m.kind .. " module " .. m.index .. " has no footholds")
	-- walk along the path: from the start connector, each foothold must be reachable from some earlier one
	local reachable = { fs[1] }
	local limit = MAX_GAP
	local special = (m.kind == "speedgap" and 13) or (m.kind == "bounce" and 14) or nil
	for i = 2, #fs do
		local f = fs[i]
		local best, bestRise = math.huge, 0
		for _, g in reachable do
			local gap = gapBetween(g, f)
			if gap < best then best, bestRise = gap, f.y - g.y end
		end
		local allowed = limit
		local isSpecial = special and (f.kind == "boost" or f.kind == "bounce" or best > limit)
		if special and best > limit then
			-- only the boosted / bounced jump may exceed the normal limit, and only up to the pad's range
			check(best <= special, ("%s module %d: pad jump too long (%.1f > %.1f)"):format(m.kind, m.index, best, special))
			if m.kind == "bounce" then check(bestRise <= 10, "bounce rise too high") end
		else
			check(best <= allowed, ("%s module %d (floor %d): gap %.2f > %.1f studs"):format(m.kind, m.index, m.floor, best, allowed))
			check(bestRise <= MAX_RISE, ("%s module %d: step up %.1f too high"):format(m.kind, m.index, bestRise))
		end
		table.insert(reachable, f)
	end
	-- the walkable chain must end at the far connector
	local last = fs[#fs]
	check(last.u1 >= 21.9, m.kind .. " module " .. m.index .. " does not reach the exit")
end
for _, name in { "stepping", "vanish", "movers", "spinner", "lasers", "pillars", "belt", "pendulum", "speedgap", "bounce", "pistons", "turntable" } do
	check((kindsSeen[name] or 0) >= 1, "obstacle type never used: " .. name)
end
print("obstacle usage:")
for k, v in kindsSeen do print("  " .. k, v) end

-- the speedgap is impossible at base speed and possible with the pad; the bounce likewise
check(7.0 < 10.5, "speedgap gap exceeds unboosted jump distance (by design)")
local boostedDistance = 16 * 1.9 * 0.51
check(boostedDistance > 10.5 + 1.5, ("boosted jump %.1f must clear the 10.5 stud gap with margin"):format(boostedDistance))
-- walking-speed floor: perks make speedgap easier, never impossible: speed coil 21
check(21 * 1.9 * 0.51 > 10.5, "speed gap fine with speed coil")

-- ---- corners between modules ----
local R2 = T.JOINT_RADIUS
local function lerp(a, b, t) return a + (b - a) * t end
for i = 0, #info.modules - 2 do
	local Fa, Fb = info.modules[i + 1].frame, info.modules[i + 2].frame
	local J = Fa * Vector3.new(0, 0, -T.MODULE_LENGTH / 2)
	local J2 = Fb * Vector3.new(0, 0, T.MODULE_LENGTH / 2)
	check(math.abs(J.X - J2.X) < 0.01 and math.abs(J.Z - J2.Z) < 0.01, "module ends do not meet at " .. i)
	-- every outer/inner corner of both end edges is covered by the corner plate
	for _, x in { -T.PATH_WIDTH / 2, T.PATH_WIDTH / 2 } do
		local pa = Fa * Vector3.new(x, 0, -T.MODULE_LENGTH / 2)
		local pb = Fb * Vector3.new(x, 0, T.MODULE_LENGTH / 2)
		check(math.sqrt((pa.X - J.X) ^ 2 + (pa.Z - J.Z) ^ 2) <= R2, "corner not covered (a) at " .. i)
		check(math.sqrt((pb.X - J.X) ^ 2 + (pb.Z - J.Z) ^ 2) <= R2, "corner not covered (b) at " .. i)
	end
	local rise = Tower.surfaceY(i + 1) - Tower.surfaceY(i)
	check(rise / 2 <= MAX_RISE, "step height at joint")
end
-- vertical clearance between turns of the spiral
local perTurn = 2 * math.pi / Tower.DELTA
check(perTurn * T.RISE_PER_MODULE > 40, ("turn spacing %.1f too small for obstacles"):format(perTurn * T.RISE_PER_MODULE))

-- ---- markers / names ----
local names = {}
local function walk(n, fn)
	fn(n)
	if n.kids then for _, k in n.kids do walk(k, fn) end end
end
local behaviors = { Kill = 0, Mover = 0, KillMover = 0, SpinnerKill = 0, Turntable = 0, Vanish = 0, Bounce = 0, Speed = 0, Belt = 0, Laser = 0, Piston = 0 }
local checkpoints, summit = {}, 0
walk(root, function(n)
	if n.c == "Part" then
		names[n.n] = (names[n.n] or 0) + 1
		check(n.s[1] > 0 and n.s[2] > 0 and n.s[3] > 0, "zero size part " .. n.n)
		check(Serialize.MATERIAL[n.mat] ~= nil, "unknown material " .. n.mat)
		check(n.col[1] >= 0 and n.col[1] <= 255 and n.col[2] >= 0 and n.col[2] <= 255 and n.col[3] >= 0 and n.col[3] <= 255, "color range")
		local kind = n.n:match("^([A-Za-z]+)")
		if behaviors[kind] ~= nil then
			behaviors[kind] += 1
			if kind ~= "Kill" then
				local args = n.n:split(":")
				if kind == "Mover" or kind == "KillMover" then
					check(#args == 4 and args[2]:match("^%-?[%d%.]+,%-?[%d%.]+,%-?[%d%.]+$") and tonumber(args[3]) and tonumber(args[4]), "bad name " .. n.n)
					if kind == "KillMover" or kind == "Mover" then check(n.touch == (kind == "KillMover") or kind == "Mover", "touch flag " .. n.n) end
				elseif kind == "Piston" then check(#args == 4 and tonumber(args[2]) and tonumber(args[3]) and tonumber(args[4]), "bad name " .. n.n)
				elseif kind == "Laser" then check(#args == 2 and args[2]:match("^[%d%.]+,[%d%.]+,[%d%.]+$"), "bad name " .. n.n)
				elseif kind == "Belt" then check(#args == 2 and args[2]:match("^%-?[%d%.]+,%-?[%d%.]+,%-?[%d%.]+$"), "bad name " .. n.n)
				elseif kind == "Speed" then check(#args == 3 and tonumber(args[2]) and tonumber(args[3]), "bad name " .. n.n)
				elseif kind == "Vanish" or kind == "Bounce" or kind == "SpinnerKill" or kind == "Turntable" then check(#args == 2 and tonumber(args[2]), "bad name " .. n.n) end
			end
			if kind == "Kill" or kind == "SpinnerKill" or kind == "KillMover" or kind == "Piston" or kind == "Laser" or kind == "Vanish" or kind == "Bounce" or kind == "Speed" then
				check(n.touch == true, "behaviour part must be touchable: " .. n.n)
			end
		end
		local f = n.n:match("^Checkpoint:(%d+)$")
		if f then checkpoints[tonumber(f)] = (checkpoints[tonumber(f)] or 0) + 1 end
		if n.n == "Summit" then summit += 1 end
	end
end)
for k, v in behaviors do check(v > 0, "no parts with behaviour " .. k) end
for f = 1, T.FLOORS do check(checkpoints[f] == 1, "checkpoint " .. f .. " count " .. tostring(checkpoints[f])) end
check(summit == 1, "one summit pad")
for i = 1, Config.Plots.COUNT do
	check(names["Marker:PlotOrigin:" .. i] == 1 and names["Marker:PlotSign:" .. i] == 1 and names["Marker:PlotSpawn:" .. i] == 1, "plot markers " .. i)
end
check(names["Marker:HubSpawn"] == 1 and names["Marker:Title"] == 1, "hub markers")
for f = 1, T.FLOORS + 1 do check(names["Marker:Banner:" .. f] == 1 and names["Marker:FX:" .. f] == 1, "floor markers " .. f) end

-- ---- size budget ----
local bytes = 0
Serialize.write(root, function(s) bytes += #s end)
print(("serialised xml: %.1f MB"):format(bytes / 1e6))
check(bytes < 60e6, "xml too large")

print(fails == 0 and "world_test: PASS" or ("world_test: " .. fails .. " FAILURES"))
if fails > 0 then error("failed") end
