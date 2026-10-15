-- Builds the whole world under the mock and checks structure + geometry (placement, overlaps, alignment).
local M = __M
local WorldData = require(game.ReplicatedStorage.Shared.WorldData)
local Config = require(game.ReplicatedStorage.Shared.Config)
local fails = 0
local function check(c, msg) if not c then fails += 1; print("FAIL: " .. msg) end end

M.heightFn = WorldData.heightAt
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
Remotes.create()
local WorldBuilder = require(game.ServerScriptService.Server.World.WorldBuilder)
local t0 = os.clock()
local world = WorldBuilder.build()
M.advance(5)
print(("world built: %d instances, %d voxel slabs, %d cells"):format(M.stats.instancesCreated, M.stats.voxelWrites, M.terrain.cellsWritten))
check(#M.errors == 0, "script errors: " .. table.concat(M.errors, "\n"))
check(world:GetAttribute("Ready") == true, "world not marked ready")
check(M.stats.voxelWrites == 10, "expected 10 terrain slabs")

local targets = world.Targets:GetChildren()
check(#targets == #WorldData.Targets, "target model count " .. #targets)
local function bounds(model)
	local lo, hi
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "Root" then
			local c = p.CFrame
			local s = p.Size
			-- conservative AABB from rotated half extents
			local hx = (math.abs(c.r[1]) * s.X + math.abs(c.r[2]) * s.Y + math.abs(c.r[3]) * s.Z) / 2
			local hy = (math.abs(c.r[4]) * s.X + math.abs(c.r[5]) * s.Y + math.abs(c.r[6]) * s.Z) / 2
			local hz = (math.abs(c.r[7]) * s.X + math.abs(c.r[8]) * s.Y + math.abs(c.r[9]) * s.Z) / 2
			local a, b = Vector3.new(c.X - hx, c.Y - hy, c.Z - hz), Vector3.new(c.X + hx, c.Y + hy, c.Z + hz)
			lo = lo and Vector3.new(math.min(lo.X, a.X), math.min(lo.Y, a.Y), math.min(lo.Z, a.Z)) or a
			hi = hi and Vector3.new(math.max(hi.X, b.X), math.max(hi.Y, b.Y), math.max(hi.Z, b.Z)) or b
		end
	end
	return lo, hi
end

local perType = {}
for _, m in targets do
	local id, typ = m:GetAttribute("TargetId"), m:GetAttribute("TypeId")
	check(id and typ, "target without attributes " .. m.Name)
	local root = m:FindFirstChild("Root")
	check(root and m.PrimaryPart == root, id .. " missing Root/PrimaryPart")
	local c, r = m:FindFirstChild("Corrupted"), m:FindFirstChild("Restored")
	check(c and r, id .. " missing state folders")
	local nc, nr = #c:GetDescendants(), #r:GetDescendants()
	check(nc >= 3 and nr >= 1, ("%s has too few parts C=%d R=%d"):format(id, nc, nr))
	-- sits on terrain: lowest visible part must not float above ground nor be buried deeper than 1.5 studs
	local ground = WorldData.heightAt(root.Position.X, root.Position.Z)
	check(math.abs(root.Position.Y - ground) < 0.01, id .. " root not at ground")
	for _, folder in { c, r } do
		local lo, hi = bounds(folder)
		if lo then
			check(lo.Y >= ground - 1.6, ("%s: part buried (%.2f below ground)"):format(id, ground - lo.Y))
			check(lo.Y <= ground + 2.5 or typ == "capsule" or typ == "bloom" or typ == "surge_node" or typ == "rift_core", ("%s: floats %.2f above ground"):format(id, lo.Y - ground))
		end
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			check(d.Size.X > 0 and d.Size.Y > 0 and d.Size.Z > 0, id .. " zero-size part " .. d.Name)
			check(d.CFrame.X == d.CFrame.X and d.CFrame.Y == d.CFrame.Y, id .. " NaN CFrame in " .. d.Name)
		end
	end
	perType[typ] = (perType[typ] or 0) + 1
end
for typ in Config.Targets do check((perType[typ] or 0) > 0, "no target of type " .. typ) end

-- tree: canopy overlaps the trunk top (connected), in the restored state
for _, m in targets do
	if m:GetAttribute("TypeId") == "tree" then
		local trunkTop, canopyBottom
		for _, p in m.Restored:GetChildren() do
			if p.Shape == Enum.PartType.Cylinder and p.Size.X == 7 then trunkTop = p.CFrame.Y + p.Size.X / 2 end
			if p.Shape == Enum.PartType.Ball and p.Size.X > 7 then canopyBottom = p.CFrame.Y - p.Size.X / 2 end
		end
		check(trunkTop and canopyBottom and canopyBottom < trunkTop, m.Name .. ": canopy does not overlap trunk")
	end
end
-- ruin: lintel rests exactly on pillar tops and spans both pillars
for _, m in targets do
	if m:GetAttribute("TypeId") == "ruin" then
		local pillarTops, lintels = {}, {}
		for _, p in m.Restored:GetChildren() do
			if p.Size.Y == 8 then table.insert(pillarTops, p.CFrame.Y + 4) end
			if p.Size.X == 12 and p.Size.Y == 1.5 then table.insert(lintels, p) end
		end
		check(#pillarTops == 4 and #lintels == 2, m.Name .. ": ruin restored structure incomplete")
		for _, l in lintels do
			check(math.abs((l.CFrame.Y - 0.75) - pillarTops[1]) < 1e-6, m.Name .. ": lintel not resting on pillars")
		end
	end
end

-- landmarks
local lm = world.Landmarks
check(lm:FindFirstChild("ValleySpawn") ~= nil, "no spawn")
check(lm.Gateway.Barrier:GetAttribute("GateBarrier") == true, "gate barrier missing")
local shards = 0
for _, c in lm:GetChildren() do if c.Name:sub(1, 6) == "Shard_" then shards += 1 end end
check(shards == 6, "expected 6 shards, got " .. shards)
check(#world.Decor:GetChildren() == #WorldData.Decor, "decor count")
-- every prompt carries an Action attribute and every station has one
local actions = {}
for _, d in world:GetDescendants() do
	if d:IsA("ProximityPrompt") then
		local a = d:GetAttribute("Action")
		check(type(a) == "string", "prompt without action")
		actions[a:match("^[^:]+")] = true
	end
end
for _, a in { "sell", "menu", "secret", "gate" } do check(actions[a], "missing prompt action " .. a) end
-- boundary walls exist and are solid
local walls = 0
for _, d in lm.Boundary:GetChildren() do if d.Name == "InvisibleWall" and d.CanCollide then walls += 1 end end
check(walls >= 8, "boundary walls missing: " .. walls)
-- particle emitter budget
local emitters = 0
for _, d in world:GetDescendants() do if d:IsA("ParticleEmitter") then emitters += 1 end end
print("emitters:", emitters, "parts:", #(function() local t = {} for _, d in world:GetDescendants() do if d:IsA("BasePart") then t[#t + 1] = d end end return t end)())
check(emitters <= 80, "too many particle emitters: " .. emitters)

print(fails == 0 and "world_test: PASS" or ("world_test: " .. fails .. " FAILURES"))
if fails > 0 then error("failed") end
