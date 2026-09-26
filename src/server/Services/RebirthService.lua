--[[
	RebirthService: reset kaiju, cash and food for a permanent bonus
	(+income, +pen slots, +storage).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local CreatureMath = require(Shared.CreatureMath)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)

local RebirthService = {}

local Data, CreatureService, Food, Steal, Fx, World

function RebirthService:Init(services)
	Data = services.DataService
	CreatureService = services.CreatureService
	Food = services.FoodService
	Steal = services.StealService
	Fx = services.FxService
	World = services.WorldService
end

function RebirthService:Start()
	Net.Get("Rebirth").OnServerEvent:Connect(function(player)
		self:Rebirth(player)
	end)
end

function RebirthService:Rebirth(player: Player)
	local data = Data:Get(player)
	if not data or not Net.Throttle(player, "Rebirth", 2) then
		return
	end
	local cost = CreatureMath.RebirthCost(data.Rebirths)
	if data.Cash < cost then
		Net.Notify(player, "You need " .. Format.Money(cost) .. " to rebirth!", Color3.fromRGB(255, 90, 90))
		return
	end
	Steal:ReturnFood(player, "left")
	CreatureService:RemoveAll(player)
	data.Cash = GameConfig.StartingCash
	data.Food = Data.DeepCopy(GameConfig.StartingFood)
	data.Rebirths += 1

	local plot = World:GetPlot(player)
	Fx:PlayAll("Rebirth", {
		Position = plot and plot.CFrame.Position,
		Owner = player.UserId,
	})
	Net.Announce("🌟 REBIRTH!", player.DisplayName .. " reached Rebirth " .. data.Rebirths .. "!", Color3.fromRGB(190, 130, 255))

	CreatureService:Add(player, GameConfig.StarterCreature)
	Food:RefreshStorage(player)
	Data:Changed(player)
end

return RebirthService
