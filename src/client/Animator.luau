-- Animates decorative parts near the camera: runtime machines tagged with Bob/Spin attributes and the baked coins.
-- Purely local (the server never sees these CFrame changes).
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Animator = {}

type Item = { part: BasePart, base: CFrame, bob: number, spin: number, phase: number, cyl: boolean }
local items: { [BasePart]: Item } = {}

local function consider(d: Instance)
	if not d:IsA("BasePart") then
		return
	end
	local bob, spin = d:GetAttribute("Bob"), d:GetAttribute("Spin")
	if d.Name == "Coin" then
		spin, bob = 2.4, 0.5
	end
	if (bob or spin) and not items[d] then
		items[d] = { part = d, base = d.CFrame, bob = (bob or 0) :: number, spin = (spin or 0) :: number, phase = math.random() * 6.28, cyl = d:IsA("Part") and (d :: Part).Shape == Enum.PartType.Cylinder }
		d.AncestryChanged:Connect(function()
			if not d.Parent then
				items[d] = nil
			end
		end)
	end
end

function Animator.init()
	for _, root in { Workspace:WaitForChild("Factories"), Workspace:WaitForChild("World") } do
		for _, d in root:GetDescendants() do
			consider(d)
		end
		root.DescendantAdded:Connect(consider) -- streaming: parts arrive and leave while you move
	end
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc < 1 / 40 then
			return
		end
		acc = 0
		local cam = Workspace.CurrentCamera
		if not cam then
			return
		end
		local camPos = cam.CFrame.Position
		local now = os.clock()
		for _, it in items do
			local p = it.part
			if (p.Position - camPos).Magnitude < 140 then
				local off = if it.bob > 0 then math.sin(now * 2 + it.phase) * it.bob else 0
				p.CFrame = CFrame.new(0, off, 0) * it.base * (if it.cyl then CFrame.Angles(it.spin * now, 0, 0) else CFrame.Angles(0, it.spin * now, 0))
			end
		end
	end)
end

return Animator
