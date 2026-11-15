-- Sound.luau — one job: play the game's sounds, or stay silent.
-- Every play is wrapped in pcall, and an empty asset id means silence,
-- never an error. The experience's owner drops real uploaded asset ids
-- into Config.Sounds to turn the sound on; until then the game is
-- fully playable and the visual feedback carries the feel.

local SoundService = game:GetService("SoundService")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local Sound = {}
Sound._sounds = {}

-- _get builds (once) the Sound for a name, parented under SoundService
-- so it survives the GUI being rebuilt. An empty id builds nothing
-- and hands back nil, which play() treats as silence.
function Sound._get(name)
	local cached = Sound._sounds[name]
	if cached then
		return cached
	end
	local id = Config.Sounds[name]
	if not id or id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = "NeonRush_" .. name
	sound.SoundId = id
	sound.Volume = 0.5
	sound.Parent = SoundService
	Sound._sounds[name] = sound
	return sound
end

-- play fires a named sound. A missing id, a bad asset or a service
-- error all end here, silently: the game never waits on a sound.
function Sound.play(name)
	local sound = Sound._get(name)
	if not sound then
		return
	end
	pcall(function()
		sound:Play()
	end)
end

return Sound
