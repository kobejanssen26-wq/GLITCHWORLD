-- DataStore persistence.
--  * Session lock (UpdateAsync) so two servers can never write the same profile at once.
--  * Bounded retries with exponential backoff for every DataStore call.
--  * A profile is only ever saved if it was successfully LOADED by this server: a failed load kicks the player
--    instead of handing them a blank profile that would overwrite their real data.
--  * Autosave, save-on-leave (PlayerRemoving) and save-everything on shutdown (BindToClose).
--  * In Studio without API access an in-memory fallback is used with a loud warning.
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Profile = require(Shared.Profile)

local DataService = {}

local STORE_NAME = "GlitchWorld_Profiles_v1"
local LOCK_TIMEOUT = 120 -- seconds before another server's lock is treated as dead
local MAX_ATTEMPTS = 5
local LOAD_ROUNDS = 6

local store: DataStore? = nil
local offline = false
local memory: { [number]: any } = {}
local loaded: { [Player]: any } = {} -- profiles safe to save
local saving: { [Player]: boolean } = {} -- one save per player at a time

local function keyFor(userId: number): string
	return "Player_" .. userId
end

local function getStore(): DataStore?
	if offline then
		return nil
	end
	if not store then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(STORE_NAME)
		end)
		if ok then
			store = result
		else
			if RunService:IsStudio() then
				warn("[GlitchWorld] DataStore unavailable in Studio - progress will NOT be saved. Enable 'Enable Studio Access to API Services'.")
				offline = true
				return nil
			end
			error(result)
		end
	end
	return store
end

local function withRetry(fn: () -> any): (boolean, any)
	local lastErr
	for attempt = 1, MAX_ATTEMPTS do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		if RunService:IsStudio() and tostring(result):find("StudioAccessToApisNotAllowed") then
			warn("[GlitchWorld] DataStore API access disabled in Studio - using in-memory profiles (nothing will persist).")
			offline = true
			return false, "offline"
		end
		warn(("[GlitchWorld] DataStore attempt %d/%d failed: %s"):format(attempt, MAX_ATTEMPTS, tostring(result)))
		task.wait(2 ^ attempt * 0.5)
	end
	return false, lastErr
end

local function lockedByOther(lock: any): boolean
	return type(lock) == "table" and lock.jobId ~= game.JobId and os.time() - (lock.t or 0) < LOCK_TIMEOUT
end

-- Returns a reconciled profile, or nil + reason. Never returns a blank profile after a failed load.
function DataService.load(player: Player): (any?, string?)
	local ds = getStore()
	if not ds then
		local p = Profile.reconcile(memory[player.UserId])
		loaded[player] = p
		return p
	end
	local key = keyFor(player.UserId)
	for _ = 1, LOAD_ROUNDS do
		local blocked = false
		local ok, data = withRetry(function()
			return ds:UpdateAsync(key, function(old)
				old = old or {}
				if lockedByOther(old.lock) then
					blocked = true
					return nil -- cancel the write
				end
				old.lock = { jobId = game.JobId, t = os.time() }
				return old
			end)
		end)
		if offline then
			local p = Profile.reconcile(nil)
			loaded[player] = p
			return p
		end
		if not ok then
			return nil, "DataStore error: " .. tostring(data)
		end
		if blocked then
			task.wait(5) -- the previous server is probably still saving on leave
		else
			local p = Profile.reconcile(data and data.data)
			loaded[player] = p
			return p
		end
	end
	return nil, "Your data is still in use by another server. Please rejoin in a minute."
end

function DataService.get(player: Player): any?
	return loaded[player]
end

-- Saves a profile that this server loaded. release=true clears the session lock (leaving).
function DataService.save(player: Player, release: boolean?): boolean
	local profile = loaded[player]
	if not profile then
		return false -- never save a profile we did not load
	end
	if saving[player] then
		if not release then
			return false -- another save is already in flight; the next autosave covers it
		end
		-- a final save must not be dropped: wait for the in-flight save, then write the latest data and free the lock
		local t0 = os.clock()
		while saving[player] and os.clock() - t0 < 30 do
			task.wait(0.1)
		end
		if saving[player] then
			return false
		end
	end
	saving[player] = true
	local ds = getStore()
	if not ds then
		memory[player.UserId] = Profile.reconcile(profile)
		saving[player] = nil
		return true
	end
	-- snapshot now so the table we write cannot change mid-request
	local snapshot = Profile.reconcile(profile)
	local ok, err = withRetry(function()
		return ds:UpdateAsync(keyFor(player.UserId), function(old)
			old = old or {}
			if lockedByOther(old.lock) then
				return nil -- another server owns this profile now; do not clobber it
			end
			old.data = snapshot
			old.lock = if release then nil else { jobId = game.JobId, t = os.time() }
			return old
		end)
	end)
	saving[player] = nil
	if not ok and not offline then
		warn("[GlitchWorld] Save failed for " .. player.Name .. ": " .. tostring(err))
	end
	return ok
end

-- Call after the final save when a player leaves.
function DataService.release(player: Player)
	loaded[player] = nil
	saving[player] = nil
end

-- Autosave all loaded players (staggered so we do not burst the DataStore budget).
function DataService.startAutosave(interval: number)
	task.spawn(function()
		while true do
			task.wait(interval)
			local list = {}
			for player in loaded do
				table.insert(list, player)
			end
			for _, player in list do
				if player.Parent then
					task.spawn(DataService.save, player, false)
				end
				task.wait(1)
			end
		end
	end)
end

function DataService.saveAllBlocking()
	local pending = 0
	for player in loaded do
		pending += 1
		task.spawn(function()
			DataService.save(player, true)
			pending -= 1
		end)
	end
	local t0 = os.clock()
	while pending > 0 and os.clock() - t0 < 25 do
		task.wait(0.2)
	end
end

return DataService
