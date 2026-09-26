--[[
	CreatureBuilder: makes the 3D model for a titan.

	If ServerStorage has a folder "CreatureModels" with a Model named after
	the titan's Id (e.g. "Rex"), that model is used. Otherwise a placeholder
	is built from parts using the Style and colors in Config/Creatures.lua.

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
local BLACK = Color3.new(0.05, 0.05, 0.05)

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

local function eyes(model: Model, headCf: CFrame, headSize: Vector3)
	local eyeSize = math.min(headSize.X, headSize.Y) * 0.35
	for _, side in { -1, 1 } do
		local eyeCf = headCf * CFrame.new(side * headSize.X * 0.25, headSize.Y * 0.12, -headSize.Z / 2)
		part(model, "Eye", Vector3.one * eyeSize, eyeCf, WHITE, Enum.PartType.Ball)
		part(
			model,
			"Eye",
			Vector3.one * eyeSize * 0.5,
			eyeCf * CFrame.new(0, 0, -eyeSize * 0.3),
			BLACK,
			Enum.PartType.Ball
		)
	end
end

local function spikes(model: Model, fromY: number, z: number, count: number, color: Color3)
	for i = 0, count - 1 do
		part(
			model,
			"Accent",
			Vector3.new(0.7, 0.7, 0.7),
			CFrame.new(0, fromY - i * 1.1, z) * CFrame.Angles(math.rad(45), 0, 0),
			color
		)
	end
end

local function quadBody(model: Model, def, body: Color3, accent: Color3, scaleBody: number)
	local s = scaleBody
	part(model, "Body", Vector3.new(3, 2.4, 5) * s, CFrame.new(0, 2.6 * s, 0), body)
	for _, x in { -1.1, 1.1 } do
		for _, z in { -1.7, 1.7 } do
			part(model, "Accent", Vector3.new(0.9, 1.6, 0.9) * s, CFrame.new(x * s, 0.8 * s, z * s), accent)
		end
	end
	part(
		model,
		"Body",
		Vector3.new(0.6, 0.6, 1.8) * s,
		CFrame.new(0, 2.8 * s, 3.2 * s) * CFrame.Angles(math.rad(-20), 0, 0),
		body
	)
	local heads = def.Heads or 1
	for h = 1, heads do
		local x = (h - (heads + 1) / 2) * 1.8 * s
		local headSize = Vector3.new(1.8, 1.6, 1.8) * s
		local headCf = CFrame.new(x, 3.4 * s + (heads > 1 and 0.8 or 0), -3.1 * s)
		if heads > 1 then
			part(model, "Body", Vector3.new(0.7, 1.6, 0.7) * s, CFrame.new(x * 0.7, 3.2 * s, -2.6 * s), body)
		end
		part(model, "Body", headSize, headCf, body)
		eyes(model, headCf, headSize)
		if def.Horn then
			part(
				model,
				"Accent",
				Vector3.new(0.5, 1.6, 0.5) * s,
				headCf * CFrame.new(0, headSize.Y * 0.6, -headSize.Z * 0.3) * CFrame.Angles(math.rad(-25), 0, 0),
				accent
			)
		end
	end
end

local BUILDERS = {}

function BUILDERS.Biped(model: Model, def, body: Color3, accent: Color3)
	for _, side in { -1, 1 } do
		part(model, "Accent", Vector3.new(1.2, 2.4, 1.2), CFrame.new(side * 0.9, 1.2, 0), accent)
		part(
			model,
			"Body",
			Vector3.new(0.9, 2.2, 0.9),
			CFrame.new(side * 2.05, 4.2, -0.3) * CFrame.Angles(math.rad(-20), 0, 0),
			body
		)
	end
	part(model, "Body", Vector3.new(3.2, 3.2, 2.4), CFrame.new(0, 4, 0), body)
	part(model, "Accent", Vector3.new(2.2, 2.2, 0.2), CFrame.new(0, 3.8, -1.25), accent)
	local headSize = Vector3.new(2.6, 2.2, 2.4)
	local headCf = CFrame.new(0, 6.7, -0.4)
	part(model, "Body", headSize, headCf, body)
	part(model, "Body", Vector3.new(1.6, 1, 1), headCf * CFrame.new(0, -0.4, -1.5), body)
	eyes(model, headCf, headSize)
	part(model, "Body", Vector3.new(1, 1, 2.4), CFrame.new(0, 2.6, 1.9) * CFrame.Angles(math.rad(25), 0, 0), body)
	spikes(model, 5.4, 1.25, 3, accent)
	if def.Horn then
		part(
			model,
			"Accent",
			Vector3.new(0.5, 1.4, 0.5),
			headCf * CFrame.new(-0.7, 1.4, 0) * CFrame.Angles(0, 0, math.rad(20)),
			accent
		)
		part(
			model,
			"Accent",
			Vector3.new(0.5, 1.4, 0.5),
			headCf * CFrame.new(0.7, 1.4, 0) * CFrame.Angles(0, 0, math.rad(-20)),
			accent
		)
	end
end

function BUILDERS.Quad(model: Model, def, body: Color3, accent: Color3)
	quadBody(model, def, body, accent, 1)
	-- shell / back plate
	part(model, "Accent", Vector3.new(2.6, 0.8, 4), CFrame.new(0, 4.1, 0), accent)
end

function BUILDERS.Blob(model: Model, def, body: Color3, accent: Color3)
	local bodySize = Vector3.new(5, 5, 5)
	local bodyCf = CFrame.new(0, 2.5, 0)
	part(model, "Body", bodySize, bodyCf, body, Enum.PartType.Ball)
	part(model, "Accent", Vector3.new(3, 3, 3), CFrame.new(0, 4.2, 0.4), accent, Enum.PartType.Ball)
	eyes(model, CFrame.new(0, 3, 0.2), bodySize)
	if def.Tentacles then
		for i = 1, 6 do
			local angle = (i / 6) * math.pi * 2
			part(
				model,
				"Accent",
				Vector3.new(3.2, 0.8, 0.8),
				CFrame.new(math.cos(angle) * 2.8, 0.4, math.sin(angle) * 2.8) * CFrame.Angles(0, -angle, 0),
				accent,
				Enum.PartType.Cylinder
			)
		end
	end
end

function BUILDERS.Winged(model: Model, def, body: Color3, accent: Color3)
	quadBody(model, def, body, accent, 0.9)
	for _, side in { -1, 1 } do
		part(
			model,
			"Accent",
			Vector3.new(4.5, 0.3, 2.8),
			CFrame.new(side * 3.4, 4, 0.2) * CFrame.Angles(0, 0, math.rad(side * 25)),
			accent
		)
	end
	spikes(model, 4.2, 1.8, 2, accent)
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
			if paint == "Body" then
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
	elseif def and Rarities[def.Rarity].Order >= Rarities.Legendary.Order then
		Auras.RarityGlow(mainPart(model), Rarities[def.Rarity].Color)
	end
	model:SetAttribute("CreatureId", creature.Id)
	model:SetAttribute("Mutation", creature.Mutation)
	return model
end

return CreatureBuilder
