-- Builds every restorable target as a Model with two visual states:
--   Model "T_<id>"  (attributes TargetId, TypeId)
--     Root       invisible anchored part on the ground (range / distance reference)
--     Shared     parts that look the same in both states (ruin slab)
--     Corrupted  the glitched look           (client hides it once the target is restored for that player)
--     Restored   the healed look             (client hides it while the target is corrupted)
-- Per-player state is applied by the client (TargetVisuals), so one shared world serves players at different
-- stages of progress. Parts are authored relative to the ground point so everything sits on the terrain.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local EchoModel = require(Shared.EchoModel)
local Build = require(script.Parent.Build)

local TargetBuilder = {}

local Mat = Enum.Material
local C = Config.Colors
local PURPLE, CYAN = C.glitchPurple, C.glitchCyan

local function seedOf(id: string): number
	local h = 17
	for i = 1, #id do
		h = (h * 31 + string.byte(id, i)) % 2147483647
	end
	return h
end

local function echoConfig(id: string): any?
	for _, e in Config.Echoes do
		if e.id == id then
			return e
		end
	end
	return nil
end

type Ctx = { corrupted: Model, restored: Model, shared: Model, root: CFrame, rand: Random, id: string, echo: any? }

local function pick(rand: Random, a: number, b: number): number
	return a + rand:NextNumber() * (b - a)
end

local function green(rand: Random, base: Color3?): Color3
	local b = base or Color3.fromRGB(86, 190, 80)
	local k = pick(rand, 0.85, 1.15)
	return Color3.new(math.clamp(b.R * k, 0, 1), math.clamp(b.G * k, 0, 1), math.clamp(b.B * k, 0, 1))
end

-- neon ground disc marking corrupted ground
local function pool(ctx: Ctx, radius: number)
	Build.cyl(ctx.corrupted, 0.12, radius * 2, ctx.root * CFrame.new(0, 0.1, 0), PURPLE, Mat.Neon, { transparency = 0.6 })
end

-- floating glitch cube; the client bobs/spins parts that carry these attributes
local function bit(ctx: Ctx, offset: Vector3, size: number, color: Color3?)
	local p = Build.box(ctx.corrupted, Vector3.new(size, size, size), ctx.root * CFrame.new(offset) * CFrame.Angles(pick(ctx.rand, 0, 3), pick(ctx.rand, 0, 3), pick(ctx.rand, 0, 3)), color or (if ctx.rand:NextNumber() > 0.5 then PURPLE else CYAN), Mat.Neon)
	p:SetAttribute("Bob", 0.4)
	p:SetAttribute("Spin", 1.5)
	return p
end

-- a box that starts at `base` and extends `len` along a direction given by yaw / tilt (pivot at the base)
local function limb(parent: Instance, root: CFrame, base: Vector3, yaw: number, tilt: number, len: number, thick: number, color: Color3, material: Enum.Material?, extra: any?)
	local cf = root * CFrame.new(base) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, -tilt) * CFrame.new(0, len / 2, 0)
	return Build.box(parent, Vector3.new(thick, len, thick), cf, color, material, extra)
end

local B = {}

function B.grass(ctx: Ctx)
	local r = ctx.rand
	pool(ctx, 3)
	for _ = 1, 7 do
		limb(ctx.corrupted, ctx.root, Vector3.new(pick(r, -2, 2), 0, pick(r, -2, 2)), pick(r, 0, 6.28), pick(r, 0.2, 0.7), pick(r, 1.0, 1.9), 0.22, C.corruptGrey, Mat.Slate)
	end
	for i = 1, 3 do
		local p = Build.box(ctx.corrupted, Vector3.new(0.3, 0.9, 0.3), ctx.root * CFrame.new(pick(r, -1.6, 1.6), 1.9 + i * 0.2, pick(r, -1.6, 1.6)) * CFrame.Angles(0.4 * i, 0.7, 0.3), if i % 2 == 0 then PURPLE else CYAN, Mat.Neon)
		p:SetAttribute("Bob", 0.3)
	end
	for _ = 1, 14 do
		limb(ctx.restored, ctx.root, Vector3.new(pick(r, -2.2, 2.2), 0, pick(r, -2.2, 2.2)), pick(r, 0, 6.28), pick(r, 0.0, 0.35), pick(r, 1.2, 2.2), 0.2, green(r), Mat.Grass)
	end
	local petal = { Color3.fromRGB(255, 120, 150), Color3.fromRGB(255, 220, 90), Color3.fromRGB(190, 150, 255) }
	for i = 1, 3 do
		local x, z = pick(r, -1.6, 1.6), pick(r, -1.6, 1.6)
		limb(ctx.restored, ctx.root, Vector3.new(x, 0, z), 0, 0, 1.3, 0.12, green(r), Mat.Grass)
		Build.ball(ctx.restored, 0.55, ctx.root * CFrame.new(x, 1.4, z), petal[i], Mat.SmoothPlastic)
	end
end

function B.bush(ctx: Ctx)
	local r = ctx.rand
	pool(ctx, 3.4)
	Build.ball(ctx.corrupted, 3.2, ctx.root * CFrame.new(0, 1.3, 0), C.corruptDark, Mat.Slate)
	for i = 1, 6 do
		limb(ctx.corrupted, ctx.root, Vector3.new(math.cos(i) * 0.9, 1.4, math.sin(i) * 0.9), i * 1.05, 0.9, pick(r, 1.2, 1.9), 0.3, if i % 2 == 0 then PURPLE else CYAN, Mat.Neon)
	end
	Build.ball(ctx.restored, 3.0, ctx.root * CFrame.new(0, 1.3, 0), green(r), Mat.Grass)
	Build.ball(ctx.restored, 2.2, ctx.root * CFrame.new(1.3, 1.0, 0.6), green(r), Mat.Grass)
	Build.ball(ctx.restored, 2.0, ctx.root * CFrame.new(-1.2, 0.95, -0.7), green(r), Mat.Grass)
	for i = 1, 6 do
		local a = i * 1.1
		Build.ball(ctx.restored, 0.34, ctx.root * CFrame.new(math.cos(a) * 1.5, 1.2 + (i % 3) * 0.35, math.sin(a) * 1.5), Color3.fromRGB(230, 60, 80), Mat.SmoothPlastic)
	end
end

function B.tree(ctx: Ctx)
	local r = ctx.rand
	pool(ctx, 4.2)
	-- corrupted: bare, cracked trunk with angular branches
	Build.cyl(ctx.corrupted, 7, 1.6, ctx.root * CFrame.new(0, 3.5, 0), C.corruptDark, Mat.Slate, { solid = true })
	for i = 1, 3 do
		local a = i * 2.1
		Build.box(ctx.corrupted, Vector3.new(0.14, 2.6, 0.05), ctx.root * CFrame.new(math.cos(a) * 0.82, 2.6 + i * 0.5, math.sin(a) * 0.82) * CFrame.Angles(0, -a + math.pi / 2, 0), PURPLE, Mat.Neon)
	end
	for i = 1, 3 do
		limb(ctx.corrupted, ctx.root, Vector3.new(0, 6.4, 0), i * 2.1 + pick(r, 0, 0.5), pick(r, 0.9, 1.2), pick(r, 2.6, 3.6), 0.4, C.corruptDark, Mat.Slate)
	end
	for _ = 1, 4 do
		bit(ctx, Vector3.new(pick(r, -3, 3), pick(r, 6, 9.5), pick(r, -3, 3)), pick(r, 0.5, 0.9))
	end
	-- restored: healthy trunk + canopy overlapping the trunk top
	Build.cyl(ctx.restored, 7, 1.8, ctx.root * CFrame.new(0, 3.5, 0), Color3.fromRGB(112, 80, 52), Mat.Wood, { solid = true })
	Build.cyl(ctx.restored, 0.8, 2.8, ctx.root * CFrame.new(0, 0.4, 0), Color3.fromRGB(104, 74, 48), Mat.Wood)
	Build.ball(ctx.restored, 7.4, ctx.root * CFrame.new(0, 9.3, 0), green(r), Mat.Grass)
	Build.ball(ctx.restored, 5.0, ctx.root * CFrame.new(2.4, 8.2, 1.0), green(r), Mat.Grass)
	Build.ball(ctx.restored, 4.8, ctx.root * CFrame.new(-2.3, 8.0, -1.2), green(r), Mat.Grass)
	Build.ball(ctx.restored, 4.4, ctx.root * CFrame.new(0.4, 8.4, -2.5), green(r), Mat.Grass)
end

local function crystalCluster(parent: Instance, ctx: Ctx, cols: { Color3 }, glassMat: Enum.Material, core: Color3?)
	local r = ctx.rand
	local specs = { { 0, 0, 7.0, 1.9, 0.1 }, { 1.7, 0.8, 4.4, 1.4, 0.35 }, { -1.6, -0.9, 5.0, 1.5, -0.3 }, { 0.5, -2.0, 3.2, 1.1, 0.5 } }
	for i, s in specs do
		local col = cols[(i - 1) % #cols + 1]
		local base = Vector3.new(s[1], 0, s[2])
		local main = limb(parent, ctx.root, base, i * 1.7, s[5], s[3], s[4], col, glassMat, { solid = i == 1 })
		main.CFrame = main.CFrame * CFrame.Angles(0, math.rad(45), 0)
		-- pointed tip: a rotated cube sitting on the top of the shaft
		local tip = ctx.root * CFrame.new(base) * CFrame.Angles(0, i * 1.7, 0) * CFrame.Angles(0, 0, -s[5]) * CFrame.new(0, s[3] + s[4] * 0.25, 0) * CFrame.Angles(math.rad(45), math.rad(45), 0)
		Build.box(parent, Vector3.new(s[4], s[4], s[4]) * 0.8, tip, col, glassMat)
		if core then
			limb(parent, ctx.root, base, i * 1.7, s[5], s[3] * 0.9, 0.35, core, Mat.Neon)
		end
	end
	return r
end

function B.crystal(ctx: Ctx)
	pool(ctx, 4.4)
	crystalCluster(ctx.corrupted, ctx, { Color3.fromRGB(34, 30, 56), Color3.fromRGB(46, 38, 74) }, Mat.Glass, PURPLE)
	local sp = Build.part(ctx.corrupted, { size = Vector3.new(1, 1, 1), cf = ctx.root * CFrame.new(0, 4, 0), transparency = 1 })
	Build.sparkle(sp, PURPLE, 4)
	crystalCluster(ctx.restored, ctx, { Color3.fromRGB(90, 225, 255), Color3.fromRGB(255, 140, 230) }, Mat.Glass, Color3.fromRGB(200, 250, 255))
	local lightPart = Build.part(ctx.restored, { size = Vector3.new(1, 1, 1), cf = ctx.root * CFrame.new(0, 3.5, 0), transparency = 1 })
	Build.glow(lightPart, Color3.fromRGB(120, 230, 255), 16, 1.2)
end

function B.ruin(ctx: Ctx)
	local r = ctx.rand
	local slab = Build.box(ctx.shared, Vector3.new(15, 0.8, 15), ctx.root * CFrame.new(0, 0, 0), Color3.fromRGB(150, 140, 125), Mat.Slate, { solid = true })
	slab.Name = "Slab"
	local px = { { -5, -5 }, { 5, -5 }, { -5, 5 }, { 5, 5 } }
	-- corrupted: broken, tilted pillars, floating rubble, glitch core
	pool(ctx, 8)
	for i, p in px do
		local h = pick(r, 3.0, 5.5)
		local pil = limb(ctx.corrupted, ctx.root, Vector3.new(p[1], 0.2, p[2]), i, pick(r, 0.1, 0.3) * (if i % 2 == 0 then 1 else -1), h, 2.0, C.corruptGrey, Mat.Slate, { solid = true })
		pil.Name = "Pillar"
		Build.box(ctx.corrupted, Vector3.new(0.14, h * 0.7, 0.5), pil.CFrame * CFrame.new(1.02, 0, 0), PURPLE, Mat.Neon)
	end
	for _ = 1, 7 do
		bit(ctx, Vector3.new(pick(r, -6, 6), pick(r, 4, 9), pick(r, -6, 6)), pick(r, 0.6, 1.4), nil)
	end
	local core = Build.ball(ctx.corrupted, 2.2, ctx.root * CFrame.new(0, 3.2, 0), PURPLE, Mat.Neon, { transparency = 0.2 })
	core:SetAttribute("Bob", 0.5)
	Build.sparkle(core, CYAN, 6, 0.5)
	-- restored: exact square of pillars, lintels resting on the pillar tops, mossy, with glowing runes
	for _, p in px do
		Build.box(ctx.restored, Vector3.new(2.0, 8.0, 2.0), ctx.root * CFrame.new(p[1], 4.2, p[2]), Color3.fromRGB(176, 164, 140), Mat.Slate, { solid = true })
		Build.box(ctx.restored, Vector3.new(0.12, 3.0, 0.6), ctx.root * CFrame.new(p[1] + (if p[1] < 0 then 1.03 else -1.03), 4.5, p[2]), CYAN, Mat.Neon)
		Build.box(ctx.restored, Vector3.new(2.2, 0.35, 2.2), ctx.root * CFrame.new(p[1], 0.58, p[2]), Color3.fromRGB(110, 96, 80), Mat.Slate)
	end
	for _, z in { -5, 5 } do
		Build.box(ctx.restored, Vector3.new(12, 1.5, 2.6), ctx.root * CFrame.new(0, 8.95, z), Color3.fromRGB(190, 176, 150), Mat.Slate)
		Build.box(ctx.restored, Vector3.new(9, 0.3, 2.2), ctx.root * CFrame.new(-0.5, 9.85, z), green(r), Mat.Grass)
	end
	local orb = Build.ball(ctx.restored, 1.5, ctx.root * CFrame.new(0, 3.6, 0), CYAN, Mat.Neon)
	orb:SetAttribute("Bob", 0.35)
	Build.glow(orb, CYAN, 20, 1.4)
	Build.cyl(ctx.restored, 0.3, 3.2, ctx.root * CFrame.new(0, 0.62, 0), Color3.fromRGB(110, 96, 80), Mat.Slate)
end

function B.capsule(ctx: Ctx)
	local posts = { { -2.2, -2.2 }, { 2.2, -2.2 }, { -2.2, 2.2 }, { 2.2, 2.2 } }
	local barColor = CYAN
	for _, p in posts do
		Build.box(ctx.corrupted, Vector3.new(0.38, 5.2, 0.38), ctx.root * CFrame.new(p[1], 2.9, p[2]), PURPLE, Mat.Neon)
	end
	for _, y in { 0.35, 5.45 } do
		for _, z in { -2.2, 2.2 } do
			Build.box(ctx.corrupted, Vector3.new(4.78, 0.38, 0.38), ctx.root * CFrame.new(0, y, z), barColor, Mat.Neon)
		end
		for _, x in { -2.2, 2.2 } do
			Build.box(ctx.corrupted, Vector3.new(0.38, 0.38, 4.78), ctx.root * CFrame.new(x, y, 0), barColor, Mat.Neon)
		end
	end
	Build.box(ctx.corrupted, Vector3.new(4.2, 5.0, 4.2), ctx.root * CFrame.new(0, 2.9, 0), PURPLE, Mat.Glass, { transparency = 0.78 })
	pool(ctx, 4)
	if ctx.echo then
		local m = EchoModel.build(ctx.echo.look, ctx.corrupted)
		m:ScaleTo(1.2)
		m:PivotTo(ctx.root * CFrame.new(0, 2.9, 0))
		local body = m:FindFirstChild("Body")
		if body then
			body:SetAttribute("Bob", 0.3)
			Build.sparkle(body :: BasePart, CYAN, 5, 0.3)
		end
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d:SetAttribute("EchoPart", true)
			end
		end
	end
	-- restored: the empty pad and the cage bars lying on the ground
	Build.cyl(ctx.restored, 0.25, 5.6, ctx.root * CFrame.new(0, 0.12, 0), CYAN, Mat.Neon, { transparency = 0.2 })
	for i = 1, 4 do
		Build.box(ctx.restored, Vector3.new(0.34, 0.34, 2.6), ctx.root * CFrame.new(math.cos(i * 1.6) * 3.4, 0.2, math.sin(i * 1.6) * 3.4) * CFrame.Angles(0, i * 1.1, 0), Color3.fromRGB(110, 90, 160), Mat.SmoothPlastic)
	end
	local glow = Build.ball(ctx.restored, 1.1, ctx.root * CFrame.new(0, 1.4, 0), Color3.fromRGB(255, 255, 255), Mat.Neon, { transparency = 0.5 })
	glow:SetAttribute("Bob", 0.3)
end

function B.anomaly(ctx: Ctx)
	local r = ctx.rand
	pool(ctx, 4.5)
	local ob = Build.box(ctx.corrupted, Vector3.new(2.2, 11, 2.2), ctx.root * CFrame.new(0, 5.4, 0) * CFrame.Angles(0.08, 0.4, 0.06), Color3.fromRGB(26, 22, 44), Mat.Slate, { solid = true })
	Build.box(ctx.corrupted, Vector3.new(0.16, 8, 0.6), ob.CFrame * CFrame.new(1.12, 0, 0), PURPLE, Mat.Neon)
	Build.box(ctx.corrupted, Vector3.new(0.6, 8, 0.16), ob.CFrame * CFrame.new(0, 0, 1.12), CYAN, Mat.Neon)
	local ring = Build.cyl(ctx.corrupted, 0.3, 6, ctx.root * CFrame.new(0, 7.5, 0), PURPLE, Mat.Neon, { transparency = 0.2 })
	ring:SetAttribute("Bob", 0.4)
	ring:SetAttribute("Spin", 1.0)
	for _ = 1, 5 do
		bit(ctx, Vector3.new(pick(r, -3, 3), pick(r, 3, 10), pick(r, -3, 3)), pick(r, 0.5, 1.0))
	end
	Build.sparkle(ring, CYAN, 6, 0.45)
	local gold = Color3.fromRGB(255, 205, 80)
	Build.box(ctx.restored, Vector3.new(2.2, 11, 2.2), ctx.root * CFrame.new(0, 5.5, 0), gold, Mat.Metal, { solid = true })
	Build.box(ctx.restored, Vector3.new(0.16, 8, 0.6), ctx.root * CFrame.new(1.12, 5.5, 0), Color3.fromRGB(255, 250, 200), Mat.Neon)
	Build.box(ctx.restored, Vector3.new(1.4, 1.4, 1.4), ctx.root * CFrame.new(0, 11.6, 0) * CFrame.Angles(math.rad(45), math.rad(45), 0), Color3.fromRGB(255, 250, 200), Mat.Neon)
	local rg = Build.cyl(ctx.restored, 0.25, 6, ctx.root * CFrame.new(0, 7.5, 0), CYAN, Mat.Neon, { transparency = 0.3 })
	rg:SetAttribute("Spin", 0.8)
	Build.glow(rg, gold, 22, 1.5)
end

function B.bloom(ctx: Ctx)
	pool(ctx, 2.8)
	Build.cyl(ctx.shared, 0.9, 1.6, ctx.root * CFrame.new(0, 0.45, 0), Color3.fromRGB(58, 52, 74), Mat.Slate)
	local orb = Build.ball(ctx.corrupted, 2.4, ctx.root * CFrame.new(0, 2.5, 0), PURPLE, Mat.Neon, { transparency = 0.1 })
	orb:SetAttribute("Bob", 0.35)
	for i = 1, 3 do
		local a = i * 2.09
		local s = Build.ball(ctx.corrupted, 0.7, ctx.root * CFrame.new(math.cos(a) * 1.8, 2.6 + i * 0.2, math.sin(a) * 1.8), CYAN, Mat.Neon)
		s:SetAttribute("Bob", 0.5)
	end
	Build.sparkle(orb, CYAN, 5, 0.3)
	limb(ctx.restored, ctx.root, Vector3.new(0, 0.9, 0), 0, 0, 1.1, 0.14, Color3.fromRGB(110, 190, 90), Mat.Grass)
	limb(ctx.restored, ctx.root, Vector3.new(0, 1.7, 0), 0.5, 1.0, 0.7, 0.34, Color3.fromRGB(110, 190, 90), Mat.Grass)
	limb(ctx.restored, ctx.root, Vector3.new(0, 1.7, 0), 3.6, 1.0, 0.7, 0.34, Color3.fromRGB(110, 190, 90), Mat.Grass)
end

function B.prism_vein(ctx: Ctx)
	local r = ctx.rand
	pool(ctx, 3)
	local cols = { CYAN, PURPLE, CYAN, PURPLE }
	for i = 1, 4 do
		local c = limb(ctx.corrupted, ctx.root, Vector3.new(math.cos(i * 1.6) * 0.9, 0, math.sin(i * 1.6) * 0.9), i * 1.3, pick(r, 0.1, 0.45), pick(r, 3.4, 5), 1.2, cols[i], Mat.Neon, { transparency = 0.12 })
		c.CFrame = c.CFrame * CFrame.Angles(0, math.rad(45), 0)
		limb(ctx.restored, ctx.root, Vector3.new(math.cos(i * 1.6) * 0.9, 0, math.sin(i * 1.6) * 0.9), i * 1.3, pick(r, 0.1, 0.4), pick(r, 0.5, 1.0), 1.1, Color3.fromRGB(90, 86, 108), Mat.Slate)
	end
	local sp = Build.part(ctx.corrupted, { size = Vector3.new(1, 1, 1), cf = ctx.root * CFrame.new(0, 3, 0), transparency = 1 })
	Build.sparkle(sp, CYAN, 4, 0.3)
end

function B.surge_node(ctx: Ctx)
	pool(ctx, 3.6)
	Build.cyl(ctx.shared, 6, 1.3, ctx.root * CFrame.new(0, 3, 0), Color3.fromRGB(52, 48, 70), Mat.Metal, { solid = true })
	local orb = Build.ball(ctx.corrupted, 2.1, ctx.root * CFrame.new(0, 7, 0), CYAN, Mat.Neon)
	orb:SetAttribute("Bob", 0.4)
	for i, y in { 4.0, 5.2 } do
		local ring = Build.cyl(ctx.corrupted, 0.2, 3.6 + i * 0.5, ctx.root * CFrame.new(0, y, 0), PURPLE, Mat.Neon, { transparency = 0.15 })
		ring:SetAttribute("Spin", if i == 1 then 1.6 else -1.2)
	end
	Build.sparkle(orb, PURPLE, 6, 0.4)
	Build.ball(ctx.restored, 1.0, ctx.root * CFrame.new(0, 6.6, 0), Color3.fromRGB(70, 66, 92), Mat.Slate)
end

function B.rift_core(ctx: Ctx)
	local r = ctx.rand
	pool(ctx, 6)
	Build.cyl(ctx.shared, 0.5, 8, ctx.root * CFrame.new(0, 0.25, 0), Color3.fromRGB(48, 42, 66), Mat.Slate)
	local big = Build.box(ctx.corrupted, Vector3.new(4.2, 4.2, 4.2), ctx.root * CFrame.new(0, 6.5, 0) * CFrame.Angles(math.rad(45), math.rad(45), 0), PURPLE, Mat.Neon, { transparency = 0.15 })
	big:SetAttribute("Bob", 0.5)
	big:SetAttribute("Spin", 0.9)
	local inner = Build.box(ctx.corrupted, Vector3.new(2, 2, 2), ctx.root * CFrame.new(0, 6.5, 0), CYAN, Mat.Neon)
	inner:SetAttribute("Spin", -1.8)
	for i = 1, 4 do
		local a = i * 1.57
		local s = Build.box(ctx.corrupted, Vector3.new(1, 1, 1), ctx.root * CFrame.new(math.cos(a) * 4.2, 6 + pick(r, -0.5, 1), math.sin(a) * 4.2), CYAN, Mat.Neon)
		s:SetAttribute("Bob", 0.6)
		s:SetAttribute("Spin", 2.4)
	end
	Build.sparkle(big, CYAN, 10, 0.5)
	for i = 1, 3 do
		Build.box(ctx.restored, Vector3.new(1.4, 0.8, 1.2), ctx.root * CFrame.new(math.cos(i * 2.1) * 1.8, 0.9, math.sin(i * 2.1) * 1.8) * CFrame.Angles(0, i, 0.2), Color3.fromRGB(80, 74, 100), Mat.Slate)
	end
end

-- Builds one target model at the terrain surface. Returns the model and its Root part.
function TargetBuilder.build(placement: { id: string, type: string, x: number, z: number, ry: number, echo: string? }, parent: Instance): (Model, BasePart)
	local builder = B[placement.type]
	assert(builder, "no builder for target type " .. placement.type)
	local gy = Build.groundY(placement.x, placement.z)
	local rootCF = CFrame.new(placement.x, gy, placement.z) * CFrame.Angles(0, math.rad(placement.ry), 0)

	local model = Instance.new("Model")
	model.Name = "T_" .. placement.id
	model:SetAttribute("TargetId", placement.id)
	model:SetAttribute("TypeId", placement.type)

	local root = Build.part(model, { size = Vector3.new(1, 1, 1), cf = rootCF, transparency = 1, name = "Root" })
	model.PrimaryPart = root
	local ctx: Ctx = {
		corrupted = Build.model(model, "Corrupted"),
		restored = Build.model(model, "Restored"),
		shared = Build.model(model, "Shared"),
		root = rootCF,
		rand = Random.new(seedOf(placement.id)),
		id = placement.id,
		echo = if placement.echo then echoConfig(placement.echo) else nil,
	}
	builder(ctx)
	model.Parent = parent
	return model, root
end

return TargetBuilder
