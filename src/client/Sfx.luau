-- Sound effects. Uses Config.Sounds (engine sounds by default; swap ids there for custom audio).
-- Respects the player's sfx / music settings from the server snapshot.
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local State = require(script.Parent.State)

local Sfx = {}

local lastPlayed: { [string]: number } = {}
local loops: { [string]: Sound } = {}

local function enabled(): boolean
	local d = State.data
	return not d or d.settings.sfx ~= false
end

function Sfx.play(name: string, pitchScale: number?)
	local cfg = Config.Sounds[name]
	if not cfg or cfg.id == "" or not enabled() then
		return
	end
	local now = os.clock()
	if lastPlayed[name] and now - lastPlayed[name] < 0.04 then
		return
	end
	lastPlayed[name] = now
	local s = Instance.new("Sound")
	s.SoundId = cfg.id
	s.Volume = cfg.volume
	s.PlaybackSpeed = (cfg.pitch or 1) * (pitchScale or 1)
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, 4)
end

function Sfx.startLoop(name: string)
	if loops[name] or not enabled() then
		return
	end
	local cfg = Config.Sounds[name]
	if not cfg or cfg.id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = cfg.id
	s.Volume = cfg.volume
	s.PlaybackSpeed = cfg.pitch or 1
	s.Looped = true
	s.Parent = SoundService
	s:Play()
	loops[name] = s
end

function Sfx.setLoopPitch(name: string, pitch: number)
	local s = loops[name]
	if s then
		s.PlaybackSpeed = (Config.Sounds[name].pitch or 1) * pitch
	end
end

function Sfx.stopLoop(name: string)
	local s = loops[name]
	if s then
		loops[name] = nil
		s:Stop()
		s:Destroy()
	end
end

-- optional background music (set Config.Sounds.music.id to an audio asset you own)
local music: Sound? = nil
function Sfx.updateMusic()
	local cfg = Config.Sounds.music
	local want = cfg.id ~= "" and State.data ~= nil and State.data.settings.music ~= false
	if want and not music then
		local m = Instance.new("Sound")
		m.Name = "GlitchMusic"
		m.SoundId = cfg.id
		m.Volume = cfg.volume
		m.Looped = true
		m.Parent = SoundService
		m:Play()
		music = m
	elseif not want and music then
		music:Destroy()
		music = nil
	end
end

return Sfx
