--!strict
--[[
	Base upgrades, bought at the upgrade board in every base.
	Cost of the next level = BaseCost * Growth ^ currentLevel.

	  Pens       +1 pen per level (pens go up to GameConfig.MaxSlots = 24)
	  Storage    +25 food storage per level
	  Incubators for eggs (Phase 2: shown as "coming soon" until Enabled)
]]

export type Upgrade = {
	Id: string,
	Name: string,
	Icon: string,
	Text: string,
	Max: number,
	Per: number,
	BaseCost: number,
	Growth: number,
	Enabled: boolean,
}

local Upgrades: { [string]: any } = {
	Order = { "Pens", "Storage", "Incubators" },
	Pens = {
		Name = "Extra Pen",
		Icon = "🐾",
		Text = "+1 pen for a titan",
		Max = 16,
		Per = 1,
		BaseCost = 2500,
		Growth = 1.6,
		Enabled = true,
	},
	Storage = {
		Name = "Bigger Storage",
		Icon = "📦",
		Text = "+25 food storage",
		Max = 10,
		Per = 25,
		BaseCost = 1500,
		Growth = 1.8,
		Enabled = true,
	},
	Incubators = {
		Name = "Incubator",
		Icon = "🥚",
		Text = "+1 incubator for eggs",
		Max = 5,
		Per = 1,
		BaseCost = 10000,
		Growth = 2.5,
		Enabled = false, -- turned on with breeding & eggs (Phase 2)
	},
}

for id, def in Upgrades do
	if type(def) == "table" and def.Name then
		def.Id = id
	end
end

return Upgrades
