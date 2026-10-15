-- Writes the valley terrain from WorldData.heightAt using voxel writes (one WriteVoxels call per 32-stud slab).
-- Occupancy is fractional at the surface so the ground is smooth instead of blocky.
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local WorldData = require(Shared.WorldData)

local TerrainBuilder = {}

local RES = 4
local MIN_X, MIN_Z = -160, -160
local MIN_Y = -20
local NX, NZ, NY = 80, 80, 21 -- 320 x 320 x 84 studs
local SLAB = 8 -- voxels (in x) per WriteVoxels call

function TerrainBuilder.build()
	local terrain = Workspace.Terrain
	terrain:Clear()
	local pond, waterLevel = WorldData.POND, WorldData.WATER_LEVEL

	for slab = 0, NX / SLAB - 1 do
		local x0 = MIN_X + slab * SLAB * RES
		local region = Region3.new(Vector3.new(x0, MIN_Y, MIN_Z), Vector3.new(x0 + SLAB * RES, MIN_Y + NY * RES, MIN_Z + NZ * RES))
		local materials, occupancies = {}, {}
		for xi = 1, SLAB do
			local mx, ox = {}, {}
			materials[xi], occupancies[xi] = mx, ox
			local cx = x0 + (xi - 1) * RES + RES / 2
			-- per-column data (height, surface material), computed once and shared by every y cell
			local colH, colMat, colWater = {}, {}, {}
			for zi = 1, NZ do
				local cz = MIN_Z + (zi - 1) * RES + RES / 2
				local h = WorldData.heightAt(cx, cz)
				local sx = math.abs(WorldData.heightAt(cx + 2, cz) - WorldData.heightAt(cx - 2, cz))
				local sz = math.abs(WorldData.heightAt(cx, cz + 2) - WorldData.heightAt(cx, cz - 2))
				local slope = (sx + sz) / 4
				local pd = math.sqrt((cx - pond.x) ^ 2 + (cz - pond.z) ^ 2)
				local mat = Enum.Material.Grass
				if slope > 1.0 or h > 16 then
					mat = Enum.Material.Rock
				elseif pd < pond.r + 4 and h < 0.6 then
					mat = Enum.Material.Sand
				end
				colH[zi], colMat[zi] = h, mat
				colWater[zi] = pd < pond.r * 1.4 and h < waterLevel
			end
			for yi = 1, NY do
				local my, oy = {}, {}
				mx[yi], ox[yi] = my, oy
				local yb = MIN_Y + (yi - 1) * RES
				for zi = 1, NZ do
					local h = colH[zi]
					local occ = math.clamp((h - yb) / RES, 0, 1)
					local mat = Enum.Material.Air
					if occ > 0 then
						mat = if h - yb < RES * 2 then colMat[zi] else Enum.Material.Ground
					end
					if colWater[zi] and occ < 0.5 and yb < waterLevel then
						mat = Enum.Material.Water
						occ = math.clamp((waterLevel - yb) / RES, 0.1, 1)
					end
					my[zi], oy[zi] = mat, occ
				end
			end
		end
		terrain:WriteVoxels(region, RES, materials, occupancies)
		task.wait()
	end

	-- default (corrupted) palette; each client lerps these locally toward the restored palette (see Ambience)
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(96, 92, 112))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(78, 70, 92))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(104, 98, 120))
	terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(176, 160, 150))
	terrain.WaterColor = Color3.fromRGB(110, 90, 190)
	terrain.WaterTransparency = 0.75
	terrain.WaterWaveSize = 0.15
	terrain.WaterWaveSpeed = 6
	terrain.WaterReflectance = 0.2
end

return TerrainBuilder
