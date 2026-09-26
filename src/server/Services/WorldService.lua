--[[
	WorldService: builds the map, the player bases (plots) and the lighting.
	Everything is generated from code so the game works in an empty place.
	Later you can replace parts of it with a map you build in Studio.

	  WorldService:Assign(player) / :Release(player)
	  WorldService:GetPlot(player)
	  WorldService:IsInside(plot, position)
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)

local WorldService = {
	Plots = {} :: { any },
	ByPlayer = {} :: { [Player]: any },
	Folder = nil :: Folder?,
}

local PLOT_COLORS = {
	Color3.fromRGB(120, 200, 110),
	Color3.fromRGB(110, 170, 230),
	Color3.fromRGB(240, 170, 90),
	Color3.fromRGB(200, 120, 220),
	Color3.fromRGB(240, 220, 100),
	Color3.fromRGB(230, 110, 110),
	Color3.fromRGB(100, 210, 200),
	Color3.fromRGB(180, 180, 190),
}

local function makePart(parent: Instance, props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

local function textLabel(parent: Instance, text: string, color: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = label
	return label
end

local function ensure(className: string, parent: Instance): Instance
	local existing = parent:FindFirstChildWhichIsA(className)
	if existing then
		return existing
	end
	local inst = Instance.new(className)
	inst.Parent = parent
	return inst
end

local function setupLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 160)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1

	local atmosphere = ensure("Atmosphere", Lighting) :: Atmosphere
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(200, 220, 255)
	atmosphere.Decay = Color3.fromRGB(110, 130, 170)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.5

	local bloom = ensure("BloomEffect", Lighting) :: BloomEffect
	bloom.Intensity = 0.8
	bloom.Size = 24
	bloom.Threshold = 1.2

	local color = ensure("ColorCorrectionEffect", Lighting) :: ColorCorrectionEffect
	color.Saturation = 0.15
	color.Contrast = 0.05

	local rays = ensure("SunRaysEffect", Lighting) :: SunRaysEffect
	rays.Intensity = 0.05
end

function WorldService:Init(services)
	self.Services = services
end

function WorldService:Start()
	setupLighting()

	if GameConfig.ReplaceBaseplate then
		local baseplate = Workspace:FindFirstChild("Baseplate")
		if baseplate then
			baseplate:Destroy()
		end
	end

	local world = Instance.new("Folder")
	world.Name = "KaijuWorld"
	world.Parent = Workspace
	self.Folder = world

	local mapSize = (GameConfig.Plots.Radius + GameConfig.Plots.Size) * 2 + 200
	makePart(world, {
		Name = "Ground",
		Size = Vector3.new(mapSize, 2, mapSize),
		CFrame = CFrame.new(0, -1, 0),
		Color = Color3.fromRGB(95, 170, 85),
		Material = Enum.Material.Grass,
	})
	-- Center arena where wild food spawns
	makePart(world, {
		Name = "Arena",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, GameConfig.WildFood.AreaRadius * 2 + 20, GameConfig.WildFood.AreaRadius * 2 + 20),
		CFrame = CFrame.new(0, -0.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(215, 195, 140),
		Material = Enum.Material.Sand,
	})

	if not Workspace:FindFirstChildWhichIsA("SpawnLocation", true) then
		local spawn = Instance.new("SpawnLocation")
		spawn.Anchored = true
		spawn.Size = Vector3.new(12, 1, 12)
		spawn.CFrame = CFrame.new(0, 0.5, 0)
		spawn.Neutral = true
		spawn.Parent = world
	end

	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = world

	for i = 1, GameConfig.Plots.Count do
		table.insert(self.Plots, self:_buildPlot(plotsFolder, i))
	end
end

function WorldService:_buildPlot(parent: Instance, index: number)
	local S = GameConfig.Plots.Size
	local angle = (index - 1) / GameConfig.Plots.Count * math.pi * 2
	local position = Vector3.new(math.cos(angle), 0, math.sin(angle)) * GameConfig.Plots.Radius
	-- LookVector (-Z) faces the middle of the map = the plot's "front"
	local cf = CFrame.lookAt(position, Vector3.zero)
	local color = PLOT_COLORS[(index - 1) % #PLOT_COLORS + 1]
	local wallColor = color:Lerp(Color3.new(0, 0, 0), 0.35)

	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model:SetAttribute("PlotIndex", index)

	makePart(model, {
		Name = "Floor",
		Size = Vector3.new(S, 1, S),
		CFrame = cf * CFrame.new(0, 0.5, 0),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
	})

	local function wall(size: Vector3, offset: Vector3)
		makePart(model, {
			Name = "Wall",
			Size = size,
			CFrame = cf * CFrame.new(offset),
			Color = wallColor,
			Material = Enum.Material.WoodPlanks,
		})
	end
	wall(Vector3.new(S, 4, 1), Vector3.new(0, 3, S / 2 - 0.5))
	wall(Vector3.new(1, 4, S), Vector3.new(S / 2 - 0.5, 3, 0))
	wall(Vector3.new(1, 4, S), Vector3.new(-(S / 2 - 0.5), 3, 0))
	local gap = 24
	local segment = (S - gap) / 2
	wall(Vector3.new(segment, 4, 1), Vector3.new(gap / 2 + segment / 2, 3, -(S / 2 - 0.5)))
	wall(Vector3.new(segment, 4, 1), Vector3.new(-(gap / 2 + segment / 2), 3, -(S / 2 - 0.5)))

	-- Food storage crate (other players steal from here)
	local crate = makePart(model, {
		Name = "FoodStorage",
		Size = Vector3.new(6, 5, 6),
		CFrame = cf * CFrame.new(0, 3.5, -S / 2 + 10),
		Color = Color3.fromRGB(150, 100, 55),
		Material = Enum.Material.WoodPlanks,
	})
	local crateGui = Instance.new("BillboardGui")
	crateGui.Size = UDim2.fromScale(10, 3)
	crateGui.StudsOffset = Vector3.new(0, 5, 0)
	crateGui.MaxDistance = 120
	crateGui.LightInfluence = 0
	crateGui.Parent = crate
	local foodLabel = textLabel(crateGui, "🍖 0 / 0")
	foodLabel.Size = UDim2.fromScale(1, 0.6)
	local lockLabel = textLabel(crateGui, "", Color3.fromRGB(120, 190, 255))
	lockLabel.Size = UDim2.fromScale(1, 0.4)
	lockLabel.Position = UDim2.fromScale(0, 0.6)

	local stealPrompt = Instance.new("ProximityPrompt")
	stealPrompt.Name = "StealPrompt"
	stealPrompt.ActionText = "Steal Food"
	stealPrompt.ObjectText = "Food Storage"
	stealPrompt.HoldDuration = GameConfig.Steal.HoldTime
	stealPrompt.MaxActivationDistance = 12
	stealPrompt.RequiresLineOfSight = false
	stealPrompt:SetAttribute("OnlyUserId", -1) -- hidden until someone owns the plot
	stealPrompt.Parent = crate

	local lockBubble = makePart(model, {
		Name = "LockBubble",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(18, 18, 18),
		CFrame = crate.CFrame,
		Color = Color3.fromRGB(90, 170, 255),
		Material = Enum.Material.ForceField,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})

	-- Owner sign at the back, facing the middle
	local sign = makePart(model, {
		Name = "Sign",
		Size = Vector3.new(24, 7, 1),
		CFrame = cf * CFrame.new(0, 9, S / 2 - 2),
		Color = wallColor,
		Material = Enum.Material.WoodPlanks,
	})
	for _, x in { -10, 10 } do
		makePart(model, {
			Name = "SignPost",
			Size = Vector3.new(1, 6, 1),
			CFrame = cf * CFrame.new(x, 3, S / 2 - 2),
			Color = wallColor,
			Material = Enum.Material.WoodPlanks,
		})
	end
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.LightInfluence = 0
	surface.PixelsPerStud = 30
	surface.Parent = sign
	local signLabel = textLabel(surface, "Empty Plot")

	-- Pen slots: 4 columns x 3 rows
	local slots = {}
	for row = 0, 2 do
		for col = 0, 3 do
			local slotCf = cf * CFrame.new(-30 + col * 20, 1.2, -8 + row * 18)
			makePart(model, {
				Name = "SlotPad",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.2, 9, 9),
				CFrame = slotCf * CFrame.new(0, -0.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
				Color = color:Lerp(Color3.new(1, 1, 1), 0.4),
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
			})
			table.insert(slots, slotCf)
		end
	end

	local creatures = Instance.new("Folder")
	creatures.Name = "Creatures"
	creatures.Parent = model

	model.Parent = parent

	return {
		Index = index,
		Model = model,
		CFrame = cf,
		Crate = crate,
		StealPrompt = stealPrompt,
		LockBubble = lockBubble,
		FoodLabel = foodLabel,
		LockLabel = lockLabel,
		SignLabel = signLabel,
		Slots = slots,
		CreatureFolder = creatures,
		SpawnCFrame = cf * CFrame.new(0, 4, -S / 2 + 18),
		Owner = nil :: Player?,
		CharacterConnection = nil :: RBXScriptConnection?,
	}
end

function WorldService:Assign(player: Player)
	for _, plot in self.Plots do
		if not plot.Owner then
			plot.Owner = player
			self.ByPlayer[player] = plot
			plot.Model:SetAttribute("OwnerUserId", player.UserId)
			plot.StealPrompt:SetAttribute("OnlyUserId", nil)
			plot.StealPrompt:SetAttribute("HideForUserId", player.UserId)
			plot.SignLabel.Text = player.DisplayName .. "'s " .. GameConfig.CreatureNamePlural
			plot.CharacterConnection = player.CharacterAdded:Connect(function(character)
				self:_teleportHome(plot, character)
			end)
			if player.Character then
				self:_teleportHome(plot, player.Character)
			end
			return plot
		end
	end
	return nil
end

function WorldService:_teleportHome(plot, character: Model)
	task.spawn(function()
		local root = character:WaitForChild("HumanoidRootPart", 5)
		if root then
			task.wait(0.1)
			character:PivotTo(plot.SpawnCFrame)
		end
	end)
end

function WorldService:Release(player: Player)
	local plot = self.ByPlayer[player]
	if not plot then
		return
	end
	self.ByPlayer[player] = nil
	plot.Owner = nil
	plot.Model:SetAttribute("OwnerUserId", nil)
	plot.Model:SetAttribute("LockedUntil", nil)
	plot.StealPrompt:SetAttribute("HideForUserId", nil)
	plot.StealPrompt:SetAttribute("OnlyUserId", -1)
	plot.SignLabel.Text = "Empty Plot"
	plot.FoodLabel.Text = ""
	plot.LockLabel.Text = ""
	plot.LockBubble.Transparency = 1
	if plot.CharacterConnection then
		plot.CharacterConnection:Disconnect()
		plot.CharacterConnection = nil
	end
	plot.CreatureFolder:ClearAllChildren()
end

function WorldService:GetPlot(player: Player)
	return self.ByPlayer[player]
end

function WorldService:IsInside(plot, position: Vector3): boolean
	local localPos = plot.CFrame:PointToObjectSpace(position)
	local half = GameConfig.Plots.Size / 2
	return math.abs(localPos.X) <= half and math.abs(localPos.Z) <= half
end

-- Random point inside the middle arena
function WorldService:RandomArenaPoint(): Vector3
	local radius = GameConfig.WildFood.AreaRadius * math.sqrt(math.random())
	local angle = math.random() * math.pi * 2
	return Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

return WorldService
