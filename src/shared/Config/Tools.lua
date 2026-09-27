--!strict
--[[
	Taming tools every player gets (ToolService). Crafting better ones comes
	in Phase 3; these are the starters.

	Damage = HP taken from a wild titan per hit
	Torpor = knock-out points added per hit (fill the titan's torpor to put it to sleep)
	Range  = studs (melee tools also need the target in front of you)
	Cooldown = seconds between uses
]]

export type Tool = {
	Id: string,
	Name: string,
	Kind: "Melee" | "Ranged",
	Damage: number,
	Torpor: number,
	Range: number,
	Cooldown: number,
	Color: Color3,
	Tip: string,
}

local Tools: { [string]: Tool } = {
	Club = {
		Id = "Club",
		Name = "Wooden Club",
		Kind = "Melee",
		Damage = 6,
		Torpor = 14,
		Range = 12,
		Cooldown = 0.6,
		Color = Color3.fromRGB(140, 95, 55),
		Tip = "Bonk wild titans to knock them out",
	},
	Tranq = {
		Id = "Tranq",
		Name = "Tranq Blowgun",
		Kind = "Ranged",
		Damage = 1,
		Torpor = 30,
		Range = 120,
		Cooldown = 1.4,
		Color = Color3.fromRGB(90, 170, 90),
		Tip = "Sleepy darts from far away",
	},
}

return Tools
