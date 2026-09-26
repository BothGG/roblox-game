--[[
	ConfigValidator: checks all config files fit together (every egg points
	to a real kaiju, every biome food exists, etc.). The server runs it on
	start and the tests run it too, so content mistakes are caught early.

	  local errors = ConfigValidator.Validate()   -- { "message", ... }
]]

local Config = script.Parent.Parent.Config
local Biomes = require(Config.Biomes)
local Creatures = require(Config.Creatures)
local Eggs = require(Config.Eggs)
local Foods = require(Config.Foods)
local GameConfig = require(Config.GameConfig)
local Mutations = require(Config.Mutations)
local Rarities = require(Config.Rarities)

local ConfigValidator = {}

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

function ConfigValidator.Validate(): { string }
	local errors = {}
	local function check(condition: boolean, message: string, ...)
		if not condition then
			table.insert(errors, string.format(message, ...))
		end
	end

	for id, def in Creatures do
		check(Rarities[def.Rarity] ~= nil, "Creature %s has unknown rarity %s", id, tostring(def.Rarity))
		check(type(def.BaseIncome) == "number" and def.BaseIncome > 0, "Creature %s needs BaseIncome > 0", id)
		check(type(def.Traits) == "table", "Creature %s needs a Traits table", id)
		for _, foodId in def.Diet or {} do
			check(isEntry(Foods, foodId), "Creature %s Diet has unknown food %s", id, tostring(foodId))
		end
	end

	for id, def in Foods do
		if type(def) == "table" and def.Id == id then
			check(Rarities[def.Rarity] ~= nil, "Food %s has unknown rarity %s", id, tostring(def.Rarity))
			check(type(def.Growth) == "number" and def.Growth > 0, "Food %s needs Growth > 0", id)
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
				check(isEntry(Creatures, odd.Creature), "Egg %s has unknown creature %s", id, tostring(odd.Creature))
				check(odd.Weight > 0, "Egg %s has a weight <= 0", id)
			end
		end
	end
	checkOrder(errors, "Eggs", Eggs, Eggs.Order)

	for _, entry in Mutations.HatchPool do
		check(isEntry(Mutations, entry.Id), "Mutations.HatchPool has unknown mutation %s", tostring(entry.Id))
	end

	local wildSomewhere = {}
	for id, biome in Biomes do
		if type(biome) == "table" and biome.Id == id then
			check(#biome.Foods > 0, "Biome %s has no Foods", id)
			for _, entry in biome.Foods do
				check(isEntry(Foods, entry.Food), "Biome %s has unknown food %s", id, tostring(entry.Food))
			end
			for _, entry in biome.Wild do
				check(
					isEntry(Creatures, entry.Creature),
					"Biome %s has unknown creature %s",
					id,
					tostring(entry.Creature)
				)
				wildSomewhere[entry.Creature] = true
			end
			check(type(biome.Unlock) == "table", "Biome %s needs an Unlock table", id)
			check(biome.Ambience ~= nil, "Biome %s needs an Ambience", id)
		end
	end
	checkOrder(errors, "Biomes", Biomes, Biomes.Order)
	for _, biomeId in GameConfig.StartingBiomes do
		check(isEntry(Biomes, biomeId), "GameConfig.StartingBiomes has unknown biome %s", tostring(biomeId))
	end

	check(isEntry(Creatures, GameConfig.StarterCreature), "GameConfig.StarterCreature is not a creature")
	for foodId in GameConfig.StartingFood do
		check(isEntry(Foods, foodId), "GameConfig.StartingFood has unknown food %s", tostring(foodId))
	end
	check(GameConfig.Zoo.PlotCount >= 1, "GameConfig.Zoo.PlotCount must be >= 1")
	check(GameConfig.MaxSlots <= 12, "GameConfig.MaxSlots can't be more than 12 (enclosures per zoo)")

	return errors
end

return ConfigValidator
