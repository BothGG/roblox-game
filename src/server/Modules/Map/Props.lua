--[[
	Props: builds decoration models (trees, rocks, crystals...) from parts.
	Placeholder art: swap any of these for real models later by changing
	the function to clone a model from ServerStorage instead.

	Every builder: Props.X(parent, position, rng) -> Model
]]

local Props = {}

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end
Props.Part = part

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Vertical cylinder (Roblox cylinders lie along X, so rotate them upright).
local function column(
	parent: Instance,
	position: Vector3,
	height: number,
	diameter: number,
	props: { [string]: any }
): Part
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(height, diameter, diameter)
	props.CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	return part(parent, props)
end
Props.Column = column

local function vary(color: Color3, rng: Random, amount: number): Color3
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, s, math.clamp(v + (rng:NextNumber() - 0.5) * amount, 0, 1))
end

function Props.Tree(parent: Instance, position: Vector3, rng: Random): Model
	local m = model(parent, "Tree")
	local scale = rng:NextNumber(0.8, 1.6)
	local height = 12 * scale
	column(m, position, height, 2.2 * scale, { Color = Color3.fromRGB(110, 75, 45), Material = Enum.Material.Wood })
	local leaf = Color3.fromRGB(70, 160, 70)
	for i = 1, 3 do
		local offset = Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2)) * scale
		part(m, {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * rng:NextNumber(8, 11) * scale,
			CFrame = CFrame.new(position + Vector3.new(0, height + (i - 1) * 2.5 * scale, 0) + offset),
			Color = vary(leaf, rng, 0.2),
			Material = Enum.Material.Grass,
		})
	end
	return m
end

function Props.Bush(parent: Instance, position: Vector3, rng: Random): Model
	local m = model(parent, "Bush")
	for _ = 1, 3 do
		part(m, {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * rng:NextNumber(3, 5),
			CFrame = CFrame.new(position + Vector3.new(rng:NextNumber(-1.5, 1.5), 1, rng:NextNumber(-1.5, 1.5))),
			Color = vary(Color3.fromRGB(60, 140, 60), rng, 0.2),
			Material = Enum.Material.Grass,
			CanCollide = false,
		})
	end
	return m
end

function Props.Pine(parent: Instance, position: Vector3, rng: Random): Model
	local m = model(parent, "Pine")
	local scale = rng:NextNumber(0.8, 1.5)
	column(m, position, 6 * scale, 1.6 * scale, { Color = Color3.fromRGB(100, 70, 45), Material = Enum.Material.Wood })
	local layers = 4
	for i = 1, layers do
		local diameter = (13 - i * 2.5) * scale
		local y = (4 + i * 3) * scale
		column(m, position + Vector3.new(0, y, 0), 3 * scale, diameter, {
			Color = Color3.fromRGB(45, 110, 70):Lerp(Color3.new(1, 1, 1), 0.15 + i * 0.05),
			Material = Enum.Material.Grass,
		})
		column(m, position + Vector3.new(0, y + 3 * scale, 0), 0.6 * scale, diameter * 0.8, {
			Color = Color3.fromRGB(240, 245, 255),
			Material = Enum.Material.Snow,
		})
	end
	return m
end

function Props.Palm(parent: Instance, position: Vector3, rng: Random): Model
	local m = model(parent, "Palm")
	local scale = rng:NextNumber(0.9, 1.4)
	local lean = rng:NextNumber(0, math.pi * 2)
	local dir = Vector3.new(math.cos(lean), 0, math.sin(lean))
	local top = position
	for i = 1, 5 do
		local nextTop = top + Vector3.new(0, 3.2 * scale, 0) + dir * (0.35 * i * scale)
		local mid = (top + nextTop) / 2
		part(m, {
			Size = Vector3.new(1.4, (nextTop - top).Magnitude + 0.3, 1.4) * Vector3.new(scale, 1, scale),
			CFrame = CFrame.lookAt(mid, nextTop) * CFrame.Angles(math.rad(-90), 0, 0),
			Color = Color3.fromRGB(150, 110, 70),
			Material = Enum.Material.Wood,
		})
		top = nextTop
	end
	for i = 1, 6 do
		local angle = i / 6 * math.pi * 2
		part(m, {
			Size = Vector3.new(1.6, 0.3, 9) * scale,
			CFrame = CFrame.new(top)
				* CFrame.Angles(0, angle, 0)
				* CFrame.Angles(math.rad(-20), 0, 0)
				* CFrame.new(0, 0, -4.5 * scale),
			Color = vary(Color3.fromRGB(60, 170, 70), rng, 0.15),
			Material = Enum.Material.Grass,
			CanCollide = false,
		})
	end
	for i = 1, 3 do
		local angle = i / 3 * math.pi * 2
		part(m, {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.2 * scale,
			CFrame = CFrame.new(top + Vector3.new(math.cos(angle), -0.8, math.sin(angle)) * scale),
			Color = Color3.fromRGB(110, 75, 45),
		})
	end
	return m
end

function Props.Rock(parent: Instance, position: Vector3, rng: Random, color: Color3?): Model
	local m = model(parent, "Rock")
	local size = rng:NextNumber(3, 9)
	for _ = 1, rng:NextInteger(1, 3) do
		part(m, {
			Size = Vector3.new(
				size * rng:NextNumber(0.7, 1.3),
				size * rng:NextNumber(0.5, 0.9),
				size * rng:NextNumber(0.7, 1.3)
			),
			CFrame = CFrame.new(position + Vector3.new(rng:NextNumber(-2, 2), size * 0.2, rng:NextNumber(-2, 2)))
				* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6.28), rng:NextNumber(-0.4, 0.4)),
			Color = vary(color or Color3.fromRGB(120, 120, 125), rng, 0.15),
			Material = Enum.Material.Slate,
		})
	end
	return m
end

function Props.Crystal(parent: Instance, position: Vector3, rng: Random): Model
	local m = model(parent, "Crystal")
	local colors = { Color3.fromRGB(170, 110, 255), Color3.fromRGB(110, 220, 255), Color3.fromRGB(255, 120, 220) }
	local color = colors[rng:NextInteger(1, #colors)]
	for _ = 1, rng:NextInteger(2, 4) do
		local height = rng:NextNumber(4, 12)
		local p = part(m, {
			Size = Vector3.new(1.6, height, 1.6) * rng:NextNumber(0.8, 1.5),
			CFrame = CFrame.new(position + Vector3.new(rng:NextNumber(-2, 2), height * 0.35, rng:NextNumber(-2, 2)))
				* CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6.28), rng:NextNumber(-0.5, 0.5)),
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = 0.15,
		})
		if not m:FindFirstChildWhichIsA("PointLight", true) then
			local light = Instance.new("PointLight")
			light.Color = color
			light.Range = 14
			light.Brightness = 1.5
			light.Parent = p
		end
	end
	return m
end

function Props.Mushroom(parent: Instance, position: Vector3, rng: Random): Model
	local m = model(parent, "Mushroom")
	local scale = rng:NextNumber(0.8, 2.5)
	column(m, position, 3 * scale, 0.8 * scale, { Color = Color3.fromRGB(230, 225, 210) })
	local cap = part(m, {
		Size = Vector3.new(4, 4, 4) * scale,
		CFrame = CFrame.new(position + Vector3.new(0, 3 * scale, 0)),
		Color = Color3.fromRGB(150, 70, 230),
		Material = Enum.Material.Neon,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1, 0.5, 1)
	mesh.Parent = cap
	local light = Instance.new("PointLight")
	light.Color = cap.Color
	light.Range = 10
	light.Brightness = 1
	light.Parent = cap
	return m
end

function Props.LavaVent(parent: Instance, position: Vector3, rng: Random): Model
	local m = model(parent, "LavaVent")
	local p = part(m, {
		Size = Vector3.new(rng:NextNumber(4, 8), 0.4, rng:NextNumber(4, 8)),
		CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
		Color = Color3.fromRGB(255, 110, 20),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local fire = Instance.new("Fire")
	fire.Size = 5
	fire.Heat = 8
	fire.Parent = p
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 120, 40)
	light.Range = 16
	light.Brightness = 2
	light.Parent = p
	Props.Rock(m, position + Vector3.new(3, 0, 2), rng, Color3.fromRGB(50, 45, 45))
	return m
end

function Props.FencePost(parent: Instance, position: Vector3, color: Color3?): Part
	return part(parent, {
		Name = "Post",
		Size = Vector3.new(1.2, 5, 1.2),
		CFrame = CFrame.new(position + Vector3.new(0, 2.5, 0)),
		Color = color or Color3.fromRGB(120, 85, 55),
		Material = Enum.Material.WoodPlanks,
	})
end

function Props.Lamp(parent: Instance, position: Vector3): Model
	local m = model(parent, "Lamp")
	column(m, position, 12, 0.8, { Color = Color3.fromRGB(50, 50, 55), Material = Enum.Material.Metal })
	local bulb = part(m, {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2,
		CFrame = CFrame.new(position + Vector3.new(0, 12.5, 0)),
		Color = Color3.fromRGB(255, 235, 180),
		Material = Enum.Material.Neon,
	})
	local light = Instance.new("PointLight")
	light.Color = bulb.Color
	light.Range = 24
	light.Brightness = 1.5
	light.Parent = bulb
	return m
end

function Props.Signpost(parent: Instance, position: Vector3, facing: Vector3, text: string, color: Color3): Model
	local m = model(parent, "Signpost")
	column(m, position, 9, 1, { Color = Color3.fromRGB(110, 80, 50), Material = Enum.Material.Wood })
	local board = part(m, {
		Size = Vector3.new(12, 3.5, 0.6),
		CFrame = CFrame.lookAt(position + Vector3.new(0, 8, 0), position + Vector3.new(0, 8, 0) + facing),
		Color = color,
		Material = Enum.Material.WoodPlanks,
	})
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.PixelsPerStud = 25
		gui.LightInfluence = 0
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = text
		label.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Parent = label
	end
	return m
end

function Props.Fountain(parent: Instance, position: Vector3): Model
	local m = model(parent, "Fountain")
	column(m, position, 2.5, 30, { Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Marble })
	column(m, position + Vector3.new(0, 2.5, 0), 0.2, 27, {
		Color = Color3.fromRGB(80, 170, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.3,
		CanCollide = false,
	})
	column(m, position, 9, 4, { Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Marble })
	local top = column(
		m,
		position + Vector3.new(0, 9, 0),
		1.2,
		10,
		{ Color = Color3.fromRGB(210, 210, 220), Material = Enum.Material.Marble }
	)
	local water = Instance.new("ParticleEmitter")
	water.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	water.Color = ColorSequence.new(Color3.fromRGB(150, 210, 255))
	water.Rate = 40
	water.Lifetime = NumberRange.new(1.2, 1.6)
	water.Speed = NumberRange.new(14, 18)
	water.SpreadAngle = Vector2.new(15, 15)
	water.Acceleration = Vector3.new(0, -30, 0)
	water.EmissionDirection = Enum.NormalId.Right -- the cylinder's axis points up after rotation
	water.Size = NumberSequence.new(0.6, 0.2)
	water.Parent = top
	return m
end

function Props.GateArch(parent: Instance, cf: CFrame, width: number, color: Color3): Model
	local m = model(parent, "GateArch")
	for _, x in { -width / 2 - 1.5, width / 2 + 1.5 } do
		part(m, {
			Size = Vector3.new(3, 16, 3),
			CFrame = cf * CFrame.new(x, 8, 0),
			Color = color,
			Material = Enum.Material.Slate,
		})
	end
	part(m, {
		Size = Vector3.new(width + 6, 3, 3.5),
		CFrame = cf * CFrame.new(0, 17.5, 0),
		Color = color,
		Material = Enum.Material.Slate,
	})
	return m
end

return Props
