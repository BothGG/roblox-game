--[[
	Every food. Growth = XP given when fed.
	Price = cost in the food shop (nil = can't be bought: find it or steal it!).
	SpawnWeight = how often it grows in the food fields (bigger = more common).
	Mutation = chance to mutate the titan that eats it.
	Model = how it looks on the ground ("Ball", "Fruit", "Fish", "Crystal", "Mushroom", "Star").
]]

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local Foods = {
	Meat = {
		Name = "Meat",
		Rarity = "Common",
		Growth = 10,
		Price = 25,
		SpawnWeight = 50,
		Color = rgb(190, 90, 70),
		Model = "Ball",
	},
	Fish = {
		Name = "Fish",
		Rarity = "Common",
		Growth = 14,
		Price = 60,
		SpawnWeight = 35,
		Color = rgb(120, 180, 230),
		Model = "Fish",
	},
	GoldenApple = {
		Name = "Golden Apple",
		Rarity = "Rare",
		Growth = 35,
		Price = 400,
		SpawnWeight = 18,
		Color = rgb(255, 210, 60),
		Model = "Fruit",
	},
	Coconut = {
		Name = "Coconut",
		Rarity = "Rare",
		Growth = 30,
		SpawnWeight = 14,
		Color = rgb(140, 95, 60),
		Model = "Fruit",
	},
	IceBerry = {
		Name = "Ice Berry",
		Rarity = "Rare",
		Growth = 45,
		SpawnWeight = 10,
		Color = rgb(150, 210, 255),
		Model = "Fruit",
	},
	FirePepper = {
		Name = "Fire Pepper",
		Rarity = "Epic",
		Growth = 25,
		SpawnWeight = 6,
		Color = rgb(255, 70, 30),
		Model = "Fruit",
		Mutation = { Id = "Lava", Chance = 0.08 },
	},
	CrystalFruit = {
		Name = "Crystal Fruit",
		Rarity = "Epic",
		Growth = 25,
		SpawnWeight = 5,
		Color = rgb(120, 230, 255),
		Model = "Crystal",
		Mutation = { Id = "Crystal", Chance = 0.08 },
	},
	ShadowShroom = {
		Name = "Shadow Shroom",
		Rarity = "Legendary",
		Growth = 40,
		SpawnWeight = 2,
		Color = rgb(140, 60, 220),
		Model = "Mushroom",
		Mutation = { Id = "Shadow", Chance = 0.07 },
	},
	StarFood = {
		Name = "Star Food",
		Rarity = "Mythic",
		Growth = 250,
		SpawnWeight = 0.6,
		Color = rgb(255, 255, 150),
		Model = "Star",
		Mutation = { Id = "Golden", Chance = 0.05 },
	},
}

for id, def in Foods do
	def.Id = id
end

-- Display order in menus (must list every food)
Foods.Order =
	{ "Meat", "Fish", "GoldenApple", "Coconut", "IceBerry", "FirePepper", "CrystalFruit", "ShadowShroom", "StarFood" }

return Foods
