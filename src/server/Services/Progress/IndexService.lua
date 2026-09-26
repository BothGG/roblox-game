--[[
	IndexService: rewards for collecting titans (Config/Index.lua).
	The Index itself is filled by CreatureService when a titan / mutation is
	obtained for the first time.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local IndexConfig = require(Shared.Config.Index)
local Progress = require(Shared.Game.Progress)
local Net = require(Shared.Net)

local IndexService = {
	Priority = 73,
}

local Data, Reward

function IndexService:Init(registry)
	Data = registry.DataService
	Reward = registry.RewardService
end

function IndexService:Start()
	Net.On("ClaimIndex", function(player, milestone)
		self:Claim(player, milestone)
	end)
end

function IndexService:Claim(player: Player, milestone: number)
	local data = Data:Get(player)
	if not data then
		return
	end
	if not table.find(Progress.ClaimableMilestones(data.Index, data.IndexClaimed), milestone) then
		return
	end
	data.IndexClaimed[tostring(milestone)] = true
	local def = IndexConfig.Milestones[milestone]
	Reward:Grant(player, def.Reward, "📖 Index: " .. def.Count .. " collected!", "Index")
end

return IndexService
