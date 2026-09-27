--!strict
--[[
	Types: shared type definitions. Using these in function signatures lets
	the type checker catch mistakes (typos in field names, wrong values).
]]

export type CreatureData = {
	Id: string,
	Level: number,
	Xp: number,
	Mutation: string?,
	Size: number?, -- x1 .. x100,000 size multiplier (Config/Sizes.lua)
	Tamed: boolean?, -- false while a wild titan is being tamed (Phase 1)
	Saddle: string?, -- saddle item id; needed to ride (Phase 1)
	Hunger: number?, -- 0..100 (Phase 3)
	Bonus: number?, -- stat bonus from breeding (0.05 = +5% HP and Attack)
	BreedReadyAt: number?, -- os.time() when it can breed again
}

export type InventoryItem = { Id: string, Count: number }
export type Inventory = {
	Resources: { [string]: number }, -- wood, stone, fiber, metal, crystal...
	Items: { InventoryItem }, -- tools, saddles, food, ammo (stacks)
}
-- A placed build piece in the base (plot-local position, rotation in degrees).
export type Structure = { Id: string, X: number, Y: number, Z: number, R: number, Hp: number? }
export type Upgrades = { Pens: number, Storage: number, Incubators: number, IncubatorSpeed: number }
export type EggData = {
	Uid: string,
	Species: string,
	Mutation: string?,
	Size: number,
	Bonus: number,
	Source: string,
	Slot: number?,
	StartedAt: number?,
	HatchAt: number?,
}
export type BreedingPen = { A: string?, B: string?, StartedAt: number?, ReadyAt: number? }

export type PlayerStats = {
	StarterGiven: boolean,
	Hatched: number,
	Steals: number,
	Stolen: number,
	FoodEaten: number,
	FoodPicked: number,
	PlayTime: number,
	BattlesPlayed: number,
	BattlesWon: number,
	Tamed: number,
	CashEarned: number,
}

export type Quest = { Id: string, Goal: number, Progress: number, Claimed: boolean }

export type PlayerData = {
	Version: number,
	Cash: number,
	Rebirths: number,
	NextUid: number,
	Creatures: { [string]: CreatureData },
	Active: string?, -- uid of the titan used in battles
	Food: { [string]: number },
	Trophies: number,
	Index: { [string]: boolean }, -- "Rex" and "Rex:Lava"
	IndexClaimed: { [string]: boolean }, -- milestone number (as string) -> claimed
	Tutorial: number, -- current step, 0 = finished
	TutorialProgress: number,
	Daily: { Streak: number, LastDay: number },
	Quests: { Day: number, List: { Quest } },
	Codes: { [string]: boolean },
	Boosts: { [string]: number }, -- boost id -> expires at (os.time)
	Passes: { [string]: boolean }, -- game pass key -> owned
	Purchases: { string }, -- recent receipt ids (duplicate protection)
	Settings: { Music: boolean, Sfx: boolean },
	Stats: PlayerStats,
	LastOnline: number,
	Inventory: Inventory,
	Structures: { Structure },
	Upgrades: Upgrades,
	Eggs: { [string]: EggData },
	Breeding: BreedingPen,
}

-- What the client UI receives (PlayerData + computed values).
export type Snapshot = {
	Cash: number,
	Rebirths: number,
	Creatures: { [string]: CreatureData },
	Active: string?,
	Food: { [string]: number },
	Trophies: number,
	Index: { [string]: boolean },
	IndexClaimed: { [string]: boolean },
	IndexCount: number,
	Slots: number,
	StorageCap: number,
	RebirthCost: number,
	SelectedFood: string?,
	Tutorial: number,
	TutorialProgress: number,
	Daily: { Streak: number, LastDay: number },
	Quests: { Day: number, List: { Quest } },
	Boosts: { [string]: number },
	Passes: { [string]: boolean },
	Settings: { Music: boolean, Sfx: boolean },
	Stats: PlayerStats,
	Income: number?,
	IsKing: boolean?,
	Friends: number?,
	LockedUntil: number?,
	LockCooldownUntil: number?,
	ServerTime: number?,
	IsAdmin: boolean?,
	Upgrades: Upgrades?,
	Inventory: Inventory?,
	Following: { [string]: boolean }?, -- titans following you (FollowerService)
	Eggs: { [string]: EggData }?,
	Breeding: BreedingPen?,
	Incubators: number?,
}

-- Modules must return exactly one non-nil value.
return {}
