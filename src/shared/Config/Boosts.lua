--[[
	Timed boosts. Given by potions (Store), daily rewards, quests and codes.
	Kind: what it multiplies. Mult: how much. Stacking the same boost adds time.
]]

local Boosts = {
	Cash = { Name = "2x Cash", Icon = "💰", Kind = "Income", Mult = 2 },
	Growth = { Name = "2x Growth", Icon = "🌱", Kind = "Growth", Mult = 2 },
	Luck = { Name = "2x Luck", Icon = "🍀", Kind = "Luck", Mult = 2 },
}

for id, def in Boosts do
	def.Id = id
end

Boosts.Order = { "Cash", "Growth", "Luck" }

return Boosts
