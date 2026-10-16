-- Applies behaviour to baked tower parts according to their names (see tools/bake/Modules.luau for the grammar):
--   Kill | SpinnerKill:speed | Turntable:speed | KillMover:vx,vy,vz:period:phase | Mover:vx,vy,vz:period:phase |
--   Piston:dy:period:offset | Laser:on,off,offset | Vanish:delay | Bounce:power | Speed:mult:seconds |
--   Belt:vx,vy,vz | Coin
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Behaviors = {}

local function humanoidOf(hit: BasePart): (Humanoid?, Player?)
	local model = hit.Parent
	if not model then
		return nil, nil
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum then
		return nil, nil
	end
	return hum, Players:GetPlayerFromCharacter(model)
end

local function vec(s: string): Vector3
	local x, y, z = s:match("^(%-?[%d%.]+),(%-?[%d%.]+),(%-?[%d%.]+)$")
	return Vector3.new(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0)
end

local function startMover(part: BasePart, offset: Vector3, period: number, phase: number)
	local base = part.CFrame
	local info = TweenInfo.new(math.max(0.2, period / 2), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local tween = TweenService:Create(part, info, { CFrame = base + offset })
	if phase > 0 then
		part.CFrame = base
		task.delay(phase, function()
			tween:Play()
		end)
	else
		tween:Play()
	end
end

-- motor-driven rotation around the world's up axis (works for bars and cylinders whatever their local axes)
local function makeSpinner(part: BasePart, speed: number)
	local pivot = Instance.new("Part")
	pivot.Name = "SpinPivot"
	pivot.Anchored = true
	pivot.CanCollide = false
	pivot.CanTouch = false
	pivot.CanQuery = false
	pivot.Transparency = 1
	pivot.Size = Vector3.new(1, 1, 1)
	pivot.CFrame = part.CFrame
	pivot.Parent = part.Parent
	local axisLocal = part.CFrame:VectorToObjectSpace(Vector3.yAxis)
	local attCF = CFrame.lookAt(Vector3.zero, axisLocal) * CFrame.Angles(0, math.pi / 2, 0)
	local a0 = Instance.new("Attachment")
	a0.CFrame = attCF
	a0.Parent = pivot
	local a1 = Instance.new("Attachment")
	a1.CFrame = attCF
	a1.Parent = part
	local hinge = Instance.new("HingeConstraint")
	hinge.Attachment0 = a0
	hinge.Attachment1 = a1
	hinge.ActuatorType = Enum.ActuatorType.Motor
	hinge.AngularVelocity = speed
	hinge.MotorMaxTorque = 1e9
	hinge.Parent = part
	part.Anchored = false
	part:SetNetworkOwner(nil) -- server simulates it, so every player sees the same rotation
end

function Behaviors.apply(root: Instance, hooks: any)
	local lasers = {}
	local counts = { kill = 0, mover = 0, spinner = 0, laser = 0, vanish = 0, bounce = 0, speed = 0, belt = 0, coin = 0 }

	local function connectKill(part: BasePart, gate: (() -> boolean)?)
		local last: { [Humanoid]: number } = {}
		part.Touched:Connect(function(hit)
			if gate and not gate() then
				return
			end
			local hum, player = humanoidOf(hit)
			if hum and hum.Health > 0 then
				local now = os.clock()
				if now - (last[hum] or 0) > 0.4 then
					last[hum] = now
					hooks.kill(hum, player)
				end
			end
		end)
		counts.kill += 1
	end

	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			local name = d.Name
			local kind = name:match("^([A-Za-z]+)")
			local args = name:split(":")
			if kind == "Kill" then
				connectKill(d)
			elseif kind == "SpinnerKill" then
				makeSpinner(d, tonumber(args[2]) or 1)
				connectKill(d)
				counts.spinner += 1
			elseif kind == "Turntable" then
				makeSpinner(d, tonumber(args[2]) or 0.5)
				counts.spinner += 1
			elseif kind == "KillMover" or kind == "Mover" then
				startMover(d, vec(args[2] or ""), tonumber(args[3]) or 3, tonumber(args[4]) or 0)
				if kind == "KillMover" then
					connectKill(d)
				end
				counts.mover += 1
			elseif kind == "Piston" then
				startMover(d, Vector3.new(0, tonumber(args[2]) or -6, 0), tonumber(args[3]) or 2.4, tonumber(args[4]) or 0)
				connectKill(d)
				counts.mover += 1
			elseif kind == "Laser" then
				local on, off, offset = (args[2] or ""):match("^([%d%.]+),([%d%.]+),([%d%.]+)$")
				local laser = { part = d, on = tonumber(on) or 1, off = tonumber(off) or 1, offset = tonumber(offset) or 0, active = true }
				table.insert(lasers, laser)
				connectKill(d, function()
					return laser.active
				end)
				counts.laser += 1
			elseif kind == "Vanish" then
				local delay = tonumber(args[2]) or 0.8
				local busy = false
				d.Touched:Connect(function(hit)
					if busy or not humanoidOf(hit) then
						return
					end
					busy = true
					task.delay(delay, function()
						TweenService:Create(d, TweenInfo.new(0.25), { Transparency = 1 }):Play()
						task.delay(0.25, function()
							d.CanCollide = false
						end)
						task.delay(3.2, function()
							d.Transparency = 0
							d.CanCollide = true
							busy = false
						end)
					end)
				end)
				counts.vanish += 1
			elseif kind == "Bounce" then
				local power = tonumber(args[2]) or 100
				local last = 0
				d.Touched:Connect(function(hit)
					local hum, player = humanoidOf(hit)
					if hum and player and os.clock() - last > 0.6 then
						last = os.clock()
						hooks.bounce(player, power)
					end
				end)
				counts.bounce += 1
			elseif kind == "Speed" then
				local mult, secs = tonumber(args[2]) or 1.8, tonumber(args[3]) or 3
				local last = 0
				d.Touched:Connect(function(hit)
					local hum, player = humanoidOf(hit)
					if hum and player and os.clock() - last > 0.5 then
						last = os.clock()
						hooks.speed(player, mult, secs)
					end
				end)
				counts.speed += 1
			elseif kind == "Belt" then
				d.AssemblyLinearVelocity = vec(args[2] or "")
				counts.belt += 1
			elseif kind == "Coin" then
				d.Touched:Connect(function(hit)
					local hum, player = humanoidOf(hit)
					if hum and player then
						hooks.coin(player, d)
					end
				end)
				counts.coin += 1
			end
		end
	end

	if #lasers > 0 then
		RunService.Heartbeat:Connect(function()
			local t = Workspace:GetServerTimeNow()
			for _, l in lasers do
				local cycle = l.on + l.off
				local want = ((t + l.offset) % cycle) < l.on
				if want ~= l.active then
					l.active = want
					l.part.Transparency = if want then 0.1 else 1
				end
			end
		end)
	end
	return counts
end

return Behaviors
