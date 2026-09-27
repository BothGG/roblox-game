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

	t.test("wild pool: common titans are far more likely than legendary ones", function()
		local Creatures = t.require(t.Shared.Config.Creatures)
		local Rarities = t.require(t.Shared.Config.Rarities)
		local total = { Common = 0, Legendary = 0 }
		local all = 0
		for _, entry in Rules.WildPool() do
			local rarity = Creatures[entry.Creature].Rarity
			total[rarity] = (total[rarity] or 0) + entry.Weight
			all += entry.Weight
		end
		t.expect(total.Common).toBeCloseTo(Rarities.Common.WildWeight, 1e-6)
		t.expect(total.Common).toBeGreaterThan(total.Legendary * 10)
		-- luck only boosts Epic+ titans
		local lucky = 0
		for _, entry in Rules.WildPool(3) do
			lucky += entry.Weight
		end
		t.expect(lucky).toBeGreaterThan(all)
	end)

	t.test("taming uses favorite food first and needs enough food", function()
		-- Gloop (Common) needs 1 food and loves Meat
		local plan, favorite = Rules.TameFoodPlan({ Fish = 5, Meat = 1 }, "Gloop")
		t.expect(plan and plan.Meat).toBe(1)
		t.expect(favorite).toBe(true)
		-- Rhinobug (Rare) needs 2 food; no favorites -> no bonus
		local need = Rules.TameFood("Rhinobug")
		t.expect(need).toBe(2)
		local plan2, favorite2 = Rules.TameFoodPlan({ Meat = 5 }, "Rhinobug")
		t.expect(plan2 and plan2.Meat).toBe(2)
		t.expect(favorite2).toBe(false)
		t.expect((Rules.TameFoodPlan({ Meat = 1 }, "Rhinobug"))).toBe(nil)
		t.expect(Rules.TameChance("Rhinobug", true)).toBeGreaterThan(Rules.TameChance("Rhinobug", false))
		t.expect(Rules.TameChance("Gloop", true) <= 1).toBe(true)
	end)

	t.test("size tiers, labels and caps", function()
		t.expect(CreatureMath.SizeTier(1).Id).toBe("Tiny")
		t.expect(CreatureMath.SizeTier(3).Id).toBe("Normal")
		t.expect(CreatureMath.SizeTier(99).Id).toBe("Big")
		t.expect(CreatureMath.SizeTier(1000).Id).toBe("Giant")
		t.expect(CreatureMath.SizeTier(50000).Id).toBe("Titanic")
		t.expect(CreatureMath.SizeTier(100000).Id).toBe("Mythical")
		t.expect(CreatureMath.ClampSize(5e9)).toBe(100000)
		t.expect(CreatureMath.ClampSize(0)).toBe(1)
		t.expect(CreatureMath.ClampSize(nil)).toBe(1)
		t.expect(CreatureMath.ClampSize(0 / 0)).toBe(1)
		t.expect(CreatureMath.SizeLabel(1)).toBe("x1")
		t.expect(CreatureMath.SizeLabel(2.5)).toBe("x2.5")
		t.expect(CreatureMath.SizeLabel(1500)).toBe("x1.5K")
		t.expect(CreatureMath.SizeLabel(100000)).toBe("x100K")
	end)

	t.test("income multiplies by size; model scale grows with log(size) and is capped", function()
		local small = { Id = "Rex", Level = 10, Xp = 0 }
		local big = { Id = "Rex", Level = 10, Xp = 0, Size = 1000 }
		t.expect(CreatureMath.BaseIncome(big)).toBeCloseTo(CreatureMath.BaseIncome(small) * 1000, 1e-6)
		t.expect(CreatureMath.SizeScale(1)).toBe(1)
		t.expect(CreatureMath.SizeScale(100000)).toBeCloseTo(3, 1e-9)
		local huge = { Id = "Rex", Level = 100, Xp = 0, Size = 100000 }
		t.expect(CreatureMath.VisualScale(huge)).toBe(25) -- 12.88 * 3 would be 38.6
		t.expect(CreatureMath.DisplayName(big)).toBe("Giant Rex")
		t.expect(CreatureMath.DisplayName(small)).toBe("Rex")
	end)

	t.test("base upgrades: cost grows, pens and storage go up, capped at 24 pens", function()
		local data = Schema.Template()
		data.Cash = 1e12
		local slots = Rules.MaxSlots(data)
		local storage = Rules.StorageCap(data)
		local first = Rules.UpgradeCost(data, "Pens")
		t.expect(Rules.BuyUpgrade(data, "Pens")).toBe(true)
		t.expect(Rules.MaxSlots(data)).toBe(slots + 1)
		t.expect(Rules.UpgradeCost(data, "Pens") > (first :: number)).toBe(true)
		t.expect(Rules.BuyUpgrade(data, "Storage")).toBe(true)
		t.expect(Rules.StorageCap(data)).toBe(storage + 25)
		t.expect((Rules.BuyUpgrade(data, "Incubators"))).toBe(false) -- Phase 2
		for _ = 1, 40 do
			Rules.BuyUpgrade(data, "Pens")
		end
		data.Rebirths = 50
		t.expect(Rules.MaxSlots(data)).toBe(GameConfig.MaxSlots)
		local poor = Schema.Template()
		poor.Cash = 0
		local ok, reason = Rules.BuyUpgrade(poor, "Pens")
		t.expect(ok).toBe(false)
		t.expect(reason).toBe("Not enough cash")
	end)
end
