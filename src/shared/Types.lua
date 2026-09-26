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
}

export type PlayerStats = {
	StarterGiven: boolean,
	Hatched: number,
	Caught: number,
	Steals: number,
	Stolen: number,
	FoodEaten: number,
	PlayTime: number,
}

export type PlayerData = {
	Version: number,
	Cash: number,
	Rebirths: number,
	NextUid: number,
	Creatures: { [string]: CreatureData },
	Food: { [string]: number },
	Unlocks: { [string]: boolean }, -- biome ids
	Index: { [string]: boolean }, -- "Rex" and "Rex:Lava"
	Stats: PlayerStats,
	LastOnline: number,
}

-- What the client UI receives (PlayerData + computed values).
export type Snapshot = {
	Cash: number,
	Rebirths: number,
	Creatures: { [string]: CreatureData },
	Food: { [string]: number },
	Unlocks: { [string]: boolean },
	IndexCount: number,
	Slots: number,
	StorageCap: number,
	RebirthCost: number,
	SelectedFood: string?,
	Income: number?,
	IsKing: boolean?,
	LockedUntil: number?,
	LockCooldownUntil: number?,
}

-- Modules must return exactly one non-nil value.
return {}
