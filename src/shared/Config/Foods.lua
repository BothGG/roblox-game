--[[
	Every food. Growth = XP given when fed.
	Price = cost in the food shop (nil = can't be bought, only found or stolen).
	WildWeight = how often it spawns in the middle (bigger = more common).
	Mutation = chance to mutate the kaiju that eats it.
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
		WildWeight = 50,
		Color = rgb(190, 90, 70),
	},
	GoldenApple = {
		Name = "Golden Apple",
		Rarity = "Rare",
		Growth = 35,
		Price = 400,
		WildWeight = 18,
		Color = rgb(255, 210, 60),
	},
	FirePepper = {
		Name = "Fire Pepper",
		Rarity = "Epic",
		Growth = 20,
		Price = 2500,
		WildWeight = 8,
		Color = rgb(255, 70, 30),
		Mutation = { Id = "Lava", Chance = 0.08 },
	},
	CrystalFruit = {
		Name = "Crystal Fruit",
		Rarity = "Epic",
		Growth = 20,
		Price = 4000,
		WildWeight = 6,
		Color = rgb(120, 230, 255),
		Mutation = { Id = "Crystal", Chance = 0.08 },
	},
	ShadowShroom = {
		Name = "Shadow Shroom",
		Rarity = "Legendary",
		Growth = 30,
		WildWeight = 3,
		Color = rgb(120, 50, 200),
		Mutation = { Id = "Shadow", Chance = 0.07 },
	},
	StarFood = {
		Name = "Star Food",
		Rarity = "Mythic",
		Growth = 250,
		WildWeight = 1,
		Color = rgb(255, 255, 150),
		Mutation = { Id = "Golden", Chance = 0.05 },
		Announce = true,
	},
}

-- Display order in menus
Foods.Order = { "Meat", "GoldenApple", "FirePepper", "CrystalFruit", "ShadowShroom", "StarFood" }

return Foods
