--[[
	Every titan species. To add a new one:
	  1. Copy an entry below and give it a new key (the key is its Id).
	  2. Add it to an egg in Eggs.lua so players can hatch it.
	That's it. The placeholder model is generated from Style + colors.
	To use your own model instead, see docs/ARCHITECTURE.md.

	Style:  "Biped" | "Quad" | "Blob" | "Winged"
	Traits (all optional):
	  Growth = 0.25  -> grows 25% faster
	  Income = 0.5   -> +50% income
	  Guard  = 0.12  -> chance per second to knock thieves out of your base
	  Forage = 0.25  -> 25% chance to get double food from field pickups
	  Speed  = 4     -> +4 walk speed while carrying stolen food
	Extra looks (optional): Heads = 3, Horn = true, Tentacles = true
	Diet = favorite foods: feeding these gives bonus XP (GameConfig.FavoriteFoodBonus).
	Stats = battle stats at level 1: HP, Attack, Speed (1 = normal walk speed).
	  They grow with level (see shared/Game/Battle.lua). The special move comes
	  from Style: Biped = Ground Slam, Quad = Charge, Blob = Bounce, Winged = Fire Breath.
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
		Diet = { "Meat", "GoldenApple" },
		Stats = { HP = 100, Attack = 10, Speed = 0.95 },
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
		Diet = { "Meat" },
		Stats = { HP = 110, Attack = 12, Speed = 1.0 },
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
		Diet = { "Fish", "Coconut" },
		Stats = { HP = 140, Attack = 8, Speed = 0.8 },
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
		Diet = { "ShadowShroom", "CrystalFruit" },
		Stats = { HP = 150, Attack = 15, Speed = 0.95 },
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
		Diet = { "GoldenApple", "Coconut" },
		Stats = { HP = 170, Attack = 16, Speed = 0.95 },
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
		Diet = { "Fish" },
		Stats = { HP = 200, Attack = 20, Speed = 0.9 },
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
		Diet = { "FirePepper", "Meat" },
		Stats = { HP = 190, Attack = 22, Speed = 1.15 },
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
		Diet = { "FirePepper" },
		Stats = { HP = 260, Attack = 30, Speed = 1.2 },
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
		Diet = { "StarFood", "Fish" },
		Stats = { HP = 380, Attack = 38, Speed = 0.95 },
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
		Diet = { "ShadowShroom", "StarFood" },
		Stats = { HP = 520, Attack = 50, Speed = 1.1 },
		Traits = { Guard = 0.2, Growth = 0.5, Income = 0.5 },
		Description = "Nobody knows where it came from.",
	},
	Pincher = {
		Name = "Pincher",
		Rarity = "Common",
		BaseIncome = 4,
		Style = "Quad",
		Horn = true,
		BodyColor = rgb(240, 110, 80),
		AccentColor = rgb(255, 210, 170),
		Diet = { "Fish" },
		Stats = { HP = 95, Attack = 11, Speed = 1.1 },
		Traits = { Forage = 0.1 },
		Description = "A beach crab that snaps up extra food.",
	},
	Frostbite = {
		Name = "Frostbite",
		Rarity = "Rare",
		BaseIncome = 14,
		Style = "Biped",
		BodyColor = rgb(235, 245, 255),
		AccentColor = rgb(120, 190, 255),
		Diet = { "IceBerry" },
		Stats = { HP = 150, Attack = 14, Speed = 1.05 },
		Traits = { Guard = 0.1 },
		Description = "A baby yeti. Cold hands, warm heart.",
	},
	Tuskar = {
		Name = "Tuskar",
		Rarity = "Epic",
		BaseIncome = 40,
		Style = "Quad",
		Horn = true,
		BodyColor = rgb(150, 110, 80),
		AccentColor = rgb(250, 245, 230),
		Diet = { "IceBerry", "CrystalFruit" },
		Stats = { HP = 240, Attack = 19, Speed = 0.85 },
		Traits = { Income = 0.3 },
		Description = "A woolly mammoth titan from the snow.",
	},
}

for id, def in Creatures do
	def.Id = id
end

return Creatures
