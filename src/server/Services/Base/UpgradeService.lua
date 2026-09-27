--[[
	UpgradeService: the upgrade board at every base (pens, storage,
	incubators). Walk up to it and hold E on an upgrade to buy one level.
	Costs and effects are in Config/Upgrades.lua; the rules (cost, max,
	how many pens) are in shared/Game/Rules.lua so the UI shows the same.

	Remote: BuyUpgrade(id) for menus.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Upgrades = require(Shared.Config.Upgrades)
local Rules = require(Shared.Game.Rules)
local Format = require(Shared.Lib.Format)
local Log = require(Shared.Lib.Log)
local Net = require(Shared.Net)

local StudGround = require(ServerScriptService:WaitForChild("Server").Modules.Map.StudGround)

local log = Log.new("UpgradeService")

local UpgradeService = {
	Priority = 22, -- after BaseService (10) built the plots
	Boards = {} :: { [number]: { Prompts: { [string]: ProximityPrompt }, Labels: { [string]: TextLabel } } },
}

local Data, Base, Creature, Food, Fx

local RED = Color3.fromRGB(255, 90, 90)
local GOLD = Color3.fromRGB(255, 210, 60)

function UpgradeService:Init(registry)
	Data = registry.DataService
	Base = registry.BaseService
	Creature = registry.CreatureService
	Food = registry.FoodService
	Fx = registry.FxService
end

local function label(parent: Instance, text: string, color: Color3?, size: UDim2, position: UDim2): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = size
	l.Position = position
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Text = text
	l.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = l
	return l
end

-- Builds the board next to the entrance of one plot.
function UpgradeService:_build(plot)
	local S = GameConfig.Plots.Size
	local cf = plot.CFrame * CFrame.new(24, 0, -S / 2 + 12)
	local model = Instance.new("Model")
	model.Name = "UpgradeBoard"
	local function part(name: string, size: Vector3, offset: CFrame, color: Color3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cf * offset
		p.Color = color
		p.Parent = model
		return p
	end
	for _, x in { -9, 9 } do
		part("Post", Vector3.new(1.5, 14, 1.5), CFrame.new(x, 7, 0), Color3.fromRGB(110, 80, 55))
	end
	local board = part("Board", Vector3.new(20, 11, 1), CFrame.new(0, 9, 0), Color3.fromRGB(35, 38, 55))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front -- faces the entrance (-Z)
	gui.CanvasSize = Vector2.new(400, 220)
	gui.LightInfluence = 0
	gui.Parent = board
	label(gui, "⬆️ BASE UPGRADES", GOLD, UDim2.new(1, 0, 0, 44), UDim2.fromOffset(0, 4))
	local entry = { Prompts = {}, Labels = {} }
	for i, id in Upgrades.Order do
		local def = Upgrades[id]
		entry.Labels[id] = label(
			gui,
			def.Icon .. " " .. def.Name,
			if def.Enabled then Color3.new(1, 1, 1) else Color3.fromRGB(150, 150, 170),
			UDim2.new(1, -16, 0, 50),
			UDim2.fromOffset(8, 50 + (i - 1) * 56)
		)
		-- A button pad per upgrade in front of the board
		local pad = part(
			"Pad_" .. id,
			Vector3.new(5, 1, 3),
			CFrame.new((i - 2) * 6.5, 0.5, -4),
			if def.Enabled then Color3.fromRGB(80, 200, 90) else Color3.fromRGB(120, 120, 130)
		)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Upgrade_" .. id
		prompt.ActionText = def.Icon .. " " .. def.Name
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("OnlyUserId", -1) -- only the owner sees it
		prompt.Parent = pad
		prompt.Triggered:Connect(function(player)
			if Base:GetPlot(player) == plot then
				self:Buy(player, id)
			end
		end)
		entry.Prompts[id] = prompt
	end
	if GameConfig.Map.Style ~= "Terrain" then
		StudGround.Style(model)
	end
	model.Parent = plot.Model
	self.Boards[plot.Index] = entry
end

function UpgradeService:Start()
	for _, plot in Base.Plots do
		self:_build(plot)
	end
	Net.On("BuyUpgrade", function(player, id)
		self:Buy(player, id)
	end)
	log:Info("upgrade boards built:", #Base.Plots)
end

function UpgradeService:OnPlayerReady(player: Player)
	self:Refresh(player)
end

function UpgradeService:OnPlayerRemoving(player: Player)
	local plot = Base:GetPlot(player)
	local board = plot and self.Boards[plot.Index]
	if board then
		for id, prompt in board.Prompts do
			prompt:SetAttribute("OnlyUserId", -1)
			board.Labels[id].Text = Upgrades[id].Icon .. " " .. Upgrades[id].Name
		end
	end
end

-- Updates the board text and prompt prices for a player's base.
function UpgradeService:Refresh(player: Player)
	local plot = Base:GetPlot(player)
	local data = Data:Get(player)
	local board = plot and self.Boards[plot.Index]
	if not board or not data then
		return
	end
	for id, prompt in board.Prompts do
		local def = Upgrades[id]
		local level = Rules.UpgradeLevel(data, id)
		local cost = Rules.UpgradeCost(data, id)
		prompt:SetAttribute("OnlyUserId", player.UserId)
		local status = if not def.Enabled then "Coming soon" elseif cost then Format.Money(cost) else "MAX"
		prompt.ObjectText = def.Text .. " • " .. status
		board.Labels[id].Text = string.format("%s %s  Lv.%d/%d  %s", def.Icon, def.Name, level, def.Max, status)
	end
end

function UpgradeService:Buy(player: Player, id: string)
	local data = Data:Get(player)
	if not data or not Upgrades[id] then
		return
	end
	local ok, reason = Rules.BuyUpgrade(data, id)
	if not ok then
		Net.Notify(player, "⬆️ " .. (reason or "Can't upgrade"), RED)
		return
	end
	log:Info(player.Name, "bought", id, "level", Rules.UpgradeLevel(data, id))
	local plot = Base:GetPlot(player)
	if plot then
		Fx:PlayAll("LevelUp", {
			Position = plot.CFrame.Position + Vector3.new(0, 6, 0),
			Level = Rules.UpgradeLevel(data, id),
			Owner = player.UserId,
		})
	end
	Net.Notify(player, "⬆️ " .. Upgrades[id].Name .. " upgraded! " .. Upgrades[id].Text, GOLD)
	Base:RefreshPens(player)
	Food:RefreshStorage(player)
	Creature:RefreshAllTags(player)
	self:Refresh(player)
	Data:Changed(player)
end

return UpgradeService
