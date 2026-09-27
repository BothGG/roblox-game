return function(t)
	local Schema = t.require(t.Server.Data.Schema)
	local SessionStore = t.require(t.Server.Data.SessionStore)

	t.test("new players get the template", function()
		local data = Schema.Prepare(nil)
		t.expect(data.Version).toBe(Schema.CURRENT_VERSION)
		t.expect(data.Tutorial).toBe(1)
		t.expect(data.Trophies).toBe(0)
		t.expect(data.Daily.LastDay).toBe(-1)
	end)

	t.test("v1 saves are migrated without losing progress", function()
		local old = {
			Version = 1,
			Cash = 1234,
			Rebirths = 2,
			NextUid = 5,
			Creatures = { ["1"] = { Id = "Rex", Level = 10, Xp = 3 } },
			Food = {},
			Index = { Rex = true },
			Stats = { StarterGiven = true, Hatched = 3, Steals = 1, Stolen = 0, FoodEaten = 50 },
		}
		local data = Schema.Prepare(old)
		t.expect(data.Version).toBe(Schema.CURRENT_VERSION)
		t.expect(data.Cash).toBe(1234)
		t.expect(data.Creatures["1"].Level).toBe(10)
		t.expect(data.Unlocks).toBe(nil)
		t.expect(data.Trophies).toBe(0)
		t.expect(data.Stats.BattlesWon).toBe(0)
		t.expect(data.Settings.Music).toBe(true)
		t.expect(data.Tutorial).toBe(0) -- played a lot already: no tutorial
		t.expect(next(data.Food)).toBe(nil) -- empty food stays empty
	end)

	t.test("v2 saves (big land update) migrate to the current version", function()
		local old = {
			Version = 2,
			Cash = 50,
			Rebirths = 0,
			NextUid = 2,
			Creatures = {},
			Food = { Meat = 1 },
			Unlocks = { Forest = true, Beach = true },
			Index = {},
			Stats = {
				StarterGiven = true,
				Hatched = 0,
				Caught = 4,
				Steals = 0,
				Stolen = 0,
				FoodEaten = 3,
				PlayTime = 10,
			},
			LastOnline = 123,
		}
		local data = Schema.Prepare(old)
		t.expect(data.Version).toBe(Schema.CURRENT_VERSION)
		t.expect(data.Unlocks).toBe(nil)
		t.expect(data.Stats.Caught).toBe(nil)
		t.expect(data.Tutorial).toBe(1)
		t.expect(data.LastOnline).toBe(123)
		t.expect(data.Food.Meat).toBe(1)
	end)

	t.test("v3 saves migrate to v4 keeping titans, food and cash", function()
		local old = Schema.Template() :: any
		old.Version = 3
		old.Cash = 98765
		old.Food = { Meat = 7, StarFood = 1 }
		old.Creatures = {
			["1"] = { Id = "Rex", Level = 30, Xp = 12, Mutation = "Lava" },
			["2"] = { Id = "Gloop", Level = 2, Xp = 0 },
		}
		old.Inventory = nil
		old.Structures = nil
		old.Upgrades = nil
		local data = Schema.Prepare(old)
		t.expect(data.Version).toBe(Schema.CURRENT_VERSION)
		t.expect(data.Cash).toBe(98765)
		t.expect(data.Food.StarFood).toBe(1)
		t.expect(data.Creatures["1"].Level).toBe(30)
		t.expect(data.Creatures["1"].Mutation).toBe("Lava")
		t.expect(data.Creatures["1"].Size).toBe(1)
		t.expect(data.Creatures["1"].Tamed).toBe(true)
		t.expect(data.Creatures["2"].Hunger).toBe(100)
		t.expect(data.Creatures["2"].Saddle).toBe(nil)
		t.expect(data.Upgrades.Pens).toBe(0)
		t.expect(#data.Structures).toBe(0)
		t.expect(data.Inventory.Resources ~= nil).toBe(true)
	end)

	t.test("a maxed-out save stays far under the 4 MB DataStore limit", function()
		local GameConfig = t.require(t.Shared.Config.GameConfig)
		local limits = GameConfig.Data.Limits
		local data = Schema.Template() :: any
		for i = 1, GameConfig.MaxSlots do
			data.Creatures[tostring(i)] = {
				Id = "Hydra",
				Level = 100,
				Xp = 123456,
				Mutation = "Rainbow",
				Size = 100000,
				Tamed = true,
				Hunger = 100,
				Saddle = "SaddleQuadMetal",
			}
		end
		for i = 1, limits.Structures + 50 do
			table.insert(
				data.Structures,
				{ Id = "StoneWall", X = i * 4.5, Y = 12.25, Z = -i * 3.75, R = 270, Hp = 1500 }
			)
		end
		for i = 1, limits.ItemStacks + 10 do
			table.insert(data.Inventory.Items, { Id = "TranqArrow" .. i, Count = 999 })
		end
		for i = 1, limits.ResourceKinds + 5 do
			data.Inventory.Resources["Resource" .. i] = 99999
		end
		for i = 1, 300 do
			data.Index["Titan" .. i .. ":Rainbow"] = true
		end
		local removed = Schema.Trim(data)
		t.expect(removed).toBe(50 + 10 + 5)
		t.expect(#data.Structures).toBe(limits.Structures)
		t.expect(Schema.EstimateSize(data) < 200 * 1024).toBe(true) -- 4 MB limit, keep a huge margin
	end)

	t.test("every old version has a migration", function()
		for v = 1, Schema.CURRENT_VERSION - 1 do
			if not Schema.Migrations[v] then
				error("missing migration from v" .. v)
			end
		end
	end)

	t.test("session lock: second server waits, then can take an abandoned lock", function()
		local store = SessionStore.new("LockTest")
		local data, status = store:Load("P1", function()
			return true
		end)
		t.expect(status).toBe("ok")
		t.expect(data).toBe(nil)

		-- Pretend another (alive) server holds the lock right now.
		__DATASTORE.LockTest.P1.Lock = { JobId = "other-server", Time = os.time() }
		local ok, lost = store:Save("P1", { Cash = 1 })
		t.expect(ok).toBe(false)
		t.expect(lost).toBe(true) -- we must stop saving

		-- Loading waits for it, then takes it over (task.wait is instant in tests).
		local _, status2 = store:Load("P1", function()
			return true
		end)
		t.expect(status2).toBe("ok")
		t.expect(__DATASTORE.LockTest.P1.Lock.JobId).toBe("test-job")
	end)

	t.test("session lock is released on final save", function()
		local store = SessionStore.new("ReleaseTest")
		store:Load("P2", function()
			return true
		end)
		local ok = store:Save("P2", { Cash = 5 }, true)
		t.expect(ok).toBe(true)
		t.expect(__DATASTORE.ReleaseTest.P2.Lock).toBe(nil)
		t.expect(__DATASTORE.ReleaseTest.P2.Data.Cash).toBe(5)
	end)

	t.test("legacy saves without the lock wrapper still load", function()
		__DATASTORE.Legacy = { P3 = { Version = 1, Cash = 77 } }
		local store = SessionStore.new("Legacy")
		local data = store:Load("P3", function()
			return true
		end)
		t.expect(data.Cash).toBe(77)
	end)
end
