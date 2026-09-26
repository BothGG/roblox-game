return function(t)
	local ConfigValidator = t.require(t.Shared.Game.ConfigValidator)

	t.test("all config files are valid and fit together", function()
		local errors = ConfigValidator.Validate()
		if #errors > 0 then
			error("\n      " .. table.concat(errors, "\n      "))
		end
	end)

	t.test("every creature lives in at least one biome or egg", function()
		local Creatures = t.require(t.Shared.Config.Creatures)
		local Biomes = t.require(t.Shared.Config.Biomes)
		local Eggs = t.require(t.Shared.Config.Eggs)
		local obtainable = {}
		for _, id in Biomes.Order do
			for _, entry in Biomes[id].Wild do
				obtainable[entry.Creature] = true
			end
		end
		for _, id in Eggs.Order do
			for _, odd in Eggs[id].Odds do
				obtainable[odd.Creature] = true
			end
		end
		for id in Creatures do
			if not obtainable[id] then
				error(id .. " can't be obtained anywhere")
			end
		end
	end)

	t.test("every food grows in a biome or can be bought", function()
		local Foods = t.require(t.Shared.Config.Foods)
		local Biomes = t.require(t.Shared.Config.Biomes)
		local found = {}
		for _, id in Biomes.Order do
			for _, entry in Biomes[id].Foods do
				found[entry.Food] = true
			end
		end
		for _, id in Foods.Order do
			if not found[id] and not Foods[id].Price then
				error(id .. " can't be obtained anywhere")
			end
		end
	end)
end
