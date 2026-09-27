--!strict
--[[
	Rarities.
	Announce    = tell the whole server when someone hatches / finds one.
	LuckBoosted = egg weights of this rarity are multiplied by the player's luck.
	WildWeight  = how often wild titans of this rarity appear (shared by all
	              titans of that rarity).
	TameTime    = seconds to hold the Tame prompt.
	TameFood    = food it eats to be tamed.
	TameChance  = (old quick-tame) chance taming works.
	Torpor      = knock-out points (club hits, tranq darts) to put a wild titan to
	              sleep (bigger sizes need more; see shared/Game/Taming.lua).
]]

export type Rarity = {
	Id: string,
	Order: number,
	Color: Color3,
	LuckBoosted: boolean,
	Announce: boolean,
	WildWeight: number,
	TameTime: number,
	TameFood: number,
	TameChance: number,
	Torpor: number,
}

local function rarity(
	id: string,
	order: number,
	color: Color3,
	lucky: boolean,
	announce: boolean,
	wild: { number }
): Rarity
	return {
		Id = id,
		Order = order,
		Color = color,
		LuckBoosted = lucky,
		Announce = announce,
		WildWeight = wild[1],
		TameTime = wild[2],
		TameFood = wild[3],
		TameChance = wild[4],
		Torpor = wild[5],
	}
end

--                                                                  { WildWeight, TameTime, TameFood, TameChance, Torpor }
local Rarities: { [string]: Rarity } = {
	Common = rarity("Common", 1, Color3.fromRGB(200, 200, 200), false, false, { 60, 1, 1, 1, 60 }),
	Rare = rarity("Rare", 2, Color3.fromRGB(70, 150, 255), false, false, { 26, 2, 2, 0.85, 110 }),
	Epic = rarity("Epic", 3, Color3.fromRGB(175, 90, 255), true, false, { 10, 3, 4, 0.7, 200 }),
	Legendary = rarity("Legendary", 4, Color3.fromRGB(255, 175, 0), true, true, { 3, 4.5, 6, 0.55, 350 }),
	Mythic = rarity("Mythic", 5, Color3.fromRGB(255, 60, 95), true, true, { 0.8, 6, 10, 0.4, 600 }),
	Secret = rarity("Secret", 6, Color3.fromRGB(20, 255, 200), true, true, { 0.2, 8, 15, 0.3, 1000 }),
}

return Rarities
