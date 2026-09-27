return function(t)
	local Breeding = t.require(t.Shared.Game.Breeding)
	local GameConfig = t.require(t.Shared.Config.GameConfig)
	local Schema = t.require(t.Server.Data.Schema)
	local BREED = GameConfig.Breeding

	local function rolls(overrides)
		local r = { Mutation = 0.99, PickParent = 0.2, Bonus = 0.5, Size = 0, Jump = 0.99, PoolMutation = "Lava" }
		for k, v in overrides or {} do
			r[k] = v
		end
		return r
	end

	t.test("breeding needs two different titans of the same species, both rested", function()
		local a = { Id = "Rex", Size = 1 }
		local b = { Id = "Rex", Size = 1 }
		t.expect((Breeding.CanBreed(a, b, 100))).toBe(true)
		t.expect((Breeding.CanBreed(a, a, 100))).toBe(false)
		t.expect((Breeding.CanBreed(a, { Id = "Gloop" }, 100))).toBe(false)
		t.expect((Breeding.CanBreed(a, { Id = "Rex", BreedReadyAt = 200 }, 100))).toBe(false)
		t.expect((Breeding.CanBreed(a, nil, 100))).toBe(false)
		t.expect(Breeding.Time("Rex")).toBe(BREED.Time.Common)
		t.expect(Breeding.Time("Voidmaw")).toBe(BREED.Time.Secret)
	end)

	t.test("baby inherits: mutations by chance, stat bonus around the parents', size between their tiers", function()
		local plain = { Id = "Rex", Size = 1, Bonus = 0.1 }
		local lava = { Id = "Rex", Size = 10, Bonus = 0.3, Mutation = "Lava" }
		local gold = { Id = "Rex", Size = 10, Mutation = "Golden" }
		t.expect(Breeding.MakeEgg(plain, plain, rolls()).Mutation).toBe(nil)
		t.expect(Breeding.MakeEgg(plain, plain, rolls({ Mutation = 0.01 })).Mutation).toBe("Lava") -- pool pick
		t.expect(Breeding.MakeEgg(plain, lava, rolls({ Mutation = 0.05 })).Mutation).toBe("Lava")
		t.expect(Breeding.MakeEgg(lava, gold, rolls({ Mutation = 0.1, PickParent = 0.9 })).Mutation).toBe("Golden")
		local egg = Breeding.MakeEgg(plain, lava, rolls({ Bonus = 0 }))
		t.expect(egg.Bonus).toBeCloseTo(0.2 + BREED.BonusRange[1], 1e-9)
		t.expect(egg.Size).toBe(1) -- Size roll 0 -> lower parent tier
		t.expect(Breeding.MakeEgg(plain, lava, rolls({ Size = 0.99 })).Size).toBe(10)
		t.expect(Breeding.MakeEgg(lava, lava, rolls({ Jump = 0 })).Size).toBe(100) -- rare jump: Big -> Huge
		t.expect(Breeding.MakeEgg({ Id = "Rex", Bonus = 5 }, { Id = "Rex", Bonus = 5 }, rolls()).Bonus)
			.toBe(BREED.MaxBonus)
	end)

	t.test("bigger eggs hatch slower and carry slower; incubator speed helps", function()
		local tiny = Breeding.HatchTime("Rex", 1, 0)
		t.expect(tiny).toBe(BREED.HatchTime.Common)
		t.expect(Breeding.HatchTime("Rex", 100000, 0) > tiny * 3).toBe(true)
		t.expect(Breeding.HatchTime("Rex", 1, 10) < tiny).toBe(true)
		t.expect(Breeding.CarrySpeed(1)).toBe(BREED.CarrySpeed)
		t.expect(Breeding.CarrySpeed(100000) < Breeding.CarrySpeed(10)).toBe(true)
		t.expect(Breeding.CarrySpeed(100000) >= BREED.MinCarrySpeed).toBe(true)
		local egg =
			{ Uid = "e1", Species = "Rex", Size = 1, Bonus = 0, Source = "Breed", StartedAt = 100, HatchAt = 200 }
		t.expect(Breeding.HatchProgress(egg, 150)).toBe(0.5)
		t.expect(Breeding.HatchProgress(egg, 999)).toBe(1)
		t.expect(Breeding.IncubatorCount(2)).toBe(3)
	end)

	t.test("size tiers: announcements and sky beams only for huge eggs", function()
		t.expect(Breeding.TierIndex(1)).toBe(1)
		t.expect(Breeding.TierIndex(10000)).toBe(6)
		t.expect(Breeding.ShouldAnnounce(1000)).toBe(false)
		t.expect(Breeding.ShouldAnnounce(10000)).toBe(true)
		t.expect(Breeding.HasBeam(10000)).toBe(false)
		t.expect(Breeding.HasBeam(50000)).toBe(true)
	end)

	t.test("fusion: 3 of the same titan and tier become the next tier", function()
		local rex = { Id = "Rex", Size = 3 }
		t.expect((Breeding.FuseResult({ rex, rex, rex }))).toBe(10)
		t.expect((Breeding.FuseResult({ rex, rex }))).toBe(nil)
		t.expect((Breeding.FuseResult({ rex, rex, { Id = "Gloop", Size = 3 } }))).toBe(nil)
		t.expect((Breeding.FuseResult({ rex, rex, { Id = "Rex", Size = 10 } }))).toBe(nil)
		local top = { Id = "Rex", Size = 100000 }
		local _, reason = Breeding.FuseResult({ top, top, top })
		t.expect(reason).toBe("Already the biggest size")
	end)

	t.test("v4 saves migrate to v5 with eggs, breeding and a titan stat bonus", function()
		local old = Schema.Template() :: any
		old.Version = 4
		old.Eggs = nil
		old.Breeding = nil
		old.Upgrades = { Pens = 2, Storage = 1, Incubators = 0 }
		old.Creatures = { ["1"] = { Id = "Rex", Level = 5, Xp = 0, Size = 10, Tamed = true, Hunger = 100 } }
		local data = Schema.Prepare(old)
		t.expect(data.Version).toBe(5)
		t.expect(data.Creatures["1"].Bonus).toBe(0)
		t.expect(data.Creatures["1"].Size).toBe(10)
		t.expect(data.Upgrades.Pens).toBe(2)
		t.expect(data.Upgrades.IncubatorSpeed).toBe(0)
		t.expect(next(data.Eggs)).toBe(nil)
		t.expect(data.Breeding ~= nil).toBe(true)
	end)

	t.test("nest eggs roll size tiers by weight; fusing costs more for bigger and rarer titans", function()
		t.expect(Breeding.RollNestSize(0)).toBe(1)
		t.expect(Breeding.RollNestSize(0.6)).toBe(3) -- past Tiny (0.5), inside Normal
		t.expect(Breeding.RollNestSize(0.9)).toBe(10)
		t.expect(Breeding.RollNestSize(0.999)).toBe(1000)
		t.expect(Breeding.FuseCost("Rex", 1)).toBe(BREED.FuseCost.Common)
		t.expect(Breeding.FuseCost("Rex", 10)).toBe(BREED.FuseCost.Common * 4)
		t.expect(Breeding.FuseCost("Voidmaw", 1)).toBe(BREED.FuseCost.Secret)
	end)
end
