--[[
	OfflineService: pays out part of the player's income for the time they
	were away (GameConfig.Offline; VIP gets a better rate).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Progress = require(Shared.Game.Progress)
local Rules = require(Shared.Game.Rules)
local Net = require(Shared.Net)

local OfflineService = {
	Priority = 72,
}

local Data

function OfflineService:Init(registry)
	Data = registry.DataService
end

function OfflineService:OnPlayerReady(player: Player)
	local data = Data:Get(player)
	if not data or data.LastOnline <= 0 then
		return
	end
	local now = os.time()
	local seconds = now - data.LastOnline
	local income = Rules.Income(data, { Now = now })
	local amount = Progress.OfflineEarnings(income, seconds, Rules.Perks(data).OfflineRate)
	if amount <= 0 then
		return
	end
	data.Cash += amount
	data.Stats.CashEarned += amount
	task.delay(2, function()
		if player.Parent then
			Net.Fire(player, "OfflineEarnings", { Amount = amount, Seconds = seconds })
		end
	end)
	Data:Changed(player)
end

return OfflineService
