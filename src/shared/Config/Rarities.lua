--!strict
--[[
	Rarities.
	Announce    = tell the whole server when someone hatches one.
	LuckBoosted = egg weights of this rarity are multiplied by the player's luck.
]]

export type Rarity = {
	Id: string,
	Order: number,
	Color: Color3,
	LuckBoosted: boolean,
	Announce: boolean,
}

local Rarities: { [string]: Rarity } = {
	Common = { Id = "Common", Order = 1, Color = Color3.fromRGB(200, 200, 200), LuckBoosted = false, Announce = false },
	Rare = { Id = "Rare", Order = 2, Color = Color3.fromRGB(70, 150, 255), LuckBoosted = false, Announce = false },
	Epic = { Id = "Epic", Order = 3, Color = Color3.fromRGB(175, 90, 255), LuckBoosted = true, Announce = false },
	Legendary = {
		Id = "Legendary",
		Order = 4,
		Color = Color3.fromRGB(255, 175, 0),
		LuckBoosted = true,
		Announce = true,
	},
	Mythic = { Id = "Mythic", Order = 5, Color = Color3.fromRGB(255, 60, 95), LuckBoosted = true, Announce = true },
	Secret = { Id = "Secret", Order = 6, Color = Color3.fromRGB(20, 255, 200), LuckBoosted = true, Announce = true },
}

return Rarities
