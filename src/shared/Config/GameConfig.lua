--[[
	GameConfig: every balance number for the game lives here.
	Change numbers here instead of inside scripts.
]]

local GameConfig = {
	-- Display names. Rename the game or the creatures in one place.
	GameName = "Titan Clash",
	CreatureName = "Titan",
	CreatureNamePlural = "Titans",

	-- Starting state for a new player (and after a rebirth)
	StartingCash = 150,
	StartingFood = { Meat = 5 },
	StarterCreature = "Rex",

	-- Pens (titans per base) / food storage
	StartingSlots = 3,
	MaxSlots = 8, -- pens per base (the base has 8 pen spots)
	SlotsPerRebirth = 1,
	StorageCap = 50,
	StorageCapPerRebirth = 10,

	-- Growth
	MaxLevel = 100,
	ScalePerLevel = 0.12, -- Lv 100 = ~13x bigger than Lv 1
	IncomePerLevel = 0.25, -- each level adds +25% of base income
	SellSeconds = 40, -- selling gives this many seconds of the titan's income
	FavoriteFoodBonus = 2, -- XP multiplier when fed a food in its Diet

	-- Hatching
	HatchMutationChance = 0.03,
	RainbowHatchChance = 0.002,

	-- Rebirth
	RebirthBaseCost = 250000,
	RebirthCostGrowth = 4,
	RebirthIncomeBonus = 0.5, -- +50% income per rebirth

	-- Titan King (biggest titan on the server)
	KingIncomeBonus = 0.5,
	KingMinLevel = 5,
	KingCheckInterval = 3,

	-- Island layout (used by the map generator; a hand-built map ignores these)
	Map = {
		Seed = 2026, -- change for a different random layout of props/spawns
		IslandRadius = 330,
		ArenaRadius = 95,
		FieldInner = 143, -- food fields ring
		FieldOuter = 197,
		-- "Studs" = classic Roblox look (Plastic parts with studs, like a baseplate).
		-- "Terrain" = smooth terrain grass.
		Style = "Studs",
		-- The arena stands on its own ground in the middle, with a water moat
		-- and 4 bridges around it.
		ArenaPlatform = 30, -- ground around the arena wall (studs past ArenaRadius)
		MoatWidth = 10,
	},

	Plots = {
		Count = 12, -- set the place's Max Players to this number (6 also works)
		RingRadius = 262,
		Size = 74,
	},

	Food = {
		FieldSpawns = 60, -- food spawn spots in the fields
		RespawnTime = { Common = 20, Rare = 35, Epic = 60, Legendary = 120, Mythic = 300, Secret = 600 },
	},

	-- Wild titans roaming the fields: find them and tame them with food.
	-- Per-rarity odds / tame time / food cost are in Rarities.lua.
	Wild = {
		MaxWild = 8, -- wild titans on the island at once
		RespawnDelay = 12, -- seconds between spawns (randomized a bit)
		Lifetime = { Min = 120, Max = 240 }, -- then it wanders off
		WanderRadius = 28,
		MoveSpeed = 7,
		TameDistance = 14,
		MutationChance = 0.04,
		FavoriteBonus = 0.2, -- + tame chance when fed a favorite food
		EventLuck = 3, -- rare weight multiplier during the Wild Rush event
	},

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

	Battle = {
		Countdown = 3,
		MaxDuration = 90,
		ResultsTime = 4,
		RequestTimeout = 15,
		ChallengeCooldown = 10, -- seconds between challenges per player
		AttackCooldown = 0.7,
		AttackRange = 8, -- + titan size bonus (see shared/Game/Battle.lua)
		MaxSpeed = 34,
		-- Duel rewards
		WinTrophies = 10,
		LoseTrophies = 5,
		WinCashSeconds = 60, -- seconds of the winner's income
		WinCashBonus = 500,
		WinFoodShare = 0.15, -- winner takes this share of the loser's food
		-- Titan Clash (free-for-all event)
		ClashJoinTime = 20,
		ClashWinTrophies = 25,
		ClashWinCashSeconds = 180,
		ClashWinFood = { StarFood = 1 },
		ClashParticipateCashSeconds = 30,
	},

	Events = {
		FirstDelay = 150,
		Interval = 300,
		MeteorFoodCount = 30,
		BloodMoonDuration = 90,
		BloodMoonGrowthMult = 2,
		WildRushDuration = 90,
	},

	Offline = {
		MinSeconds = 60,
		MaxSeconds = 8 * 3600,
		Rate = 0.25,
		VipRate = 0.5,
	},

	Social = {
		FriendBoost = 0.1, -- +10% income per friend in the server
		MaxFriendBoost = 0.5,
	},

	Data = {
		StoreName = "TitanClash_v1",
		AutosaveInterval = 120,
		MaxReceipts = 100, -- purchase receipts remembered per player
	},

	Leaderboards = {
		RefreshInterval = 90,
		Size = 10,
	},

	-- Players who can use the admin panel (user ids). The game's creator and
	-- anyone testing in Studio are always admins.
	Admins = {},

	-- Removes the default "Baseplate" part so the generated map is used.
	ReplaceBaseplate = true,
}

return GameConfig
