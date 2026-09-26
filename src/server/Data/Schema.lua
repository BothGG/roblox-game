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

Schema.CURRENT_VERSION = 3

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
	}
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
	for _, section in { "Stats", "Settings", "Daily", "Quests" } do
		for key, value in template[section] do
			if data[section][key] == nil then
				data[section][key] = value
			end
		end
	end
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
