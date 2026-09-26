return function(t)
	local Battle = t.require(t.Shared.Game.Battle)
	local GameConfig = t.require(t.Shared.Config.GameConfig)

	t.test("stats grow with level and mutation", function()
		local lv1 = Battle.Stats({ Id = "Rex", Level = 1, Xp = 0 })
		t.expect(lv1.MaxHP).toBe(110)
		t.expect(lv1.Attack).toBe(12)
		local lv11 = Battle.Stats({ Id = "Rex", Level = 11, Xp = 0 })
		t.expect(lv11.MaxHP).toBe(math.floor(110 * 2.2))
		t.expect(lv11.Attack).toBe(24)
		local golden = Battle.Stats({ Id = "Rex", Level = 11, Xp = 0, Mutation = "Golden" })
		t.expect(golden.MaxHP).toBeGreaterThan(lv11.MaxHP)
	end)

	t.test("speed is capped", function()
		local huge = Battle.Stats({ Id = "Phoenix", Level = 100, Xp = 0 })
		t.expect(huge.Speed <= GameConfig.Battle.MaxSpeed).toBe(true)
	end)

	t.test("each body style has a special move", function()
		t.expect(Battle.SpecialFor("Rex").Id).toBe("Slam")
		t.expect(Battle.SpecialFor("Shellback").Id).toBe("Charge")
		t.expect(Battle.SpecialFor("Gloop").Id).toBe("Bounce")
		t.expect(Battle.SpecialFor("Drake").Id).toBe("Breath")
	end)

	t.test("damage is attack x mult with +-10%", function()
		t.expect(Battle.Damage(100, 1, 0.5)).toBe(100)
		t.expect(Battle.Damage(100, 1, 0)).toBe(90)
		t.expect(Battle.Damage(100, 1.8, 1)).toBe(198)
		t.expect(Battle.Damage(0, 1, 0)).toBe(1) -- always at least 1
	end)

	t.test("cone hit test respects range and direction", function()
		local me, look = { X = 0, Z = 0 }, { X = 0, Z = -1 }
		t.expect(Battle.InCone(me, look, { X = 0, Z = -5 }, 10, 0.3)).toBe(true) -- in front
		t.expect(Battle.InCone(me, look, { X = 0, Z = 5 }, 10, 0.3)).toBe(false) -- behind
		t.expect(Battle.InCone(me, look, { X = 0, Z = -20 }, 10, 0.3)).toBe(false) -- too far
		t.expect(Battle.InCone(me, look, { X = 8, Z = -1 }, 10, 0.3)).toBe(false) -- off to the side
	end)

	t.test("specials use their own shapes", function()
		local me, look = { X = 0, Z = 0 }, { X = 0, Z = -1 }
		local slam = Battle.Specials.Biped
		local breath = Battle.Specials.Winged
		-- Ground Slam hits behind you too
		t.expect(Battle.Hits("Special", slam, me, look, { X = 0, Z = 8 }, 8, 1)).toBe(true)
		t.expect(Battle.Hits("Attack", nil, me, look, { X = 0, Z = 8 }, 8, 1)).toBe(false)
		-- Fire Breath reaches further in front
		t.expect(Battle.Hits("Special", breath, me, look, { X = 0, Z = -18 }, 8, 1)).toBe(true)
		t.expect(Battle.Hits("Attack", nil, me, look, { X = 0, Z = -18 }, 8, 1)).toBe(false)
	end)

	t.test("giant targets are easier to hit", function()
		local me, look = { X = 0, Z = 0 }, { X = 0, Z = -1 }
		t.expect(Battle.Hits("Attack", nil, me, look, { X = 0, Z = -15 }, 8, 1)).toBe(false)
		t.expect(Battle.Hits("Attack", nil, me, look, { X = 0, Z = -15 }, 8, 10)).toBe(true)
	end)

	t.test("leader is the highest HP percent; exact ties are draws", function()
		local a = { UserId = 1, HP = 50, MaxHP = 100 }
		local b = { UserId = 2, HP = 90, MaxHP = 300 }
		t.expect(Battle.Leader({ a, b }).UserId).toBe(1)
		local c = { UserId = 3, HP = 25, MaxHP = 50 }
		t.expect(Battle.Leader({ a, c })).toBe(nil)
		t.expect(#Battle.Alive({ a, { UserId = 4, HP = 0, MaxHP = 10 } })).toBe(1)
	end)

	t.test("winner takes a share of the loser's food", function()
		local taken = Battle.FoodShare({ Meat = 20, StarFood = 1 }, 0.15)
		t.expect(taken.Meat).toBe(3)
		t.expect(taken.StarFood).toBe(nil)
		-- Tiny storage still loses one of the most common food
		local small = Battle.FoodShare({ Meat = 2, Fish = 5 }, 0.15)
		t.expect(small.Fish).toBe(1)
		t.expect(next(Battle.FoodShare({}, 0.15))).toBe(nil)
	end)

	t.test("losing trophies never goes below zero", function()
		t.expect(Battle.TrophiesAfterLoss(100)).toBe(100 - GameConfig.Battle.LoseTrophies)
		t.expect(Battle.TrophiesAfterLoss(2)).toBe(0)
	end)
end
