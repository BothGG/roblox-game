--[[
	Particle / beam textures used by effects. The defaults are textures that
	ship with Roblox (used by Explosion, ForceField and Fire), so everything
	works with no uploads. To level up the look, swap any of them for a
	Creator Store texture ("rbxassetid://...") and every effect updates.
]]

local P = "rbxasset://textures/particles/"

return {
	Sparkle = P .. "sparkles_main.dds", -- 4-point star sparkle
	Star = P .. "sparkles_main.dds",
	Fire = P .. "fire_main.dds", -- soft flame
	Sparks = P .. "fire_sparks_main.dds", -- small bright sparks (good for streaks)
	Smoke = P .. "smoke_main.dds", -- soft puff
	Core = P .. "explosion01_core_main.dds", -- bright round flash
	Shockwave = P .. "explosion01_shockwave_main.dds", -- ring
	Implode = P .. "explosion01_implosion_main.dds", -- swirl for charge-ups
	Dust = P .. "explosion01_smoke_main.dds", -- dusty smoke
	Glow = P .. "forcefield_glow_main.dds", -- soft round glow
	Vortex = P .. "forcefield_vortex_main.dds", -- swirly ring
}
