--!strict
--[[
	Rules: pure game rules (no Roblox objects), so they're easy to test.
	The server uses these to decide; the client uses them to show the same
	numbers in the UI.
]]

local Config = script.Parent.Parent.Config
local Biomes = require(Config.Biomes)
local Creatures = require(Config.Creatures)
local Foods = require(Config.Foods)
local GameConfig = require(Config.GameConfig)
local Rarities = require(Config.Rarities)
local Types = require(script.Parent.Parent.Types)
local CreatureMath = require(script.Parent.CreatureMath)

type PlayerData = Types.PlayerData
type CreatureData = Types.CreatureData

local Rules = {}

-- Biomes -------------------------------------------------------------------

-- Returns (canUnlock, reason). reason explains why not.
function Rules.CanUnlockBiome(data: PlayerData, biomeId: string): (boolean, string?)
	local biome = Biomes[biomeId]
	if type(biome) ~= "table" or biome.Id ~= biomeId then
		return false, "Unknown area"
	end
	if data.Unlocks[biomeId] then
		return false, "Already unlocked"
	end
	if data.Rebirths < biome.Unlock.Rebirths then
		return false, string.format("Needs Rebirth %d", biome.Unlock.Rebirths)
	end
	if data.Cash < biome.Unlock.Cash then
		return false, "Not enough cash"
	end
	return true, nil
end

function Rules.IsBiomeUnlocked(data: PlayerData, biomeId: string): boolean
	return data.Unlocks[biomeId] == true
end

-- Feeding ------------------------------------------------------------------

function Rules.IsFavorite(creatureId: string, foodId: string): boolean
	local def = Creatures[creatureId]
	return def ~= nil and def.Diet ~= nil and table.find(def.Diet, foodId) ~= nil
end

-- XP a creature gets from one food.
function Rules.FeedXp(creature: CreatureData, foodId: string, eventMult: number?): number
	local food = Foods[foodId]
	if not food then
		return 0
	end
	local mult = (1 + CreatureMath.Trait(creature, "Growth")) * (eventMult or 1)
	if Rules.IsFavorite(creature.Id, foodId) then
		mult *= GameConfig.FavoriteFoodBonus
	end
	return math.floor(food.Growth * mult)
end

-- Adds XP and levels up. Returns the number of levels gained.
function Rules.AddXp(creature: CreatureData, xp: number): number
	local gained = 0
	creature.Xp += xp
	while creature.Level < GameConfig.MaxLevel and creature.Xp >= CreatureMath.XpToNext(creature.Level) do
		creature.Xp -= CreatureMath.XpToNext(creature.Level)
		creature.Level += 1
		gained += 1
	end
	if creature.Level >= GameConfig.MaxLevel then
		creature.Level = GameConfig.MaxLevel
		creature.Xp = 0
	end
	return gained
end

-- Picks which food to use: the selected one if the player has it, otherwise
-- the first one they have in menu order.
function Rules.PickFood(food: { [string]: number }, selected: string?): string?
	if selected and (food[selected] or 0) > 0 then
		return selected
	end
	for _, id in Foods.Order do
		if (food[id] or 0) > 0 then
			return id
		end
	end
	return nil
end

-- Pen / storage ------------------------------------------------------------

function Rules.HasFreeSlot(data: PlayerData): boolean
	return CreatureMath.Count(data.Creatures) < CreatureMath.MaxSlots(data.Rebirths)
end

function Rules.StorageSpace(data: PlayerData): number
	return CreatureMath.StorageCap(data.Rebirths) - CreatureMath.CountFood(data.Food)
end

-- Catching -----------------------------------------------------------------

function Rules.CatchTime(creatureId: string): number
	local def = Creatures[creatureId]
	return Rarities[def.Rarity].CatchTime
end

function Rules.CatchChance(creatureId: string): number
	local def = Creatures[creatureId]
	return Rarities[def.Rarity].CatchChance
end

return Rules
