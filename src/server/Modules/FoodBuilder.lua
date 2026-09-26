--[[
	FoodBuilder: makes the 3D model for a food lying on the ground.
	Every food model has an invisible "Hitbox" (touch it to pick up) as its
	PrimaryPart. FoodService tags resting food "FoodPickup" so the client
	spins/bobs it.

	Swap for real models: put a Model named after the food id in
	ServerStorage/FoodModels (it needs a PrimaryPart named "Hitbox").
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Foods = require(Shared.Config.Foods)
local Rarities = require(Shared.Config.Rarities)
local Auras = require(Shared.Fx.Auras)

local FoodBuilder = {}

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local SHAPES = {}

function SHAPES.Ball(m: Model, color: Color3)
	part(m, { Shape = Enum.PartType.Ball, Size = Vector3.one * 2, Color = color })
	part(m, {
		Size = Vector3.new(0.5, 1.2, 0.5),
		CFrame = CFrame.new(0.9, 0.3, 0) * CFrame.Angles(0, 0, math.rad(-40)),
		Color = Color3.fromRGB(240, 235, 220),
	})
end

function SHAPES.Fruit(m: Model, color: Color3)
	part(m, { Shape = Enum.PartType.Ball, Size = Vector3.one * 2, Color = color })
	part(m, { Size = Vector3.new(0.2, 0.6, 0.2), CFrame = CFrame.new(0, 1.2, 0), Color = Color3.fromRGB(100, 70, 40) })
	part(m, {
		Size = Vector3.new(0.8, 0.1, 0.4),
		CFrame = CFrame.new(0.4, 1.3, 0) * CFrame.Angles(0, 0, math.rad(20)),
		Color = Color3.fromRGB(80, 180, 70),
	})
end

function SHAPES.Fish(m: Model, color: Color3)
	part(m, { Size = Vector3.new(2.4, 1.2, 0.6), Color = color })
	part(m, {
		Shape = Enum.PartType.Wedge,
		Size = Vector3.new(0.4, 1.2, 0.8),
		CFrame = CFrame.new(1.5, 0, 0) * CFrame.Angles(0, math.rad(90), 0),
		Color = color:Lerp(Color3.new(0, 0, 0), 0.2),
	})
	part(m, {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.3,
		CFrame = CFrame.new(-0.8, 0.2, 0.3),
		Color = Color3.new(0, 0, 0),
	})
end

function SHAPES.Crystal(m: Model, color: Color3)
	for i = 1, 3 do
		part(m, {
			Size = Vector3.new(0.7, 1.6 + i * 0.3, 0.7),
			CFrame = CFrame.new((i - 2) * 0.5, 0, 0) * CFrame.Angles(0, i, math.rad((i - 2) * 20)),
			Color = color,
			Material = Enum.Material.Neon,
		})
	end
end

function SHAPES.Mushroom(m: Model, color: Color3)
	part(
		m,
		{ Size = Vector3.new(0.6, 1.2, 0.6), CFrame = CFrame.new(0, -0.3, 0), Color = Color3.fromRGB(235, 230, 215) }
	)
	local cap = part(
		m,
		{ Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(0, 0.4, 0), Color = color, Material = Enum.Material.Neon }
	)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1, 0.5, 1)
	mesh.Parent = cap
end

function SHAPES.Star(m: Model, color: Color3)
	for i = 0, 2 do
		part(m, {
			Size = Vector3.new(0.5, 2.6, 0.5),
			CFrame = CFrame.Angles(0, 0, math.rad(i * 60)),
			Color = color,
			Material = Enum.Material.Neon,
		})
	end
	part(m, { Shape = Enum.PartType.Ball, Size = Vector3.one * 1.2, Color = color, Material = Enum.Material.Neon })
end

-- Builds a food model centered at `position`. Not parented.
function FoodBuilder.Build(foodId: string, position: Vector3): Model
	local def = Foods[foodId]
	local rarity = Rarities[def.Rarity]
	local custom = ServerStorage:FindFirstChild("FoodModels")
	custom = custom and custom:FindFirstChild(foodId)

	local m: Model
	if custom and custom:IsA("Model") and custom.PrimaryPart then
		m = custom:Clone()
	else
		m = Instance.new("Model")
		local builder = SHAPES[def.Model] or SHAPES.Ball
		builder(m, def.Color)
		local hitbox = part(m, {
			Name = "Hitbox",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 4,
			Transparency = 1,
			CanTouch = true,
		})
		m.PrimaryPart = hitbox
	end
	m.Name = foodId
	m:SetAttribute("FoodId", foodId)

	local main = m.PrimaryPart :: BasePart
	if rarity.Order >= 2 then
		Auras.Apply(main, { Color = def.Color, Light = rarity.Order >= 3, Particles = "Sparkles" })
	end
	if rarity.Order >= 4 then
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromScale(8, 1.5)
		gui.StudsOffset = Vector3.new(0, 3, 0)
		gui.LightInfluence = 0
		gui.MaxDistance = 200
		gui.Parent = main
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = rarity.Color
		label.Text = def.Name
		label.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Parent = label
	end
	m:PivotTo(CFrame.new(position))
	return m
end

return FoodBuilder
