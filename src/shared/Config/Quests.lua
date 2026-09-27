--[[
	Daily quests. Each day every player gets `PerDay` quests picked from Pool
	(the same ones all day, different each day).

	Event  = game event that counts (see server/Modules/GameEvents.lua)
	Goal   = { min, max } the target is picked in this range
	Field  = optional event field to add instead of 1 (e.g. Amount)
	Reward = reward (cash scales with rebirths through CashSeconds)
]]

return {
	PerDay = 3,
	Pool = {
		{
			Id = "Feed",
			Text = "Feed your titans %d times",
			Event = "Fed",
			Goal = { 15, 40 },
			Reward = { CashSeconds = 120, Cash = 500 },
		},
		{
			Id = "Pick",
			Text = "Pick up %d food in the fields",
			Event = "FoodPicked",
			Goal = { 10, 30 },
			Field = "Amount",
			Reward = { CashSeconds = 120, Cash = 500 },
		},
		{
			Id = "Tame",
			Text = "Tame %d wild titans",
			Event = "Tamed",
			Goal = { 1, 3 },
			Reward = { Boost = { Id = "Luck", Minutes = 10 }, Cash = 800 },
		},
		{
			Id = "Steal",
			Text = "Steal food %d times",
			Event = "Stole",
			Goal = { 2, 5 },
			Reward = { Food = { GoldenApple = 3 }, Cash = 800 },
		},
		{
			Id = "Win",
			Text = "Win %d battles",
			Event = "BattleWon",
			Goal = { 1, 3 },
			Reward = { Boost = { Id = "Growth", Minutes = 10 }, Cash = 1000 },
		},
		{
			Id = "Fight",
			Text = "Take part in %d battles",
			Event = "BattlePlayed",
			Goal = { 2, 4 },
			Reward = { CashSeconds = 180 },
		},
		{
			Id = "Hatch",
			Text = "Hatch %d eggs",
			Event = "Hatched",
			Goal = { 1, 3 },
			Reward = { Boost = { Id = "Luck", Minutes = 10 } },
		},
		{
			Id = "Breed",
			Text = "Breed %d eggs",
			Event = "Bred",
			Goal = { 1, 2 },
			Reward = { CashSeconds = 240 },
		},
		{
			Id = "Level",
			Text = "Gain %d titan levels",
			Event = "LevelUp",
			Goal = { 5, 15 },
			Field = "Levels",
			Reward = { Food = { FirePepper = 2 } },
		},
		{
			Id = "Earn",
			Text = "Earn %s cash",
			Event = "Earned",
			Goal = { 5000, 20000 },
			Field = "Amount",
			ScaleWithRebirth = true,
			Reward = { Boost = { Id = "Cash", Minutes = 10 } },
		},
	},
}
