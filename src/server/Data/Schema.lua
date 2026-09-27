--!strict
--[[
	Schema: what a player's save looks like, and how old saves are upgraded.

	Changing the save format:
	  1. Change Template() below.
	  2. Bump CURRENT_VERSION.
	  3. Add Migrations[oldVersion] = function(data) ... end that upgrades
	     a save from oldVersion to oldVersion + 1.
	Never delete old migrations: some players haven't played in months.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Types = require(Shared.Types)

type PlayerData = Types.PlayerData

local Schema = {}

Schema.CURRENT_VERSION = 5

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value :: any do
		copy[k] = deepCopy(v)
	end
	return copy :: any
end
Schema.DeepCopy = deepCopy

function Schema.Template(): PlayerData
	return {
		Version = Schema.CURRENT_VERSION,
		Cash = GameConfig.StartingCash,
		Rebirths = 0,
		NextUid = 1,
		Creatures = {},
		Active = nil,
		Food = deepCopy(GameConfig.StartingFood),
		Trophies = 0,
		Index = {},
		IndexClaimed = {},
		Tutorial = 1,
		TutorialProgress = 0,
		Daily = { Streak = 0, LastDay = -1 },
		Quests = { Day = -1, List = {} },
		Codes = {},
		Boosts = {},
		Passes = {},
		Purchases = {},
		Settings = { Music = true, Sfx = true },
		Stats = {
			StarterGiven = false,
			Hatched = 0,
			Steals = 0,
			Stolen = 0,
			FoodEaten = 0,
			FoodPicked = 0,
			PlayTime = 0,
			BattlesPlayed = 0,
			BattlesWon = 0,
			Tamed = 0,
			CashEarned = 0,
		},
		LastOnline = 0,
		-- v4 (ARK-style foundation)
		Inventory = { Resources = {}, Items = {} },
		Structures = {},
		Upgrades = { Pens = 0, Storage = 0, Incubators = 0, IncubatorSpeed = 0 },
		-- v5 (eggs and breeding)
		Eggs = {}, -- [uid] = EggData (shared/Game/Breeding.lua)
		Breeding = {}, -- { A = uid, B = uid, StartedAt, ReadyAt }
	}
end

-- Defaults for the titan fields added in v4 (used by migration and new titans).
function Schema.FillCreature(creature: any)
	creature.Size = if type(creature.Size) == "number" then creature.Size else 1
	creature.Tamed = if creature.Tamed == nil then true else creature.Tamed
	creature.Hunger = if type(creature.Hunger) == "number" then creature.Hunger else 100
	creature.Bonus = if type(creature.Bonus) == "number" then creature.Bonus else 0
	-- Saddle stays nil until one is crafted (Phase 3)
end

-- Migrations[v] upgrades a save from version v to v + 1.
local Migrations: { [number]: (any) -> () } = {
	[1] = function(data)
		-- v2: big land update (biomes). Only LastOnline survives into v3.
		data.LastOnline = data.LastOnline or 0
	end,
	[2] = function(data)
		-- v3: Titan Clash. Biomes/catching removed; battles + retention added.
		data.Unlocks = nil
		if data.Stats then
			data.Stats.Caught = nil
		end
		-- Players who already played a lot skip the tutorial.
		local played = data.Stats and (data.Stats.FoodEaten or 0) > 30
		data.Tutorial = if played then 0 else 1
	end,
	[3] = function(data)
		-- v4: ARK-style foundation. Titans get Size/Tamed/Hunger; the save gets
		-- Inventory, Structures and base Upgrades (reconcile adds the tables).
		for _, creature in data.Creatures or {} do
			Schema.FillCreature(creature)
		end
	end,
	[4] = function(data)
		-- v5: eggs and breeding. Titans get a stat Bonus (inherited when bred);
		-- reconcile adds Eggs, Breeding and the IncubatorSpeed upgrade.
		for _, creature in data.Creatures or {} do
			Schema.FillCreature(creature)
		end
	end,
}
Schema.Migrations = Migrations

-- Fills in anything missing from the template (top level + Stats/Settings
-- only, so an empty Food / Creatures table stays empty).
local function reconcile(data: any)
	local template = Schema.Template() :: any
	for key, value in template do
		if data[key] == nil then
			data[key] = value
		end
	end
	for _, section in { "Stats", "Settings", "Daily", "Quests", "Inventory", "Upgrades" } do
		for key, value in template[section] do
			if data[section][key] == nil then
				data[section][key] = value
			end
		end
	end
end

-- Keeps a save inside GameConfig.Data.Limits (drops the newest extra
-- structures / item stacks). Returns how many entries were removed.
function Schema.Trim(data: PlayerData): number
	local limits = GameConfig.Data.Limits
	local removed = 0
	while #data.Structures > limits.Structures do
		table.remove(data.Structures)
		removed += 1
	end
	local eggUids = {}
	for uid in data.Eggs do
		table.insert(eggUids, uid)
	end
	table.sort(eggUids)
	for i = limits.Eggs + 1, #eggUids do
		data.Eggs[eggUids[i]] = nil
		removed += 1
	end
	while #data.Inventory.Items > limits.ItemStacks do
		table.remove(data.Inventory.Items)
		removed += 1
	end
	local kinds = {}
	for id in data.Inventory.Resources do
		table.insert(kinds, id)
	end
	table.sort(kinds)
	for i = limits.ResourceKinds + 1, #kinds do
		data.Inventory.Resources[kinds[i]] = nil
		removed += 1
	end
	return removed
end

-- Rough size of the save in bytes when stored as JSON (for tests and warnings).
function Schema.EstimateSize(value: any): number
	local t = type(value)
	if t == "table" then
		local size = 2
		for k, v in value do
			size += Schema.EstimateSize(k) + Schema.EstimateSize(v) + 2
		end
		return size
	elseif t == "string" then
		return #value + 2
	elseif t == "number" then
		return #tostring(value)
	end
	return 5
end

-- Turns any stored value into a valid, up-to-date save.
function Schema.Prepare(stored: any): PlayerData
	if type(stored) ~= "table" then
		return Schema.Template()
	end
	local data = stored
	data.Version = data.Version or 1
	while data.Version < Schema.CURRENT_VERSION do
		local migrate = Migrations[data.Version]
		if migrate then
			migrate(data)
		end
		data.Version += 1
	end
	reconcile(data)
	return data :: PlayerData
end

return Schema
