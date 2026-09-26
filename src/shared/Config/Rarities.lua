--!strict
--[[
	Rarities. CatchTime = seconds to hold the Catch prompt on a wild kaiju,
	CatchChance = chance the catch works (fail = it runs away),
	Announce = tell the whole server when one spawns / is caught.
]]

export type Rarity = {
	Id: string,
	Order: number,
	Color: Color3,
	CatchTime: number,
	CatchChance: number,
	Announce: boolean,
}

local Rarities: { [string]: Rarity } = {
	Common = {
		Id = "Common",
		Order = 1,
		Color = Color3.fromRGB(200, 200, 200),
		CatchTime = 1.5,
		CatchChance = 1,
		Announce = false,
	},
	Rare = {
		Id = "Rare",
		Order = 2,
		Color = Color3.fromRGB(70, 150, 255),
		CatchTime = 2.5,
		CatchChance = 0.8,
		Announce = false,
	},
	Epic = {
		Id = "Epic",
		Order = 3,
		Color = Color3.fromRGB(175, 90, 255),
		CatchTime = 3.5,
		CatchChance = 0.6,
		Announce = false,
	},
	Legendary = {
		Id = "Legendary",
		Order = 4,
		Color = Color3.fromRGB(255, 175, 0),
		CatchTime = 5,
		CatchChance = 0.4,
		Announce = true,
	},
	Mythic = {
		Id = "Mythic",
		Order = 5,
		Color = Color3.fromRGB(255, 60, 95),
		CatchTime = 6,
		CatchChance = 0.25,
		Announce = true,
	},
	Secret = {
		Id = "Secret",
		Order = 6,
		Color = Color3.fromRGB(20, 255, 200),
		CatchTime = 8,
		CatchChance = 0.15,
		Announce = true,
	},
}

return Rarities
