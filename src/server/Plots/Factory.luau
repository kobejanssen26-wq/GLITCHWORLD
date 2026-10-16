-- Builds the machines of one tycoon plot. Plot-local axes: +X along the belt, -Z towards the tower.
-- Ores are NOT parts: the client draws them from the same deterministic schedule the server uses for income.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Mk = require(script.Parent.Parent.Mk)

local Factory = {}

local BELT_Y = Config.Plots.BELT_Y
Factory.BELT_X0, Factory.BELT_X1 = -38, 38

local function dark(c, k)
	return { c[1] * k, c[2] * k, c[3] * k }
end

-- the belt itself (always present)
function Factory.buildBelt(folder: Instance, O: CFrame)
	local m = Instance.new("Model")
	m.Name = "Belt"
	local function L(x, y, z) return O * CFrame.new(x, y, z) end
	Mk.part(m, "Belt", Vector3.new(76, 0.8, 8), L(0, BELT_Y - 0.4, 0), { 40, 36, 60 }, "DiamondPlate", { collide = true })
	for _, z in { -4.3, 4.3 } do
		Mk.part(m, "Rail", Vector3.new(76, 1.2, 0.7), L(0, BELT_Y + 0.2, z), { 70, 240, 255 }, "Neon")
	end
	for x = -36, 36, 12 do
		Mk.part(m, "Leg", Vector3.new(1.4, BELT_Y, 1.4), L(x, BELT_Y / 2 - 0.4, 3.2), { 60, 52, 90 }, "Metal")
		Mk.part(m, "Leg", Vector3.new(1.4, BELT_Y, 1.4), L(x, BELT_Y / 2 - 0.4, -3.2), { 60, 52, 90 }, "Metal")
	end
	for x = -34, 34, 4 do
		Mk.part(m, "Chevron", Vector3.new(1.6, 0.1, 3), L(x, BELT_Y + 0.05, 0), { 255, 215, 90 }, "Neon", { tr = 0.35 })
	end
	m.Parent = folder
	return m
end

local builders: { [string]: (Instance, CFrame, any) -> () } = {}

builders.dropper = function(m, O, it)
	local function L(x, y, z) return O * CFrame.new(x, y, z) end
	local x = it.x
	for _, z in { -3.4, 3.4 } do
		Mk.part(m, "Post", Vector3.new(1, 14, 1), L(x, 7 + BELT_Y, z), { 60, 52, 90 }, "Metal", { collide = true })
	end
	Mk.part(m, "Top", Vector3.new(7, 1.6, 9), L(x, 14.8 + BELT_Y, 0), dark(it.color, 0.55), "Metal", { collide = true })
	Mk.cyl(m, "Funnel", 3.4, 5.4, L(x, 12.2 + BELT_Y, 0), dark(it.color, 0.7), "Metal")
	Mk.cyl(m, "Nozzle", 2.4, 1.6, L(x, 9.6 + BELT_Y, 0), { 90, 80, 120 }, "Metal")
	Mk.cyl(m, "Ring", 0.5, 5.9, L(x, 13.6 + BELT_Y, 0), it.color, "Neon")
	Mk.ball(m, "Core", 2.2, L(x, 12.6 + BELT_Y, 0), it.color, "Neon", { bob = 0.3 })
	local plate = Mk.part(m, "Plate", Vector3.new(6, 1.6, 0.4), L(x, 17 + BELT_Y, 0), { 24, 18, 48 }, "SmoothPlastic")
	Mk.label(plate, it.name, 1.6, it.color, UDim2.fromOffset(230, 40), 120)
	Mk.light(m:FindFirstChild("Core") :: Instance, it.color, 14, 1)
end

builders.upgrader = function(m, O, it)
	local function L(x, y, z) return O * CFrame.new(x, y, z) end
	local x = it.x
	for _, z in { -6, 6 } do
		Mk.part(m, "Post", Vector3.new(1.4, 11, 1.4), L(x, 5.5 + BELT_Y, z), { 60, 52, 90 }, "Metal", { collide = true })
		Mk.part(m, "PostGlow", Vector3.new(0.3, 10, 0.3), L(x, 5.5 + BELT_Y, z * 0.9), it.color, "Neon")
	end
	Mk.part(m, "Beam", Vector3.new(1.8, 1.8, 14), L(x, 11.2 + BELT_Y, 0), { 60, 52, 90 }, "Metal")
	Mk.part(m, "Curtain", Vector3.new(0.4, 8.6, 10.6), L(x, 5.4 + BELT_Y, 0), it.color, "Neon", { tr = 0.65 })
	local sign = Mk.part(m, "Sign", Vector3.new(5, 2, 0.5), L(x, 13.4 + BELT_Y, 0), { 24, 18, 48 }, "SmoothPlastic")
	Mk.label(sign, ("x%s"):format(tostring(it.mult)), 1.8, it.color, UDim2.fromOffset(150, 50), 140)
	Mk.part(m, "BeamGlow", Vector3.new(0.4, 0.4, 14.2), L(x, 12.2 + BELT_Y, 0), it.color, "Neon")
end

builders.generator = function(m, O, it)
	local function L(x, y, z) return O * CFrame.new(x, y, z) end
	local x, z = it.x, -16
	Mk.part(m, "Base", Vector3.new(9, 2, 9), L(x, 1, z), { 50, 44, 80 }, "Metal", { collide = true })
	Mk.cyl(m, "Body", 7, 6, L(x, 5.5, z), dark(it.color, 0.5), "Metal", { collide = true })
	Mk.cyl(m, "Rotor", 0.8, 8, L(x, 9.4, z), it.color, "Neon", { spin = 3.2 })
	Mk.ball(m, "Spark", 2.4, L(x, 11.2, z), { 255, 255, 255 }, "Neon", { bob = 0.4 })
	Mk.part(m, "Cable", Vector3.new(0.9, 0.9, math.abs(z) - 4), L(x, 0.7, z / 2 + 2), it.color, "Neon")
	local sign = Mk.part(m, "Sign", Vector3.new(5, 1.4, 0.4), L(x, 14.4, z), { 24, 18, 48 }, "SmoothPlastic")
	Mk.label(sign, ("+%s/s"):format(tostring(it.rate)), 1.6, it.color, UDim2.fromOffset(170, 44), 140)
	Mk.light(m:FindFirstChild("Spark") :: Instance, it.color, 18, 1.4)
end

builders.collector = function(m, O, it)
	local function L(x, y, z) return O * CFrame.new(x, y, z) end
	local gold = it.bonus > 1
	local c = gold and { 255, 205, 80 } or { 90, 255, 150 }
	local x = 35
	local s = gold and 1.25 or 1
	Mk.part(m, "BinFloor", Vector3.new(9 * s, 0.8, 10 * s), L(x, BELT_Y - 0.4, 0), dark(c, 0.4), "Metal", { collide = true })
	for _, z in { -5 * s, 5 * s } do
		Mk.part(m, "BinWall", Vector3.new(9 * s, 5 * s, 0.8), L(x, BELT_Y + 2.5 * s, z), dark(c, 0.55), "Metal", { collide = true })
		Mk.part(m, "BinGlow", Vector3.new(9 * s, 0.4, 1), L(x, BELT_Y + 5 * s, z), c, "Neon")
	end
	Mk.part(m, "BinBack", Vector3.new(0.8, 5 * s, 10 * s), L(x + 4.4 * s, BELT_Y + 2.5 * s, 0), dark(c, 0.55), "Metal", { collide = true })
	local sign = Mk.part(m, "Sign", Vector3.new(7, 1.6, 0.4), L(x, BELT_Y + 7.5 * s, 0), { 24, 18, 48 }, "SmoothPlastic")
	Mk.label(sign, gold and "MEGA COLLECTOR x1.5" or "COLLECTOR", 1.6, c, UDim2.fromOffset(260, 44), 140)
	Mk.cyl(m, "Funnel", 2, 6 * s, L(x - 1, BELT_Y + 6.2 * s, 0), c, "Neon", { tr = 0.35 })
end

builders.decor = function(m, O, it)
	local function L(x, y, z) return O * CFrame.new(x, y, z) end
	if it.id == "decor_lights" then
		for k = 0, 8 do
			local x = -36 + k * 9
			Mk.part(m, "RoofBar", Vector3.new(0.6, 0.6, 18), L(x, 20, 0), k % 2 == 0 and { 255, 90, 200 } or { 70, 240, 255 }, "Neon")
			Mk.ball(m, "Lamp", 2, L(x, 18.4, 8), k % 2 == 0 and { 255, 90, 200 } or { 70, 240, 255 }, "Neon", { bob = 0.25 })
			Mk.ball(m, "Lamp", 2, L(x, 18.4, -8), k % 2 == 0 and { 70, 240, 255 } or { 255, 90, 200 }, "Neon", { bob = 0.25 })
		end
		Mk.part(m, "RoofSpine", Vector3.new(76, 0.6, 0.6), L(0, 20, 0), { 255, 255, 255 }, "Neon")
	else -- turbine fans
		for _, z in { -22, 22 } do
			Mk.cyl(m, "FanPole", 16, 1.4, L(-20, 8, z), { 60, 52, 90 }, "Metal", { collide = true })
			Mk.ball(m, "FanHub", 3, L(-20, 17, z), it.color, "Neon")
			for b = 0, 3 do
				Mk.part(m, "Blade", Vector3.new(0.4, 9, 2.4), L(-20, 17, z) * CFrame.Angles(0, 0, b * math.pi / 2) * CFrame.new(0, 4.5, 0), { 220, 230, 255 }, "SmoothPlastic", { spin = 4 })
			end
		end
	end
end

builders.overdrive = function(m, O, it)
	local function L(x, y, z) return O * CFrame.new(x, y, z) end
	local z = -24
	Mk.cyl(m, "ReactorBase", 3, 18, L(0, 1.5, z), { 40, 30, 60 }, "Metal", { collide = true })
	Mk.cyl(m, "ReactorCore", 16, 6.4, L(0, 11, z), it.color, "Neon", { tr = 0.2 })
	for k, y in { 7, 12, 17 } do
		Mk.cyl(m, "ReactorRing", 0.8, 11 - k, L(0, y, z), { 255, 215, 90 }, "Neon", { spin = k % 2 == 0 and 2.4 or -2.4 })
	end
	Mk.ball(m, "ReactorOrb", 5, L(0, 21.5, z), { 255, 255, 255 }, "Neon", { bob = 0.6 })
	Mk.light(m:FindFirstChild("ReactorOrb") :: Instance, it.color, 40, 2.5)
	local sign = Mk.part(m, "Sign", Vector3.new(9, 2, 0.5), L(0, 26, z), { 24, 18, 48 }, "SmoothPlastic")
	Mk.label(sign, "OVERDRIVE REACTOR", 2, it.color, UDim2.fromOffset(300, 50), 200)
	local pad = Mk.cyl(m, "OverdrivePad", 0.6, 7, L(0, 3.3, z + 11), it.color, "Neon", { collide = true })
	local pp = Instance.new("ProximityPrompt")
	pp.ObjectText = "Overdrive Reactor"
	pp.ActionText = "Hold to trigger OVERDRIVE"
	pp.HoldDuration = 2
	pp.MaxActivationDistance = 12
	pp.RequiresLineOfSight = false
	pp.Parent = pad
	pp:SetAttribute("Action", "overdrive")
end

function Factory.buildItem(folder: Instance, O: CFrame, it): Model
	local old = folder:FindFirstChild(it.id)
	if old then
		old:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = it.id
	local b = builders[it.kind]
	if b then
		b(m, O, it)
	end
	m.Parent = folder
	return m
end

-- the buy pad: a glowing disc showing the next piece and its price
function Factory.buildPad(folder: Instance, O: CFrame): Part
	local pad = Mk.cyl(folder, "BuyPad", 0.8, 11, O * CFrame.new(0, 0.9, Config.Plots.BUTTON_Z), { 70, 240, 255 }, "Neon", { collide = true, touch = true })
	Mk.cyl(folder, "BuyPadRim", 0.6, 12.5, O * CFrame.new(0, 0.8, Config.Plots.BUTTON_Z), { 40, 30, 70 }, "Metal")
	Mk.ball(folder, "BuyPadOrb", 2.4, O * CFrame.new(0, 6, Config.Plots.BUTTON_Z), { 255, 255, 255 }, "Neon", { bob = 0.5 })
	return pad
end

return Factory
