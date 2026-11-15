-- Config.luau — one job: every number and color PRISM DRIVE tunes by.
-- The server and the client both require this module, so a value changed
-- here changes the whole game in one place. Nothing here runs; it only
-- describes the game.

local Config = {}

-- The palette. Dark navy boards, neon ink: cyan is the player, magenta
-- is danger, amber is reward, lime is a power-up.
Config.Palette = {
	Background = Color3.fromRGB(11, 16, 38),
	Panel = Color3.fromRGB(19, 26, 54),
	PanelEdge = Color3.fromRGB(42, 54, 96),
	Player = Color3.fromRGB(34, 211, 238),
	Hazard = Color3.fromRGB(244, 114, 182),
	Star = Color3.fromRGB(251, 191, 36),
	Power = Color3.fromRGB(163, 230, 53),
	Text = Color3.fromRGB(242, 237, 228),
	DimText = Color3.fromRGB(160, 168, 200),
	Danger = Color3.fromRGB(239, 68, 68),
}

-- The playfield, in pixels. The arena is a fixed box centred on screen,
-- so the game reads the same on any screen size.
Config.Arena = { Width = 760, Height = 520 }
Config.Player = { Size = 34, Speed = 380, DashSpeed = 980, DashTime = 0.16, DashCooldown = 1.6 }

-- One run starts here. Lives are the run's length; the level clock is
-- the run's difficulty curve.
Config.Start = { Lives = 3, Level = 1, ScoreToLevel = 150 }

-- Hazards. Each kind has its own movement, so the player must read the
-- shape, not just dodge a blob.
--   drifter: straight across, the baseline threat.
--   weaver: sine wave, it covers a lane instead of a line.
--   chaser: slow, turns toward the player, but it burns out fast.
Config.Hazards = {
	drifter = { Speed = 170, Size = 30, Score = 0, Weight = 55 },
	weaver = { Speed = 140, Size = 34, Score = 0, Weight = 30, Wave = 90, WaveSpeed = 3.2 },
	chaser = { Speed = 105, Size = 30, Score = 0, Weight = 15, Lifetime = 4.5 },
}

-- Spawning. The interval shrinks and the speed grows with the level,
-- so level 1 teaches and level 5+ pressures.
Config.Spawn = {
	BaseInterval = 1.15,
	MinInterval = 0.38,
	IntervalPerLevel = 0.09,
	SpeedPerLevel = 16,
	StarInterval = 2.4,
	PowerChance = 0.14,
}

-- Rewards. A star is 10 points; the combo multiplies it. A near miss
-- (a hazard passing within 46 px without a hit) pays 2 and feeds the
-- combo, so brave play is worth more than hiding in a corner.
Config.Scoring = {
	Star = 10,
	NearMiss = 2,
	NearMissRadius = 46,
	ComboStep = 4,
	ComboMax = 8,
}

-- Power-ups. Each one changes the rules for a few seconds, so the
-- player has a reason to chase them instead of only dodging.
--   shield: the next hit costs nothing.
--   slowmo: hazards move at half speed for 5 seconds.
--   magnet: stars fly to the player for 6 seconds.
Config.PowerUps = {
	shield = { Duration = 0, Color = Color3.fromRGB(96, 165, 250), Label = "SHIELD" },
	slowmo = { Duration = 5, Color = Color3.fromRGB(192, 132, 252), Label = "SLOW-MO" },
	magnet = { Duration = 6, Color = Color3.fromRGB(163, 230, 53), Label = "MAGNET" },
}

-- Sectors. The run is five sectors, not one endless arena. Each
-- sector asks for a number of stars: collect them all and the portal
-- opens to the next sector, faster and with a new accent. Sector 5
-- holds the PRISM WARDEN, a boss that hunts the player and never
-- burns out — clearing sector 5 wins the run. The objective is
-- always on screen, so the player knows exactly what "winning"
-- means. Hostile names the sector's signature hazard for the
-- select-screen cards; Threat is its 1–5 bar.
Config.Zones = {
	{ Name = "CRIMSON GATE", Stars = 8, SpeedMul = 1.0, Accent = Color3.fromRGB(239, 68, 68), Hostile = "SHARD", Threat = 1 },
	{ Name = "AMBER DRIFT", Stars = 10, SpeedMul = 1.15, Accent = Color3.fromRGB(251, 191, 36), Hostile = "DRIFTER", Threat = 2 },
	{ Name = "EMERALD CORE", Stars = 12, SpeedMul = 1.3, Accent = Color3.fromRGB(52, 211, 153), Hostile = "LATTICE", Threat = 3 },
	{ Name = "AZURE VAULT", Stars = 14, SpeedMul = 1.45, Accent = Color3.fromRGB(96, 165, 250), Hostile = "LANCER", Threat = 4 },
	{ Name = "VIOLET NEXUS", Stars = 16, SpeedMul = 1.6, Accent = Color3.fromRGB(192, 132, 252), Hostile = "BOSS: PRISM", Threat = 5, Boss = true },
}
Config.ZoneClearBonus = 50

-- The boss. A big hunting diamond that never burns out and never
-- dies to one touch: a hit costs the player a life (or the shield)
-- and the Warden retreats to an edge, then comes back.
Config.Boss = { Name = "PRISM WARDEN", Size = 64, Speed = 135 }

-- Sound. Asset ids are empty on purpose: sounds only play when the
-- experience's owner drops real uploaded asset ids in here. An empty
-- id is silence, never an error (SoundManager guards every play).
Config.Sounds = { Coin = "", Hit = "", Dash = "", Power = "", Over = "", Level = "" }

-- Remotes. The client owns the arcade loop; the server owns the record.
-- The client only ever sends a finished run's score, and the server
-- only ever answers with the player's best.
Config.Remotes = { SubmitScore = "SubmitScore", RequestBest = "RequestBest" }

-- Persistence. Best scores live in a DataStore when the service
-- answers, and in memory when it does not (Studio with API access off,
-- or a service hiccup). The game never blocks on it.
Config.DataStore = { Name = "NeonRushBest_v1", Scope = "best" }

return Config
