-- init.server.luau — one job: wire the server side together.
-- It creates the two remotes (the client sends a finished run's score,
-- the server answers with the player's best), builds leaderstats for
-- everyone who joins, and answers both remotes through State. It holds
-- no gameplay: the arcade loop lives on the client, where the input is.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local State = require(script.Parent:WaitForChild("State"))

local submitScore = Instance.new("RemoteEvent")
submitScore.Name = Config.Remotes.SubmitScore
submitScore.Parent = ReplicatedStorage

local requestBest = Instance.new("RemoteFunction")
requestBest.Name = Config.Remotes.RequestBest
requestBest.Parent = ReplicatedStorage

-- onPlayerJoined builds the board for the newcomer. The best loads
-- here so the HUD can show it from the first frame.
local function onPlayerJoined(player)
	State.setupLeaderstats(player)
end

Players.PlayerAdded:Connect(onPlayerJoined)
for _, player in Players:GetPlayers() do
	onPlayerJoined(player)
end

-- onSubmitScore takes a finished run's score, validates it through
-- State, and hands the player's best back to the client.
submitScore.OnServerEvent:Connect(function(player, score)
	local best = State.submitScore(player, score)
	submitScore:FireClient(player, best)
end)

-- onRequestBest answers a client's ask for its saved best.
requestBest.OnServerInvoke = function(player)
	return State.loadBest(player)
end

print("NEON RUSH server ready.")
