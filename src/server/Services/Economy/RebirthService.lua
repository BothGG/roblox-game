--[[
	RebirthService: reset kaiju, cash and food for a permanent bonus
	(+income, +pen slots, +storage).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local CreatureMath = require(Shared.Game.CreatureMath)
local Format = require(Shared.Lib.Format)
local Net = require(Shared.Net)

local RebirthService = {
	Priority = 55,
}

local Data, CreatureService, Food, Steal, Fx, Zoo

function RebirthService:Init(registry)
	Data = registry.DataService
	CreatureService = registry.CreatureService
	Food = registry.FoodService
	Steal = registry.StealService
	Fx = registry.FxService
	Zoo = registry.ZooService
end

function RebirthService:Start()
	Net.On("Rebirth", function(player)
		self:Rebirth(player)
	end)
end

function RebirthService:Rebirth(player: Player)
	local data = Data:Get(player)
	if not data then
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

	local plot = Zoo:GetPlot(player)
	Fx:PlayAll("Rebirth", {
		Position = plot and plot.CFrame.Position,
		Owner = player.UserId,
	})
	Net.Announce(
		"🌟 REBIRTH!",
		player.DisplayName .. " reached Rebirth " .. data.Rebirths .. "!",
		Color3.fromRGB(190, 130, 255)
	)

	CreatureService:Add(player, GameConfig.StarterCreature)
	Zoo:RefreshEnclosures(player)
	Food:RefreshStorage(player)
	Data:Changed(player)
end

return RebirthService
