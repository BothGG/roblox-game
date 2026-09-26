--[[
	Every kaiju species. To add a new one:
	  1. Copy an entry below and give it a new key (the key is its Id).
	  2. Add it to an egg in Eggs.lua so players can hatch it.
	That's it. The placeholder model is generated from Style + colors.
	To use your own model instead, see docs/ARCHITECTURE.md.

	Style:  "Biped" | "Quad" | "Blob" | "Winged"
	Traits (all optional):
	  Growth = 0.25  -> grows 25% faster
	  Income = 0.5   -> +50% income
	  Guard  = 0.12  -> chance per second to knock thieves out of your base
	  Forage = 0.25  -> 25% chance to get double food from wild pickups
	  Speed  = 4     -> +4 walk speed while carrying stolen food
	Extra looks (optional): Heads = 3, Horn = true, Tentacles = true
]]

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local Creatures = {
	Gloop = {
		Name = "Gloop",
		Rarity = "Common",
		BaseIncome = 3,
		Style = "Blob",
		BodyColor = rgb(120, 220, 90),
		AccentColor = rgb(70, 160, 55),
		Traits = {},
		Description = "A wobbly slime that eats anything.",
	},
	Rex = {
		Name = "Rex",
		Rarity = "Common",
		BaseIncome = 5,
		Style = "Biped",
		BodyColor = rgb(90, 170, 90),
		AccentColor = rgb(230, 200, 120),
		Traits = { Growth = 0.25 },
		Description = "A baby dino that grows fast.",
	},
	Shellback = {
		Name = "Shellback",
		Rarity = "Common",
		BaseIncome = 4,
		Style = "Quad",
		BodyColor = rgb(110, 180, 140),
		AccentColor = rgb(120, 85, 50),
		Traits = { Income = 0.5 },
		Description = "Slow, but earns lots of money.",
	},
	Rhinobug = {
		Name = "Rhinobug",
		Rarity = "Rare",
		BaseIncome = 12,
		Style = "Quad",
		Horn = true,
		BodyColor = rgb(60, 90, 200),
		AccentColor = rgb(230, 230, 255),
		Traits = {},
		Description = "A giant beetle with a shiny horn.",
	},
	Kong = {
		Name = "Kong",
		Rarity = "Rare",
		BaseIncome = 10,
		Style = "Biped",
		BodyColor = rgb(80, 60, 50),
		AccentColor = rgb(170, 140, 120),
		Traits = { Guard = 0.12 },
		Description = "Guards your food and smacks thieves.",
	},
	Kraken = {
		Name = "Kraken",
		Rarity = "Epic",
		BaseIncome = 30,
		Style = "Blob",
		Tentacles = true,
		BodyColor = rgb(200, 70, 120),
		AccentColor = rgb(255, 160, 190),
		Traits = { Forage = 0.25 },
		Description = "Its tentacles grab extra food.",
	},
	Drake = {
		Name = "Drake",
		Rarity = "Epic",
		BaseIncome = 35,
		Style = "Winged",
		BodyColor = rgb(200, 50, 40),
		AccentColor = rgb(255, 190, 60),
		Traits = { Speed = 4 },
		Description = "Makes you faster when you steal.",
	},
	Phoenix = {
		Name = "Phoenix",
		Rarity = "Legendary",
		BaseIncome = 90,
		Style = "Winged",
		BodyColor = rgb(255, 130, 20),
		AccentColor = rgb(255, 230, 80),
		Traits = { Growth = 0.5 },
		Description = "Born from fire. Grows very fast.",
	},
	Hydra = {
		Name = "Hydra",
		Rarity = "Mythic",
		BaseIncome = 250,
		Style = "Quad",
		Heads = 3,
		BodyColor = rgb(40, 110, 90),
		AccentColor = rgb(160, 255, 200),
		Traits = { Guard = 0.2, Income = 0.25 },
		Description = "Three heads, three times the trouble.",
	},
	Voidmaw = {
		Name = "Voidmaw",
		Rarity = "Secret",
		BaseIncome = 1000,
		Style = "Biped",
		Horn = true,
		BodyColor = rgb(25, 20, 40),
		AccentColor = rgb(140, 60, 255),
		Traits = { Guard = 0.2, Growth = 0.5, Income = 0.5 },
		Description = "Nobody knows where it came from.",
	},
}

for id, def in Creatures do
	def.Id = id
end

return Creatures
