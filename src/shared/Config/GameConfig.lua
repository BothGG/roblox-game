--[[
	GameConfig: every balance number for the game lives here.
	Change numbers here instead of inside scripts.
]]

local GameConfig = {
	-- Display names. Rename the game or the creatures in one place.
	GameName = "Kaiju Keepers",
	CreatureName = "Kaiju",
	CreatureNamePlural = "Kaiju",

	-- Starting state for a new player (and after a rebirth)
	StartingCash = 150,
	StartingFood = { Meat = 5 },
	StarterCreature = "Rex",
	StartingBiomes = { "Forest" }, -- biomes unlocked for free

	-- Pen / storage
	StartingSlots = 3,
	MaxSlots = 12,
	SlotsPerRebirth = 1,
	StorageCap = 50,
	StorageCapPerRebirth = 10,

	-- Growth
	MaxLevel = 100,
	ScalePerLevel = 0.12, -- Lv 100 = ~13x bigger than Lv 1
	IncomePerLevel = 0.25, -- each level adds +25% of base income
	SellSeconds = 40, -- selling gives this many seconds of the kaiju's income
	FavoriteFoodBonus = 2, -- XP multiplier when fed a food in its Diet

	-- Hatching
	HatchMutationChance = 0.03,
	RainbowHatchChance = 0.002,

	-- Rebirth
	RebirthBaseCost = 250000,
	RebirthCostGrowth = 4,
	RebirthIncomeBonus = 0.5, -- +50% income per rebirth

	-- Kaiju King (biggest kaiju on the server)
	KingIncomeBonus = 0.5,
	KingMinLevel = 5,
	KingCheckInterval = 3,

	-- Map layout (used by the map generator; a hand-built map ignores these)
	Map = {
		Seed = 2026, -- change for a different random layout of props/spawns
		Size = 1700, -- the whole land is Size x Size studs
		HubRadius = 250, -- the zoo area in the middle
		BiomeDistance = 600, -- how far biome centers are from the middle
		BiomeRadius = 190,
	},

	Zoo = {
		PlotCount = 8, -- set the place's Max Players to this number
		RingRadius = 165,
		PlotSize = 90,
	},

	Food = {
		RespawnTime = { Common = 20, Rare = 35, Epic = 60, Legendary = 120, Mythic = 300, Secret = 600 },
	},

	Wild = {
		WanderRadius = 40,
		MoveSpeed = 8, -- studs per second
		RespawnDelay = 15, -- seconds between spawn checks per biome
		Lifetime = { Min = 180, Max = 300 }, -- wild kaiju wander off after this
		MutationChance = 0.02, -- chance a wild kaiju spawns already mutated
		CatchDistance = 20, -- server-side distance check for catching
	},

	BiomeCheckInterval = 1, -- how often the server checks players aren't in locked biomes

	Steal = {
		HoldTime = 1.5,
		CarryWalkSpeed = 11,
		NormalWalkSpeed = 16,
		DepositDistance = 12,
		LockDuration = 30,
		LockCooldown = 90,
		JoinProtection = 60,
		GuardCheckInterval = 1,
		MaxGuardChance = 0.6,
	},

	Events = {
		FirstDelay = 180,
		Interval = 420,
		MeteorFoodCount = 30,
		BloodMoonDuration = 90,
		BloodMoonGrowthMult = 2,
	},

	Data = {
		StoreName = "KaijuKeepers_v1",
		AutosaveInterval = 120,
	},

	-- Removes the default "Baseplate" part so the generated map is used.
	ReplaceBaseplate = true,
}

return GameConfig
