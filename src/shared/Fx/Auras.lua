--[[
	Auras: effects that stay on a titan so rare and mutated ones LOOK rare
	from across the map (like the glowing rare pets in top Roblox games).
	Added by the server when it builds a titan model, so everyone sees them.

	Rarity auras (Auras.Rarity):
	  Rare       glowing ground ring + a few sparkles
	  Epic       + rising sparkles and a soft light
	  Legendary  + a light beam into the sky
	  Mythic     + a colored outline (Highlight) and more sparkles
	  Secret     + a swirling vortex

	Mutation auras (Auras.Apply) use PARTICLES below. Add a new style there
	and use its name in Config/Mutations.lua (Aura = { Particles = "Name" }).

	Every part added here has Paint = "Fx" so mutation paint skips it.
]]

local Textures = require(script.Parent.Textures)

local Auras = {}

local function kp(time: number, value: number): NumberSequenceKeypoint
	return NumberSequenceKeypoint.new(time, value)
end

local function emitter(parent: Instance, color: Color3 | ColorSequence): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "Aura"
	e.Color = if typeof(color) == "ColorSequence" then color else ColorSequence.new(color :: Color3)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-90, 90)
	e.Parent = parent
	return e
end

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 200, 60)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(90, 230, 110)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(70, 180, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(170, 90, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 70, 170)),
})

local PARTICLES = {
	-- Glowing embers rising off the body + a flicker of flame.
	Embers = function(parent: Instance, color: Color3)
		local e = emitter(parent, ColorSequence.new(Color3.fromRGB(255, 230, 120), color))
		e.Texture = Textures.Sparks
		e.Rate = 14
		e.Lifetime = NumberRange.new(1, 1.8)
		e.Speed = NumberRange.new(2, 5)
		e.Acceleration = Vector3.new(0, 6, 0)
		e.SpreadAngle = Vector2.new(50, 50)
		e.Size = NumberSequence.new({ kp(0, 0.5), kp(1, 0) })
		local flame = emitter(parent, color)
		flame.Texture = Textures.Fire
		flame.Rate = 6
		flame.Lifetime = NumberRange.new(0.5, 0.9)
		flame.Speed = NumberRange.new(1, 2)
		flame.Acceleration = Vector3.new(0, 5, 0)
		flame.Size = NumberSequence.new({ kp(0, 1.2), kp(1, 0) })
		flame.Transparency = NumberSequence.new({ kp(0, 0.4), kp(1, 1) })
	end,
	-- Twinkling star sparkles around the body.
	Sparkles = function(parent: Instance, color: Color3)
		local e = emitter(parent, color)
		e.Texture = Textures.Sparkle
		e.Rate = 8
		e.Lifetime = NumberRange.new(0.8, 1.6)
		e.Speed = NumberRange.new(0.5, 1.5)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new({ kp(0, 0), kp(0.5, 0.9), kp(1, 0) })
	end,
	-- Dark wisps + purple glints.
	Smoke = function(parent: Instance, color: Color3)
		local e = emitter(parent, Color3.fromRGB(40, 20, 60))
		e.Texture = Textures.Smoke
		e.LightEmission = 0
		e.Rate = 6
		e.Lifetime = NumberRange.new(1.5, 2.5)
		e.Speed = NumberRange.new(0.5, 1.5)
		e.Acceleration = Vector3.new(0, 1.5, 0)
		e.Transparency = NumberSequence.new({ kp(0, 1), kp(0.3, 0.4), kp(1, 1) })
		e.Size = NumberSequence.new({ kp(0, 1.5), kp(1, 3.5) })
		local glint = emitter(parent, color)
		glint.Texture = Textures.Sparkle
		glint.Rate = 5
		glint.Lifetime = NumberRange.new(0.6, 1)
		glint.Speed = NumberRange.new(0.5, 1)
		glint.Size = NumberSequence.new({ kp(0, 0), kp(0.5, 0.7), kp(1, 0) })
	end,
	-- Rainbow sparkles (for the Rainbow mutation).
	Rainbow = function(parent: Instance, _color: Color3)
		local e = emitter(parent, RAINBOW)
		e.Texture = Textures.Sparkle
		e.Rate = 16
		e.Lifetime = NumberRange.new(1, 1.6)
		e.Speed = NumberRange.new(1, 3)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new({ kp(0, 0), kp(0.4, 1.1), kp(1, 0) })
	end,
}

export type AuraDef = {
	Color: Color3,
	Light: boolean?,
	Particles: string?,
}

-- Adds a mutation aura to a part (usually the titan's body). Call before
-- scaling the model, so Model:ScaleTo scales the particles and light with it.
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

local function fxPart(model: Model, size: Vector3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = "AuraFx"
	p:SetAttribute("Paint", "Fx")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Parent = model
	return p
end

-- Rarity aura. `order` is Rarities[x].Order (2 = Rare ... 6 = Secret).
-- Call on a freshly built model (scale 1, pivot at the feet, at the origin).
function Auras.Rarity(model: Model, order: number, color: Color3, body: BasePart)
	if order < 2 then
		return
	end
	local pivot = model:GetPivot()
	local extents = model:GetExtentsSize()
	local footprint = math.max(extents.X, extents.Z) * 1.25 + 1

	-- Glowing ring on the ground.
	local ring = fxPart(
		model,
		Vector3.new(0.1, footprint, footprint),
		pivot * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90))
	)
	ring.Name = "AuraRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.55
	local inner = fxPart(
		model,
		Vector3.new(0.12, footprint * 0.8, footprint * 0.8),
		pivot * CFrame.new(0, 0.11, 0) * CFrame.Angles(0, 0, math.rad(90))
	)
	inner.Shape = Enum.PartType.Cylinder
	inner.Material = Enum.Material.SmoothPlastic
	inner.Color = color:Lerp(Color3.new(0, 0, 0), 0.5)
	inner.Transparency = 0.35

	-- Sparkles rising from the ring.
	local rise = emitter(ring, color)
	rise.Texture = Textures.Sparkle
	rise.Shape = Enum.ParticleEmitterShape.Disc
	rise.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	rise.EmissionDirection = Enum.NormalId.Right -- the cylinder's axis points up
	rise.Rate = 2 + order * 2
	rise.Lifetime = NumberRange.new(1, 2)
	rise.Speed = NumberRange.new(2, 4 + order)
	rise.Size = NumberSequence.new({ kp(0, 0), kp(0.3, 0.5 + order * 0.1), kp(1, 0) })

	if order >= 3 then
		local light = Instance.new("PointLight")
		light.Name = "AuraLight"
		light.Color = color
		light.Brightness = 1 + order * 0.3
		light.Range = 8 + order * 2
		light.Parent = body
	end

	if order >= 4 then
		-- A light beam into the sky: rare titans can be spotted from far away.
		local bottom = Instance.new("Attachment")
		bottom.Name = "BeamBottom"
		bottom.Parent = ring
		local top = Instance.new("Attachment")
		top.Name = "BeamTop"
		top.Parent = ring
		top.WorldPosition = ring.Position + Vector3.new(0, 30 + order * 5, 0)
		local beam = Instance.new("Beam")
		beam.Name = "AuraBeam"
		beam.Attachment0 = bottom
		beam.Attachment1 = top
		beam.FaceCamera = true
		beam.Texture = Textures.Glow
		beam.TextureMode = Enum.TextureMode.Stretch
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Brightness = 2
		beam.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
		beam.Transparency = NumberSequence.new({ kp(0, 0.25), kp(0.6, 0.7), kp(1, 1) })
		beam.Width0 = footprint * 0.9
		beam.Width1 = footprint * 0.4
		beam.Segments = 1
		beam.Parent = ring
	end

	if order >= 5 then
		local h = Instance.new("Highlight")
		h.Name = "AuraOutline"
		h.FillTransparency = 1
		h.OutlineColor = color
		h.OutlineTransparency = 0.2
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = model
		local glints = emitter(body, color)
		glints.Texture = Textures.Star
		glints.Rate = 10
		glints.Lifetime = NumberRange.new(0.6, 1.2)
		glints.Speed = NumberRange.new(0.5, 2)
		glints.SpreadAngle = Vector2.new(180, 180)
		glints.Size = NumberSequence.new({ kp(0, 0), kp(0.5, 1.2), kp(1, 0) })
	end

	if order >= 6 then
		local vortex = emitter(ring, color)
		vortex.Texture = Textures.Vortex
		vortex.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		vortex.EmissionDirection = Enum.NormalId.Right
		vortex.Speed = NumberRange.new(0.01)
		vortex.SpreadAngle = Vector2.zero
		vortex.Rate = 1.5
		vortex.Lifetime = NumberRange.new(1.5)
		vortex.RotSpeed = NumberRange.new(120)
		vortex.Size = NumberSequence.new({ kp(0, footprint * 0.3), kp(1, footprint * 0.6) })
		vortex.Transparency = NumberSequence.new({ kp(0, 1), kp(0.3, 0.3), kp(1, 1) })
	end
end

-- Kept for older code: a small sparkle glow on a part.
function Auras.RarityGlow(part: BasePart, color: Color3)
	Auras.Apply(part, { Color = color, Light = true, Particles = "Sparkles" })
end

return Auras
