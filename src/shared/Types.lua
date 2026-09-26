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
}

-- Modules must return exactly one non-nil value.
return {}
