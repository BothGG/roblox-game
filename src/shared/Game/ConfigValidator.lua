--[[
	ConfigValidator: checks all config files fit together (every egg points
	to a real titan, every reward uses real foods and boosts, etc.). The
	server runs it on start and the tests run it too, so content mistakes are
	caught early.

	  local errors = ConfigValidator.Validate()   -- { "message", ... }
]]

local Config = script.Parent.Parent.Config
local Boosts = require(Config.Boosts)
local Codes = require(Config.Codes)
local Creatures = require(Config.Creatures)
local DailyRewards = require(Config.DailyRewards)
local Eggs = require(Config.Eggs)
local Foods = require(Config.Foods)
local GameConfig = require(Config.GameConfig)
local IndexConfig = require(Config.Index)
local Mutations = require(Config.Mutations)
local Quests = require(Config.Quests)
local Rarities = require(Config.Rarities)
local Store = require(Config.Store)
local Tutorial = require(Config.Tutorial)
local Sizes = require(Config.Sizes)
local Upgrades = require(Config.Upgrades)

local ConfigValidator = {}

-- Game events the server fires (server/Modules/GameEvents.lua).
ConfigValidator.Events = {
	Fed = true,
	LevelUp = true,
	FoodPicked = true,
	Stole = true,
	Hatched = true,
	Mutated = true,
	BattleWon = true,
	BattlePlayed = true,
	Earned = true,
	Rebirthed = true,
	Equipped = true,
	Tamed = true,
	Bred = true,
}

local STYLES = { Biped = true, Quad = true, Blob = true, Winged = true }

local function isEntry(config, id): boolean
	return type(id) == "string" and type(config[id]) == "table" and config[id].Id == id
end

local function checkOrder(errors, label: string, config, order)
	local seen = {}
	for _, id in order do
		if not isEntry(config, id) then
			table.insert(errors, string.format("%s.Order lists unknown id '%s'", label, tostring(id)))
		end
		if seen[id] then
			table.insert(errors, string.format("%s.Order lists '%s' twice", label, id))
		end
		seen[id] = true
	end
	for id, def in config do
		if type(def) == "table" and def.Id == id and not seen[id] then
			table.insert(errors, string.format("%s '%s' is missing from %s.Order", label, id, label))
		end
	end
end

local function checkReward(errors, where: string, reward)
	if type(reward) ~= "table" then
		table.insert(errors, where .. " has no Reward table")
		return
	end
	for foodId, count in reward.Food or {} do
		if not isEntry(Foods, foodId) then
			table.insert(errors, string.format("%s rewards unknown food %s", where, tostring(foodId)))
		end
		if type(count) ~= "number" or count <= 0 then
			table.insert(errors, where .. " has a food amount <= 0")
		end
	end
	if reward.Boost then
		if not isEntry(Boosts, reward.Boost.Id) then
			table.insert(errors, string.format("%s rewards unknown boost %s", where, tostring(reward.Boost.Id)))
		end
		if type(reward.Boost.Minutes) ~= "number" or reward.Boost.Minutes <= 0 then
			table.insert(errors, where .. " boost needs Minutes > 0")
		end
	end
end

function ConfigValidator.Validate(): { string }
	local errors = {}
	local function check(condition: boolean, message: string, ...)
		if not condition then
			table.insert(errors, string.format(message, ...))
		end
	end

	for id, def in Creatures do
		check(Rarities[def.Rarity] ~= nil, "Titan %s has unknown rarity %s", id, tostring(def.Rarity))
		check(type(def.BaseIncome) == "number" and def.BaseIncome > 0, "Titan %s needs BaseIncome > 0", id)
		check(type(def.Traits) == "table", "Titan %s needs a Traits table", id)
		check(STYLES[def.Style] == true, "Titan %s has unknown Style %s", id, tostring(def.Style))
		check(
			type(def.Stats) == "table"
				and (def.Stats.HP or 0) > 0
				and (def.Stats.Attack or 0) > 0
				and (def.Stats.Speed or 0) > 0,
			"Titan %s needs Stats = { HP, Attack, Speed } > 0",
			id
		)
		for _, foodId in def.Diet or {} do
			check(isEntry(Foods, foodId), "Titan %s Diet has unknown food %s", id, tostring(foodId))
		end
	end

	for id, def in Foods do
		if type(def) == "table" and def.Id == id then
			check(Rarities[def.Rarity] ~= nil, "Food %s has unknown rarity %s", id, tostring(def.Rarity))
			check(type(def.Growth) == "number" and def.Growth > 0, "Food %s needs Growth > 0", id)
			check(type(def.SpawnWeight) == "number" and def.SpawnWeight >= 0, "Food %s needs SpawnWeight >= 0", id)
			if def.Mutation then
				check(
					isEntry(Mutations, def.Mutation.Id),
					"Food %s has unknown mutation %s",
					id,
					tostring(def.Mutation.Id)
				)
			end
			check(
				GameConfig.Food.RespawnTime[def.Rarity] ~= nil,
				"No respawn time for rarity %s (food %s)",
				def.Rarity,
				id
			)
		end
	end
	checkOrder(errors, "Foods", Foods, Foods.Order)

	for id, egg in Eggs do
		if type(egg) == "table" and egg.Id == id then
			check(type(egg.Price) == "number" and egg.Price >= 0, "Egg %s needs a Price", id)
			check(#egg.Odds > 0, "Egg %s has no Odds", id)
			for _, odd in egg.Odds do
				check(isEntry(Creatures, odd.Creature), "Egg %s has unknown titan %s", id, tostring(odd.Creature))
				check(odd.Weight > 0, "Egg %s has a weight <= 0", id)
			end
		end
	end
	checkOrder(errors, "Eggs", Eggs, Eggs.Order)

	for id, def in Mutations do
		if type(def) == "table" and def.Id == id then
			check(type(def.StatMult) == "number" and def.StatMult >= 1, "Mutation %s needs StatMult >= 1", id)
		end
	end
	for _, entry in Mutations.HatchPool do
		check(isEntry(Mutations, entry.Id), "Mutations.HatchPool has unknown mutation %s", tostring(entry.Id))
	end
	checkOrder(errors, "Boosts", Boosts, Boosts.Order)

	-- Retention configs
	check(#DailyRewards == 7, "DailyRewards should have 7 days (has %d)", #DailyRewards)
	for i, day in DailyRewards do
		checkReward(errors, "DailyRewards day " .. i, day.Reward)
	end
	local questIds = {}
	for _, def in Quests.Pool do
		check(not questIds[def.Id], "Quest id %s is used twice", tostring(def.Id))
		questIds[def.Id] = true
		check(ConfigValidator.Events[def.Event] == true, "Quest %s uses unknown event %s", def.Id, tostring(def.Event))
		check(def.Goal[1] >= 1 and def.Goal[2] >= def.Goal[1], "Quest %s has a bad Goal range", def.Id)
		checkReward(errors, "Quest " .. def.Id, def.Reward)
	end
	check(Quests.PerDay <= #Quests.Pool, "Quests.PerDay is bigger than the pool")
	for code, def in Codes do
		check(code == string.upper(code), "Code %s must be UPPERCASE in Codes.lua", code)
		checkReward(errors, "Code " .. code, def.Reward)
	end
	for i, step in Tutorial.Steps do
		check(
			ConfigValidator.Events[step.Event] == true,
			"Tutorial step %d uses unknown event %s",
			i,
			tostring(step.Event)
		)
	end
	local lastCount = 0
	for i, milestone in IndexConfig.Milestones do
		check(milestone.Count > lastCount, "Index milestone %d must need more than the one before", i)
		lastCount = milestone.Count
		checkReward(errors, "Index milestone " .. i, milestone.Reward)
	end
	for key, product in Store.Products do
		checkReward(errors, "Store product " .. key, product.Reward)
	end
	for _, key in Store.PassOrder do
		check(Store.Passes[key] ~= nil, "Store.PassOrder lists unknown pass %s", key)
	end
	for _, key in Store.ProductOrder do
		check(Store.Products[key] ~= nil, "Store.ProductOrder lists unknown product %s", key)
	end

	check(isEntry(Creatures, GameConfig.StarterCreature), "GameConfig.StarterCreature is not a titan")
	for foodId in GameConfig.StartingFood do
		check(isEntry(Foods, foodId), "GameConfig.StartingFood has unknown food %s", tostring(foodId))
	end
	for foodId in GameConfig.Battle.ClashWinFood do
		check(isEntry(Foods, foodId), "Battle.ClashWinFood has unknown food %s", tostring(foodId))
	end
	check(GameConfig.Plots.Count >= 2 and GameConfig.Plots.Count <= 16, "GameConfig.Plots.Count must be 2..16")
	check(GameConfig.MaxSlots <= 24, "GameConfig.MaxSlots can't be more than 24 (pens per base)")
	local lastMin = 0
	for i, tier in Sizes.Tiers do
		check(tier.Min > lastMin, "Sizes tier %d (%s) must need a bigger size than the one before", i, tier.Id)
		lastMin = tier.Min
	end
	check(Sizes.Tiers[1].Min == Sizes.Min, "The first size tier must start at Sizes.Min")
	check(Sizes.Tiers[#Sizes.Tiers].Min <= Sizes.Max, "The last size tier can't be above Sizes.Max")
	for _, id in Upgrades.Order do
		local def = Upgrades[id]
		check(def ~= nil and def.Id == id, "Upgrades.Order lists unknown upgrade %s", tostring(id))
		if def then
			check(def.Max >= 1 and def.BaseCost > 0 and def.Growth >= 1, "Upgrade %s needs Max, BaseCost, Growth", id)
		end
	end

	return errors
end

return ConfigValidator
