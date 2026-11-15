-- Effects.luau — one job: every bit of juice the game shows.
-- Particles, screen shake, hit flash, floating score popups and the
-- combo pulse. Nothing here knows the rules; it only makes an action
-- look and feel like something happened. All tweens clean up after
-- themselves, so the loop never leaks frames.

local TweenService = game:GetService("TweenService")

local Effects = {}

-- burst sprays small squares out of a point and fades them away. Used
-- for a collected star, a destroyed hazard and a power-up pickup.
function Effects.burst(parent, position, color, count)
	count = count or 10
	for _ = 1, count do
		local piece = Instance.new("Frame")
		piece.Name = "Particle"
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Position = UDim2.fromOffset(position.X, position.Y)
		piece.Size = UDim2.fromOffset(6, 6)
		piece.BackgroundColor3 = color
		piece.BorderSizePixel = 0
		piece.Parent = parent
		local angle = math.random() * math.pi * 2
		local dist = 24 + math.random() * 42
		local target = UDim2.fromOffset(
			position.X + math.cos(angle) * dist,
			position.Y + math.sin(angle) * dist
		)
		local tween = TweenService:Create(piece, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = target,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(2, 2),
		})
		tween:Play()
		tween.Completed:Connect(function()
			piece:Destroy()
		end)
	end
end

-- shake jolts a frame a few pixels in random directions, then puts it
-- back. Used when the player takes a hit.
function Effects.shake(frame, strength, duration)
	strength = strength or 8
	duration = duration or 0.25
	local base = frame.Position
	local start = os.clock()
	task.spawn(function()
		while os.clock() - start < duration do
			local dx = math.random(-strength, strength)
			local dy = math.random(-strength, strength)
			frame.Position = UDim2.new(base.X.Scale, base.X.Offset + dx, base.Y.Scale, base.Y.Offset + dy)
			task.wait(0.03)
		end
		frame.Position = base
	end)
end

-- flash washes a full-screen overlay with a color and fades it out.
-- Red for a hit, white for a level-up.
function Effects.flash(overlay, color)
	overlay.BackgroundColor3 = color
	overlay.BackgroundTransparency = 0.45
	local tween = TweenService:Create(overlay, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	})
	tween:Play()
end

-- popup floats a short text up from a point and fades it. Used for
-- "+10", "+20", "NEAR MISS +2" and power-up names.
function Effects.popup(parent, position, text, color)
	local label = Instance.new("TextLabel")
	label.Name = "Popup"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromOffset(position.X, position.Y)
	label.Size = UDim2.fromOffset(120, 28)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextSize = 18
	label.Font = Enum.Font.GothamBold
	label.TextStrokeTransparency = 0.6
	label.Parent = parent
	local tween = TweenService:Create(label, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(position.X, position.Y - 44),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween:Play()
	tween.Completed:Connect(function()
		label:Destroy()
	end)
end

-- pulse grows a frame briefly and settles it back. Used on the combo
-- label when the multiplier steps up.
function Effects.pulse(label)
	local base = label.TextSize
	local up = TweenService:Create(label, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextSize = base + 8,
	})
	local down = TweenService:Create(label, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextSize = base,
	})
	up:Play()
	up.Completed:Connect(function()
		down:Play()
	end)
end

return Effects
