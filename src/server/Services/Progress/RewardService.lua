--[[
	RewardService: the one place that hands out rewards (quests, daily
	rewards, codes, Index, battles, store products). Shows a popup.

	  RewardService:Grant(player, reward, title, source?)

	Reward format (see shared/Game/Progress.lua):
	  { Cash = 500, CashSeconds = 60, Food = { Meat = 5 }, Boost = { Id = "Luck", Minutes = 10 }, Trophies = 5 }
	CashSeconds = seconds of the player's current income, so rewards stay
	useful as players progress. Reward food ignores the storage limit.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Foods = require(Shared.Config.Foods)
local Progress = require(Shared.Game.Progress)
local Log = require(Shared.Lib.Log)
local Net = require(Shared.Net)

local log = Log.new("RewardService")

local RewardService = {
	Priority = 45,
}

local Data, Food, Creature, Fx

function RewardService:Init(registry)
	Data = registry.DataService
	Food = registry.FoodService
	Creature = registry.CreatureService
	Fx = registry.FxService
end

function RewardService:Grant(player: Player, reward: Progress.Reward, title: string, source: string?): boolean
	local data = Data:Get(player)
	if not data then
		return false
	end
	local income = Creature:GetIncome(player)
	local cash = Progress.RewardCash(reward, income)
	data.Cash += cash
	local foods: { [string]: number } = reward.Food or {}
	for foodId, amount in foods do
		if Foods[foodId] then
			data.Food[foodId] = (data.Food[foodId] or 0) + amount
		end
	end
	if reward.Boost then
		Progress.AddBoost(data.Boosts, reward.Boost.Id, reward.Boost.Minutes, os.time())
	end
	if reward.Trophies then
		data.Trophies += reward.Trophies
	end
	log:Debug(player.Name, "got", source or "?", cash)
	Food:RefreshStorage(player)
	Net.Fire(player, "Rewarded", { Title = title, Text = Progress.DescribeReward(reward, income) })
	Fx:PlayFor(player, "Reward", {})
	Data:Changed(player)
	return true
end

return RewardService
