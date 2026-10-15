-- Spawn pad, clue signs, hidden fragment shards, the Frostlight gateway + teaser vista, and the boundary.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local WorldData = require(Shared.WorldData)
local Build = require(script.Parent.Build)

local LandmarkBuilder = {}

local Mat = Enum.Material
local C = Config.Colors
local STONE = Color3.fromRGB(176, 164, 144)

local function signBoard(parent: Instance, x: number, z: number, ryDeg: number, text: string, name: string)
	local gy = Build.groundY(x, z)
	local cf = CFrame.new(x, gy, z) * CFrame.Angles(0, math.rad(ryDeg), 0)
	local m = Build.model(parent, name)
	Build.box(m, Vector3.new(0.4, 4.4, 0.4), cf * CFrame.new(-1.8, 2.2, 0), Color3.fromRGB(110, 78, 50), Mat.Wood, { solid = true })
	Build.box(m, Vector3.new(0.4, 4.4, 0.4), cf * CFrame.new(1.8, 2.2, 0), Color3.fromRGB(110, 78, 50), Mat.Wood, { solid = true })
	local board = Build.box(m, Vector3.new(5.6, 3.0, 0.3), cf * CFrame.new(0, 4.0, 0), Color3.fromRGB(46, 38, 70), Mat.SmoothPlastic)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.MaxDistance = 60
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamMedium
		label.TextColor3 = Color3.fromRGB(235, 250, 255)
		label.TextScaled = true
		label.Text = text
		label.Parent = gui
		local pad = Instance.new("UIPadding")
		pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 10), UDim.new(0, 10)
		pad.Parent = label
	end
	Build.box(m, Vector3.new(5.8, 0.15, 0.4), cf * CFrame.new(0, 5.55, 0), C.glitchCyan, Mat.Neon)
end

local function shard(parent: Instance, s: { id: string, x: number, z: number })
	local gy = Build.groundY(s.x, s.z)
	local cf = CFrame.new(s.x, gy + 1.8, s.z)
	local m = Build.model(parent, "Shard_" .. s.id)
	m:SetAttribute("SecretId", s.id)
	local core = Build.box(m, Vector3.new(0.7, 1.4, 0.7), cf * CFrame.Angles(0.3, 0.8, 0.2), Color3.fromRGB(255, 225, 120), Mat.Neon, { name = "Core" })
	core:SetAttribute("Bob", 0.35)
	core:SetAttribute("Spin", 1.6)
	Build.glow(core, Color3.fromRGB(255, 225, 120), 10, 1.0)
	local sp = Build.sparkle(core, Color3.fromRGB(255, 240, 160), 3, 0.25)
	sp.Name = "ShardSparkle"
	local prompt = Build.prompt(core, "secret:" .. s.id, "Hidden Fragment", "Collect", 8, 0.25)
	prompt.RequiresLineOfSight = false
end

local function spawnPad(parent: Instance)
	local sp = Instance.new("SpawnLocation")
	sp.Name = "ValleySpawn"
	sp.Anchored = true
	sp.CanCollide = true
	sp.Neutral = true
	sp.Duration = 0
	sp.Size = Vector3.new(9, 0.6, 9)
	local gy = Build.groundY(WorldData.SPAWN.x, WorldData.SPAWN.z)
	sp.CFrame = CFrame.new(WorldData.SPAWN.x, gy + 0.1, WorldData.SPAWN.z)
	sp.Material = Mat.Neon
	sp.Color = Color3.fromRGB(70, 200, 210)
	sp.Transparency = 0.35
	sp.TopSurface = Enum.SurfaceType.Smooth
	sp.Parent = parent
	Build.cyl(parent, 0.2, 12, CFrame.new(WorldData.SPAWN.x, gy + 0.05, WorldData.SPAWN.z), STONE, Mat.Slate, { solid = true })
end

local function gateway(parent: Instance)
	local G = WorldData.GATEWAY
	local gy = Build.groundY(G.x, G.z)
	local cf = CFrame.new(G.x, gy, G.z)
	local m = Build.model(parent, "Gateway")
	for _, sx in { -12.5, 12.5 } do
		Build.box(m, Vector3.new(4, 24, 4), cf * CFrame.new(sx, 12, 0), Color3.fromRGB(150, 140, 160), Mat.Slate, { solid = true })
		Build.box(m, Vector3.new(0.2, 18, 1.0), cf * CFrame.new(sx + (if sx < 0 then 2.1 else -2.1), 12, 0), C.glitchCyan, Mat.Neon)
	end
	Build.box(m, Vector3.new(29, 4, 5), cf * CFrame.new(0, 25.5, 0), Color3.fromRGB(150, 140, 160), Mat.Slate, { solid = true })
	local barrier = Build.box(m, Vector3.new(21, 22, 1.2), cf * CFrame.new(0, 11, 0), C.glitchPurple, Mat.ForceField, { solid = true, name = "Barrier" })
	barrier:SetAttribute("GateBarrier", true)
	local prompt = Build.prompt(barrier, "gate", "Frostlight Gateway", "Inspect Gateway", 14)
	prompt.RequiresLineOfSight = false
	Build.label(barrier, "FROSTLIGHT GATEWAY", 13, 120, UDim2.fromOffset(240, 36))
	-- teaser vista behind the gate: icy crystals and a notice. Nothing else exists there yet (honest placeholder).
	local vista = Build.model(parent, "FrostTeaser")
	local rand = Random.new(2024)
	for i = 1, 9 do
		local x = (rand:NextNumber() * 2 - 1) * 14
		local z = G.z - 6 - rand:NextNumber() * 16
		local y = Build.groundY(x, z)
		local h = 3 + rand:NextNumber() * 5
		Build.box(vista, Vector3.new(1.6, h, 1.6), CFrame.new(x, y + h / 2 - 0.3, z) * CFrame.Angles(rand:NextNumber() * 0.3, rand:NextNumber() * 3, rand:NextNumber() * 0.3), Color3.fromRGB(170, 225, 255), Mat.Ice, { solid = true })
	end
	signBoard(vista, 0, G.z - 22, 0, "FROSTLIGHT PEAKS\nCOMING SOON\nCold Corruption freezes the world solid.", "TeaserSign")
end

local function boundary(parent: Instance)
	local m = Build.model(parent, "Boundary")
	local W, H = WorldData.WALL, 220
	local function wall(size: Vector3, pos: Vector3)
		Build.part(m, { size = size, cf = CFrame.new(pos), transparency = 1, solid = true, name = "InvisibleWall" })
	end
	local function curtain(size: Vector3, pos: Vector3)
		Build.part(m, { size = size, cf = CFrame.new(pos), color = C.glitchPurple, material = Mat.ForceField, transparency = 0, name = "GlitchCurtain" })
	end
	wall(Vector3.new(4, H, 2 * W + 20), Vector3.new(W + 2, 0, 0))
	wall(Vector3.new(4, H, 2 * W + 20), Vector3.new(-W - 2, 0, 0))
	wall(Vector3.new(2 * W + 20, H, 4), Vector3.new(0, 0, W + 2))
	-- north wall has a gap for the gateway corridor
	wall(Vector3.new(W - 20, H, 4), Vector3.new(-(W + 20) / 2, 0, -W - 2))
	wall(Vector3.new(W - 20, H, 4), Vector3.new((W + 20) / 2, 0, -W - 2))
	-- gateway corridor: side walls and an end wall behind the teaser vista
	wall(Vector3.new(4, H, 50), Vector3.new(-22, 0, -134))
	wall(Vector3.new(4, H, 50), Vector3.new(22, 0, -134))
	wall(Vector3.new(48, H, 4), Vector3.new(0, 0, -158))
	-- visible glitch static near the edges so the limit reads as "unfinished world", not a bug
	curtain(Vector3.new(0.4, 70, 2 * W), Vector3.new(W - 6, 20, 0))
	curtain(Vector3.new(0.4, 70, 2 * W), Vector3.new(-W + 6, 20, 0))
	curtain(Vector3.new(2 * W, 70, 0.4), Vector3.new(0, 20, W - 6))
end

function LandmarkBuilder.build(parent: Instance)
	local folder = Build.model(parent, "Landmarks")
	spawnPad(folder)
	for _, s in WorldData.Signs do
		signBoard(folder, s.x, s.z, s.ry, s.text, s.id)
	end
	for _, s in WorldData.Secrets do
		shard(folder, s)
	end
	gateway(folder)
	boundary(folder)
end

return LandmarkBuilder
