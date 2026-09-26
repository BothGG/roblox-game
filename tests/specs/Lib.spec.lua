return function(t)
	local Guard = t.require(t.Shared.Lib.Guard)
	local Signal = t.require(t.Shared.Lib.Signal)
	local Trove = t.require(t.Shared.Lib.Trove)
	local WeightedRandom = t.require(t.Shared.Lib.WeightedRandom)
	local Zones = t.require(t.Shared.Game.Zones)

	t.test("Guard rejects bad client input", function()
		t.expect(Guard.Check("Meat", "string")).toBe(true)
		t.expect(Guard.Check(5, "string")).toBe(false)
		t.expect(Guard.Check(0 / 0, "number")).toBe(false) -- NaN
		t.expect(Guard.Check(math.huge, "number")).toBe(false)
		t.expect(Guard.Check(2.5, "integer")).toBe(false)
		t.expect(Guard.Check(3, "integer")).toBe(true)
		t.expect(Guard.Check(nil, "string?")).toBe(true)
		t.expect(Guard.Check(string.rep("a", 500), "string")).toBe(false)
	end)

	t.test("Guard.CheckArgs rejects extra arguments", function()
		t.expect((Guard.CheckArgs({ "a" }, { "string" }, 1))).toBe(true)
		t.expect((Guard.CheckArgs({ "a", "b" }, { "string" }, 2))).toBe(false)
		t.expect((Guard.CheckArgs({}, { "string" }, 0))).toBe(false)
	end)

	t.test("Guard.IsConfigKey ignores helper keys like Order", function()
		local Foods = t.require(t.Shared.Config.Foods)
		t.expect(Guard.IsConfigKey(Foods, "Meat")).toBe(true)
		t.expect(Guard.IsConfigKey(Foods, "Order")).toBe(false)
		t.expect(Guard.IsConfigKey(Foods, "Nope")).toBe(false)
		t.expect(Guard.IsConfigKey(Foods, 5)).toBe(false)
	end)

	t.test("Signal connects, fires and disconnects", function()
		local signal = Signal.new()
		local total = 0
		local connection = signal:Connect(function(n)
			total += n
		end)
		signal:Fire(2)
		signal:Fire(3)
		connection:Disconnect()
		signal:Fire(100)
		t.expect(total).toBe(5)
	end)

	t.test("Signal:Once fires only once", function()
		local signal = Signal.new()
		local count = 0
		signal:Once(function()
			count += 1
		end)
		signal:Fire()
		signal:Fire()
		t.expect(count).toBe(1)
	end)

	t.test("Trove cleans functions and tables in reverse order", function()
		local trove = Trove.new()
		local order = {}
		trove:Add(function()
			table.insert(order, "first")
		end)
		trove:Add({
			Destroy = function()
				table.insert(order, "second")
			end,
		})
		trove:Clean()
		t.expect(order[1]).toBe("second")
		t.expect(order[2]).toBe("first")
	end)

	t.test("WeightedRandom respects weights", function()
		local counts = { A = 0, B = 0 }
		local entries = { { Id = "A", W = 90 }, { Id = "B", W = 10 } }
		for _ = 1, 5000 do
			local e = WeightedRandom.Pick(entries, function(e)
				return e.W
			end)
			counts[e.Id] += 1
		end
		t.expect(counts.A).toBeGreaterThan(4200)
		t.expect(counts.B).toBeGreaterThan(300)
		t.expect(WeightedRandom.Pick({}, function()
			return 1
		end)).toBe(nil)
	end)

	t.test("round zones contain points by XZ distance", function()
		local zone = { Biome = "Forest", Center = Vector3.new(100, 0, 0), Radius = 50 }
		t.expect(Zones.Contains(zone, Vector3.new(140, 999, 0))).toBe(true)
		t.expect(Zones.Contains(zone, Vector3.new(160, 0, 0))).toBe(false)
		t.expect(Zones.Find({ zone }, Vector3.new(100, 0, 49))).toBe("Forest")
		t.expect(Zones.Find({ zone }, Vector3.new(0, 0, 0))).toBe(nil)
	end)
end
