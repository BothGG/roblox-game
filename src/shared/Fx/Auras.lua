--[[
	Auras: effects that stay attached to a titan (mutation glow, rare sparkle).
	Used by the server when it builds a titan model, so every player sees them.

	Add a new particle style: add a function to PARTICLES below and use its
	name in Config/Mutations.lua  (Aura = { Particles = "YourStyle" }).
]]

local Textures = require(script.Parent.Textures)

local Auras = {}

local function emitter(parent: Instance, color: Color3): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "Aura"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-90, 90)
	e.Parent = parent
	return e
end

local PARTICLES = {
	Embers = function(parent: Instance, color: Color3)
		local e = emitter(parent, color)
		e.Texture = Textures.Sparkle
		e.Rate = 10
		e.Lifetime = NumberRange.new(1.2, 2.2)
		e.Speed = NumberRange.new(1, 3)
		e.Acceleration = Vector3.new(0, 4, 0)
		e.SpreadAngle = Vector2.new(60, 60)
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(1, 0),
		})
	end,
	Sparkles = function(parent: Instance, color: Color3)
		local e = emitter(parent, color)
		e.Texture = Textures.Sparkle
		e.Rate = 6
		e.Lifetime = NumberRange.new(1, 2)
		e.Speed = NumberRange.new(0.5, 1.5)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0.6),
			NumberSequenceKeypoint.new(1, 0),
		})
	end,
	Smoke = function(parent: Instance, color: Color3)
		local e = emitter(parent, color)
		e.Texture = Textures.Smoke
		e.LightEmission = 0
		e.Rate = 5
		e.Lifetime = NumberRange.new(2, 3)
		e.Speed = NumberRange.new(0.5, 1.5)
		e.Acceleration = Vector3.new(0, 1, 0)
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.5),
			NumberSequenceKeypoint.new(1, 1),
		})
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.5),
			NumberSequenceKeypoint.new(1, 3),
		})
	end,
}

export type AuraDef = {
	Color: Color3,
	Light: boolean?,
	Particles: string?,
}

-- Adds the aura to a part (usually the titan's body). Call before scaling
-- the model, so Model:ScaleTo scales the particles and light with it.
function Auras.Apply(part: BasePart, aura: AuraDef)
	if aura.Particles and PARTICLES[aura.Particles] then
		PARTICLES[aura.Particles](part, aura.Color)
	end
	if aura.Light then
		local light = Instance.new("PointLight")
		light.Name = "AuraLight"
		light.Color = aura.Color
		light.Brightness = 1.5
		light.Range = 10
		light.Parent = part
	end
end

-- Subtle sparkle for Legendary+ titan so rare ones stand out.
function Auras.RarityGlow(part: BasePart, color: Color3)
	Auras.Apply(part, { Color = color, Light = true, Particles = "Sparkles" })
end

return Auras
