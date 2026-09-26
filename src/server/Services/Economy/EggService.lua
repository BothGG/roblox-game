--[[
	EggService: buying and hatching eggs, plus the free starter kaiju.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Creatures = require(Shared.Config.Creatures)
local Eggs = require(Shared.Config.Eggs)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Rules = require(Shared.Game.Rules)
local Guard = require(Shared.Lib.Guard)
local WeightedRandom = require(Shared.Lib.WeightedRandom)
local Net = require(Shared.Net)

local RED = Color3.fromRGB(255, 90, 90)

local EggService = {
	Priority = 50,
}

local Data, CreatureService

function EggService:Init(registry)
	Data = registry.DataService
	CreatureService = registry.CreatureService
end

function EggService:Start()
	Net.On("BuyEgg", function(player, eggId)
		self:Buy(player, eggId)
	end)
end

function EggService:OnPlayerReady(player: Player)
	local data = Data:Get(player)
	if data and not data.Stats.StarterGiven and next(data.Creatures) == nil then
		data.Stats.StarterGiven = true
		task.delay(1.5, function()
			if player.Parent then
				CreatureService:Add(player, GameConfig.StarterCreature)
				Net.Notify(
					player,
					"🥚 Here's your first " .. GameConfig.CreatureName .. "! Walk up to it and press E to feed it.",
					Color3.fromRGB(120, 220, 120)
				)
			end
		end)
	end
end

local function rollMutation(): string?
	local roll = math.random()
	if roll < GameConfig.RainbowHatchChance then
		return "Rainbow"
	end
	if roll < GameConfig.HatchMutationChance then
		local pick = WeightedRandom.Pick(Mutations.HatchPool, function(e)
			return e.Weight
		end)
		return pick and pick.Id
	end
	return nil
end

function EggService:Buy(player: Player, eggId: string)
	local data = Data:Get(player)
	if not data or not Guard.IsConfigKey(Eggs, eggId) then
		return
	end
	local egg = Eggs[eggId]
	if not Rules.HasFreeSlot(data) then
		Net.Notify(player, "Your pen is full! Sell a " .. GameConfig.CreatureName .. " or Rebirth for more slots.", RED)
		return
	end
	if data.Cash < egg.Price then
		Net.Notify(player, "Not enough cash!", RED)
		return
	end
	local pick = WeightedRandom.Pick(egg.Odds, function(e)
		return e.Weight
	end)
	if not pick then
		return
	end
	data.Cash -= egg.Price
	local mutation = rollMutation()
	local uid = CreatureService:Add(player, pick.Creature, mutation)
	if not uid then
		data.Cash += egg.Price
		return
	end
	data.Stats.Hatched += 1

	local def = Creatures[pick.Creature]
	local rarity = Rarities[def.Rarity]
	Net.Fire(player, "Hatched", {
		CreatureId = pick.Creature,
		Mutation = mutation,
		EggId = eggId,
	})
	if rarity.Order >= Rarities.Legendary.Order or mutation then
		local name = (if mutation then Mutations[mutation].Name .. " " else "") .. def.Name
		Net.NotifyAll(
			string.format("🥚 %s hatched a %s %s!", player.DisplayName, string.upper(def.Rarity), name),
			rarity.Color
		)
	end
	Data:Changed(player)
end

return EggService
