-- The four interactive stations around the Restoration Plaza + the plaza paving and the tutorial path.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local WorldData = require(Shared.WorldData)
local Build = require(script.Parent.Build)

local StationBuilder = {}

local Mat = Enum.Material
local C = Config.Colors
local STONE = Color3.fromRGB(176, 164, 144)

local function spin(p: BasePart, speed: number)
	p:SetAttribute("Spin", speed)
end

local function sellStation(parent: Instance, cf: CFrame)
	local m = Build.model(parent, "RestorationStation")
	Build.cyl(m, 0.6, 10, cf * CFrame.new(0, 0.3, 0), STONE, Mat.Slate, { solid = true })
	local body = Build.box(m, Vector3.new(4.4, 3.6, 3.2), cf * CFrame.new(0, 2.4, 0), Color3.fromRGB(70, 150, 160), Mat.Metal, { solid = true })
	Build.cyl(m, 1.2, 3.6, cf * CFrame.new(0, 4.8, 0), Color3.fromRGB(60, 120, 130), Mat.Metal)
	Build.cyl(m, 0.9, 2.4, cf * CFrame.new(0, 5.6, 0), Color3.fromRGB(26, 22, 40), Mat.SmoothPlastic)
	spin(Build.cyl(m, 0.2, 4.8, cf * CFrame.new(0, 4.3, 0), C.glitchCyan, Mat.Neon, { transparency = 0.15 }), 1.2)
	Build.box(m, Vector3.new(2.6, 1.2, 0.15), cf * CFrame.new(0, 2.8, -1.65), C.glitchCyan, Mat.Neon)
	Build.box(m, Vector3.new(0.5, 3.0, 0.5), cf * CFrame.new(-2.9, 2.1, 1.4), STONE, Mat.Slate, { solid = true })
	Build.box(m, Vector3.new(0.5, 3.0, 0.5), cf * CFrame.new(2.9, 2.1, 1.4), STONE, Mat.Slate, { solid = true })
	local orb = Build.ball(m, 1.2, cf * CFrame.new(0, 7.4, 0), C.glitchCyan, Mat.Neon)
	orb:SetAttribute("Bob", 0.4)
	Build.glow(orb, C.glitchCyan, 18, 1.2)
	Build.prompt(body, "sell", "Restoration Station", "Convert Fragments", 12)
	Build.label(body, "RESTORATION STATION", 4.6, 90)
end

local function upgradeStation(parent: Instance, cf: CFrame)
	local m = Build.model(parent, "UpgradeStation")
	Build.cyl(m, 0.6, 10, cf * CFrame.new(0, 0.3, 0), STONE, Mat.Slate, { solid = true })
	local bench = Build.box(m, Vector3.new(6.4, 0.5, 2.8), cf * CFrame.new(0, 2.6, 0), Color3.fromRGB(150, 108, 70), Mat.Wood, { solid = true })
	for _, x in { -2.8, 2.8 } do
		for _, z in { -1.1, 1.1 } do
			Build.box(m, Vector3.new(0.5, 2.4, 0.5), cf * CFrame.new(x, 1.3, z), Color3.fromRGB(110, 78, 50), Mat.Wood, { solid = true })
		end
	end
	Build.box(m, Vector3.new(6.4, 2.6, 0.4), cf * CFrame.new(0, 4.1, 1.5), Color3.fromRGB(110, 78, 50), Mat.Wood, { solid = true })
	local tube = Build.part(m, { size = Vector3.new(3.4, 0.5, 0.5), cf = cf * CFrame.new(0, 3.5, 0) * CFrame.Angles(0, 0.3, 0), color = Color3.fromRGB(255, 160, 50), material = Mat.Neon })
	tube:SetAttribute("Bob", 0.15)
	Build.ball(m, 0.9, cf * CFrame.new(1.7, 3.5, 0.5), Color3.fromRGB(255, 220, 120), Mat.Neon)
	Build.box(m, Vector3.new(1.4, 0.9, 0.9), cf * CFrame.new(-2.2, 3.15, 0), Color3.fromRGB(90, 90, 100), Mat.Metal)
	Build.glow(tube, Color3.fromRGB(255, 170, 70), 16, 1.0)
	Build.prompt(bench, "menu:equipment", "Upgrade Station", "Open Upgrades", 12)
	Build.label(bench, "UPGRADE STATION", 4.8, 90)
end

local function researchTerminal(parent: Instance, cf: CFrame)
	local m = Build.model(parent, "ResearchTerminal")
	Build.cyl(m, 0.5, 7, cf * CFrame.new(0, 0.25, 0), STONE, Mat.Slate, { solid = true })
	local ped = Build.cyl(m, 3.2, 2.4, cf * CFrame.new(0, 2.1, 0), Color3.fromRGB(60, 52, 90), Mat.Metal, { solid = true })
	Build.box(m, Vector3.new(3.4, 2.2, 0.25), cf * CFrame.new(0, 4.3, 0) * CFrame.Angles(math.rad(-20), 0, 0), C.glitchPurple, Mat.Neon, { transparency = 0.1 })
	local cube = Build.box(m, Vector3.new(1, 1, 1), cf * CFrame.new(0, 6.3, 0) * CFrame.Angles(0.7, 0.7, 0), C.glitchCyan, Mat.Neon)
	cube:SetAttribute("Bob", 0.35)
	spin(cube, 1.4)
	Build.glow(cube, C.glitchPurple, 16, 1.0)
	Build.prompt(ped, "menu:research", "Research Terminal", "Open Research", 12)
	Build.label(ped, "RESEARCH TERMINAL", 5.6, 90)
end

local function echoShrine(parent: Instance, cf: CFrame)
	local m = Build.model(parent, "EchoShrine")
	Build.cyl(m, 0.5, 10.5, cf * CFrame.new(0, 0.25, 0), STONE, Mat.Slate, { solid = true })
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		Build.box(m, Vector3.new(0.9, 3.4, 0.9), cf * CFrame.new(math.cos(a) * 4.4, 2.2, math.sin(a) * 4.4), Color3.fromRGB(190, 180, 160), Mat.Slate, { solid = true })
		Build.ball(m, 0.5, cf * CFrame.new(math.cos(a) * 4.4, 4.2, math.sin(a) * 4.4), C.glitchCyan, Mat.Neon)
	end
	local altar = Build.cyl(m, 1.4, 2.2, cf * CFrame.new(0, 1.2, 0), Color3.fromRGB(150, 140, 125), Mat.Slate, { solid = true })
	local crystal = Build.box(m, Vector3.new(1.3, 2.4, 1.3), cf * CFrame.new(0, 3.6, 0) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(255, 140, 230), Mat.Glass)
	crystal:SetAttribute("Bob", 0.3)
	spin(crystal, 0.8)
	Build.glow(crystal, Color3.fromRGB(255, 150, 230), 16, 1.2)
	Build.prompt(altar, "menu:echo", "Echo Index Shrine", "Open Echo Index", 12)
	Build.label(altar, "ECHO INDEX SHRINE", 5.2, 90)
end

function StationBuilder.build(parent: Instance)
	local folder = Build.model(parent, "Stations")
	-- plaza paving: two stacked discs, buried slightly so the rim blends with the terrain
	local pc = WorldData.Stations
	local gy = Build.groundY(0, 55)
	Build.cyl(folder, 0.7, 46, CFrame.new(0, gy - 0.1, 55), Color3.fromRGB(158, 146, 128), Mat.Slate, { solid = true, name = "PlazaOuter" })
	Build.cyl(folder, 0.8, 32, CFrame.new(0, gy - 0.05, 55), Color3.fromRGB(190, 178, 154), Mat.Slate, { solid = true, name = "PlazaInner" })
	local builders = { sell = sellStation, upgrade = upgradeStation, research = researchTerminal, echo = echoShrine }
	for id, build in builders do
		local s = pc[id]
		local sy = Build.groundY(s.x, s.z)
		-- face the plaza centre (the model's front, -Z, points toward +Z of the plaza after lookAt)
		local cf = CFrame.lookAt(Vector3.new(s.x, sy, s.z), Vector3.new(0, sy, 70))
		build(folder, cf)
	end
	-- tutorial path: stepping stones from the spawn glade to the plaza
	local stones = Build.model(parent, "Path")
	local z = WorldData.SPAWN.z - 8
	local i = 0
	while z > 70 do
		i += 1
		local x = math.sin(i * 1.7) * 0.6
		local y = Build.groundY(x, z)
		Build.cyl(stones, 0.3, 2.8, CFrame.new(x, y - 0.05, z), Color3.fromRGB(190, 170, 140), Mat.Slate, { solid = true })
		z -= 4.6
	end
end

return StationBuilder
