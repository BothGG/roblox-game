return function(t)
	local Rules = t.require(t.Shared.Game.Rules)
	local CreatureMath = t.require(t.Shared.Game.CreatureMath)
	local Schema = t.require(t.Server.Data.Schema)
	local GameConfig = t.require(t.Shared.Config.GameConfig)

	t.test("favorite food gives bonus XP", function()
		local rex = { Id = "Rex", Level = 1, Xp = 0 }
		local normal = Rules.FeedXp(rex, "GoldenApple")
		local favorite = Rules.FeedXp(rex, "Meat")
		-- Rex: Growth +25%, loves Meat (10 growth) -> 10 * 1.25 * 2 = 25
		t.expect(favorite).toBe(25)
		-- Golden Apple (35 growth) not a favorite -> 35 * 1.25 = 43
		t.expect(normal).toBe(43)
	end)

	t.test("AddXp levels up across multiple levels and keeps leftover", function()
		local c = { Id = "Gloop", Level = 1, Xp = 0 }
		local need = CreatureMath.XpToNext(1) + CreatureMath.XpToNext(2)
		local gained = Rules.AddXp(c, need + 3)
		t.expect(gained).toBe(2)
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

	t.test("biome unlock checks rebirths, cash and duplicates", function()
		local data = Schema.Template()
		local ok, reason = Rules.CanUnlockBiome(data, "Forest")
		t.expect(ok).toBe(false)
		t.expect(reason).toBe("Already unlocked")

		data.Cash = 0
		ok, reason = Rules.CanUnlockBiome(data, "Beach")
		t.expect(reason).toBe("Not enough cash")

		data.Cash = 1e12
		ok = Rules.CanUnlockBiome(data, "Beach")
		t.expect(ok).toBe(true)

		ok, reason = Rules.CanUnlockBiome(data, "Volcano")
		t.expect(ok).toBe(false)
		t.expect(reason).toBe("Needs Rebirth 1")

		ok, reason = Rules.CanUnlockBiome(data, "Order")
		t.expect(reason).toBe("Unknown area")
	end)

	t.test("slots and storage grow with rebirths", function()
		t.expect(CreatureMath.MaxSlots(0)).toBe(GameConfig.StartingSlots)
		t.expect(CreatureMath.MaxSlots(100)).toBe(GameConfig.MaxSlots)
		t.expect(CreatureMath.StorageCap(2)).toBe(GameConfig.StorageCap + 2 * GameConfig.StorageCapPerRebirth)
	end)

	t.test("income scales with level, mutation and rebirth", function()
		local base = CreatureMath.BaseIncome({ Id = "Gloop", Level = 1, Xp = 0 })
		t.expect(base).toBe(3)
		local lava = CreatureMath.BaseIncome({ Id = "Gloop", Level = 1, Xp = 0, Mutation = "Lava" })
		t.expect(lava).toBe(6)
		t.expect(CreatureMath.PlayerMultiplier(2, true)).toBeCloseTo(2 * 1.5)
	end)
end
