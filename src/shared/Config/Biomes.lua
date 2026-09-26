--[[
	Biomes: the areas of the big land. Each biome has its own food, wild
	kaiju, unlock cost, look (for the map generator) and ambience (lighting
	the client fades to when you walk in).

	Add a biome: add an entry + add its id to Biomes.Order. The map generator
	places biomes in a circle around the zoo in that order.
]]

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local Biomes = {
	Forest = {
		Name = "Forest",
		Icon = "🌲",
		Color = rgb(90, 190, 90),
		Unlock = { Cash = 0, Rebirths = 0 },
		Foods = {
			{ Food = "Meat", Weight = 70 },
			{ Food = "GoldenApple", Weight = 25 },
			{ Food = "ShadowShroom", Weight = 1 },
		},
		Wild = {
			{ Creature = "Gloop", Weight = 45 },
			{ Creature = "Rex", Weight = 40 },
			{ Creature = "Kong", Weight = 12 },
			{ Creature = "Phoenix", Weight = 0.5 },
		},
		MaxWild = 5,
		FoodSpawns = 22,
		Terrain = { Ground = Enum.Material.LeafyGrass, Detail = Enum.Material.Grass, Height = 6 },
		Props = "Trees",
		Ambience = {
			AtmosphereColor = rgb(200, 230, 200),
			Density = 0.3,
			Tint = rgb(255, 255, 255),
			Brightness = 2.5,
		},
	},
	Beach = {
		Name = "Beach",
		Icon = "🏖️",
		Color = rgb(250, 220, 140),
		Unlock = { Cash = 5000, Rebirths = 0 },
		Foods = {
			{ Food = "Fish", Weight = 65 },
			{ Food = "Coconut", Weight = 30 },
			{ Food = "StarFood", Weight = 0.5 },
		},
		Wild = {
			{ Creature = "Pincher", Weight = 50 },
			{ Creature = "Shellback", Weight = 40 },
			{ Creature = "Kraken", Weight = 8 },
			{ Creature = "Hydra", Weight = 0.3 },
		},
		MaxWild = 5,
		FoodSpawns = 20,
		Terrain = { Ground = Enum.Material.Sand, Detail = Enum.Material.Sandstone, Height = 2, Water = true },
		Props = "Palms",
		Ambience = {
			AtmosphereColor = rgb(210, 235, 255),
			Density = 0.25,
			Tint = rgb(255, 250, 235),
			Brightness = 3,
		},
	},
	Snow = {
		Name = "Snow Peaks",
		Icon = "❄️",
		Color = rgb(200, 230, 255),
		Unlock = { Cash = 75000, Rebirths = 0 },
		Foods = {
			{ Food = "IceBerry", Weight = 60 },
			{ Food = "CrystalFruit", Weight = 20 },
			{ Food = "Meat", Weight = 30 },
		},
		Wild = {
			{ Creature = "Frostbite", Weight = 55 },
			{ Creature = "Tuskar", Weight = 35 },
			{ Creature = "Rhinobug", Weight = 10 },
		},
		MaxWild = 4,
		FoodSpawns = 20,
		Terrain = { Ground = Enum.Material.Snow, Detail = Enum.Material.Glacier, Height = 14 },
		Props = "Pines",
		Ambience = {
			AtmosphereColor = rgb(230, 240, 255),
			Density = 0.45,
			Tint = rgb(225, 240, 255),
			Brightness = 3,
		},
	},
	Volcano = {
		Name = "Volcano",
		Icon = "🌋",
		Color = rgb(255, 110, 50),
		Unlock = { Cash = 250000, Rebirths = 1 },
		Foods = {
			{ Food = "FirePepper", Weight = 55 },
			{ Food = "Meat", Weight = 40 },
			{ Food = "StarFood", Weight = 0.5 },
		},
		Wild = {
			{ Creature = "Drake", Weight = 70 },
			{ Creature = "Phoenix", Weight = 25 },
			{ Creature = "Hydra", Weight = 2 },
		},
		MaxWild = 4,
		FoodSpawns = 18,
		Terrain = { Ground = Enum.Material.Basalt, Detail = Enum.Material.CrackedLava, Height = 10 },
		Props = "Lava",
		Ambience = {
			AtmosphereColor = rgb(255, 170, 120),
			Density = 0.5,
			Tint = rgb(255, 225, 200),
			Brightness = 2,
		},
	},
	Caves = {
		Name = "Crystal Caves",
		Icon = "💎",
		Color = rgb(170, 120, 255),
		Unlock = { Cash = 1500000, Rebirths = 2 },
		Foods = {
			{ Food = "CrystalFruit", Weight = 50 },
			{ Food = "ShadowShroom", Weight = 30 },
			{ Food = "StarFood", Weight = 1 },
		},
		Wild = {
			{ Creature = "Rhinobug", Weight = 60 },
			{ Creature = "Kraken", Weight = 25 },
			{ Creature = "Voidmaw", Weight = 0.5 },
		},
		MaxWild = 4,
		FoodSpawns = 18,
		Terrain = { Ground = Enum.Material.Slate, Detail = Enum.Material.Rock, Height = 8 },
		Props = "Crystals",
		Ambience = {
			AtmosphereColor = rgb(150, 110, 220),
			Density = 0.55,
			Tint = rgb(215, 200, 255),
			Brightness = 1.5,
		},
	},
	Island = {
		Name = "Star Island",
		Icon = "⭐",
		Color = rgb(255, 240, 120),
		Unlock = { Cash = 10000000, Rebirths = 3 },
		Foods = {
			{ Food = "StarFood", Weight = 15 },
			{ Food = "GoldenApple", Weight = 50 },
			{ Food = "ShadowShroom", Weight = 20 },
		},
		Wild = {
			{ Creature = "Hydra", Weight = 60 },
			{ Creature = "Phoenix", Weight = 38 },
			{ Creature = "Voidmaw", Weight = 2 },
		},
		MaxWild = 3,
		FoodSpawns = 14,
		Terrain = { Ground = Enum.Material.Grass, Detail = Enum.Material.Sand, Height = 4, Water = true },
		Props = "Palms",
		Ambience = {
			AtmosphereColor = rgb(255, 240, 200),
			Density = 0.2,
			Tint = rgb(255, 250, 225),
			Brightness = 3.2,
		},
	},
}

for id, def in Biomes do
	def.Id = id
end

-- Map placement order (clockwise around the zoo) and UI order.
Biomes.Order = { "Forest", "Beach", "Snow", "Volcano", "Caves", "Island" }

-- Ambience used in the zoo area in the middle (not a biome).
Biomes.HubAmbience = {
	AtmosphereColor = rgb(200, 220, 255),
	Density = 0.3,
	Tint = rgb(255, 255, 255),
	Brightness = 2.5,
}

return Biomes
