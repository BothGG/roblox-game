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

Schema.CURRENT_VERSION = 2

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
	local unlocks = {}
	for _, biomeId in GameConfig.StartingBiomes do
		unlocks[biomeId] = true
	end
	return {
		Version = Schema.CURRENT_VERSION,
		Cash = GameConfig.StartingCash,
		Rebirths = 0,
		NextUid = 1,
		Creatures = {},
		Food = deepCopy(GameConfig.StartingFood),
		Unlocks = unlocks,
		Index = {},
		Stats = {
			StarterGiven = false,
			Hatched = 0,
			Caught = 0,
			Steals = 0,
			Stolen = 0,
			FoodEaten = 0,
			PlayTime = 0,
		},
		LastOnline = 0,
	}
end

-- Migrations[v] upgrades a save from version v to v + 1.
local Migrations: { [number]: (any) -> () } = {
	[1] = function(data)
		-- v2: big land update. Biome unlocks + catch stats.
		data.Unlocks = data.Unlocks or {}
		for _, biomeId in GameConfig.StartingBiomes do
			data.Unlocks[biomeId] = true
		end
		data.Stats = data.Stats or {}
		data.Stats.Caught = data.Stats.Caught or 0
		data.LastOnline = data.LastOnline or 0
	end,
}
Schema.Migrations = Migrations

-- Fills in anything missing from the template (top level + Stats only,
-- so an empty Food / Creatures table stays empty).
local function reconcile(data: any)
	local template = Schema.Template() :: any
	for key, value in template do
		if data[key] == nil then
			data[key] = value
		end
	end
	for key, value in template.Stats do
		if data.Stats[key] == nil then
			data.Stats[key] = value
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
