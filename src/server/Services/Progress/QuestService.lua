--[[
	QuestService: 3 daily quests per player (Config/Quests.lua).
	Progress comes from GameEvents; the player claims finished quests in the
	Quests menu. The list resets at 00:00 UTC.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Progress = require(Shared.Game.Progress)
local Net = require(Shared.Net)

local GameEvents = require(ServerScriptService:WaitForChild("Server").Modules.GameEvents)

local QuestService = {
	Priority = 70,
}

local Data, Reward

function QuestService:Init(registry)
	Data = registry.DataService
	Reward = registry.RewardService
end

local function ensure(player: Player, data): boolean
	return Progress.EnsureQuests(data.Quests, Progress.Day(os.time()), player.UserId, data.Rebirths)
end

function QuestService:Start()
	GameEvents.Listen(function(player, name, payload)
		local data = Data:Get(player)
		if not data then
			return
		end
		ensure(player, data)
		local before = {}
		for i, quest in data.Quests.List do
			before[i] = quest.Progress
		end
		local completed = Progress.QuestEvent(data.Quests, name, payload)
		for _, quest in completed do
			Net.Notify(
				player,
				"✅ Quest done: " .. Progress.QuestText(quest) .. "! Claim it in 📜 Quests.",
				Color3.fromRGB(120, 230, 140)
			)
		end
		for i, quest in data.Quests.List do
			if quest.Progress ~= before[i] then
				Data:Changed(player)
				break
			end
		end
	end)

	Net.On("ClaimQuest", function(player, index)
		self:Claim(player, index)
	end)

	-- New quests at midnight (UTC) for everyone online
	task.spawn(function()
		while true do
			task.wait(60)
			for player in Data.Profiles do
				local data = Data:Get(player)
				if data and ensure(player, data) then
					Net.Notify(player, "📜 New daily quests are here!", Color3.fromRGB(255, 220, 120))
					Data:Changed(player)
				end
			end
		end
	end)
end

function QuestService:OnPlayerReady(player: Player)
	local data = Data:Get(player)
	if data then
		ensure(player, data)
	end
end

function QuestService:Claim(player: Player, index: number)
	local data = Data:Get(player)
	local quest = data and data.Quests.List[index]
	if not quest or quest.Claimed or quest.Progress < quest.Goal then
		return
	end
	local def = Progress.QuestDefs[quest.Id]
	if not def then
		return
	end
	quest.Claimed = true
	Reward:Grant(player, def.Reward, "📜 " .. Progress.QuestText(quest), "Quest")
end

return QuestService
