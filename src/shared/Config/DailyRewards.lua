--[[
	7-day login streak. Claim once per day (UTC). Missing a day resets to day 1.
	After day 7 it starts again from day 1.
]]

return {
	{ Reward = { Cash = 500, CashSeconds = 60 } },
	{ Reward = { Food = { GoldenApple = 5 } } },
	{ Reward = { Cash = 2000, CashSeconds = 180 } },
	{ Reward = { Boost = { Id = "Growth", Minutes = 15 } } },
	{ Reward = { Food = { FirePepper = 2, CrystalFruit = 2 } } },
	{ Reward = { Cash = 8000, CashSeconds = 600 } },
	{ Reward = { Boost = { Id = "Luck", Minutes = 30 }, Food = { StarFood = 1 } } },
}
