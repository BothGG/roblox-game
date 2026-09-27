--!strict
--[[
	Rules: pure game rules (no Roblox objects), so they're easy to test.
	The server uses these to decide; the client uses them to show the same
	numbers in the UI.
]]

local Config = script.Parent.Parent.Config
local Creatures = require(Config.Creatures)
local Foods = require(Config.Foods)
local GameConfig = require(Config.GameConfig)
local Rarities = require(Config.Rarities)
local Store = require(Config.Store)
local Upgrades = require(Config.Upgrades)
local Types = require(script.Parent.Parent.Types)
local CreatureMath = require(script.Parent.CreatureMath)
local Progress = require(script.Parent.Progress)

type PlayerData = Types.PlayerData
type CreatureData = Types.CreatureData

local Rules = {}

-- Perks from owned game passes ----------------------------------------------

export type Perks = {
	IncomeMult: number,
	GrowthMult: number,
	OfflineRate: number,
	ExtraStorage: number,
	ExtraSlots: number,
	Tags: { string },
}

function Rules.Perks(data: PlayerData): Perks
	local perks: Perks = {
		IncomeMult = 1,
		GrowthMult = 1,
		OfflineRate = GameConfig.Offline.Rate,
		ExtraStorage = 0,
		ExtraSlots = 0,
		Tags = {},
	}
	for key, owned in data.Passes do
		local pass = Store.Passes[key]
		if owned and pass then
			local p = pass.Perks
			perks.IncomeMult *= p.IncomeMult or 1
			perks.GrowthMult *= p.GrowthMult or 1
			perks.OfflineRate = math.max(perks.OfflineRate, p.OfflineRate or 0)
			perks.ExtraStorage += p.ExtraStorage or 0
			perks.ExtraSlots += p.ExtraSlots or 0
			if p.Tag then
				table.insert(perks.Tags, p.Tag)
			end
		end
	end
	return perks
end

-- Pens / storage -------------------------------------------------------------

-- Level of a base upgrade (0 if never bought).
function Rules.UpgradeLevel(data: PlayerData, id: string): number
	local levels = (data :: any).Upgrades
	return if levels and type(levels[id]) == "number" then levels[id] else 0
end

function Rules.MaxSlots(data: PlayerData): number
	local perks = Rules.Perks(data)
	return math.min(
		GameConfig.MaxSlots,
		GameConfig.StartingSlots
			+ data.Rebirths * GameConfig.SlotsPerRebirth
			+ perks.ExtraSlots
			+ Rules.UpgradeLevel(data, "Pens") * Upgrades.Pens.Per
	)
end

function Rules.StorageCap(data: PlayerData): number
	return CreatureMath.StorageCap(data.Rebirths)
		+ Rules.Perks(data).ExtraStorage
		+ Rules.UpgradeLevel(data, "Storage") * Upgrades.Storage.Per
end

-- Base upgrades ---------------------------------------------------------------

-- Cash cost of the next level, or nil when maxed / not available yet.
function Rules.UpgradeCost(data: PlayerData, id: string): number?
	local def = Upgrades[id]
	if not def or not def.Enabled then
		return nil
	end
	local level = Rules.UpgradeLevel(data, id)
	if level >= def.Max then
		return nil
	end
	return math.floor(def.BaseCost * def.Growth ^ level)
end

-- Buys one level of an upgrade. Returns ok, and a reason when it fails.
function Rules.BuyUpgrade(data: PlayerData, id: string): (boolean, string?)
	local def = Upgrades[id]
	if not def then
		return false, "Unknown upgrade"
	end
	if not def.Enabled then
		return false, "Coming soon!"
	end
	local cost = Rules.UpgradeCost(data, id)
	if not cost then
		return false, "Already maxed!"
	end
	if data.Cash < cost then
		return false, "Not enough cash"
	end
	data.Cash -= cost
	local levels = (data :: any).Upgrades
	levels[id] = Rules.UpgradeLevel(data, id) + 1
	return true, nil
end

function Rules.HasFreeSlot(data: PlayerData): boolean
	return CreatureMath.Count(data.Creatures) < Rules.MaxSlots(data)
end

function Rules.StorageSpace(data: PlayerData): number
	return Rules.StorageCap(data) - CreatureMath.CountFood(data.Food)
end

-- Multipliers ----------------------------------------------------------------

export type IncomeContext = {
	IsKing: boolean?,
	Friends: number?,
	Now: number,
}

function Rules.FriendMult(friends: number): number
	return 1 + math.min(friends * GameConfig.Social.FriendBoost, GameConfig.Social.MaxFriendBoost)
end

function Rules.IncomeMultiplier(data: PlayerData, ctx: IncomeContext): number
	return CreatureMath.PlayerMultiplier(data.Rebirths, ctx.IsKing)
		* Rules.Perks(data).IncomeMult
		* Progress.BoostMult(data.Boosts, "Income", ctx.Now)
		* Rules.FriendMult(ctx.Friends or 0)
end

function Rules.Income(data: PlayerData, ctx: IncomeContext): number
	local total = 0
	for _, creature in data.Creatures do
		total += CreatureMath.BaseIncome(creature)
	end
	return total * Rules.IncomeMultiplier(data, ctx)
end

-- Growth multiplier from passes, boosts and events (e.g. Blood Moon).
function Rules.GrowthMultiplier(data: PlayerData, now: number, eventMult: number?): number
	return Rules.Perks(data).GrowthMult * Progress.BoostMult(data.Boosts, "Growth", now) * (eventMult or 1)
end

function Rules.Luck(data: PlayerData, now: number): number
	return Progress.BoostMult(data.Boosts, "Luck", now)
end

-- Egg odds with luck applied: rare (LuckBoosted) weights are multiplied.
function Rules.ApplyLuck(
	odds: { { Creature: string, Weight: number } },
	luck: number
): { { Creature: string, Weight: number } }
	local result = {}
	for _, entry in odds do
		local def = Creatures[entry.Creature]
		local boosted = def and Rarities[def.Rarity].LuckBoosted
		table.insert(
			result,
			{ Creature = entry.Creature, Weight = if boosted then entry.Weight * luck else entry.Weight }
		)
	end
	return result
end

-- Feeding ------------------------------------------------------------------

function Rules.IsFavorite(creatureId: string, foodId: string): boolean
	local def = Creatures[creatureId]
	return def ~= nil and def.Diet ~= nil and table.find(def.Diet, foodId) ~= nil
end

-- XP a creature gets from one food. growthMult = Rules.GrowthMultiplier(...)
function Rules.FeedXp(creature: CreatureData, foodId: string, growthMult: number?): number
	local food = Foods[foodId]
	if not food then
		return 0
	end
	local mult = (1 + CreatureMath.Trait(creature, "Growth")) * (growthMult or 1)
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

-- Wild titans ----------------------------------------------------------------

-- Spawn odds for wild titans. Each rarity's WildWeight is shared by the
-- titans of that rarity; luck multiplies the LuckBoosted (Epic+) ones.
function Rules.WildPool(luck: number?): { { Creature: string, Weight: number } }
	local perRarity: { [string]: number } = {}
	local all: { [string]: any } = Creatures :: any
	for _, def in all do
		perRarity[def.Rarity] = (perRarity[def.Rarity] or 0) + 1
	end
	local pool: { { Creature: string, Weight: number } } = {}
	for id, def in all do
		local rarity = Rarities[def.Rarity]
		local weight = rarity.WildWeight / perRarity[def.Rarity]
		if rarity.LuckBoosted then
			weight *= luck or 1
		end
		if weight > 0 then
			table.insert(pool, { Creature = id, Weight = weight })
		end
	end
	table.sort(pool, function(a, b)
		return a.Creature < b.Creature
	end)
	return pool
end

function Rules.TameTime(creatureId: string): number
	return Rarities[Creatures[creatureId].Rarity].TameTime
end

function Rules.TameFood(creatureId: string): number
	return Rarities[Creatures[creatureId].Rarity].TameFood
end

-- Which food taming uses: favorites first, then the rest in menu order.
-- Returns nil if the player doesn't have enough food, and whether a
-- favorite food was used (it raises the chance).
function Rules.TameFoodPlan(food: { [string]: number }, creatureId: string): ({ [string]: number }?, boolean)
	local need = Rules.TameFood(creatureId)
	local order = {}
	for _, id in Creatures[creatureId].Diet or {} do
		table.insert(order, id)
	end
	for _, id in Foods.Order do
		if not table.find(order, id) then
			table.insert(order, id)
		end
	end
	local plan: { [string]: number } = {}
	local favorite = false
	for _, id in order do
		if need <= 0 then
			break
		end
		local take = math.min(need, food[id] or 0)
		if take > 0 then
			plan[id] = take
			need -= take
			favorite = favorite or Rules.IsFavorite(creatureId, id)
		end
	end
	if need > 0 then
		return nil, false
	end
	return plan, favorite
end

function Rules.TameChance(creatureId: string, favorite: boolean): number
	local base = Rarities[Creatures[creatureId].Rarity].TameChance
	return math.min(1, base + (if favorite then GameConfig.Wild.FavoriteBonus else 0))
end

-- Battle titan -----------------------------------------------------------------

-- The titan used in battles: the chosen one, or the highest level one.
function Rules.ActiveTitan(data: PlayerData): (string?, CreatureData?)
	if data.Active and data.Creatures[data.Active] then
		return data.Active, data.Creatures[data.Active]
	end
	local bestUid, best = nil, nil
	for uid, creature in data.Creatures do
		if not best or creature.Level > best.Level then
			bestUid, best = uid, creature
		end
	end
	return bestUid, best
end

return Rules
