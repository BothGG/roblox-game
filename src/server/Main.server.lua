--[[
	Server entry point.

	1. Validates all config files (content mistakes show up in Output).
	2. Loader finds every "*Service" module in Services/ and runs
	   Init(registry) then Start(), ordered by each service's Priority.
	3. Player lifecycle:
	     join  -> DataService:Load -> BaseService:Assign -> OnPlayerReady(player) on every service
	     leave -> OnPlayerRemoving(player) on every service (reverse order) -> save & release

	See docs/ARCHITECTURE.md.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigValidator = require(Shared.Game.ConfigValidator)
local Loader = require(Shared.Lib.Loader)
local Log = require(Shared.Lib.Log)

local log = Log.new("Main")

local configErrors = ConfigValidator.Validate()
for _, message in configErrors do
	log:Error("CONFIG:", message)
end

local registry, ordered = Loader.Boot(script.Parent:WaitForChild("Services"), "Service")
local Data = registry.DataService
local Base = registry.BaseService

local reversed = table.clone(ordered)
for i = 1, #reversed // 2 do
	reversed[i], reversed[#reversed - i + 1] = reversed[#reversed - i + 1], reversed[i]
end

local function onPlayerAdded(player: Player)
	local data = Data:Load(player)
	if not data or not player.Parent then
		return
	end
	if not Base:Assign(player) then
		player:Kick("This server is full. Please join another one!")
		return
	end
	Loader.Each(ordered, "OnPlayerReady", player)
	Data:Changed(player)
end

local function onPlayerRemoving(player: Player)
	if not Data:IsLoaded(player) then
		return
	end
	Loader.Each(reversed, "OnPlayerRemoving", player)
	Base:Release(player)
	Data:Release(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
