--[[
	Index (collection book) milestone rewards. Count = number of Index entries
	collected (each titan = 1 entry, each titan + mutation = 1 more entry).
]]

return {
	Milestones = {
		{ Count = 3, Reward = { Cash = 1000 } },
		{ Count = 6, Reward = { Food = { GoldenApple = 5 }, Cash = 3000 } },
		{ Count = 10, Reward = { Boost = { Id = "Luck", Minutes = 20 }, Cash = 10000 } },
		{ Count = 15, Reward = { Food = { StarFood = 1 }, CashSeconds = 1200 } },
		{ Count = 25, Reward = { Food = { StarFood = 2 }, CashSeconds = 3600 } },
		{ Count = 40, Reward = { Boost = { Id = "Cash", Minutes = 60 }, CashSeconds = 7200 } },
		{ Count = 78, Reward = { Food = { StarFood = 10 }, CashSeconds = 36000, Trophies = 100 } },
	},
}
