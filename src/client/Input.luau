-- Input.luau — one job: read what the player's hands are doing.
-- Movement reads the raw keyboard state (IsKeyDown), because Roblox's
-- default camera scripts eat the arrow keys before an InputBegan
-- handler ever sees them. Actions (dash, start, restart) bind through
-- ContextActionService, which is the documented way to claim a key.

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local Input = {}

-- The touch stick's held direction (0..1 magnitude), or zero when the
-- stick is untouched. Movement prefers the stick when it is held, so
-- touch and keyboard never fight.
local touchVector = Vector2.zero

local MOVE_KEYS = {
	{ Enum.KeyCode.W, Vector2.new(0, -1) },
	{ Enum.KeyCode.Up, Vector2.new(0, -1) },
	{ Enum.KeyCode.S, Vector2.new(0, 1) },
	{ Enum.KeyCode.Down, Vector2.new(0, 1) },
	{ Enum.KeyCode.A, Vector2.new(-1, 0) },
	{ Enum.KeyCode.Left, Vector2.new(-1, 0) },
	{ Enum.KeyCode.D, Vector2.new(1, 0) },
	{ Enum.KeyCode.Right, Vector2.new(1, 0) },
}

-- getMoveVector returns the held direction as a unit vector, or zero
-- when nothing is held. The touch stick wins when it is held;
-- otherwise WASD and the arrows. Diagonal input normalizes, so
-- diagonal speed equals straight speed.
function Input.getMoveVector()
	if touchVector ~= Vector2.zero then
		return touchVector.Magnitude > 1 and touchVector.Unit or touchVector
	end
	local x, y = 0, 0
	for _, pair in MOVE_KEYS do
		if UserInputService:IsKeyDown(pair[1]) then
			x += pair[2].X
			y += pair[2].Y
		end
	end
	if x == 0 and y == 0 then
		return Vector2.zero
	end
	return Vector2.new(x, y).Unit
end

-- isTouch reports whether this device has a touch screen.
function Input.isTouch()
	return UserInputService.TouchEnabled
end

-- setupJoystick wires a stick base and its knob: dragging the base
-- steers, releasing it recentres. The knob follows the finger, clamped
-- to the base's radius, and the direction it holds becomes the move
-- vector. Screen Y runs downward, same as the arena, so no flip.
function Input.setupJoystick(base, knob)
	local stickTouch = nil
	local function updateStick(input)
		local center = base.AbsolutePosition + base.AbsoluteSize / 2
		local offset = Vector2.new(input.Position.X - center.X, input.Position.Y - center.Y)
		local radius = base.AbsoluteSize.X / 2
		if offset.Magnitude > radius then
			offset = offset.Unit * radius
		end
		knob.Position = UDim2.new(0.5, offset.X, 0.5, offset.Y)
		touchVector = offset / radius
		if touchVector.Magnitude < 0.15 then
			touchVector = Vector2.zero
		end
	end
	base.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			stickTouch = input
			updateStick(input)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if stickTouch and input == stickTouch and input.UserInputType == Enum.UserInputType.Touch then
			updateStick(input)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input == stickTouch then
			stickTouch = nil
			touchVector = Vector2.zero
			knob.Position = UDim2.fromScale(0.5, 0.5)
		end
	end)
end

-- _bind claims one action name on one key and calls the callback only
-- on the press (Begin), never on release.
local function _bind(name, key, callback)
	ContextActionService:BindAction(name, function(_, state)
		if state == Enum.UserInputState.Begin then
			callback()
		end
	end, false, key)
end

-- bindDash claims Space for the dash.
function Input.bindDash(callback)
	_bind("NeonRushDash", Enum.KeyCode.Space, callback)
end

-- bindStart claims Enter (and the keypad's) for starting from the title.
function Input.bindStart(callback)
	_bind("NeonRushStart", Enum.KeyCode.Return, callback)
end

-- bindRestart claims R for starting again from the game-over screen.
function Input.bindRestart(callback)
	_bind("NeonRushRestart", Enum.KeyCode.R, callback)
end

-- unbindAll releases the three actions (called when the game is torn
-- down, so a second session never double-binds).
function Input.unbindAll()
	ContextActionService:UnbindAction("NeonRushDash")
	ContextActionService:UnbindAction("NeonRushStart")
	ContextActionService:UnbindAction("NeonRushRestart")
end

return Input
