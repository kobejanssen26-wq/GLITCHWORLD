-- The tower: checkpoints, floor rewards, respawning, teleports, coins, bounce / speed pads and fall recovery.
-- Progress rules live in shared/Rules; this module adds the physical-world checks (touching, timing, distance).
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)
local Remotes = require(Shared.Remotes)
local Sessions = require(script.Parent.Sessions)
local StateService = require(script.Parent.StateService)
local ProgressService = require(script.Parent.ProgressService)
local PlotService = require(script.Parent.PlotService)
local RateLimit = require(script.Parent.RateLimit)
local Behaviors = require(script.Parent.Obby.Behaviors)

local ObbyService = {}

local T = Config.Tower
local pads: { [number]: BasePart } = {} -- checkpoint pads by floor (13 = summit)
local coins: { { part: BasePart, floor: number, taken: boolean } } = {}
local hubSpawn: CFrame = CFrame.new(0, 5, -136)

local function rootOf(player: Player): BasePart?
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or hum.Health <= 0 or not hrp or not hrp:IsA("BasePart") then
		return nil
	end
	return hrp
end

local function padCFrame(floor: number): CFrame?
	local pad = pads[floor]
	if not pad then
		return nil
	end
	return pad.CFrame + Vector3.new(0, 5, 0)
end

-- where this player should stand right now
function ObbyService.targetCFrame(session: Sessions.Session): CFrame
	if session.inTower then
		local cf = padCFrame(session.profile.checkpoint)
		if cf then
			return cf
		end
	end
	if session.plot then
		return PlotService.spawnCFrame(session.plot)
	end
	return hubSpawn + Vector3.new(0, 3, 0)
end

function ObbyService.place(session: Sessions.Session)
	local char = session.player.Character
	local hrp = rootOf(session.player)
	if not char or not hrp then
		return
	end
	hrp.AssemblyLinearVelocity = Vector3.zero
	char:PivotTo(ObbyService.targetCFrame(session))
end

local function setMoveSpeed(session: Sessions.Session)
	ProgressService.applyCharacter(session)
end

-- ===== checkpoints / floors =====
local function onCheckpoint(player: Player, floor: number, pad: BasePart)
	local session = Sessions.get(player)
	local hrp = rootOf(player)
	if not session or not hrp then
		return
	end
	if not RateLimit.allow(player, "checkpoint", 4, 6) then
		return
	end
	if (hrp.Position - pad.Position).Magnitude > Config.Obby.CHECKPOINT_REACH_RADIUS then
		return
	end
	local p = session.profile
	local now = os.clock()
	session.inTower = true
	if floor == session.lastCheckpoint then
		if floor <= p.reached then
			Rules.gotoFloor(p, floor)
		end
		return
	end
	local events = {}
	if floor >= 2 and floor == session.lastCheckpoint + 1 then
		if now - session.checkpointAt < T.MIN_FLOOR_SECONDS then
			StateService.notify(player, { kind = "msg", text = "Too fast! That floor cannot be cleared this quickly.", tone = "warn" })
			return
		end
		if not Rules.reachFloor(p, floor) then
			return
		end
		local res = Rules.clearFloor(p, floor - 1)
		if res then
			table.insert(events, { kind = "floorClear", floor = floor - 1, name = Config.Floors[floor - 1].name, crowns = res.crowns, cash = res.cash, first = res.first })
		end
	elseif floor <= p.reached then
		Rules.gotoFloor(p, floor) -- arriving at a checkpoint you already unlocked (no rewards)
	else
		StateService.notify(player, { kind = "msg", text = "Climb the floors in order to unlock this checkpoint.", tone = "warn" })
		return
	end
	session.lastCheckpoint = floor
	session.checkpointAt = now
	table.insert(events, { kind = "checkpoint", floor = floor, name = Config.Floors[floor].name })
	ProgressService.commit(session, events)
end

local function onSummit(player: Player, pad: BasePart)
	local session = Sessions.get(player)
	local hrp = rootOf(player)
	if not session or not hrp or not RateLimit.allow(player, "checkpoint", 4, 6) then
		return
	end
	if (hrp.Position - pad.Position).Magnitude > Config.Obby.CHECKPOINT_REACH_RADIUS then
		return
	end
	local p = session.profile
	if session.lastCheckpoint ~= T.FLOORS or os.clock() - session.checkpointAt < T.MIN_FLOOR_SECONDS or p.reached < T.FLOORS then
		return
	end
	local res = Rules.clearFloor(p, T.FLOORS)
	session.lastCheckpoint = T.FLOORS + 1
	if res then
		ProgressService.commit(session, { { kind = "floorClear", floor = T.FLOORS, name = Config.Floors[T.FLOORS].name, crowns = res.crowns, cash = res.cash, first = res.first, summit = true } })
	end
end

-- ===== teleports =====
local function teleportCooldown(session: Sessions.Session): boolean
	local now = os.clock()
	if now - session.lastGoto < 1.5 then
		return false
	end
	session.lastGoto = now
	return true
end

function ObbyService.goTower(session: Sessions.Session)
	session.inTower = true
	session.lastCheckpoint = session.profile.checkpoint
	session.checkpointAt = os.clock()
	ObbyService.place(session)
	ProgressService.commit(session)
end

function ObbyService.goHome(session: Sessions.Session)
	session.inTower = false
	session.lastCheckpoint = 0
	ObbyService.place(session)
	ProgressService.commit(session)
end

-- ===== characters =====
function ObbyService.onCharacter(session: Sessions.Session, character: Model)
	local hum = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local hrp = character:WaitForChild("HumanoidRootPart", 10)
	if not hum or not hrp then
		return
	end
	hum.MaxSlopeAngle = 60
	ProgressService.applyCharacter(session)
	ObbyService.place(session)
	hum.Died:Connect(function()
		if session.inTower then
			session.profile.stats.deaths += 1
			StateService.notify(session.player, { kind = "death" })
			StateService.markDirty(session)
		end
	end)
end

-- ===== hooks used by the behaviours =====
local hooks = {}

function hooks.kill(hum: Humanoid, player: Player?)
	hum.Health = 0
end

function hooks.bounce(player: Player, power: number)
	Remotes.get("Launch"):FireClient(player, power)
	StateService.notify(player, { kind = "fx", what = "bounce" })
end

function hooks.speed(player: Player, mult: number, secs: number)
	local session = Sessions.get(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not session or not hum then
		return
	end
	session.boostToken += 1
	local token = session.boostToken
	hum.WalkSpeed = Rules.movement(session.profile).walk * mult
	StateService.notify(player, { kind = "fx", what = "speed", seconds = secs })
	task.delay(secs, function()
		if session.boostToken == token then
			setMoveSpeed(session)
		end
	end)
end

local function floorAtHeight(y: number): number
	local per = T.MODULES_PER_FLOOR * T.RISE_PER_MODULE
	return math.clamp(math.floor((y - T.BASE_Y + 3) / per) + 1, 1, T.FLOORS)
end

local function collect(session: Sessions.Session, coin)
	if coin.taken then
		return
	end
	coin.taken = true
	coin.part.Transparency = 1
	coin.part.CanTouch = false
	local cash = Config.Obby.COIN_CASH * coin.floor * math.max(1, session.profile.overdrive + 1)
	Rules.addCash(session.profile, cash)
	session.profile.stats.coins += 1
	StateService.notify(session.player, { kind = "coin", cash = cash })
	StateService.markDirty(session)
	task.delay(25, function()
		coin.taken = false
		coin.part.Transparency = 0
		coin.part.CanTouch = true
	end)
end

function hooks.coin(player: Player, part: BasePart)
	local session = Sessions.get(player)
	if not session then
		return
	end
	for _, c in coins do
		if c.part == part then
			collect(session, c)
			return
		end
	end
end

-- ===== start =====
function ObbyService.start(world: Instance)
	local tower = world:WaitForChild("Tower")
	local counts = Behaviors.apply(tower, hooks)
	for _, d in tower:GetDescendants() do
		if d:IsA("BasePart") then
			local f = d.Name:match("^Checkpoint:(%d+)$")
			if f then
				local floor = tonumber(f) :: number
				pads[floor] = d
				d.Touched:Connect(function(hit)
					local player = Players:GetPlayerFromCharacter(hit.Parent)
					if player then
						onCheckpoint(player, floor, d)
					end
				end)
			elseif d.Name == "Summit" then
				pads[T.FLOORS + 1] = d
				d.Touched:Connect(function(hit)
					local player = Players:GetPlayerFromCharacter(hit.Parent)
					if player then
						onSummit(player, d)
					end
				end)
			elseif d.Name == "Coin" then
				table.insert(coins, { part = d, floor = floorAtHeight(d.Position.Y), taken = false })
			end
		end
	end
	local hs = world:FindFirstChild("Marker:HubSpawn", true) :: BasePart?
	if hs then
		hubSpawn = hs.CFrame
	end

	Remotes.get("Teleport").OnServerInvoke = function(player: Player, where: any)
		local session = Sessions.get(player)
		if not session or not RateLimit.allow(player, "tp", 2, 3) then
			return { ok = false }
		end
		if where ~= "tower" and where ~= "home" then
			return { ok = false }
		end
		if not teleportCooldown(session) then
			return { ok = false, reason = "cooldown" }
		end
		if where == "tower" then
			ObbyService.goTower(session)
		else
			ObbyService.goHome(session)
		end
		return { ok = true }
	end
	Remotes.get("GotoFloor").OnServerInvoke = function(player: Player, floor: any)
		local session = Sessions.get(player)
		if not session or not RateLimit.allow(player, "tp", 2, 3) then
			return { ok = false }
		end
		local valid = type(floor) == "number" and floor == math.floor(floor) and floor >= 1 and floor <= session.profile.reached
		if not valid then
			return { ok = false, reason = "locked" }
		end
		if not teleportCooldown(session) then
			return { ok = false, reason = "cooldown" }
		end
		Rules.gotoFloor(session.profile, floor)
		ObbyService.goTower(session)
		return { ok = true }
	end
	Remotes.get("Skip").OnServerInvoke = function(player: Player)
		local session = Sessions.get(player)
		if not session or not RateLimit.allow(player, "skip", 1, 2) then
			return { ok = false }
		end
		local ok, reason = Rules.skipFloor(session.profile)
		if not ok then
			return { ok = false, reason = reason }
		end
		ObbyService.goTower(session)
		StateService.notify(player, { kind = "msg", text = ("Skipped to floor %d."):format(session.profile.checkpoint), tone = "good" })
		return { ok = true }
	end

	-- every 0.4 s: fall recovery, out-of-bounds and coin magnet
	task.spawn(function()
		while true do
			task.wait(0.4)
			for _, session in Sessions.all() do
				local hrp = rootOf(session.player)
				if hrp then
					local pos = hrp.Position
					if session.inTower then
						local pad = pads[session.profile.checkpoint]
						if pad and (pos.Y < pad.Position.Y - T.FALL_MARGIN or pos.Y < -150) then
							ObbyService.place(session)
						end
						local mg = Rules.movement(session.profile).magnet
						if mg > 0 then
							for _, c in coins do
								if not c.taken and (c.part.Position - pos).Magnitude <= mg then
									collect(session, c)
								end
							end
						end
					elseif pos.Y < -60 or pos.Magnitude > 3000 then
						ObbyService.place(session)
					end
				end
			end
		end
	end)
	return counts
end

return ObbyService
