-- State.luau — one job: the server's record of every player.
-- The arcade loop runs on the client, so the server never sees a frame
-- of gameplay. What it owns is the record: each player's best score,
-- kept in leaderstats for the board and in a DataStore when the service
-- answers. Every DataStore call is wrapped in pcall, so a service
-- hiccup degrades to memory instead of erroring the game.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local State = {}
State._best = {} -- [Player] = best score this session (or loaded)
State._lastSubmit = {} -- [Player] = os.clock() of the last accepted score
State._store = nil
State._storeOk = false

do
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStore.Name, Config.DataStore.Scope)
	end)
	if ok and store then
		State._store = store
		State._storeOk = true
	end
end

-- loadBest reads the player's saved best (0 when there is none, or when
-- the service does not answer) and hands back the number.
function State.loadBest(player)
	if State._storeOk then
		local ok, saved = pcall(function()
			return State._store:GetAsync("best_" .. player.UserId)
		end)
		if ok and typeof(saved) == "number" then
			State._best[player] = math.floor(saved)
			return State._best[player]
		end
	end
	State._best[player] = State._best[player] or 0
	return State._best[player]
end

-- saveBest writes the best back when the service answers. A failure is
-- swallowed: the in-memory best still stands for this session.
function State.saveBest(player)
	if not State._storeOk then
		return false
	end
	local ok = pcall(function()
		State._store:SetAsync("best_" .. player.UserId, State._best[player] or 0)
	end)
	return ok
end

-- setupLeaderstats builds the board columns (Score is the run in
-- progress, Best is the record) and loads the saved best into them.
function State.setupLeaderstats(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local score = Instance.new("IntValue")
	score.Name = "Score"
	score.Value = 0
	score.Parent = stats
	local best = Instance.new("IntValue")
	best.Name = "Best"
	best.Value = State.loadBest(player)
	best.Parent = stats
	stats.Parent = player
	return stats
end

-- submitScore takes a finished run's score from the client, validates
-- it, and updates the record. The client can only raise its own best,
-- never anyone else's, and never faster than once per 5 seconds.
-- Returns the player's best after the call.
function State.submitScore(player, score)
	if typeof(score) ~= "number" then
		return State._best[player] or 0
	end
	score = math.floor(score)
	if score < 0 or score > 1000000 then
		return State._best[player] or 0
	end
	local now = os.clock()
	if State._lastSubmit[player] and now - State._lastSubmit[player] < 5 then
		return State._best[player] or 0
	end
	State._lastSubmit[player] = now
	local best = State._best[player] or 0
	if score > best then
		State._best[player] = score
		local stats = player:FindFirstChild("leaderstats")
		if stats then
			local bestValue = stats:FindFirstChild("Best")
			if bestValue then
				bestValue.Value = score
			end
			local scoreValue = stats:FindFirstChild("Score")
			if scoreValue then
				scoreValue.Value = score
			end
		end
		State.saveBest(player)
	end
	return State._best[player] or 0
end

-- forget drops a leaving player's session rows. The saved best stays
-- in the DataStore; only the memory goes.
function State.forget(player)
	State._best[player] = nil
	State._lastSubmit[player] = nil
end

Players.PlayerRemoving:Connect(function(player)
	State.forget(player)
end)

return State
