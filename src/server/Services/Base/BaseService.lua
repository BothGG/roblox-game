--[[
	BaseService: builds a base on every Plot marker and gives one to each
	player. A base has 8 titan pens (locked ones show a sign), a food storage
	crate (others can steal from it), a lock bubble, a name sign, and a
	"Challenge" prompt so other players can call you out to a duel.

	  BaseService:Assign(player) / :Release(player)
	  BaseService:GetPlot(player) -> Plot
	  BaseService:IsInside(plot, position)
	  BaseService:RefreshPens(player)
	  BaseService:TeleportHome(player)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Rules = require(Shared.Game.Rules)
local Log = require(Shared.Lib.Log)
local Net = require(Shared.Net)

local log = Log.new("BaseService")

export type Plot = {
	Index: number,
	Model: Model,
	CFrame: CFrame,
	Crate: BasePart,
	StealPrompt: ProximityPrompt,
	ChallengePrompt: ProximityPrompt,
	LockBubble: BasePart,
	FoodLabel: TextLabel,
	LockLabel: TextLabel,
	SignLabel: TextLabel,
	Slots: { CFrame },
	PenSigns: { BillboardGui },
	CreatureFolder: Folder,
	SpawnCFrame: CFrame,
	Owner: Player?,
	CharacterConnection: RBXScriptConnection?,
}

local BaseService = {
	Priority = 10,
	Plots = {} :: { Plot },
	ByPlayer = {} :: { [Player]: Plot },
	Folder = nil :: Folder?,
}

local Data, Map, Battle

local PLOT_COLORS = {
	Color3.fromRGB(120, 200, 110),
	Color3.fromRGB(110, 170, 230),
	Color3.fromRGB(240, 170, 90),
	Color3.fromRGB(200, 120, 220),
	Color3.fromRGB(240, 220, 100),
	Color3.fromRGB(230, 110, 110),
	Color3.fromRGB(100, 210, 200),
	Color3.fromRGB(180, 180, 190),
	Color3.fromRGB(255, 150, 190),
	Color3.fromRGB(150, 220, 120),
	Color3.fromRGB(130, 140, 240),
	Color3.fromRGB(230, 190, 140),
}

-- Pen grid (plot-local X, Z). Front of the base is -Z (towards the arena).
local PEN_X = { -24, -8, 8, 24 }
local PEN_Z = { 2, 22 }
local PEN_SIZE = 15

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

function BaseService:Init(registry)
	Data = registry.DataService
	Map = registry.MapService
	Battle = registry.BattleService
end

function BaseService:Start()
	local bases = Instance.new("Folder")
	bases.Name = "Bases"
	bases.Parent = Map.Map or workspace
	self.Folder = bases
	for i, anchor in Map.PlotAnchors do
		if i > GameConfig.Plots.Count then
			break
		end
		table.insert(self.Plots, self:_build(bases, i, anchor.CFrame))
	end
	log:Info("built", #self.Plots, "bases")

	Net.On("TeleportHome", function(player)
		if not Battle:IsFighting(player) then
			self:TeleportHome(player)
		end
	end)
end

function BaseService:_build(parent: Instance, index: number, anchorCf: CFrame): Plot
	local S = GameConfig.Plots.Size
	local cf = CFrame.new(anchorCf.Position.X, 0, anchorCf.Position.Z) * anchorCf.Rotation
	local color = PLOT_COLORS[(index - 1) % #PLOT_COLORS + 1]
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.4)

	local model = Instance.new("Model")
	model.Name = "Base" .. index
	model:SetAttribute("PlotIndex", index)

	makePart(model, {
		Name = "Floor",
		Size = Vector3.new(S, 1, S),
		CFrame = cf * CFrame.new(0, 0.5, 0),
		Color = Color3.fromRGB(205, 195, 170),
		Material = Enum.Material.Pavement,
	})
	makePart(model, {
		Name = "Trim",
		Size = Vector3.new(S - 4, 0.2, S - 4),
		CFrame = cf * CFrame.new(0, 1.05, 0),
		Color = color:Lerp(Color3.new(1, 1, 1), 0.5),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})

	-- Walls with an entrance at the front and back
	local gap = 20
	local segment = (S - gap) / 2
	local function wall(size: Vector3, offset: Vector3)
		makePart(model, {
			Name = "Wall",
			Size = size,
			CFrame = cf * CFrame.new(offset),
			Color = dark,
			Material = Enum.Material.Brick,
		})
	end
	for _, z in { -(S / 2 - 0.5), S / 2 - 0.5 } do
		wall(Vector3.new(segment, 5, 1), Vector3.new(gap / 2 + segment / 2, 3.5, z))
		wall(Vector3.new(segment, 5, 1), Vector3.new(-(gap / 2 + segment / 2), 3.5, z))
	end
	wall(Vector3.new(1, 5, S), Vector3.new(S / 2 - 0.5, 3.5, 0))
	wall(Vector3.new(1, 5, S), Vector3.new(-(S / 2 - 0.5), 3.5, 0))
	for _, x in { -(S / 2 - 0.5), S / 2 - 0.5 } do
		for _, z in { -(S / 2 - 0.5), S / 2 - 0.5 } do
			makePart(model, {
				Name = "Tower",
				Size = Vector3.new(4, 9, 4),
				CFrame = cf * CFrame.new(x, 4.5, z),
				Color = dark,
				Material = Enum.Material.Brick,
			})
			makePart(model, {
				Name = "Flag",
				Size = Vector3.new(0.2, 3, 4),
				CFrame = cf * CFrame.new(x, 11, z) * CFrame.new(0, 0, 2),
				Color = color,
				CanCollide = false,
			})
		end
	end

	-- Entrance arch + name sign facing the arena
	for _, x in { -gap / 2 - 1, gap / 2 + 1 } do
		makePart(model, {
			Name = "ArchPillar",
			Size = Vector3.new(2, 14, 2),
			CFrame = cf * CFrame.new(x, 8, -S / 2 + 0.5),
			Color = dark,
			Material = Enum.Material.Brick,
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
	local signLabel = textLabel(surface, "Empty Base")

	-- Duel challenge prompt at the entrance (hidden from the owner)
	local challengeAnchor = makePart(model, {
		Name = "ChallengePoint",
		Size = Vector3.new(1, 1, 1),
		CFrame = cf * CFrame.new(0, 3, -S / 2 - 2),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	local challengePrompt = Instance.new("ProximityPrompt")
	challengePrompt.Name = "ChallengePrompt"
	challengePrompt.ActionText = "Challenge to a duel"
	challengePrompt.ObjectText = "⚔️"
	challengePrompt.HoldDuration = 0.5
	challengePrompt.MaxActivationDistance = 14
	challengePrompt.KeyboardKeyCode = Enum.KeyCode.G
	challengePrompt.RequiresLineOfSight = false
	challengePrompt:SetAttribute("OnlyUserId", -1)
	challengePrompt.Parent = challengeAnchor

	-- Pens
	local slots = {}
	local penSigns = {}
	for _, z in PEN_Z do
		for _, x in PEN_X do
			local slotCf = cf * CFrame.new(x, 1, z)
			makePart(model, {
				Name = "PenGround",
				Size = Vector3.new(PEN_SIZE - 1, 0.3, PEN_SIZE - 1),
				CFrame = slotCf * CFrame.new(0, 0.2, 0),
				Color = color:Lerp(Color3.fromRGB(110, 190, 90), 0.6),
				Material = Enum.Material.Grass,
				CanCollide = false,
			})
			for _, side in { { 1, 0 }, { -1, 0 }, { 0, 1 } } do
				local half = PEN_SIZE / 2
				makePart(model, {
					Name = "PenRail",
					Size = if side[1] ~= 0 then Vector3.new(0.5, 1.8, PEN_SIZE) else Vector3.new(PEN_SIZE, 1.8, 0.5),
					CFrame = slotCf * CFrame.new(side[1] * half, 0.9, side[2] * half),
					Color = dark,
					Material = Enum.Material.Wood,
					CanCollide = false,
				})
			end
			local holder = makePart(model, {
				Name = "PenAnchor",
				Size = Vector3.one,
				CFrame = slotCf,
				Transparency = 1,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
			})
			local lockSign = Instance.new("BillboardGui")
			lockSign.Name = "LockedSign"
			lockSign.Size = UDim2.fromScale(10, 3)
			lockSign.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
			lockSign.MaxDistance = 80
			lockSign.LightInfluence = 0
			lockSign.Enabled = false
			lockSign.Parent = holder
			textLabel(lockSign, "🔒 Rebirth to unlock", Color3.fromRGB(200, 200, 220))
			table.insert(slots, slotCf * CFrame.new(0, 0.35, 0))
			table.insert(penSigns, lockSign)
		end
	end

	-- Food storage crate (other players steal from here)
	local crate = makePart(model, {
		Name = "FoodStorage",
		Size = Vector3.new(6, 5, 6),
		CFrame = cf * CFrame.new(-18, 3.5, -S / 2 + 9),
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
	stealPrompt:SetAttribute("OnlyUserId", -1) -- hidden until someone owns the base
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
	creatures.Name = "Titans"
	creatures.Parent = model
	model.Parent = parent

	local plot: Plot = {
		Index = index,
		Model = model,
		CFrame = cf,
		Crate = crate,
		StealPrompt = stealPrompt,
		ChallengePrompt = challengePrompt,
		LockBubble = lockBubble,
		FoodLabel = foodLabel,
		LockLabel = lockLabel,
		SignLabel = signLabel,
		Slots = slots,
		PenSigns = penSigns,
		CreatureFolder = creatures,
		SpawnCFrame = cf * CFrame.new(0, 4, -S / 2 + 12),
		Owner = nil,
		CharacterConnection = nil,
	}
	challengePrompt.Triggered:Connect(function(challenger)
		local owner = plot.Owner
		if owner and owner ~= challenger then
			Battle:Challenge(challenger, owner)
		end
	end)
	return plot
end

function BaseService:Assign(player: Player): Plot?
	for _, plot in self.Plots do
		if not plot.Owner then
			plot.Owner = player
			self.ByPlayer[player] = plot
			plot.Model:SetAttribute("OwnerUserId", player.UserId)
			for _, prompt in { plot.StealPrompt, plot.ChallengePrompt } do
				prompt:SetAttribute("OnlyUserId", nil)
				prompt:SetAttribute("HideForUserId", player.UserId)
			end
			plot.ChallengePrompt.ObjectText = "⚔️ " .. player.DisplayName
			plot.SignLabel.Text = player.DisplayName .. "'s Base"
			plot.CharacterConnection = player.CharacterAdded:Connect(function(character)
				self:_sendHome(plot, character)
			end)
			if player.Character then
				self:_sendHome(plot, player.Character)
			end
			self:RefreshPens(player)
			return plot
		end
	end
	return nil
end

function BaseService:_sendHome(plot: Plot, character: Model)
	task.spawn(function()
		local root = character:WaitForChild("HumanoidRootPart", 5)
		if root then
			task.wait(0.1)
			character:PivotTo(plot.SpawnCFrame)
		end
	end)
end

function BaseService:TeleportHome(player: Player)
	local plot = self.ByPlayer[player]
	if plot and player.Character then
		player.Character:PivotTo(plot.SpawnCFrame)
	end
end

function BaseService:Release(player: Player)
	local plot = self.ByPlayer[player]
	if not plot then
		return
	end
	self.ByPlayer[player] = nil
	plot.Owner = nil
	plot.Model:SetAttribute("OwnerUserId", nil)
	plot.Model:SetAttribute("LockedUntil", nil)
	for _, prompt in { plot.StealPrompt, plot.ChallengePrompt } do
		prompt:SetAttribute("HideForUserId", nil)
		prompt:SetAttribute("OnlyUserId", -1)
	end
	plot.SignLabel.Text = "Empty Base"
	plot.FoodLabel.Text = ""
	plot.LockLabel.Text = ""
	plot.LockBubble.Transparency = 1
	for _, sign in plot.PenSigns do
		sign.Enabled = false
	end
	if plot.CharacterConnection then
		plot.CharacterConnection:Disconnect()
		plot.CharacterConnection = nil
	end
	plot.CreatureFolder:ClearAllChildren()
end

function BaseService:GetPlot(player: Player): Plot?
	return self.ByPlayer[player]
end

-- Shows the lock sign on pens the player hasn't unlocked yet.
function BaseService:RefreshPens(player: Player)
	local plot = self.ByPlayer[player]
	local data = Data:Get(player)
	if not plot or not data then
		return
	end
	local slots = Rules.MaxSlots(data)
	for i, sign in plot.PenSigns do
		sign.Enabled = i > slots
	end
end

function BaseService:IsInside(plot: Plot, position: Vector3): boolean
	local localPos = plot.CFrame:PointToObjectSpace(position)
	local half = GameConfig.Plots.Size / 2
	return math.abs(localPos.X) <= half and math.abs(localPos.Z) <= half
end

return BaseService
