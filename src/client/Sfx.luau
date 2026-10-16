-- Sound effects + zone music. Asset ids come from shared/AudioIds (paste ids after uploading /audio); empty ids
-- fall back to engine sounds (sfx) or silence (music). Respects the sfx / music settings.
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local AudioIds = require(Shared.AudioIds)
local State = require(script.Parent.State)

local Sfx = {}

local lastPlayed: { [string]: number } = {}

local function assetId(v: any): string
	if v == nil or v == "" or v == 0 then
		return ""
	end
	local s = tostring(v)
	if s:sub(1, 6) == "rbxass" or s:sub(1, 6) == "rbxasset" then
		return s
	end
	return "rbxassetid://" .. s
end

local function setting(key: string): boolean
	local d = State.data
	return not d or d.settings[key] ~= false
end

function Sfx.play(name: string, pitchScale: number?)
	local cfg = Config.Sfx[name]
	if not cfg or not setting("sfx") then
		return
	end
	local now = os.clock()
	if lastPlayed[name] and now - lastPlayed[name] < 0.04 then
		return
	end
	lastPlayed[name] = now
	local id = assetId(AudioIds.sfx[name])
	local custom = id ~= ""
	local s = Instance.new("Sound")
	s.SoundId = if custom then id else cfg.fallback
	s.Volume = cfg.volume * (if custom then 1.4 else 1)
	s.PlaybackSpeed = (if custom then 1 else cfg.pitch) * (pitchScale or 1)
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, 6)
end

-- ===== music: two sounds crossfaded =====
local current: Sound? = nil
local currentName = ""
local MUSIC_VOLUME = 0.32

function Sfx.music(track: string)
	if track == currentName then
		return
	end
	currentName = track
	local id = assetId(AudioIds.music[track])
	if current then
		local old = current
		TweenService:Create(old, TweenInfo.new(1.5), { Volume = 0 }):Play()
		Debris:AddItem(old, 1.8)
		current = nil
	end
	if id == "" or not setting("music") then
		return
	end
	local s = Instance.new("Sound")
	s.Name = "Music_" .. track
	s.SoundId = id
	s.Looped = true
	s.Volume = 0
	s.Parent = SoundService
	s:Play()
	TweenService:Create(s, TweenInfo.new(2), { Volume = MUSIC_VOLUME }):Play()
	current = s
end

-- apply a changed music setting right away (ZoneFx requests the track again on its next tick when re-enabled)
function Sfx.refresh()
	if not setting("music") and current then
		current:Destroy()
		current = nil
		currentName = ""
	end
end

return Sfx
