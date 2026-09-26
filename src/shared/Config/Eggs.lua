--[[
	Eggs are how players get new kaiju. Odds are weights, not percents
	(the UI converts them to percents).
]]

local Eggs = {
	BasicEgg = {
		Name = "Basic Egg",
		Price = 100,
		Color = Color3.fromRGB(240, 235, 220),
		Odds = {
			{ Creature = "Gloop", Weight = 35 },
			{ Creature = "Rex", Weight = 30 },
			{ Creature = "Pincher", Weight = 15 },
			{ Creature = "Shellback", Weight = 15 },
			{ Creature = "Rhinobug", Weight = 4.5 },
			{ Creature = "Kong", Weight = 0.5 },
		},
	},
	GreatEgg = {
		Name = "Great Egg",
		Price = 3000,
		Color = Color3.fromRGB(90, 160, 255),
		Odds = {
			{ Creature = "Shellback", Weight = 30 },
			{ Creature = "Rhinobug", Weight = 30 },
			{ Creature = "Kong", Weight = 20 },
			{ Creature = "Frostbite", Weight = 5 },
			{ Creature = "Kraken", Weight = 10 },
			{ Creature = "Drake", Weight = 5 },
		},
	},
	KaijuEgg = {
		Name = "Kaiju Egg",
		Price = 100000,
		Color = Color3.fromRGB(255, 80, 120),
		Odds = {
			{ Creature = "Kraken", Weight = 40 },
			{ Creature = "Drake", Weight = 25 },
			{ Creature = "Tuskar", Weight = 10 },
			{ Creature = "Phoenix", Weight = 20 },
			{ Creature = "Hydra", Weight = 4.9 },
			{ Creature = "Voidmaw", Weight = 0.1 },
		},
	},
}

for id, def in Eggs do
	def.Id = id
end

Eggs.Order = { "BasicEgg", "GreatEgg", "KaijuEgg" }

return Eggs
