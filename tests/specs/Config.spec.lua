return function(t)
	local ConfigValidator = t.require(t.Shared.Game.ConfigValidator)

	t.test("all config files are valid and fit together", function()
		local errors = ConfigValidator.Validate()
		if #errors > 0 then
			error("\n      " .. table.concat(errors, "\n      "))
		end
	end)

	t.test("every titan can be hatched from an egg", function()
		local Creatures = t.require(t.Shared.Config.Creatures)
		local Eggs = t.require(t.Shared.Config.Eggs)
		local obtainable = {}
		for _, id in Eggs.Order do
			for _, odd in Eggs[id].Odds do
				obtainable[odd.Creature] = true
			end
		end
		for id in Creatures do
			if not obtainable[id] then
				error(id .. " is in no egg")
			end
		end
	end)

	t.test("every food grows in the fields or can be bought", function()
		local Foods = t.require(t.Shared.Config.Foods)
		for _, id in Foods.Order do
			local def = Foods[id]
			if (def.SpawnWeight or 0) <= 0 and not def.Price then
				error(id .. " can't be obtained anywhere")
			end
		end
	end)

	t.test("every tutorial and quest event is one the server fires", function()
		local Tutorial = t.require(t.Shared.Config.Tutorial)
		for _, step in Tutorial.Steps do
			t.expect(ConfigValidator.Events[step.Event]).toBe(true)
		end
	end)
end
