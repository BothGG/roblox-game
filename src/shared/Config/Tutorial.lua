--[[
	Tutorial steps, in order. Each step completes when its Event happens
	Count times (with an optional MinLevel for LevelUp).
	Target tells the client where to point the arrow:
	  "MyTitan" | "Food" | "Wild" | "Menu:Eggs" | "Menu:Titans" | "Arena"
]]

return {
	RewardCash = 300, -- per finished step
	Steps = {
		{ Text = "Walk to your titan and press E to feed it", Event = "Fed", Count = 1, Target = "MyTitan" },
		{ Text = "Grab 3 food in the fields around the arena", Event = "FoodPicked", Count = 3, Target = "Food" },
		{
			Text = "Knock out a wild titan with your 🏏 club, then hold E to feed it until it's tamed",
			Event = "Tamed",
			Count = 1,
			Target = "Wild",
		},
		{
			Text = "Feed your titans until one reaches Lv.5",
			Event = "LevelUp",
			Count = 1,
			MinLevel = 5,
			Target = "MyTitan",
		},
		{ Text = "Choose your fighter in the 🐾 Titans menu", Event = "Equipped", Count = 1, Target = "Menu:Titans" },
		{
			Text = "Fight! Challenge a player or join a Titan Clash",
			Event = "BattlePlayed",
			Count = 1,
			Target = "Arena",
		},
	},
}
