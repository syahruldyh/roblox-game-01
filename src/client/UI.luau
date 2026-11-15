-- UI.luau — one job: build every pixel of chrome and keep it current.
-- The title screen, the HUD (score, best, level, lives, combo, dash),
-- the banner announcements and the game-over screen. It never knows
-- the rules: the game tells it what to show, and it shows it. Roblox's
-- own menu buttons sit over the top-left corner, so the HUD bar sits
-- below them (y 48), clear of the corner.

local TweenService = game:GetService("TweenService")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local UI = {}
local P = Config.Palette

local gui = nil
local arena = nil
local playerFrame = nil
local flashOverlay = nil
local hud = {}
local titleScreen = nil
local overScreen = nil
local bannerLabel = nil
local launchButton = nil

-- makeLabel builds a centred text label. zindex is REQUIRED whenever
-- the label sits inside a panel with a raised ZIndex: a label keeps
-- the default ZIndex 1, and a label with a lower ZIndex than its
-- parent renders BEHIND the parent's background, invisible. So every
-- label here passes its parent's ZIndex + 1. (That was the blank-sky
-- bug: the title and HUD labels all sat at ZIndex 1 inside ZIndex 10
-- and 20 panels, so only the zone label, which had an explicit 6,
-- ever showed — dimmed through the title overlay.)
local function makeLabel(parent, name, text, size, color, font, zindex)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextSize = size
	label.TextColor3 = color
	label.Font = font or Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = zindex or 1
	label.Parent = parent
	return label
end

local function makePanel(parent, name, size, position, color)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

-- build creates the whole interface under the player's PlayerGui and
-- keeps the handles for the setters below. Called once, on join.
function UI.build(playerGui)
	gui = Instance.new("ScreenGui")
	gui.Name = "NeonRushGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10

	local background = makePanel(gui, "Background", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), P.Background)
	background.ZIndex = 1

	-- HUD bar: score, level, best, lives. Below Roblox's menu corner.
	local bar = makePanel(gui, "HudBar", UDim2.new(1, -32, 0, 52), UDim2.new(0, 16, 0, 48), P.Panel)
	bar.ZIndex = 10
	local stroke = Instance.new("UIStroke")
	stroke.Color = P.PanelEdge
	stroke.Thickness = 1
	stroke.Parent = bar
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = bar

	hud.score = makeLabel(bar, "Score", "SCORE  0", 26, P.Text, nil, 11)
	hud.score.AnchorPoint = Vector2.new(0, 0.5)
	hud.score.Position = UDim2.new(0, 20, 0.5, 0)
	hud.score.Size = UDim2.new(0.28, 0, 1, 0)
	hud.score.TextXAlignment = Enum.TextXAlignment.Left
	hud.level = makeLabel(bar, "Level", "LEVEL 1", 22, P.Player, nil, 11)
	hud.level.AnchorPoint = Vector2.new(0.5, 0.5)
	hud.level.Position = UDim2.new(0.5, 0, 0.5, 0)
	hud.level.Size = UDim2.new(0.2, 0, 1, 0)
	hud.best = makeLabel(bar, "Best", "BEST  0", 22, P.DimText, nil, 11)
	hud.best.AnchorPoint = Vector2.new(1, 0.5)
	hud.best.Position = UDim2.new(0.72, -8, 0.5, 0)
	hud.best.Size = UDim2.new(0.2, 0, 1, 0)
	hud.best.TextXAlignment = Enum.TextXAlignment.Right
	hud.lives = makeLabel(bar, "Lives", "♥♥♥", 24, P.Hazard, nil, 11)
	hud.lives.AnchorPoint = Vector2.new(1, 0.5)
	hud.lives.Position = UDim2.new(1, -16, 0.5, 0)
	hud.lives.Size = UDim2.new(0.12, 0, 1, 0)
	hud.lives.TextXAlignment = Enum.TextXAlignment.Right

	-- The arena: the playfield box, centred under the HUD.
	arena = makePanel(gui, "Arena", UDim2.fromOffset(Config.Arena.Width, Config.Arena.Height), UDim2.new(0.5, 0, 0.5, 26), P.Panel)
	arena.AnchorPoint = Vector2.new(0.5, 0.5)
	arena.ZIndex = 2
	arena.ClipsDescendants = true
	local arenaStroke = Instance.new("UIStroke")
	arenaStroke.Color = P.Player
	arenaStroke.Thickness = 2
	arenaStroke.Parent = arena
	local arenaCorner = Instance.new("UICorner")
	arenaCorner.CornerRadius = UDim.new(0, 12)
	arenaCorner.Parent = arena
	hud.arenaStroke = arenaStroke

	-- Zone progress: the run's objective, pinned to the top of the
	-- arena. "ZONE 1 · EMBER DRIFT — STARS 3/8" plus a fill bar.
	hud.zoneLabel = makeLabel(arena, "ZoneLabel", "SECTOR 1 · CRIMSON GATE", 17, P.Text, nil, 6)
	hud.zoneLabel.AnchorPoint = Vector2.new(0.5, 0)
	hud.zoneLabel.Position = UDim2.new(0.5, 0, 0, 10)
	hud.zoneLabel.Size = UDim2.new(1, -24, 0, 24)
	hud.zoneBarBg = makePanel(arena, "ZoneBarBg", UDim2.new(0, 260, 0, 6), UDim2.new(0.5, -130, 0, 36), P.PanelEdge)
	hud.zoneBarBg.ZIndex = 6
	local zoneBarCorner = Instance.new("UICorner")
	zoneBarCorner.CornerRadius = UDim.new(1, 0)
	zoneBarCorner.Parent = hud.zoneBarBg
	hud.zoneBarFill = makePanel(hud.zoneBarBg, "ZoneBarFill", UDim2.new(0, 0, 1, 0), UDim2.new(0, 0, 0, 0), P.Star)
	hud.zoneBarFill.ZIndex = 7
	local zoneFillCorner = Instance.new("UICorner")
	zoneFillCorner.CornerRadius = UDim.new(1, 0)
	zoneFillCorner.Parent = hud.zoneBarFill

	-- Touch controls: a virtual stick (bottom-left) and a DASH button
	-- (bottom-right). Hidden on desktop; shown when the device has a
	-- touch screen, so the game plays on a phone as well as a keyboard.
	hud.stickBase = makePanel(gui, "StickBase", UDim2.fromOffset(120, 120), UDim2.new(0, 36, 1, -156), P.Panel)
	hud.stickBase.BackgroundTransparency = 0.4
	hud.stickBase.ZIndex = 12
	hud.stickBase.Visible = false
	local stickCorner = Instance.new("UICorner")
	stickCorner.CornerRadius = UDim.new(1, 0)
	stickCorner.Parent = hud.stickBase
	local stickStroke = Instance.new("UIStroke")
	stickStroke.Color = P.Player
	stickStroke.Thickness = 2
	stickStroke.Transparency = 0.4
	stickStroke.Parent = hud.stickBase
	hud.stickKnob = makePanel(hud.stickBase, "StickKnob", UDim2.fromOffset(52, 52), UDim2.fromScale(0.5, 0.5), P.Player)
	hud.stickKnob.AnchorPoint = Vector2.new(0.5, 0.5)
	hud.stickKnob.BackgroundTransparency = 0.25
	hud.stickKnob.ZIndex = 13
	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = hud.stickKnob
	hud.dashButton = Instance.new("TextButton")
	hud.dashButton.Name = "DashButton"
	hud.dashButton.AnchorPoint = Vector2.new(1, 1)
	hud.dashButton.Position = UDim2.new(1, -36, 1, -36)
	hud.dashButton.Size = UDim2.fromOffset(120, 120)
	hud.dashButton.BackgroundColor3 = P.Player
	hud.dashButton.BackgroundTransparency = 0.4
	hud.dashButton.Text = "DASH"
	hud.dashButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	hud.dashButton.TextSize = 24
	hud.dashButton.Font = Enum.Font.GothamBold
	hud.dashButton.ZIndex = 12
	hud.dashButton.Visible = false
	local dashCorner = Instance.new("UICorner")
	dashCorner.CornerRadius = UDim.new(1, 0)
	dashCorner.Parent = hud.dashButton

	-- The player: a glowing cyan orb. The game moves this frame. It
	-- starts centred in the arena, so the title screen shows it in the
	-- middle instead of half-clipped at the corner.
	playerFrame = makePanel(arena, "Player", UDim2.fromOffset(Config.Player.Size, Config.Player.Size), UDim2.fromOffset(Config.Arena.Width / 2, Config.Arena.Height / 2), P.Player)
	playerFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	playerFrame.ZIndex = 5
	local orbCorner = Instance.new("UICorner")
	orbCorner.CornerRadius = UDim.new(1, 0)
	orbCorner.Parent = playerFrame
	local orbStroke = Instance.new("UIStroke")
	orbStroke.Color = Color3.fromRGB(255, 255, 255)
	orbStroke.Thickness = 2
	orbStroke.Transparency = 0.4
	orbStroke.Parent = playerFrame

	-- Combo + dash meters, under the arena.
	hud.combo = makeLabel(gui, "Combo", "", 20, P.Star, nil, 10)
	hud.combo.AnchorPoint = Vector2.new(0.5, 0)
	hud.combo.Position = UDim2.new(0.5, 0, 0.5, 26 + Config.Arena.Height / 2 + 10)
	hud.combo.Size = UDim2.new(0, 400, 0, 28)
	hud.dash = makeLabel(gui, "Dash", "DASH READY  [SPACE]", 15, P.DimText, nil, 10)
	hud.dash.AnchorPoint = Vector2.new(0.5, 0)
	hud.dash.Position = UDim2.new(0.5, 0, 0.5, 26 + Config.Arena.Height / 2 + 38)
	hud.dash.Size = UDim2.new(0, 400, 0, 22)

	-- Banner: big centre announcements (level up, power-up, warnings).
	bannerLabel = makeLabel(gui, "Banner", "", 40, P.Text, nil, 11)
	bannerLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	bannerLabel.Position = UDim2.fromScale(0.5, 0.42)
	bannerLabel.Size = UDim2.new(0, 700, 0, 56)
	bannerLabel.TextTransparency = 1

	-- Title screen: a sector-select board, not a blank title. The
	-- cover is this screen, so it has to prove the whole game at a
	-- glance: the prism, five sectors with their hostile and threat,
	-- the LAUNCH button, and the controls. Every label sits at
	-- ZIndex 21, above the screen's own ZIndex 20 (see makeLabel).
	titleScreen = makePanel(gui, "TitleScreen", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), P.Background)
	titleScreen.BackgroundTransparency = 0.25
	titleScreen.ZIndex = 20
	local title = makeLabel(titleScreen, "Title", "PRISM DRIVE", 64, P.Player, nil, 21)
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.new(0.5, 0, 0.09, 0)
	title.Size = UDim2.new(0, 800, 0, 80)
	local subtitle = makeLabel(titleScreen, "Subtitle", "REFRACT THE DARK  //  RECLAIM THE SPECTRUM", 20, P.DimText, nil, 21)
	subtitle.AnchorPoint = Vector2.new(0.5, 0.5)
	subtitle.Position = UDim2.new(0.5, 0, 0.155, 0)
	subtitle.Size = UDim2.new(0, 800, 0, 28)
	-- The prism: a white triangle glyph with one white beam in from
	-- the left and five coloured beams fanning out to the right.
	local prism = makeLabel(titleScreen, "Prism", "△", 56, Color3.fromRGB(255, 255, 255), nil, 21)
	prism.AnchorPoint = Vector2.new(0.5, 0.5)
	prism.Position = UDim2.new(0.5, 0, 0.225, 0)
	prism.Size = UDim2.new(0, 80, 0, 64)
	local beamIn = Instance.new("Frame")
	beamIn.Name = "BeamIn"
	beamIn.AnchorPoint = Vector2.new(1, 0.5)
	beamIn.Position = UDim2.new(0.5, -40, 0.225, 0)
	beamIn.Size = UDim2.new(0, 240, 0, 4)
	beamIn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	beamIn.BorderSizePixel = 0
	beamIn.ZIndex = 21
	beamIn.Parent = titleScreen
	local beamColors = {
		Color3.fromRGB(239, 68, 68),
		Color3.fromRGB(251, 191, 36),
		Color3.fromRGB(52, 211, 153),
		Color3.fromRGB(34, 211, 238),
		Color3.fromRGB(192, 132, 252),
	}
	local beamAngles = { -16, -8, 0, 8, 16 }
	for i = 1, 5 do
		local beam = Instance.new("Frame")
		beam.Name = "Beam" .. i
		beam.AnchorPoint = Vector2.new(0.5, 0.5)
		beam.Position = UDim2.new(0.5, 150, 0.225, 0)
		beam.Size = UDim2.new(0, 300, 0, 4)
		beam.BackgroundColor3 = beamColors[i]
		beam.BorderSizePixel = 0
		beam.Rotation = beamAngles[i]
		beam.ZIndex = 21
		beam.Parent = titleScreen
	end
	local selectLabel = makeLabel(titleScreen, "SelectLabel", "SELECT SECTOR", 18, P.Text, nil, 21)
	selectLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	selectLabel.Position = UDim2.new(0.5, 0, 0.31, 0)
	selectLabel.Size = UDim2.new(0, 400, 0, 26)
	-- Five sector cards, one per Config.Zones entry. Each card shows
	-- its number, name, signature hostile, star count and a 1–5
	-- threat bar. Sector 1 carries the bright stroke: the run
	-- always starts there.
	local cardXs = { 0.0125, 0.2075, 0.4025, 0.5975, 0.7925 }
	for i, def in ipairs(Config.Zones) do
		local card = makePanel(titleScreen, "SectorCard" .. i, UDim2.new(0.185, 0, 0, 132), UDim2.new(cardXs[i], 0, 0.35, 0), P.Panel)
		card.ZIndex = 20
		local stroke = Instance.new("UIStroke")
		stroke.Color = def.Accent
		stroke.Thickness = (i == 1) and 3 or 1
		stroke.Parent = card
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = card
		local no = makeLabel(card, "SectorNo", "SECTOR 0" .. i, 12, P.DimText, nil, 21)
		no.AnchorPoint = Vector2.new(0.5, 0)
		no.Position = UDim2.new(0.5, 0, 0, 8)
		no.Size = UDim2.new(1, 0, 0, 16)
		local nm = makeLabel(card, "SectorName", def.Name, 17, def.Accent, nil, 21)
		nm.AnchorPoint = Vector2.new(0.5, 0)
		nm.Position = UDim2.new(0.5, 0, 0, 26)
		nm.Size = UDim2.new(1, -8, 0, 24)
		local hostile = makeLabel(card, "Hostile", "HOSTILE: " .. def.Hostile, 13, P.DimText, nil, 21)
		hostile.AnchorPoint = Vector2.new(0.5, 0)
		hostile.Position = UDim2.new(0.5, 0, 0, 52)
		hostile.Size = UDim2.new(1, -8, 0, 18)
		local stars = makeLabel(card, "Stars", def.Stars .. " STARS", 13, P.Star, nil, 21)
		stars.AnchorPoint = Vector2.new(0.5, 0)
		stars.Position = UDim2.new(0.5, 0, 0, 72)
		stars.Size = UDim2.new(1, -8, 0, 18)
		for b = 1, 5 do
			local bar = Instance.new("Frame")
			bar.Name = "Threat" .. b
			bar.AnchorPoint = Vector2.new(0, 0.5)
			bar.Position = UDim2.new(0.5, -44 + (b - 1) * 18, 0, 108)
			bar.Size = UDim2.new(0, 14, 0, 6)
			bar.BackgroundColor3 = (b <= def.Threat) and def.Accent or P.PanelEdge
			bar.BorderSizePixel = 0
			bar.ZIndex = 21
			bar.Parent = card
		end
	end
	local flavor = makeLabel(titleScreen, "Flavor", "SPLINTERED LIGHT SHARDS DRIFT THROUGH THE GATE", 14, P.DimText, nil, 21)
	flavor.AnchorPoint = Vector2.new(0.5, 0.5)
	flavor.Position = UDim2.new(0.5, 0, 0.565, 0)
	flavor.Size = UDim2.new(0, 800, 0, 22)
	launchButton = Instance.new("TextButton")
	launchButton.Name = "Launch"
	launchButton.AnchorPoint = Vector2.new(0.5, 0.5)
	launchButton.Position = UDim2.new(0.5, 0, 0.63, 0)
	launchButton.Size = UDim2.new(0, 260, 0, 52)
	launchButton.BackgroundColor3 = P.Panel
	launchButton.Text = "LAUNCH  >>"
	launchButton.TextColor3 = P.Player
	launchButton.TextSize = 24
	launchButton.Font = Enum.Font.GothamBold
	launchButton.ZIndex = 21
	launchButton.Parent = titleScreen
	local launchStroke = Instance.new("UIStroke")
	launchStroke.Color = P.Player
	launchStroke.Thickness = 2
	launchStroke.Parent = launchButton
	local launchCorner = Instance.new("UICorner")
	launchCorner.CornerRadius = UDim.new(0, 8)
	launchCorner.Parent = launchButton
	local controls = makeLabel(titleScreen, "Controls", "WASD / ARROWS MOVE  •  SPACE DASH\nCollect stars, clear 5 sectors, beat the PRISM WARDEN — 3 hits and the run is over.\nTouch: drag the stick to move, tap DASH.", 16, P.DimText, nil, 21)
	controls.AnchorPoint = Vector2.new(0.5, 0.5)
	controls.Position = UDim2.new(0.5, 0, 0.73, 0)
	controls.Size = UDim2.new(0, 800, 0, 66)
	hud.titleBest = makeLabel(titleScreen, "TitleBest", "", 20, P.DimText, nil, 21)
	hud.titleBest.AnchorPoint = Vector2.new(0.5, 0.5)
	hud.titleBest.Position = UDim2.new(0.5, 0, 0.85, 0)
	hud.titleBest.Size = UDim2.new(0, 700, 0, 30)

	-- Game-over screen: the run's epitaph, with the score and the best.
	overScreen = makePanel(gui, "OverScreen", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), P.Background)
	overScreen.BackgroundTransparency = 0.25
	overScreen.ZIndex = 20
	overScreen.Visible = false
	local over = makeLabel(overScreen, "Over", "GAME OVER", 64, P.Hazard, nil, 21)
	over.AnchorPoint = Vector2.new(0.5, 0.5)
	over.Position = UDim2.new(0.5, 0, 0.36, 0)
	over.Size = UDim2.new(0, 700, 0, 80)
	hud.finalScore = makeLabel(overScreen, "FinalScore", "SCORE  0", 30, P.Text, nil, 21)
	hud.finalScore.AnchorPoint = Vector2.new(0.5, 0.5)
	hud.finalScore.Position = UDim2.new(0.5, 0, 0.5, 0)
	hud.finalScore.Size = UDim2.new(0, 700, 0, 44)
	hud.overBest = makeLabel(overScreen, "OverBest", "BEST  0", 22, P.DimText, nil, 21)
	hud.overBest.AnchorPoint = Vector2.new(0.5, 0.5)
	hud.overBest.Position = UDim2.new(0.5, 0, 0.58, 0)
	hud.overBest.Size = UDim2.new(0, 700, 0, 32)
	local again = makeLabel(overScreen, "AgainHint", "PRESS R TO PLAY AGAIN", 24, P.Star, nil, 21)
	again.AnchorPoint = Vector2.new(0.5, 0.5)
	again.Position = UDim2.new(0.5, 0, 0.7, 0)
	again.Size = UDim2.new(0, 700, 0, 40)

	-- Flash overlay: full-screen colour wash for hits and level-ups.
	flashOverlay = makePanel(gui, "Flash", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), P.Danger)
	flashOverlay.BackgroundTransparency = 1
	flashOverlay.ZIndex = 30

	gui.Parent = playerGui
	return gui
end

function UI.setScore(score)
	hud.score.Text = "SCORE  " .. score
end

function UI.setBest(best)
	hud.best.Text = "BEST  " .. best
	if hud.titleBest then
		hud.titleBest.Text = best > 0 and ("BEST  " .. best) or ""
	end
end

function UI.setLevel(level)
	hud.level.Text = "LEVEL " .. level
end

function UI.setLives(lives)
	local hearts = ""
	for _ = 1, lives do
		hearts ..= "♥"
	end
	hud.lives.Text = hearts
end

-- setCombo shows the multiplier when it is above x1, and hides it at x1.
function UI.setCombo(mult)
	if mult > 1 then
		hud.combo.Text = "COMBO x" .. mult
	else
		hud.combo.Text = ""
	end
end

-- pulseCombo grows the combo label briefly when the multiplier steps up.
function UI.pulseCombo()
	local base = hud.combo.TextSize
	local up = TweenService:Create(hud.combo, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextSize = base + 8,
	})
	local down = TweenService:Create(hud.combo, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextSize = base,
	})
	up:Play()
	up.Completed:Connect(function()
		down:Play()
	end)
end

-- setDashReady shows READY or the cooldown as a percentage.
function UI.setDashReady(ready, frac)
	if ready then
		hud.dash.Text = "DASH READY  [SPACE]"
		hud.dash.TextColor3 = P.Player
	else
		hud.dash.Text = "DASH  " .. math.floor(frac * 100) .. "%"
		hud.dash.TextColor3 = P.DimText
	end
end

-- banner flashes a big centre message and fades it out.
function UI.banner(text, color)
	bannerLabel.Text = text
	bannerLabel.TextColor3 = color or P.Text
	bannerLabel.TextTransparency = 0
	local tween = TweenService:Create(bannerLabel, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 1,
	})
	tween:Play()
end

-- setZone shows the current zone and how many of its stars are
-- collected, and fills the progress bar.
function UI.setZone(zoneIndex, name, got, need)
	hud.zoneLabel.Text = "SECTOR " .. zoneIndex .. " · " .. name .. "  —  STARS " .. got .. "/" .. need
	hud.zoneBarFill.Size = UDim2.new(math.clamp(got / need, 0, 1), 0, 1, 0)
end

-- setZoneAccent recolors the arena's stroke to the zone's accent.
function UI.setZoneAccent(color)
	hud.arenaStroke.Color = color
end

-- showTouchControls reveals the stick and the DASH button (touch
-- devices only; desktop keeps the keyboard).
function UI.showTouchControls()
	hud.stickBase.Visible = true
	hud.dashButton.Visible = true
end

function UI.getStickBase()
	return hud.stickBase
end

function UI.getStickKnob()
	return hud.stickKnob
end

function UI.getDashButton()
	return hud.dashButton
end

function UI.showTitle()
	titleScreen.Visible = true
	overScreen.Visible = false
end

-- showGameOver fills in the final numbers and shows the screen. A win
-- (all three zones cleared) reads differently from a loss.
function UI.showGameOver(score, best, won)
	hud.finalScore.Text = "SCORE  " .. score
	hud.overBest.Text = "BEST  " .. best
	local overTitle = overScreen:FindFirstChild("Over")
	if won then
		overTitle.Text = "ALL SECTORS CLEAR!"
		overTitle.TextColor3 = P.Player
	else
		overTitle.Text = "GAME OVER"
		overTitle.TextColor3 = P.Hazard
	end
	overScreen.Visible = true
	titleScreen.Visible = false
end

function UI.hideScreens()
	titleScreen.Visible = false
	overScreen.Visible = false
end

function UI.getArena()
	return arena
end

function UI.getPlayer()
	return playerFrame
end

function UI.getFlash()
	return flashOverlay
end

function UI.getLaunchButton()
	return launchButton
end

return UI
