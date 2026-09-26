return function(t)
	local Format = t.require(t.Shared.Lib.Format)

	t.test("money is abbreviated", function()
		t.expect(Format.Money(0)).toBe("$0")
		t.expect(Format.Money(999)).toBe("$999")
		t.expect(Format.Money(1234)).toBe("$1.23K")
		t.expect(Format.Money(999999)).toBe("$1M")
		t.expect(Format.Money(2.5e9)).toBe("$2.5B")
	end)

	t.test("time and percent", function()
		t.expect(Format.Time(75)).toBe("1:15")
		t.expect(Format.Time(9)).toBe("9s")
		t.expect(Format.Percent(0.35)).toBe("35%")
		t.expect(Format.Percent(0.001)).toBe("0.10%")
	end)
end
