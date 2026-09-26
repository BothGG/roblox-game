--[[
	All growth / income formulas, shared by the server (real values)
	and the client (numbers shown in the UI), so they always match.
]]

local Config = script.Parent.Config
local GameConfig = require(Config.GameConfig)
local Creatures = require(Config.Creatures)
local Mutations = require(Config.Mutations)

local CreatureMath = {}

export type CreatureData = {
	Id: string,
	Level: number,
	Xp: number,
	Mutation: string?,
}

function CreatureMath.XpToNext(level: number): number
	return math.floor(20 * level ^ 1.35)
end

function CreatureMath.Scale(level: number): number
	return 1 + (level - 1) * GameConfig.ScalePerLevel
end

function CreatureMath.Trait(creature: CreatureData, trait: string): number
	local def = Creatures[creature.Id]
	return def and def.Traits[trait] or 0
end

-- Income per second before player bonuses (rebirth, king)
function CreatureMath.BaseIncome(creature: CreatureData): number
	local def = Creatures[creature.Id]
	if not def then
		return 0
	end
	local mutation = creature.Mutation and Mutations[creature.Mutation]
	local mutationMult = mutation and mutation.IncomeMult or 1
	return def.BaseIncome
		* (1 + (creature.Level - 1) * GameConfig.IncomePerLevel)
		* mutationMult
		* (1 + CreatureMath.Trait(creature, "Income"))
end

function CreatureMath.PlayerMultiplier(rebirths: number, isKing: boolean?): number
	local mult = 1 + rebirths * GameConfig.RebirthIncomeBonus
	if isKing then
		mult *= 1 + GameConfig.KingIncomeBonus
	end
	return mult
end

function CreatureMath.GuardChance(creature: CreatureData): number
	local guard = CreatureMath.Trait(creature, "Guard")
	if guard <= 0 then
		return 0
	end
	return guard * (1 + creature.Level / 50)
end

function CreatureMath.SellPrice(creature: CreatureData, rebirths: number): number
	return math.floor(CreatureMath.BaseIncome(creature) * GameConfig.SellSeconds * CreatureMath.PlayerMultiplier(rebirths))
end

function CreatureMath.RebirthCost(rebirths: number): number
	return GameConfig.RebirthBaseCost * GameConfig.RebirthCostGrowth ^ rebirths
end

function CreatureMath.MaxSlots(rebirths: number): number
	return math.min(GameConfig.MaxSlots, GameConfig.StartingSlots + rebirths * GameConfig.SlotsPerRebirth)
end

function CreatureMath.StorageCap(rebirths: number): number
	return GameConfig.StorageCap + rebirths * GameConfig.StorageCapPerRebirth
end

function CreatureMath.Count(tbl: { [any]: any }): number
	local n = 0
	for _ in tbl do
		n += 1
	end
	return n
end

function CreatureMath.CountFood(food: { [string]: number }): number
	local n = 0
	for _, count in food do
		n += count
	end
	return n
end

function CreatureMath.DisplayName(creature: CreatureData): string
	local def = Creatures[creature.Id]
	local name = def and def.Name or creature.Id
	if creature.Mutation and Mutations[creature.Mutation] then
		return Mutations[creature.Mutation].Name .. " " .. name
	end
	return name
end

local TRAIT_TEXT = {
	Growth = function(v)
		return string.format("+%d%% growth", math.round(v * 100))
	end,
	Income = function(v)
		return string.format("+%d%% income", math.round(v * 100))
	end,
	Guard = function()
		return "Guards your food"
	end,
	Forage = function(v)
		return string.format("%d%% double food", math.round(v * 100))
	end,
	Speed = function(v)
		return string.format("+%d steal speed", v)
	end,
}

function CreatureMath.DescribeTraits(creatureId: string): string
	local def = Creatures[creatureId]
	if not def then
		return ""
	end
	local parts = {}
	for trait, value in def.Traits do
		local fn = TRAIT_TEXT[trait]
		if fn then
			table.insert(parts, fn(value))
		end
	end
	table.sort(parts)
	return table.concat(parts, " • ")
end

return CreatureMath
