-- Game.client.luau — one job: the arcade loop itself.
-- It owns the run's state (score, lives, level, combo, dash, power-ups)
-- and steps it every frame: move the player, move the hazards, test
-- collisions, pay out stars, and end the run. The UI only draws what
-- this script tells it; the server only records the finished score.
-- The loop runs on the client because a dodger lives or dies on input
-- latency: no round trip may sit between a key press and the orb.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local UI = require(script.Parent:WaitForChild("UI"))
local Effects = require(script.Parent:WaitForChild("Effects"))
local Input = require(script.Parent:WaitForChild("Input"))
local Sound = require(script.Parent:WaitForChild("Sound"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Build the interface FIRST, before anything that can wait. The title
-- screen must appear the moment the client joins: if the server's
-- remotes are slow (or never arrive), the game still shows and plays,
-- and only the best-score record is skipped.
UI.build(playerGui)

-- The server's remotes, waited for with a bound. If they do not show
-- in 10 seconds the game still runs: submitScore and requestBest stay
-- nil and every use of them is guarded.
local submitScore = ReplicatedStorage:WaitForChild(Config.Remotes.SubmitScore, 10)
local requestBest = ReplicatedStorage:WaitForChild(Config.Remotes.RequestBest, 10)

local W = Config.Arena.Width
local H = Config.Arena.Height

-- The run's state, kept in this one table and nowhere else.
local run = {
	phase = "title",
	score = 0,
	best = 0,
	lives = Config.Start.Lives,
	level = Config.Start.Level,
	zone = 1,
	zoneStars = 0,
	comboCount = 0,
	comboMult = 1,
	pos = Vector2.new(W / 2, H / 2),
	lastDir = Vector2.new(0, -1),
	dashUntil = 0,
	dashCooldownUntil = 0,
	invulnerableUntil = 0,
	shield = false,
	slowmoUntil = 0,
	magnetUntil = 0,
	hazardTimer = 1,
	starTimer = 0,
	ghostTimer = 0,
}

local hazards = {}
local stars = {}
local powers = {}

-- Forward declarations: takeHit ends the run and triggerDash starts
-- it, so both names must exist before those functions are defined.
local startGame
local endGame

-- intervalForLevel shrinks the hazard gap as the level rises, down to
-- the floor. Level 1 teaches; level 5 and up pressures.
local function intervalForLevel(level)
	return math.max(
		Config.Spawn.MinInterval,
		Config.Spawn.BaseInterval - (level - 1) * Config.Spawn.IntervalPerLevel
	)
end

-- levelForScore turns the score into a level: every ScoreToLevel
-- points is one level up.
local function levelForScore(score)
	return 1 + math.floor(score / Config.Start.ScoreToLevel)
end

-- comboForCount turns consecutive collects into a multiplier, capped.
local function comboForCount(count)
	return math.min(Config.Scoring.ComboMax, 1 + math.floor(count / Config.Scoring.ComboStep))
end

-- makeEntity builds one arena child: a coloured shape at a position.
-- shape "square" | "diamond" | "circle" reads the kind at a glance.
local function makeEntity(parent, size, color, shape)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = UDim2.fromOffset(size, size)
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.ZIndex = 4
	if shape == "diamond" then
		frame.Rotation = 45
	elseif shape == "circle" then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = frame
	end
	frame.Parent = parent
	return frame
end

-- clearEntities destroys every live hazard, star and power-up. Used on
-- start and on game over, so a new run never inherits the old one.
local function clearEntities()
	for _, list in { hazards, stars, powers } do
		for i = #list, 1, -1 do
			list[i].frame:Destroy()
			table.remove(list, i)
		end
	end
end

-- spawnHazard picks a kind by weight, enters from a random edge, and
-- aims inward. The kind's shape tells the player how it moves.
local function spawnHazard()
	local arena = UI.getArena()
	local roll = math.random(100)
	local kind = "drifter"
	local def = Config.Hazards.drifter
	if roll > Config.Hazards.drifter.Weight + Config.Hazards.weaver.Weight then
		kind = "chaser"
		def = Config.Hazards.chaser
	elseif roll > Config.Hazards.drifter.Weight then
		kind = "weaver"
		def = Config.Hazards.weaver
	end
	local shape = kind == "weaver" and "diamond" or (kind == "chaser" and "circle" or "square")
	local frame = makeEntity(arena, def.Size, Config.Palette.Hazard, shape)
	local edge = math.random(4)
	local pos, vel
	local speed = (def.Speed + (run.level - 1) * Config.Spawn.SpeedPerLevel) * Config.Zones[run.zone].SpeedMul
	if edge == 1 then
		pos = Vector2.new(math.random(0, W), -40)
		vel = Vector2.new(math.random(-60, 60), speed)
	elseif edge == 2 then
		pos = Vector2.new(math.random(0, W), H + 40)
		vel = Vector2.new(math.random(-60, 60), -speed)
	elseif edge == 3 then
		pos = Vector2.new(-40, math.random(0, H))
		vel = Vector2.new(speed, math.random(-60, 60))
	else
		pos = Vector2.new(W + 40, math.random(0, H))
		vel = Vector2.new(-speed, math.random(-60, 60))
	end
	frame.Position = UDim2.fromOffset(pos.X, pos.Y)
	table.insert(hazards, {
		frame = frame,
		pos = pos,
		vel = vel,
		kind = kind,
		radius = def.Size / 2,
		born = os.clock(),
		lifetime = def.Lifetime or math.huge,
		nearMissed = false,
		phase = math.random() * math.pi * 2,
	})
end

-- spawnStar drops a collectible at a random spot, clear of the player.
local function spawnStar()
	local arena = UI.getArena()
	local pos
	repeat
		pos = Vector2.new(math.random(40, W - 40), math.random(40, H - 40))
	until (pos - run.pos).Magnitude > 90
	local frame = makeEntity(arena, 24, Config.Palette.Star, "diamond")
	local core = Instance.new("Frame")
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.Position = UDim2.fromScale(0.5, 0.5)
	core.Size = UDim2.fromOffset(10, 10)
	core.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	core.BorderSizePixel = 0
	core.ZIndex = 5
	local coreCorner = Instance.new("UICorner")
	coreCorner.CornerRadius = UDim.new(1, 0)
	coreCorner.Parent = core
	core.Parent = frame
	frame.Position = UDim2.fromOffset(pos.X, pos.Y)
	table.insert(stars, { frame = frame, pos = pos, radius = 12 })
end

-- spawnPowerUp drops one of the three power-ups at a random spot.
local function spawnPowerUp()
	local arena = UI.getArena()
	local kinds = { "shield", "slowmo", "magnet" }
	local kind = kinds[math.random(#kinds)]
	local def = Config.PowerUps[kind]
	local pos = Vector2.new(math.random(50, W - 50), math.random(50, H - 50))
	local frame = makeEntity(arena, 34, def.Color, "circle")
	local letter = Instance.new("TextLabel")
	letter.AnchorPoint = Vector2.new(0.5, 0.5)
	letter.Position = UDim2.fromScale(0.5, 0.5)
	letter.Size = UDim2.fromOffset(34, 34)
	letter.BackgroundTransparency = 1
	letter.Text = kind == "shield" and "S" or (kind == "slowmo" and "T" or "M")
	letter.TextColor3 = Color3.fromRGB(255, 255, 255)
	letter.TextSize = 18
	letter.Font = Enum.Font.GothamBold
	letter.ZIndex = 5
	letter.Parent = frame
	frame.Position = UDim2.fromOffset(pos.X, pos.Y)
	table.insert(powers, { frame = frame, pos = pos, radius = 17, kind = kind })
end

-- applyPowerUp switches one power-up on and announces it.
local function applyPowerUp(kind)
	local def = Config.PowerUps[kind]
	if kind == "shield" then
		run.shield = true
	elseif kind == "slowmo" then
		run.slowmoUntil = os.clock() + def.Duration
	elseif kind == "magnet" then
		run.magnetUntil = os.clock() + def.Duration
	end
	UI.banner(def.Label .. "!", def.Color)
	Sound.play("Power")
end

-- addScore pays points and steps the combo. Called by stars and near
-- misses, never directly by the loop.
local function addScore(points)
	run.score += points
	UI.setScore(run.score)
	local level = levelForScore(run.score)
	if level > run.level then
		run.level = level
		UI.setLevel(level)
		UI.banner("LEVEL " .. level, Config.Palette.Player)
		Effects.flash(UI.getFlash(), Color3.fromRGB(255, 255, 255))
		Sound.play("Level")
	end
end

-- stepCombo counts one clean collect toward the multiplier and pulses
-- the HUD when the multiplier steps up.
local function stepCombo()
	run.comboCount += 1
	local mult = comboForCount(run.comboCount)
	if mult > run.comboMult then
		run.comboMult = mult
		UI.setCombo(mult)
		UI.pulseCombo()
	end
end

-- zoneComplete pays the zone bonus, clears the field, and opens the
-- next zone — or wins the run when the last zone falls.
local function zoneComplete()
	local zoneDef = Config.Zones[run.zone]
	local bonus = Config.ZoneClearBonus * run.zone
	addScore(bonus)
	Effects.popup(UI.getArena(), run.pos, "ZONE CLEAR +" .. bonus, Config.Palette.Power)
	Sound.play("Level")
	for i = #hazards, 1, -1 do
		hazards[i].frame:Destroy()
		table.remove(hazards, i)
	end
	if run.zone >= #Config.Zones then
		UI.banner("ALL ZONES CLEAR!", Config.Palette.Player)
		endGame(true)
		return
	end
	run.zone += 1
	run.zoneStars = 0
	local nextDef = Config.Zones[run.zone]
	UI.setZone(run.zone, nextDef.Name, 0, nextDef.Stars)
	UI.setZoneAccent(nextDef.Accent)
	UI.banner("ZONE " .. run.zone .. " — " .. nextDef.Name, nextDef.Accent)
	run.invulnerableUntil = os.clock() + 2
	for _ = 1, 3 do
		spawnStar()
	end
end

-- collectStar pays the star (times the combo), feeds the combo, counts
-- it toward the zone's portal, and sometimes drops a power-up.
local function collectStar(i, star)
	star.frame:Destroy()
	table.remove(stars, i)
	local points = Config.Scoring.Star * run.comboMult
	addScore(points)
	stepCombo()
	run.zoneStars += 1
	local zoneDef = Config.Zones[run.zone]
	UI.setZone(run.zone, zoneDef.Name, run.zoneStars, zoneDef.Stars)
	Effects.burst(UI.getArena(), star.pos, Config.Palette.Star, 8)
	Effects.popup(UI.getArena(), star.pos, "+" .. points, Config.Palette.Star)
	Sound.play("Coin")
	if run.zoneStars >= zoneDef.Stars then
		zoneComplete()
		return
	end
	if math.random() < Config.Spawn.PowerChance then
		spawnPowerUp()
	end
end

-- takeHit resolves one hazard touching the player. A dash, the shield
-- or invulnerability each answer it differently; a real hit costs a
-- life, resets the combo, and ends the run at zero lives.
local function takeHit(hazard)
	local now = os.clock()
	if now < run.invulnerableUntil or now < run.dashUntil then
		return
	end
	if run.shield then
		run.shield = false
		Effects.burst(UI.getArena(), hazard.pos, Config.Palette.Power, 12)
		Effects.popup(UI.getArena(), run.pos, "SHIELD!", Config.Palette.Power)
		hazard.frame:Destroy()
		return
	end
	run.lives -= 1
	run.comboCount = 0
	run.comboMult = 1
	UI.setCombo(1)
	UI.setLives(run.lives)
	Effects.flash(UI.getFlash(), Config.Palette.Danger)
	Effects.shake(UI.getArena(), 9, 0.3)
	Effects.burst(UI.getArena(), run.pos, Config.Palette.Hazard, 14)
	Sound.play("Hit")
	if run.lives <= 0 then
		endGame()
	else
		run.invulnerableUntil = now + 1.5
	end
end

-- triggerDash fires the dash: a burst of speed in the held direction,
-- brief invulnerability, and a cooldown. Ignored unless playing.
local function triggerDash()
	if run.phase ~= "playing" then
		return
	end
	local now = os.clock()
	if now < run.dashCooldownUntil then
		return
	end
	local dir = Input.getMoveVector()
	if dir == Vector2.zero then
		dir = run.lastDir
	end
	run.lastDir = dir
	run.dashUntil = now + Config.Player.DashTime
	run.dashCooldownUntil = now + Config.Player.DashCooldown
	Sound.play("Dash")
end

-- startGame resets the run and opens the arena. Called from the title
-- (click or Enter) and from game over (R).
startGame = function()
	clearEntities()
	run.phase = "playing"
	run.score = 0
	run.lives = Config.Start.Lives
	run.level = Config.Start.Level
	run.zone = 1
	run.zoneStars = 0
	run.comboCount = 0
	run.comboMult = 1
	run.pos = Vector2.new(W / 2, H / 2)
	run.dashUntil = 0
	run.dashCooldownUntil = 0
	run.invulnerableUntil = 0
	run.shield = false
	run.slowmoUntil = 0
	run.magnetUntil = 0
	run.hazardTimer = 0.8
	run.starTimer = 0
	UI.hideScreens()
	UI.setScore(0)
	UI.setLevel(1)
	UI.setLives(run.lives)
	UI.setCombo(1)
	UI.setDashReady(true, 1)
	UI.setZone(1, Config.Zones[1].Name, 0, Config.Zones[1].Stars)
	UI.setZoneAccent(Config.Zones[1].Accent)
	UI.getPlayer().Position = UDim2.fromOffset(run.pos.X, run.pos.Y)
	for _ = 1, 3 do
		spawnStar()
	end
end

-- endGame closes the run, sends the score to the server for the
-- record, and shows the game-over screen with the best. won is true
-- when the run ended by clearing all three zones.
endGame = function(won)
	run.phase = "over"
	clearEntities()
	Sound.play("Over")
	local best = run.best
	if submitScore then
		submitScore:FireServer(run.score)
	end
	UI.showGameOver(run.score, math.max(best, run.score), won)
end

-- update is the per-frame step. It moves the player, the hazards, the
-- stars and the power-ups, tests every collision, and keeps the HUD
-- current. It only runs while the phase is playing.
local function update(dt)
	local now = os.clock()

	-- Move the player. A dash overrides the walk speed and the
	-- direction locks to the dash direction for its short life.
	local dir = Input.getMoveVector()
	if dir ~= Vector2.zero then
		run.lastDir = dir
	end
	local dashing = now < run.dashUntil
	local speed = dashing and Config.Player.DashSpeed or Config.Player.Speed
	local moveDir = dashing and run.lastDir or dir
	if moveDir ~= Vector2.zero then
		run.pos += moveDir * speed * dt
	end
	local r = Config.Player.Size / 2
	run.pos = Vector2.new(
		math.clamp(run.pos.X, r, W - r),
		math.clamp(run.pos.Y, r, H - r)
	)
	local playerFrame = UI.getPlayer()
	playerFrame.Position = UDim2.fromOffset(run.pos.X, run.pos.Y)
	-- Blink while invulnerable; a ring while the shield holds.
	if now < run.invulnerableUntil then
		playerFrame.BackgroundTransparency = (math.floor(now * 10) % 2 == 0) and 0.5 or 0
	else
		playerFrame.BackgroundTransparency = 0
	end
	-- Dash ghosts: a fading afterimage every few frames of the dash.
	if dashing and now >= run.ghostTimer then
		run.ghostTimer = now + 0.05
		local ghost = Instance.new("Frame")
		ghost.AnchorPoint = Vector2.new(0.5, 0.5)
		ghost.Position = UDim2.fromOffset(run.pos.X, run.pos.Y)
		ghost.Size = UDim2.fromOffset(Config.Player.Size, Config.Player.Size)
		ghost.BackgroundColor3 = Config.Palette.Player
		ghost.BackgroundTransparency = 0.5
		ghost.BorderSizePixel = 0
		ghost.ZIndex = 3
		local gc = Instance.new("UICorner")
		gc.CornerRadius = UDim.new(1, 0)
		gc.Parent = ghost
		ghost.Parent = UI.getArena()
		local tween = game:GetService("TweenService"):Create(ghost, TweenInfo.new(0.35), { BackgroundTransparency = 1 })
		tween:Play()
		tween.Completed:Connect(function()
			ghost:Destroy()
		end)
	end

	-- Spawn hazards on the level's clock.
	run.hazardTimer -= dt
	if run.hazardTimer <= 0 then
		spawnHazard()
		run.hazardTimer = intervalForLevel(run.level) * (0.85 + math.random() * 0.3)
	end
	-- Keep three stars on the field.
	run.starTimer -= dt
	if #stars < 3 and run.starTimer <= 0 then
		spawnStar()
		run.starTimer = Config.Spawn.StarInterval
	end

	-- Hazards: move, age, and test against the player.
	local slow = now < run.slowmoUntil and 0.5 or 1
	for i = #hazards, 1, -1 do
		local hz = hazards[i]
		local step = hz.vel * slow * dt
		if hz.kind == "weaver" then
			local perp = Vector2.new(-hz.vel.Y, hz.vel.X).Unit
			hz.pos += perp * math.sin((os.clock() - hz.born) * Config.Hazards.weaver.WaveSpeed) * Config.Hazards.weaver.Wave * dt
		elseif hz.kind == "chaser" then
			local toPlayer = (run.pos - hz.pos)
			if toPlayer.Magnitude > 1 then
				hz.vel = toPlayer.Unit * (Config.Hazards.chaser.Speed + (run.level - 1) * Config.Spawn.SpeedPerLevel) * Config.Zones[run.zone].SpeedMul
			end
		end
		hz.pos += step
		hz.frame.Position = UDim2.fromOffset(hz.pos.X, hz.pos.Y)
		local dist = (hz.pos - run.pos).Magnitude
		local hitR = hz.radius + r
		if dist < hitR * 0.9 then
			hz.frame:Destroy()
			table.remove(hazards, i)
			takeHit(hz)
			if run.phase ~= "playing" then
				return
			end
		elseif dist < hitR + Config.Scoring.NearMissRadius and not hz.nearMissed then
			hz.nearMissed = true
			addScore(Config.Scoring.NearMiss)
			stepCombo()
			Effects.popup(UI.getArena(), hz.pos, "NEAR MISS +2", Config.Palette.DimText)
		elseif hz.pos.X < -80 or hz.pos.X > W + 80 or hz.pos.Y < -80 or hz.pos.Y > H + 80 then
			hz.frame:Destroy()
			table.remove(hazards, i)
		elseif now - hz.born > hz.lifetime then
			hz.frame:Destroy()
			table.remove(hazards, i)
		end
	end

	-- Stars: the magnet pulls them in; a touch collects.
	for i = #stars, 1, -1 do
		local star = stars[i]
		if now < run.magnetUntil then
			local toPlayer = run.pos - star.pos
			if toPlayer.Magnitude < 260 and toPlayer.Magnitude > 1 then
				star.pos += toPlayer.Unit * 320 * dt
				star.frame.Position = UDim2.fromOffset(star.pos.X, star.pos.Y)
			end
		end
		if (star.pos - run.pos).Magnitude < star.radius + r then
			collectStar(i, star)
		end
	end

	-- Power-ups: a touch switches one on.
	for i = #powers, 1, -1 do
		local pw = powers[i]
		if (pw.pos - run.pos).Magnitude < pw.radius + r then
			applyPowerUp(pw.kind)
			pw.frame:Destroy()
			table.remove(powers, i)
		end
	end

	-- Dash meter: ready, or the cooldown as a percentage.
	UI.setDashReady(now >= run.dashCooldownUntil, 1 - math.clamp((run.dashCooldownUntil - now) / Config.Player.DashCooldown, 0, 1))
end

-- Boot: ask the server for the saved best, bind the keys, and step
-- the loop. A click anywhere on the title starts. On a touch device
-- the stick and DASH button appear instead of the keyboard hints.
-- (The interface was already built at the top of this script, before
-- the remote waits, so the title is on screen from the first frame.)
if Input.isTouch() then
	UI.showTouchControls()
	Input.setupJoystick(UI.getStickBase(), UI.getStickKnob())
	UI.getDashButton().Activated:Connect(triggerDash)
end
do
	local ok, best = false, nil
	if requestBest then
		ok, best = pcall(function()
			return requestBest:InvokeServer()
		end)
	end
	if ok and typeof(best) == "number" then
		run.best = best
	end
	UI.setBest(run.best)
	UI.setScore(0)
	UI.setLevel(1)
	UI.setLives(run.lives)
	UI.showTitle()
end

if submitScore then
	submitScore.OnClientEvent:Connect(function(best)
		if typeof(best) == "number" and best > run.best then
			run.best = best
			UI.setBest(best)
		end
	end)
end

Input.bindDash(triggerDash)
Input.bindStart(function()
	if run.phase == "title" then
		startGame()
	end
end)
Input.bindRestart(function()
	if run.phase == "over" then
		startGame()
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 and run.phase == "title" then
		startGame()
	end
end)

-- The LAUNCH button on the zone-select screen. A click on it is
-- consumed by the GUI (processed), so the InputBegan handler above
-- never sees it — this is its own connection. Without it the button
-- is dead: it looks clickable and does nothing.
local launchButton = UI.getLaunchButton()
if launchButton then
	launchButton.MouseButton1Click:Connect(function()
		if run.phase == "title" then
			startGame()
		end
	end)
end

RunService.RenderStepped:Connect(function(dt)
	if run.phase == "playing" then
		update(dt)
	end
end)
