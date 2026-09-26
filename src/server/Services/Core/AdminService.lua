--[[
	AdminService: test commands for the game's creator, anyone in
	GameConfig.Admins, and everyone while testing in Studio.
	Use the 🛠️ Admin page in the menu. Commands:

	  cash <amount>            food <FoodId> <amount>     trophies <amount>
	  give <TitanId> [Mutation] level <1-100>              boost <Id> <minutes>
	  event <TitanClash|MeteorFeast|BloodMoon>             practice
	  tutorial                 daily                      quests
]]

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Foods = require(Shared.Config.Foods)
local GameConfig = require(Shared.Config.GameConfig)
local Mutations = require(Shared.Config.Mutations)
local Progress = require(Shared.Game.Progress)
local Guard = require(Shared.Lib.Guard)
local Log = require(Shared.Lib.Log)
local Net = require(Shared.Net)

local log = Log.new("AdminService")

local AdminService = {
	Priority = 80,
}

local Data, Creature, Food, Event, Battle

function AdminService:Init(registry)
	Data = registry.DataService
	Creature = registry.CreatureService
	Food = registry.FoodService
	Event = registry.EventService
	Battle = registry.BattleService
	Data:AddSnapshotHook(function(player, snapshot)
		snapshot.IsAdmin = player:GetAttribute("IsAdmin") == true
	end)
end

function AdminService:IsAdmin(player: Player): boolean
	if RunService:IsStudio() or table.find(GameConfig.Admins, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	-- Group games: the group owner is an admin
	local ok, info = pcall(GroupService.GetGroupInfoAsync, GroupService, game.CreatorId)
	return ok and type(info) == "table" and info.Owner ~= nil and info.Owner.Id == player.UserId
end

function AdminService:OnPlayerReady(player: Player)
	player:SetAttribute("IsAdmin", self:IsAdmin(player))
end

function AdminService:Start()
	Net.On("AdminCommand", function(player, text)
		if player:GetAttribute("IsAdmin") ~= true then
			return
		end
		local ok, result = pcall(self.Run, self, player, text)
		if not ok then
			log:Warn("command failed", text, result)
			Net.Notify(player, "🛠️ Error: " .. tostring(result), Color3.fromRGB(255, 120, 120))
		elseif result then
			Net.Notify(player, "🛠️ " .. result, Color3.fromRGB(150, 220, 255))
		end
	end)
end

function AdminService:Run(player: Player, text: string): string?
	local args = string.split(text, " ")
	local command = string.lower(args[1] or "")
	local data = Data:Get(player)
	if not data then
		return nil
	end
	local number = tonumber(args[2])
	if command == "cash" and number then
		data.Cash += number
	elseif command == "trophies" and number then
		data.Trophies += number
	elseif command == "food" and Guard.IsConfigKey(Foods, args[2]) then
		data.Food[args[2]] = (data.Food[args[2]] or 0) + (tonumber(args[3]) or 10)
		Food:RefreshStorage(player)
	elseif command == "give" and Creatures[args[2] or ""] then
		local mutation = if Guard.IsConfigKey(Mutations, args[3]) then args[3] else nil
		if not Creature:Add(player, args[2], mutation) then
			return "No free pen!"
		end
	elseif command == "level" and number then
		for uid in data.Creatures do
			Creature:SetLevel(player, uid, number)
		end
	elseif command == "boost" and args[2] then
		Progress.AddBoost(data.Boosts, args[2], tonumber(args[3]) or 10, os.time())
	elseif command == "event" and args[2] then
		task.spawn(Event.Run, Event, args[2])
		return "Starting " .. args[2]
	elseif command == "practice" then
		Battle:StartPractice(player)
		return nil
	elseif command == "tutorial" then
		data.Tutorial = 1
		data.TutorialProgress = 0
	elseif command == "daily" then
		data.Daily.LastDay = -1
	elseif command == "quests" then
		data.Quests.Day = -1
		Progress.EnsureQuests(data.Quests, Progress.Day(os.time()), player.UserId + math.random(1, 1e6), data.Rebirths)
	else
		return "Unknown command. Try: cash 100000, food StarFood 5, give Hydra Golden, level 50, event TitanClash"
	end
	Data:Changed(player)
	return "Done: " .. text
end

-- For testing with other players in the server
function AdminService:FindPlayer(name: string): Player?
	for _, player in Players:GetPlayers() do
		if
			string.lower(player.Name) == string.lower(name)
			or string.lower(player.DisplayName) == string.lower(name)
		then
			return player
		end
	end
	return nil
end

return AdminService
