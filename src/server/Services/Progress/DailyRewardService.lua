--[[
	DailyRewardService: 7-day login streak (Config/DailyRewards.lua).
	The client opens the Daily page automatically when a reward is ready.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DailyRewards = require(Shared.Config.DailyRewards)
local Progress = require(Shared.Game.Progress)
local Net = require(Shared.Net)

local DailyRewardService = {
	Priority = 71,
}

local Data, Reward

function DailyRewardService:Init(registry)
	Data = registry.DataService
	Reward = registry.RewardService
end

function DailyRewardService:Start()
	Net.On("ClaimDaily", function(player)
		self:Claim(player)
	end)
end

function DailyRewardService:Claim(player: Player)
	local data = Data:Get(player)
	if not data then
		return
	end
	local index = Progress.ClaimDaily(data.Daily, Progress.Day(os.time()))
	if not index then
		Net.Notify(player, "📅 Come back tomorrow for the next reward!")
		return
	end
	Reward:Grant(player, DailyRewards[index].Reward, "📅 Day " .. index .. " reward!", "Daily")
end

return DailyRewardService
