--!strict
--[[
	Sizes: every titan (and later every egg) has a Size multiplier from x1 to
	x100,000. Size multiplies income. Bigger titans also LOOK bigger, but the
	model only grows with the log of Size (and never past VisualCap), so
	giants stay on the map.

	Tiers are named by the smallest size that reaches them.
]]

export type Tier = { Id: string, Min: number, Color: Color3 }

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local Sizes = {
	Min = 1,
	Max = 100000,
	ScalePerDecade = 0.4, -- model gets 40% bigger every x10 size (x100,000 = 3x)
	VisualCap = 25, -- level scale x size scale never goes above this
	Tiers = {
		{ Id = "Tiny", Min = 1, Color = rgb(200, 200, 200) },
		{ Id = "Normal", Min = 3, Color = rgb(255, 255, 255) },
		{ Id = "Big", Min = 10, Color = rgb(120, 220, 120) },
		{ Id = "Huge", Min = 100, Color = rgb(80, 170, 255) },
		{ Id = "Giant", Min = 1000, Color = rgb(180, 110, 255) },
		{ Id = "Colossal", Min = 10000, Color = rgb(255, 170, 40) },
		{ Id = "Titanic", Min = 50000, Color = rgb(255, 80, 80) },
		{ Id = "Mythical", Min = 100000, Color = rgb(255, 100, 220) },
	} :: { Tier },
}

return Sizes
