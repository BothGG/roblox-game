return function(t)
	local Rules = t.require(t.Shared.Game.Rules)
	local CreatureMath = t.require(t.Shared.Game.CreatureMath)
	local Schema = t.require(t.Server.Data.Schema)
	local GameConfig = t.require(t.Shared.Config.GameConfig)

	t.test("favorite food gives bonus XP", function()
		local rex = { Id = "Rex", Level = 1, Xp = 0 }
		-- Rex: Growth +25%, loves Meat (10 growth) -> 10 * 1.25 * 2 = 25
		t.expect(Rules.FeedXp(rex, "Meat")).toBe(25)
		-- Golden Apple (35 growth) not a favorite -> 35 * 1.25 = 43
		t.expect(Rules.FeedXp(rex, "GoldenApple")).toBe(43)
		-- growth multiplier (boosts / VIP / Blood Moon) stacks on top
		t.expect(Rules.FeedXp(rex, "Meat", 2)).toBe(50)
	end)

	t.test("AddXp levels up across multiple levels and keeps leftover", function()
		local c = { Id = "Gloop", Level = 1, Xp = 0 }
		local need = CreatureMath.XpToNext(1) + CreatureMath.XpToNext(2)
		t.expect(Rules.AddXp(c, need + 3)).toBe(2)
		t.expect(c.Level).toBe(3)
		t.expect(c.Xp).toBe(3)
	end)

	t.test("AddXp stops at max level", function()
		local c = { Id = "Gloop", Level = GameConfig.MaxLevel - 1, Xp = 0 }
		Rules.AddXp(c, 1e12)
		t.expect(c.Level).toBe(GameConfig.MaxLevel)
		t.expect(c.Xp).toBe(0)
	end)

	t.test("PickFood uses selected food, then falls back in menu order", function()
		t.expect(Rules.PickFood({ Meat = 2, Fish = 1 }, "Fish")).toBe("Fish")
		t.expect(Rules.PickFood({ Meat = 0, Fish = 1 }, "Meat")).toBe("Fish")
		t.expect(Rules.PickFood({}, "Meat")).toBe(nil)
	end)

	t.test("pens and storage grow with rebirths and passes", function()
		local data = Schema.Template()
		t.expect(Rules.MaxSlots(data)).toBe(GameConfig.StartingSlots)
		data.Passes.ExtraPens = true
		t.expect(Rules.MaxSlots(data)).toBe(GameConfig.StartingSlots + 2)
		data.Rebirths = 100
		t.expect(Rules.MaxSlots(data)).toBe(GameConfig.MaxSlots)
		data.Rebirths = 2
		data.Passes.BigStorage = true
		t.expect(Rules.StorageCap(data)).toBe(GameConfig.StorageCap + 2 * GameConfig.StorageCapPerRebirth + 50)
	end)

	t.test("income multiplier stacks rebirth, king, pass, boost and friends", function()
		local data = Schema.Template()
		local now = 1000
		t.expect(Rules.IncomeMultiplier(data, { Now = now })).toBe(1)
		data.Rebirths = 1 -- x1.5
		data.Passes.DoubleCash = true -- x2
		data.Boosts.Cash = now + 60 -- x2
		local mult = Rules.IncomeMultiplier(data, { Now = now, IsKing = true, Friends = 2 }) -- king x1.5, friends x1.2
		t.expect(mult).toBeCloseTo(1.5 * 1.5 * 2 * 2 * 1.2)
		-- expired boost no longer counts
		t.expect(Rules.IncomeMultiplier(data, { Now = now + 61 })).toBeCloseTo(1.5 * 2)
	end)

	t.test("friend boost is capped", function()
		t.expect(Rules.FriendMult(0)).toBe(1)
		t.expect(Rules.FriendMult(20)).toBeCloseTo(1 + GameConfig.Social.MaxFriendBoost)
	end)

	t.test("luck multiplies only rare egg weights", function()
		local odds = { { Creature = "Gloop", Weight = 10 }, { Creature = "Phoenix", Weight = 1 } }
		local lucky = Rules.ApplyLuck(odds, 2)
		t.expect(lucky[1].Weight).toBe(10)
		t.expect(lucky[2].Weight).toBe(2)
	end)

	t.test("active titan is the chosen one, else the highest level", function()
		local data = Schema.Template()
		data.Creatures = { ["1"] = { Id = "Rex", Level = 5, Xp = 0 }, ["2"] = { Id = "Kong", Level = 9, Xp = 0 } }
		t.expect((Rules.ActiveTitan(data))).toBe("2")
		data.Active = "1"
		t.expect((Rules.ActiveTitan(data))).toBe("1")
		data.Active = "99" -- sold titan
		t.expect((Rules.ActiveTitan(data))).toBe("2")
	end)

	t.test("income scales with level and mutation", function()
		t.expect(CreatureMath.BaseIncome({ Id = "Gloop", Level = 1, Xp = 0 })).toBe(3)
		t.expect(CreatureMath.BaseIncome({ Id = "Gloop", Level = 1, Xp = 0, Mutation = "Lava" })).toBe(6)
	end)
end
