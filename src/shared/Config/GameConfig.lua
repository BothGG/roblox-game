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

	-- World layout
	Plots = {
		Count = 8, -- set the place's Max Players to this number
		Radius = 190,
		Size = 90,
	},

	WildFood = {
		Max = 25,
		Interval = 3,
		AreaRadius = 100,
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
