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
	MaxSlots = 24, -- pens per base (the base has 24 pen spots; unlock with rebirths/upgrades)
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
		IslandRadius = 450,
		PlazaRadius = 40, -- stone plaza in the middle with the arena portal
		FieldInner = 62, -- food fields ring
		FieldOuter = 190,
		-- "Studs" = classic Roblox look (Plastic parts with studs, like a baseplate).
		-- "Terrain" = smooth terrain grass.
		Style = "Studs",
		-- The arena is its own square block floating high above the island.
		-- Step into the portal in the plaza to go up; fighters are teleported.
		ArenaHeight = 300,
		ArenaSize = 180, -- the whole block (the fighting square is 48 studs smaller)
	},

	Plots = {
		Count = 6, -- set the place's Max Players to this number too
		RingRadius = 310,
		Size = 160,
	},

	Food = {
		FieldSpawns = 60, -- food spawn spots in the fields
		RespawnTime = { Common = 20, Rare = 35, Epic = 60, Legendary = 120, Mythic = 300, Secret = 600 },
	},

	-- Wild titans (WildService + shared/Game/WildBrain.lua).
	-- Per-rarity odds and knock-out torpor are in Rarities.lua;
	-- Temper (Passive / Aggressive) and Pack are per titan in Creatures.lua.
	Wild = {
		MaxWild = 20, -- wild titans on the server at once (packs count each titan)
		RespawnDelay = 6, -- seconds between spawn checks
		Lifetime = { Min = 300, Max = 600 },
		WanderRadius = 45,
		MoveSpeed = 8, -- walking
		RunSpeed = 22, -- fleeing / chasing
		PackSize = { 3, 5 },
		AggroRange = 45, -- aggressive titans chase players this close
		AttackRange = 9, -- + the titan's size
		LeashRange = 120, -- give up the chase this far from home
		FleeTime = 7, -- passive titans run this long after being hit
		AttackCooldown = 1.6,
		AttackDamage = 0.12, -- share of the titan's battle Attack dealt to players per hit
		SpawnNear = { Min = 70, Max = 260 }, -- new wild titans appear this far from a player
		DespawnDistance = 520, -- no player this close for DespawnAfter seconds -> despawn
		DespawnAfter = 40,
		MutationChance = 0.04,
		EventLuck = 3, -- rare weight multiplier during the Wild Rush event
		-- Size rolls for wild titans: { chance, min size, max size }
		SizeRolls = { { 0.72, 1, 3 }, { 0.2, 3, 10 }, { 0.065, 10, 100 }, { 0.015, 100, 1000 } },
		-- Old quick-tame (hold E + food), still used when KnockOut = false
		KnockOut = true,
		TameDistance = 14,
		FavoriteBonus = 0.2,
	},

	-- Knock-out taming (TameService + shared/Game/Taming.lua), ARK style:
	-- hit it until it sleeps, then feed it until the taming bar is full.
	Tame = {
		SleepTime = 60, -- seconds asleep at full torpor
		TorporDrain = 0.04, -- share of max torpor lost per second while awake
		FoodPerRarity = 3, -- food needed = Rarity.TameFood * this (x size bonus)
		FavoritePoints = 2, -- a favorite food counts this much
		DamageLoss = 0.05, -- effectiveness lost per hit while asleep
		MinEffectiveness = 0.4,
		MaxBonusLevels = 6, -- tamed at level 1 + effectiveness * this
		FeedDistance = 16, -- + the titan's size
	},

	-- Riding your titans anywhere (RideService + shared/Game/Riding.lua)
	Riding = {
		RequireSaddle = false, -- saddles are crafted in Phase 3; until then every titan can be ridden
		SprintMult = 1.6,
		SprintDrain = 18, -- stamina per second
		FlyDrain = 11,
		Regen = 12,
		MinToStart = 10, -- stamina needed to start sprinting / flying
		HpRegen = 0.03, -- share of max HP per second while not in combat
		KnockOffDamage = true, -- your titan at 0 HP throws you off
	},

	-- Eggs and breeding (Phase 2; shared/Game/Breeding.lua). Times in seconds.
	Breeding = {
		Time = { Common = 120, Rare = 300, Epic = 900, Legendary = 1800, Mythic = 3600, Secret = 7200 },
		CooldownMult = 2, -- a parent rests Time * this before breeding again
		MutationChance = 0.05, -- neither parent mutated
		OneMutatedChance = 0.12, -- one parent mutated: baby gets that mutation
		BothMutatedChance = 0.3, -- both mutated: baby gets one of theirs
		BonusRange = { -0.02, 0.08 }, -- baby stat bonus = parents' average + this
		MaxBonus = 1, -- +100% stats at most
		TierJumpChance = 0.04, -- egg jumps one size tier above its parents
		HatchTime = { Common = 60, Rare = 180, Epic = 600, Legendary = 1200, Mythic = 2400, Secret = 3600 },
		HatchPerTier = 0.5, -- each size tier above Tiny hatches 50% slower
		IncubatorSpeedPerLevel = 0.15,
		CarrySpeed = 16, -- walk speed carrying a Tiny egg
		CarryPenaltyPerTier = 0.07, -- slower for every size tier
		MinCarrySpeed = 7,
		DroppedTime = 10, -- a dropped egg can be grabbed by anyone for this long
		AnnounceTier = "Colossal", -- server message when an egg this big appears
		BeamTier = "Titanic", -- sky beam on eggs this big
		FuseCost = { Common = 500, Rare = 2500, Epic = 10000, Legendary = 50000, Mythic = 200000, Secret = 1000000 },
	},

	-- Wild nests (NestService): an egg guarded by angry titans of its kind.
	Nests = {
		Max = 2, -- nests on the island at once
		FirstDelay = 20, -- seconds after the server starts
		RespawnDelay = 180, -- after a nest is raided or expires
		Lifetime = 600,
		Guardians = { 1, 2 },
		GuardianSize = { 1, 3 }, -- guardian size = egg size * this range
		-- Egg size tier chances (1 = Tiny, 2 = Normal, ...)
		SizeTiers = { { 1, 0.5 }, { 2, 0.3 }, { 3, 0.14 }, { 4, 0.05 }, { 5, 0.01 } },
		BonusMax = 0.05, -- random stat bonus 0..this
	},

	-- Titans that follow you around (FollowerService)
	Followers = {
		Max = 3,
		TeleportDistance = 140, -- farther than this -> teleport next to you
		GuardRange = 40,
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
		-- Save size limits (a DataStore value must stay under 4 MB; these keep
		-- a maxed-out save far below that; see Schema.Trim / EstimateSize).
		Limits = {
			Structures = 600, -- placed build pieces per base (Phase 4)
			ItemStacks = 120, -- backpack + chest item stacks (Phase 3)
			ResourceKinds = 40,
			Eggs = 60, -- eggs in incubators + egg storage
		},
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
