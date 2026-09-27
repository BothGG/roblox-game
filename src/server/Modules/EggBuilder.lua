--[[
	EggBuilder: the 3D egg for an egg in an incubator, a nest or a carrier's
	hands. Bigger size tiers make a bigger, brighter egg; Titanic and
	Mythical eggs shine a beam into the sky (Breeding.HasBeam).

	  EggBuilder.Build({ Species, Mutation?, Size }) -> Model (pivot = bottom centre)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Breeding = require(Shared.Game.Breeding)
local Textures = require(Shared.Fx.Textures)

local EggBuilder = {}

local function ellipsoid(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	p.Parent = parent
	return p
end

-- How big the egg looks for a size (Tiny = 1, each tier +35%).
function EggBuilder.Scale(size: number): number
	return 1 + (Breeding.TierIndex(size) - 1) * 0.35
end

function EggBuilder.Build(egg: { Species: string, Mutation: string?, Size: number }): Model
	local def = Creatures[egg.Species]
	local rarity = Rarities[def.Rarity]
	local mutation = egg.Mutation and Mutations[egg.Mutation]
	local scale = EggBuilder.Scale(egg.Size)
	local body = if mutation then mutation.Color else def.BodyColor
	local spots = if mutation then mutation.AccentColor else def.AccentColor

	local model = Instance.new("Model")
	model.Name = "Egg"
	local shell = ellipsoid(model, "Shell", Vector3.new(3, 4, 3) * scale, CFrame.new(0, 2 * scale, 0), body)
	if mutation then
		shell.Material = mutation.Material
	end
	shell.Reflectance = 0.05
	model.PrimaryPart = shell
	-- Spots
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local y = (0.2 + (i % 3) * 0.25) * 4 * scale
		local offset = Vector3.new(math.cos(a) * 1.35, 0, math.sin(a) * 1.35) * scale
		ellipsoid(
			model,
			"Spot",
			Vector3.new(0.9, 0.9, 0.35) * scale,
			CFrame.lookAt(Vector3.new(0, y, 0) + offset, Vector3.new(0, y, 0) + offset * 2),
			spots
		)
	end
	-- Glow grows with the tier (and rarity)
	local tier = Breeding.TierIndex(egg.Size)
	if tier >= 2 or rarity.Order >= 3 then
		local light = Instance.new("PointLight")
		light.Color = rarity.Color
		light.Brightness = 0.5 + tier * 0.35
		light.Range = 6 + tier * 3
		light.Parent = shell
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Texture = Textures.Sparkle
		sparkle.Color = ColorSequence.new(rarity.Color)
		sparkle.LightEmission = 1
		sparkle.Rate = 2 + tier * 2
		sparkle.Lifetime = NumberRange.new(0.8, 1.4)
		sparkle.Speed = NumberRange.new(0.5, 2)
		sparkle.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0.5 * scale),
			NumberSequenceKeypoint.new(1, 0),
		})
		sparkle.Parent = shell
	end
	if Breeding.HasBeam(egg.Size) then
		local bottom = Instance.new("Attachment")
		bottom.Parent = shell
		local top = Instance.new("Attachment")
		top.Position = Vector3.new(0, 120, 0)
		top.Parent = shell
		local beam = Instance.new("Beam")
		beam.Attachment0 = bottom
		beam.Attachment1 = top
		beam.FaceCamera = true
		beam.Texture = Textures.Glow
		beam.TextureMode = Enum.TextureMode.Stretch
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Color = ColorSequence.new(rarity.Color, Color3.new(1, 1, 1))
		beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		beam.Width0 = 6 * scale
		beam.Width1 = 2 * scale
		beam.Parent = shell
	end
	model.WorldPivot = CFrame.new() -- pivot = bottom of the egg
	model:SetAttribute("Species", egg.Species)
	model:SetAttribute("EggSize", egg.Size)
	return model
end

return EggBuilder
