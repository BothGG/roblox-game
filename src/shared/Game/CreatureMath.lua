--[[
	All growth / income formulas, shared by the server (real values)
	and the client (numbers shown in the UI), so they always match.
]]

local Config = script.Parent.Parent.Config
local GameConfig = require(Config.GameConfig)
local Creatures = require(Config.Creatures)
local Mutations = require(Config.Mutations)
local Sizes = require(Config.Sizes)

local CreatureMath = {}

export type CreatureData = {
	Id: string,
	Level: number,
	Xp: number,
	Mutation: string?,
	Size: number?, -- x1 .. x100,000 (missing = x1)
}

function CreatureMath.XpToNext(level: number): number
	return math.floor(20 * level ^ 1.35)
end

function CreatureMath.Scale(level: number): number
	return 1 + (level - 1) * GameConfig.ScalePerLevel
end

-- Size ------------------------------------------------------------------------

function CreatureMath.ClampSize(size: number?): number
	local n = tonumber(size) or 1
	if n ~= n then -- NaN
		return 1
	end
	return math.clamp(n, Sizes.Min, Sizes.Max)
end

function CreatureMath.SizeOf(creature: CreatureData): number
	return CreatureMath.ClampSize(creature.Size)
end

-- The named tier a size belongs to (Tiny, Normal, Big ... Mythical).
function CreatureMath.SizeTier(size: number?): Sizes.Tier
	local n = CreatureMath.ClampSize(size)
	local tier = Sizes.Tiers[1]
	for _, t in Sizes.Tiers do
		if n >= t.Min then
			tier = t
		end
	end
	return tier
end

-- How much bigger the model looks because of Size: grows with the log of
-- size (x1 = 1, x10 = 1.4, x100,000 = 3).
function CreatureMath.SizeScale(size: number?): number
	return 1 + math.log10(CreatureMath.ClampSize(size)) * Sizes.ScalePerDecade
end

-- Final model scale from level and size, capped so giants stay on the map.
function CreatureMath.VisualScale(creature: CreatureData): number
	return math.min(Sizes.VisualCap, CreatureMath.Scale(creature.Level) * CreatureMath.SizeScale(creature.Size))
end

-- "x1", "x250", "x1.5K", "x100K"
function CreatureMath.SizeLabel(size: number?): string
	local n = CreatureMath.ClampSize(size)
	if n < 1000 then
		local rounded = math.floor(n * 10 + 0.5) / 10
		return "x" .. (if rounded == math.floor(rounded) then tostring(math.floor(rounded)) else tostring(rounded))
	end
	local k = n / 1000
	local text = if k >= 100 then string.format("%.0f", k) else string.format("%.1f", k)
	text = (string.gsub(text, "%.0$", ""))
	return "x" .. text .. "K"
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
	-- Income = base income x level x size x mutation (x trait bonus)
	return def.BaseIncome
		* (1 + (creature.Level - 1) * GameConfig.IncomePerLevel)
		* CreatureMath.SizeOf(creature)
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
	return math.floor(
		CreatureMath.BaseIncome(creature) * GameConfig.SellSeconds * CreatureMath.PlayerMultiplier(rebirths)
	)
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

-- "Rex", "Lava Rex", "Giant Lava Rex" (size tier shown from Big and up)
function CreatureMath.DisplayName(creature: CreatureData): string
	local def = Creatures[creature.Id]
	local name = def and def.Name or creature.Id
	if creature.Mutation and Mutations[creature.Mutation] then
		name = Mutations[creature.Mutation].Name .. " " .. name
	end
	local size = CreatureMath.SizeOf(creature)
	if size >= Sizes.Tiers[3].Min then
		name = CreatureMath.SizeTier(size).Id .. " " .. name
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
