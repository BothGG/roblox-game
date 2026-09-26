--[[
	Mutations change how a kaiju looks and multiply its income.
	Fx = the effect preset attached to the kaiju (see Fx/Presets.lua "Aura" section).
]]

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local Mutations = {
	Lava = {
		Name = "Lava",
		IncomeMult = 2,
		Color = rgb(255, 90, 20),
		AccentColor = rgb(60, 20, 10),
		Material = Enum.Material.CrackedLava,
		Aura = { Color = rgb(255, 120, 30), Light = true, Particles = "Embers" },
	},
	Crystal = {
		Name = "Crystal",
		IncomeMult = 2.5,
		Color = rgb(140, 230, 255),
		AccentColor = rgb(230, 250, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.15,
		Aura = { Color = rgb(150, 240, 255), Light = true, Particles = "Sparkles" },
	},
	Shadow = {
		Name = "Shadow",
		IncomeMult = 3,
		Color = rgb(30, 20, 45),
		AccentColor = rgb(150, 70, 255),
		Material = Enum.Material.SmoothPlastic,
		Aura = { Color = rgb(150, 70, 255), Light = false, Particles = "Smoke" },
	},
	Golden = {
		Name = "Golden",
		IncomeMult = 5,
		Color = rgb(255, 200, 40),
		AccentColor = rgb(255, 240, 150),
		Material = Enum.Material.Foil,
		Aura = { Color = rgb(255, 220, 80), Light = true, Particles = "Sparkles" },
	},
	Rainbow = {
		Name = "Rainbow",
		IncomeMult = 10,
		Color = rgb(255, 0, 0),
		AccentColor = rgb(255, 255, 255),
		Material = Enum.Material.Neon,
		Aura = { Color = rgb(255, 255, 255), Light = true, Particles = "Sparkles" },
		Animated = true, -- the client cycles its colors
	},
}

-- Mutations a kaiju can randomly hatch with (weights)
Mutations.HatchPool = {
	{ Id = "Lava", Weight = 45 },
	{ Id = "Crystal", Weight = 35 },
	{ Id = "Shadow", Weight = 20 },
}

return Mutations
