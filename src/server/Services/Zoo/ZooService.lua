--[[
	ZooService: builds a zoo on every ZooPlot marker and gives one to each
	player. A zoo has 12 enclosures (locked ones show a sign), a food
	storage crate (others can steal from it), a lock bubble and a name sign.

	  ZooService:Assign(player) / :Release(player)
	  ZooService:GetPlot(player) -> Plot
	  ZooService:IsInside(plot, position)
	  ZooService:RefreshEnclosures(player)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local CreatureMath = require(Shared.Game.CreatureMath)
local Log = require(Shared.Lib.Log)
local Net = require(Shared.Net)

local log = Log.new("ZooService")

export type Plot = {
	Index: number,
	Model: Model,
	CFrame: CFrame,
	Crate: BasePart,
	StealPrompt: ProximityPrompt,
	LockBubble: BasePart,
	FoodLabel: TextLabel,
	LockLabel: TextLabel,
	SignLabel: TextLabel,
	Slots: { CFrame },
	EnclosureSigns: { BillboardGui },
	CreatureFolder: Folder,
	SpawnCFrame: CFrame,
	Owner: Player?,
	CharacterConnection: RBXScriptConnection?,
}

local ZooService = {
	Priority = 10,
	Plots = {} :: { Plot },
	ByPlayer = {} :: { [Player]: Plot },
	Folder = nil :: Folder?,
}

local Data, Map

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

-- Enclosure grid (plot-local X, Z). Front of the zoo is -Z (towards the plaza).
local SLOT_X = { -30, -10, 10, 30 }
local SLOT_Z = { -12, 8, 28 }
local ENCLOSURE_SIZE = 17

local function makePart(parent: Instance, props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
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

function ZooService:Init(registry)
	Data = registry.DataService
	Map = registry.MapService
end

function ZooService:Start()
	local zoos = Instance.new("Folder")
	zoos.Name = "Zoos"
	zoos.Parent = Map.Map or workspace
	self.Folder = zoos
	for i, anchor in Map.PlotAnchors do
		if i > GameConfig.Zoo.PlotCount then
			break
		end
		table.insert(self.Plots, self:_build(zoos, i, anchor.CFrame))
	end
	log:Info("built", #self.Plots, "zoos")

	Net.On("TeleportHome", function(player)
		self:TeleportHome(player)
	end)
end

function ZooService:_build(parent: Instance, index: number, anchorCf: CFrame): Plot
	local S = GameConfig.Zoo.PlotSize
	local cf = CFrame.new(anchorCf.Position.X, 0, anchorCf.Position.Z) * anchorCf.Rotation
	local color = PLOT_COLORS[(index - 1) % #PLOT_COLORS + 1]
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.4)

	local model = Instance.new("Model")
	model.Name = "Zoo" .. index
	model:SetAttribute("PlotIndex", index)

	makePart(model, {
		Name = "Floor",
		Size = Vector3.new(S, 1, S),
		CFrame = cf * CFrame.new(0, 0.5, 0),
		Color = Color3.fromRGB(215, 200, 165),
		Material = Enum.Material.Pavement,
	})

	-- Outer fence with an entrance at the front and an exit at the back
	local gap = 22
	local function wall(size: Vector3, offset: Vector3)
		makePart(model, {
			Name = "Fence",
			Size = size,
			CFrame = cf * CFrame.new(offset),
			Color = dark,
			Material = Enum.Material.WoodPlanks,
		})
	end
	local segment = (S - gap) / 2
	for _, z in { -(S / 2 - 0.5), S / 2 - 0.5 } do
		wall(Vector3.new(segment, 4, 1), Vector3.new(gap / 2 + segment / 2, 3, z))
		wall(Vector3.new(segment, 4, 1), Vector3.new(-(gap / 2 + segment / 2), 3, z))
	end
	wall(Vector3.new(1, 4, S), Vector3.new(S / 2 - 0.5, 3, 0))
	wall(Vector3.new(1, 4, S), Vector3.new(-(S / 2 - 0.5), 3, 0))

	-- Entrance arch + name sign facing the plaza
	for _, x in { -gap / 2 - 1, gap / 2 + 1 } do
		makePart(model, {
			Name = "ArchPillar",
			Size = Vector3.new(2, 14, 2),
			CFrame = cf * CFrame.new(x, 8, -S / 2 + 0.5),
			Color = dark,
			Material = Enum.Material.WoodPlanks,
		})
	end
	local sign = makePart(model, {
		Name = "Sign",
		Size = Vector3.new(gap + 6, 5, 1),
		CFrame = cf * CFrame.new(0, 15, -S / 2 + 0.5),
		Color = color,
		Material = Enum.Material.WoodPlanks,
	})
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.PixelsPerStud = 25
	surface.LightInfluence = 0
	surface.Parent = sign
	local signLabel = textLabel(surface, "Empty Zoo")

	-- Enclosures
	local slots = {}
	local enclosureSigns = {}
	for _, z in SLOT_Z do
		for _, x in SLOT_X do
			local slotCf = cf * CFrame.new(x, 1, z)
			makePart(model, {
				Name = "EnclosureGround",
				Size = Vector3.new(ENCLOSURE_SIZE - 1, 0.3, ENCLOSURE_SIZE - 1),
				CFrame = slotCf * CFrame.new(0, 0.15, 0),
				Color = color:Lerp(Color3.fromRGB(110, 190, 90), 0.6),
				Material = Enum.Material.Grass,
				CanCollide = false,
			})
			for _, side in { { 1, 0 }, { -1, 0 }, { 0, 1 } } do
				local half = ENCLOSURE_SIZE / 2
				makePart(model, {
					Name = "EnclosureRail",
					Size = if side[1] ~= 0
						then Vector3.new(0.5, 1.8, ENCLOSURE_SIZE)
						else Vector3.new(ENCLOSURE_SIZE, 1.8, 0.5),
					CFrame = slotCf * CFrame.new(side[1] * half, 0.9, side[2] * half),
					Color = dark,
					Material = Enum.Material.Wood,
					CanCollide = false,
				})
			end
			local lockSign = Instance.new("BillboardGui")
			lockSign.Name = "LockedSign"
			lockSign.Size = UDim2.fromScale(10, 3)
			lockSign.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
			lockSign.MaxDistance = 80
			lockSign.LightInfluence = 0
			lockSign.Enabled = false
			local holder = makePart(model, {
				Name = "SlotAnchor",
				Size = Vector3.one,
				CFrame = slotCf,
				Transparency = 1,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
			})
			lockSign.Parent = holder
			textLabel(lockSign, "🔒 Rebirth to unlock", Color3.fromRGB(200, 200, 220))
			table.insert(slots, slotCf * CFrame.new(0, 0.3, 0))
			table.insert(enclosureSigns, lockSign)
		end
	end

	-- Food storage crate (other players steal from here)
	local crate = makePart(model, {
		Name = "FoodStorage",
		Size = Vector3.new(6, 5, 6),
		CFrame = cf * CFrame.new(-16, 3.5, -S / 2 + 8),
		Color = Color3.fromRGB(150, 100, 55),
		Material = Enum.Material.WoodPlanks,
	})
	local crateGui = Instance.new("BillboardGui")
	crateGui.Size = UDim2.fromScale(10, 3)
	crateGui.StudsOffset = Vector3.new(0, 5, 0)
	crateGui.MaxDistance = 120
	crateGui.LightInfluence = 0
	crateGui.Parent = crate
	local foodLabel = textLabel(crateGui, "")
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
	stealPrompt:SetAttribute("OnlyUserId", -1) -- hidden until someone owns the zoo
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
		EnclosureSigns = enclosureSigns,
		CreatureFolder = creatures,
		SpawnCFrame = cf * CFrame.new(0, 4, -S / 2 + 14),
		Owner = nil,
		CharacterConnection = nil,
	}
end

function ZooService:Assign(player: Player): Plot?
	for _, plot in self.Plots do
		if not plot.Owner then
			plot.Owner = player
			self.ByPlayer[player] = plot
			plot.Model:SetAttribute("OwnerUserId", player.UserId)
			plot.StealPrompt:SetAttribute("OnlyUserId", nil)
			plot.StealPrompt:SetAttribute("HideForUserId", player.UserId)
			plot.SignLabel.Text = player.DisplayName .. "'s Zoo"
			plot.CharacterConnection = player.CharacterAdded:Connect(function(character)
				self:_sendHome(plot, character)
			end)
			if player.Character then
				self:_sendHome(plot, player.Character)
			end
			self:RefreshEnclosures(player)
			return plot
		end
	end
	return nil
end

function ZooService:_sendHome(plot: Plot, character: Model)
	task.spawn(function()
		local root = character:WaitForChild("HumanoidRootPart", 5)
		if root then
			task.wait(0.1)
			character:PivotTo(plot.SpawnCFrame)
		end
	end)
end

function ZooService:TeleportHome(player: Player)
	local plot = self.ByPlayer[player]
	if plot and player.Character then
		player.Character:PivotTo(plot.SpawnCFrame)
	end
end

function ZooService:Release(player: Player)
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
	plot.SignLabel.Text = "Empty Zoo"
	plot.FoodLabel.Text = ""
	plot.LockLabel.Text = ""
	plot.LockBubble.Transparency = 1
	for _, sign in plot.EnclosureSigns do
		sign.Enabled = false
	end
	if plot.CharacterConnection then
		plot.CharacterConnection:Disconnect()
		plot.CharacterConnection = nil
	end
	plot.CreatureFolder:ClearAllChildren()
end

function ZooService:GetPlot(player: Player): Plot?
	return self.ByPlayer[player]
end

-- Shows the lock sign on enclosures the player hasn't unlocked yet.
function ZooService:RefreshEnclosures(player: Player)
	local plot = self.ByPlayer[player]
	local data = Data:Get(player)
	if not plot or not data then
		return
	end
	local slots = CreatureMath.MaxSlots(data.Rebirths)
	for i, sign in plot.EnclosureSigns do
		sign.Enabled = i > slots
	end
end

function ZooService:IsInside(plot: Plot, position: Vector3): boolean
	local localPos = plot.CFrame:PointToObjectSpace(position)
	local half = GameConfig.Zoo.PlotSize / 2
	return math.abs(localPos.X) <= half and math.abs(localPos.Z) <= half
end

return ZooService
