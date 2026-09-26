--[[
	Robux store. Create the passes / products on the Creator Dashboard, then
	put their ids here. Id = 0 means "not set up yet": it's shown as
	"Coming soon" and can't be bought. See docs/LAUNCH.md.

	Pass Perk keys (read by shared/Game/Rules.lua):
	  IncomeMult, GrowthMult, OfflineRate, ExtraStorage, ExtraSlots, Tag
	Product Reward uses the reward format from docs/ARCHITECTURE.md.
]]

local Store = {
	Passes = {
		DoubleCash = {
			Name = "2x Cash",
			Icon = "💰",
			Id = 0,
			PriceLabel = "299 R$",
			Description = "Double income forever.",
			Perks = { IncomeMult = 2 },
		},
		VIP = {
			Name = "VIP",
			Icon = "⭐",
			Id = 0,
			PriceLabel = "199 R$",
			Description = "+25% growth, 50% offline earnings, VIP tag.",
			Perks = { GrowthMult = 1.25, OfflineRate = 0.5, Tag = "VIP" },
		},
		BigStorage = {
			Name = "Big Storage",
			Icon = "📦",
			Id = 0,
			PriceLabel = "99 R$",
			Description = "+50 food storage.",
			Perks = { ExtraStorage = 50 },
		},
		ExtraPens = {
			Name = "Extra Pens",
			Icon = "🏠",
			Id = 0,
			PriceLabel = "149 R$",
			Description = "+2 titan pens.",
			Perks = { ExtraSlots = 2 },
		},
	},
	PassOrder = { "DoubleCash", "VIP", "BigStorage", "ExtraPens" },

	Products = {
		CashSmall = {
			Name = "Cash Pack",
			Icon = "💵",
			Id = 0,
			PriceLabel = "25 R$",
			Reward = { CashSeconds = 600, Cash = 1000 },
		},
		CashMedium = {
			Name = "Cash Bag",
			Icon = "💰",
			Id = 0,
			PriceLabel = "75 R$",
			Reward = { CashSeconds = 2400, Cash = 5000 },
		},
		CashLarge = {
			Name = "Cash Vault",
			Icon = "🏦",
			Id = 0,
			PriceLabel = "199 R$",
			Reward = { CashSeconds = 9000, Cash = 25000 },
		},
		LuckPotion = {
			Name = "Luck Potion",
			Icon = "🍀",
			Id = 0,
			PriceLabel = "49 R$",
			Reward = { Boost = { Id = "Luck", Minutes = 30 } },
		},
		GrowthPotion = {
			Name = "Growth Potion",
			Icon = "🌱",
			Id = 0,
			PriceLabel = "49 R$",
			Reward = { Boost = { Id = "Growth", Minutes = 30 } },
		},
		StarPack = {
			Name = "Star Food Pack",
			Icon = "⭐",
			Id = 0,
			PriceLabel = "99 R$",
			Reward = { Food = { StarFood = 3 } },
		},
	},
	ProductOrder = { "CashSmall", "CashMedium", "CashLarge", "LuckPotion", "GrowthPotion", "StarPack" },

	-- Studio testing: pretend the player owns every pass.
	StudioOwnsAllPasses = false,
}

for id, def in Store.Passes do
	def.Key = id
end
for id, def in Store.Products do
	def.Key = id
end

return Store
