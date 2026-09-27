--[[
	CreatureBuilder: makes the 3D model for a titan.

	If ServerStorage has a folder "CreatureModels" with a Model named after
	the titan's Id (e.g. "Rex"), that model is used. Otherwise a placeholder
	is built from parts using the Style and colors in Config/Creatures.lua.

	The placeholder titans are cute "chibi" shapes: round shiny bodies (Parts
	with Sphere meshes), big heads, big glossy eyes and rosy cheeks.

	Custom model rules: set a PrimaryPart at the FEET, facing -Z (forward).
	Give parts an attribute Paint = "Body" or "Accent" so mutations recolor
	them correctly (parts without it count as "Body").
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Auras = require(Shared.Fx.Auras)

local CreatureBuilder = {}

local WHITE = Color3.new(1, 1, 1)
local PUPIL = Color3.fromRGB(27, 27, 36)
local CHEEK = Color3.fromRGB(255, 135, 160)

local function part(model: Model, paint: string, size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = paint
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Shape = shape or Enum.PartType.Block
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p:SetAttribute("Paint", paint)
	p.Parent = model
	return p
end

-- A smooth ellipsoid (a Part with a Sphere mesh stretched to its size).
-- Cute round shapes are what make pets look "professional" in Roblox games.
local function ell(model: Model, paint: string, sx: number, sy: number, sz: number, cf: CFrame, color: Color3): Part
	local p = part(model, paint, Vector3.new(sx, sy, sz), cf, color)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	if paint == "Eye" then
		p.Reflectance = 0.12
	end
	p.CastShadow = paint ~= "Eye" and paint ~= "Cheek"
	return p
end

local function at(x: number, y: number, z: number, rx: number?, ry: number?, rz: number?): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(rx or 0, ry or 0, rz or 0)
end

-- Big glossy eyes, rosy cheeks and a small smile on a face at (x, y, z) facing -Z.
local function face(model: Model, x: number, y: number, z: number, size: number, spacing: number)
	for _, side in { -1, 1 } do
		local ex = x + side * spacing
		ell(model, "Eye", size, size * 1.18, size * 0.55, at(ex, y, z), WHITE)
		ell(
			model,
			"Eye",
			size * 0.66,
			size * 0.78,
			size * 0.4,
			at(ex + side * 0.04 * size, y - size * 0.08, z - size * 0.2),
			PUPIL
		)
		ell(
			model,
			"Eye",
			size * 0.24,
			size * 0.26,
			size * 0.14,
			at(ex - size * 0.14, y + size * 0.16, z - size * 0.36),
			WHITE
		)
		ell(
			model,
			"Cheek",
			size * 0.6,
			size * 0.34,
			size * 0.2,
			at(x + side * (spacing + size * 0.55), y - size * 0.72, z + size * 0.12),
			CHEEK
		)
	end
	ell(model, "Eye", size * 0.5, size * 0.16, size * 0.16, at(x, y - size * 0.75, z + size * 0.02), PUPIL)
end

local BUILDERS = {}

function BUILDERS.Biped(model: Model, def, body: Color3, accent: Color3)
	for _, s in { -1, 1 } do
		ell(model, "Accent", 1.5, 0.8, 2, at(s * 0.95, 0.4, -0.25), accent) -- feet
		ell(model, "Body", 0.95, 1.5, 0.95, at(s * 1.85, 3.1, -0.55, 0.3, 0, s * 0.55), body) -- arms
	end
	ell(model, "Body", 3.6, 3.8, 3.2, at(0, 2.6, 0), body)
	ell(model, "Accent", 2.4, 2.7, 1, at(0, 2.4, -1.35), accent) -- belly
	ell(model, "Body", 1.5, 1.4, 3, at(0, 1.5, 2.1, -0.45), body) -- tail
	ell(model, "Body", 0.95, 0.95, 1.7, at(0, 1.0, 3.5, -0.3), body)
	ell(model, "Body", 3.7, 3.3, 3.3, at(0, 5.6, -0.3), body) -- head
	ell(model, "Body", 2.5, 1.5, 1.8, at(0, 5.0, -1.75), body) -- snout
	for _, spike in { { 7.1, 0.5, 1 }, { 6.0, 1.45, 0.9 }, { 4.2, 1.7, 0.8 } } do
		local k = spike[3]
		ell(model, "Accent", 0.8 * k, 1.1 * k, 0.8 * k, at(0, spike[1], spike[2]), accent)
	end
	face(model, 0, 6.05, -1.85, 1.05, 0.82)
	if def.Horn then
		for _, s in { -1, 1 } do
			ell(model, "Accent", 0.55, 1.4, 0.55, at(s * 0.85, 7.3, -0.5, 0, 0, -s * 0.35), accent)
		end
	end
end

function BUILDERS.Quad(model: Model, def, body: Color3, accent: Color3)
	local heads = def.Heads or 1
	for _, x in { -1.35, 1.35 } do
		for _, z in { -1.45, 1.8 } do
			ell(model, "Body", 1.3, 1.9, 1.3, at(x, 0.95, z), body)
		end
	end
	ell(model, "Body", 3.9, 3.0, 5.0, at(0, 2.6, 0.2), body)
	ell(model, "Accent", 3.5, 2.1, 4.3, at(0, 3.55, 0.4), accent) -- shell / back
	ell(model, "Body", 1.0, 1.0, 1.9, at(0, 2.5, 2.9, -0.4), body) -- tail
	for h = 1, heads do
		local x = if heads > 1 then (h - (heads + 1) / 2) * 2.3 else 0
		local y = if heads > 1 then 4.6 else 3.4
		if heads > 1 then
			ell(model, "Body", 1.0, 2.4, 1.0, at(x * 0.7, 3.7, -2.1, 0.35, 0, -x * 0.12), body)
		end
		ell(model, "Body", 3.0, 2.7, 2.7, at(x, y, -2.8), body)
		face(model, x, y + 0.45, -4.05, 0.85, 0.62)
		if def.Horn then
			ell(model, "Accent", 0.6, 1.7, 0.6, at(x, y + 1.3, -3.5, -0.5), accent)
		end
	end
end

function BUILDERS.Blob(model: Model, def, body: Color3, accent: Color3)
	ell(model, "Body", 5.4, 4.7, 5.1, at(0, 2.35, 0), body)
	ell(model, "Accent", 1.5, 1.5, 1.5, at(0, 4.9, 0.4), accent)
	ell(model, "Eye", 1.1, 0.75, 0.4, at(-1.4, 3.9, -1.85, 0.5, 0.4, 0), WHITE) -- shine
	face(model, 0, 3.0, -2.4, 1.2, 0.95)
	if def.Tentacles then
		for i = 0, 5 do
			local angle = (i / 6) * math.pi * 2 + 0.5
			ell(
				model,
				"Accent",
				1.1,
				0.9,
				2.6,
				at(math.sin(angle) * 2.5, 0.45, math.cos(angle) * 2.5, 0, angle, 0),
				accent
			)
		end
	end
end

function BUILDERS.Winged(model: Model, def, body: Color3, accent: Color3)
	for _, s in { -1, 1 } do
		ell(model, "Accent", 1.3, 0.7, 1.8, at(s * 0.85, 0.35, -0.2), accent) -- feet
		ell(model, "Accent", 4.4, 0.4, 2.6, at(s * 2.9, 4.0, 0.6, 0, s * 0.25, s * 0.5), accent) -- wings
		ell(model, "Accent", 2.4, 0.35, 1.6, at(s * 4.6, 5.0, 1.0, 0, s * 0.4, s * 0.8), accent)
	end
	ell(model, "Body", 3.3, 3.3, 3.6, at(0, 2.4, 0), body)
	ell(model, "Accent", 2.2, 2.3, 1, at(0, 2.2, -1.5), accent) -- belly
	ell(model, "Body", 1.1, 1.1, 2.8, at(0, 1.7, 2.3, -0.4), body) -- tail
	ell(model, "Accent", 1.0, 1.4, 0.4, at(0, 1.4, 3.7, -0.4), accent)
	ell(model, "Body", 3.1, 2.9, 2.9, at(0, 5.0, -0.7), body) -- head
	ell(model, "Body", 1.9, 1.2, 1.4, at(0, 4.5, -2.1), body) -- snout
	ell(model, "Accent", 0.7, 1.2, 0.7, at(0, 6.5, -0.4), accent) -- crest
	face(model, 0, 5.4, -2.1, 0.95, 0.72)
	if def.Horn then
		for _, s in { -1, 1 } do
			ell(model, "Accent", 0.5, 1.3, 0.5, at(s * 0.75, 6.4, -0.8, 0, 0, -s * 0.4), accent)
		end
	end
end

local function buildPlaceholder(def): Model
	local model = Instance.new("Model")
	local root = part(model, "Root", Vector3.new(1, 1, 1), CFrame.new(0, 0.5, 0), WHITE)
	root.Name = "Root"
	root.Transparency = 1
	root:SetAttribute("Paint", nil)
	-- Pivot at the feet so scaling grows the titan upward.
	root.PivotOffset = CFrame.new(0, -0.5, 0)
	model.PrimaryPart = root
	local builder = BUILDERS[def.Style] or BUILDERS.Biped
	builder(model, def, def.BodyColor, def.AccentColor)
	return model
end

local function buildCustom(id: string): Model?
	local folder = ServerStorage:FindFirstChild("CreatureModels")
	local template = folder and folder:FindFirstChild(id)
	if not (template and template:IsA("Model") and template.PrimaryPart) then
		return nil
	end
	local model = template:Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
		end
	end
	return model
end

-- The biggest body part (auras are attached to it).
local function mainPart(model: Model): BasePart
	local best: BasePart = model.PrimaryPart :: BasePart
	local bestVolume = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= model.PrimaryPart and (d:GetAttribute("Paint") or "Body") == "Body" then
			local volume = d.Size.X * d.Size.Y * d.Size.Z
			if volume > bestVolume then
				best, bestVolume = d, volume
			end
		end
	end
	return best
end

local function applyMutation(model: Model, mutationId: string)
	local mutation = Mutations[mutationId]
	if not mutation then
		return
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= model.PrimaryPart then
			local paint = d:GetAttribute("Paint") or "Body"
			if paint == "Fx" then
				continue
			elseif paint == "Body" then
				d.Color = mutation.Color
				d.Material = mutation.Material
				d.Transparency = mutation.Transparency or d.Transparency
			elseif paint == "Accent" then
				d.Color = mutation.AccentColor
				d.Material = mutation.Material
			end
		end
	end
	if mutation.Aura then
		Auras.Apply(mainPart(model), mutation.Aura)
	end
	if mutation.Animated then
		CollectionService:AddTag(model, "AnimatedMutation")
	end
end

-- Builds a titan model at scale 1 (not parented, not positioned).
function CreatureBuilder.Build(creature): Model
	local def = Creatures[creature.Id]
	local model = buildCustom(creature.Id) or buildPlaceholder(def)
	if creature.Mutation then
		applyMutation(model, creature.Mutation)
	end
	if def then
		local rarity = Rarities[def.Rarity]
		Auras.Rarity(model, rarity.Order, rarity.Color, mainPart(model))
	end
	model:SetAttribute("CreatureId", creature.Id)
	model:SetAttribute("Mutation", creature.Mutation)
	return model
end

return CreatureBuilder
