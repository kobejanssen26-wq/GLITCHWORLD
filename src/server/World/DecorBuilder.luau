-- Already-healthy scenery (about a third of the valley starts alive so restoration visibly "spreads").
-- Decor is purely cosmetic: no remotes, no state, parts are not spatially queryable except solid trunks/rocks.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local WorldData = require(Shared.WorldData)
local Build = require(script.Parent.Build)

local DecorBuilder = {}

local Mat = Enum.Material

local function green(rand: Random): Color3
	local k = 0.85 + rand:NextNumber() * 0.3
	return Color3.new(0.34 * k, 0.75 * k, 0.31 * k)
end

local function tree(parent: Instance, cf: CFrame, s: number, rand: Random)
	local m = Build.model(parent, "Tree")
	Build.cyl(m, 6.5 * s, 1.5 * s, cf * CFrame.new(0, 3.25 * s, 0), Color3.fromRGB(112, 80, 52), Mat.Wood, { solid = true })
	Build.cyl(m, 0.7 * s, 2.5 * s, cf * CFrame.new(0, 0.35 * s, 0), Color3.fromRGB(104, 74, 48), Mat.Wood)
	Build.ball(m, 6.6 * s, cf * CFrame.new(0, 8.4 * s, 0), green(rand), Mat.Grass)
	Build.ball(m, 4.4 * s, cf * CFrame.new(2.1 * s, 7.4 * s, 0.9 * s), green(rand), Mat.Grass)
	Build.ball(m, 4.2 * s, cf * CFrame.new(-2 * s, 7.2 * s, -1 * s), green(rand), Mat.Grass)
end

local function flowers(parent: Instance, cf: CFrame, s: number, rand: Random)
	local m = Build.model(parent, "Flowers")
	local petals = { Color3.fromRGB(255, 120, 150), Color3.fromRGB(255, 220, 90), Color3.fromRGB(190, 150, 255), Color3.fromRGB(255, 255, 255) }
	for i = 1, 6 do
		local x, z = (rand:NextNumber() - 0.5) * 4 * s, (rand:NextNumber() - 0.5) * 4 * s
		local h = (0.9 + rand:NextNumber() * 0.7) * s
		Build.box(m, Vector3.new(0.12, h, 0.12), cf * CFrame.new(x, h / 2, z), Color3.fromRGB(80, 170, 70), Mat.Grass)
		Build.ball(m, 0.5 * s, cf * CFrame.new(x, h + 0.1, z), petals[(i % #petals) + 1], Mat.SmoothPlastic)
	end
	for _ = 1, 6 do
		local x, z = (rand:NextNumber() - 0.5) * 4.4 * s, (rand:NextNumber() - 0.5) * 4.4 * s
		Build.box(m, Vector3.new(0.2, 1.3 * s, 0.2), cf * CFrame.new(x, 0.55 * s, z) * CFrame.Angles(0.2, rand:NextNumber() * 6, 0.2), green(rand), Mat.Grass)
	end
end

local function rock(parent: Instance, cf: CFrame, s: number, rand: Random)
	local m = Build.model(parent, "Rock")
	local g = 0.55 + rand:NextNumber() * 0.15
	Build.ball(m, 3.0 * s, cf * CFrame.new(0, 0.7 * s, 0), Color3.new(g, g, g * 1.05), Mat.Slate, { solid = true })
	Build.ball(m, 1.8 * s, cf * CFrame.new(1.6 * s, 0.3 * s, 0.5 * s), Color3.new(g * 0.9, g * 0.9, g), Mat.Slate, { solid = true })
	Build.ball(m, 0.9 * s, cf * CFrame.new(0, 2 * s, 0), Color3.fromRGB(90, 170, 80), Mat.Grass) -- moss
end

local function stump(parent: Instance, cf: CFrame, s: number)
	local m = Build.model(parent, "Stump")
	Build.cyl(m, 1.5 * s, 2.2 * s, cf * CFrame.new(0, 0.7 * s, 0), Color3.fromRGB(106, 76, 50), Mat.Wood, { solid = true })
	Build.cyl(m, 0.1 * s, 1.7 * s, cf * CFrame.new(0, 1.5 * s, 0), Color3.fromRGB(190, 150, 100), Mat.Wood)
end

function DecorBuilder.build(parent: Instance)
	local folder = Build.model(parent, "Decor")
	for i, d in WorldData.Decor do
		local rand = Random.new(i * 7919)
		local gy = Build.groundY(d.x, d.z)
		local cf = CFrame.new(d.x, gy, d.z) * CFrame.Angles(0, math.rad(d.ry), 0)
		if d.kind == "tree" then
			tree(folder, cf, d.scale, rand)
		elseif d.kind == "flowers" then
			flowers(folder, cf, d.scale, rand)
		elseif d.kind == "rock" then
			rock(folder, cf, d.scale, rand)
		else
			stump(folder, cf, d.scale)
		end
		if i % 10 == 0 then
			task.wait()
		end
	end
end

return DecorBuilder
