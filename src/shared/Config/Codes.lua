--[[
	Redeemable codes (not case-sensitive). One use per player.
	Expires = optional unix time after which the code stops working.
]]

return {
	RELEASE = { Reward = { Cash = 5000 } },
	TITANS = { Reward = { Food = { GoldenApple = 5, Meat = 10 } } },
	CLASH = { Reward = { Boost = { Id = "Growth", Minutes = 15 } } },
	STARFOOD = { Reward = { Food = { StarFood = 1 } } },
}
