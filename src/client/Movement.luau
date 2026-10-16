-- Client-side movement perks: bounce-pad launches and the Double Jump perk (movement is client-authoritative in
-- Roblox; the server only decides WHICH perks you own via the DoubleJump attribute and walk/jump stats).
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Sfx = require(script.Parent.Sfx)

local Movement = {}

local player = Players.LocalPlayer
local canDouble = false

local function ring(hrp: BasePart)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Shape = Enum.PartType.Cylinder
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(70, 240, 255)
	p.Transparency = 0.2
	p.Size = Vector3.new(0.3, 3, 3)
	p.CFrame = CFrame.new(hrp.Position - Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	p.Parent = Workspace
	local tw = game:GetService("TweenService"):Create(p, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.3, 12, 12), Transparency = 1 })
	tw:Play()
	game:GetService("Debris"):AddItem(p, 0.6)
end

local function bindCharacter(char: Model)
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hum then
		return
	end
	canDouble = false
	hum.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Jumping then
			canDouble = true
		elseif new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running or new == Enum.HumanoidStateType.Seated then
			canDouble = false
		end
	end)
end

function Movement.init()
	Remotes.get("Launch").OnClientEvent:Connect(function(power: number)
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp and type(power) == "number" and power > 0 and power < 250 then
			local v = hrp.AssemblyLinearVelocity
			hrp.AssemblyLinearVelocity = Vector3.new(v.X, power, v.Z)
		end
	end)

	if player.Character then
		task.spawn(bindCharacter, player.Character)
	end
	player.CharacterAdded:Connect(bindCharacter)

	UserInputService.JumpRequest:Connect(function()
		if not player:GetAttribute("DoubleJump") or not canDouble then
			return
		end
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hum or not hrp then
			return
		end
		local st = hum:GetState()
		if st ~= Enum.HumanoidStateType.Freefall and st ~= Enum.HumanoidStateType.Jumping then
			return
		end
		canDouble = false
		local v = hrp.AssemblyLinearVelocity
		hrp.AssemblyLinearVelocity = Vector3.new(v.X, hum.JumpPower, v.Z)
		Sfx.play("jump2")
		ring(hrp)
		Remotes.get("Jumped2"):FireServer()
	end)
end

return Movement
