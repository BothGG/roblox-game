--[[
	KingService: the biggest kaiju on the server becomes the Kaiju King.
	Its owner gets bonus income, and the kaiju wears a crown + golden outline.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local CreatureMath = require(Shared.CreatureMath)
local Net = require(Shared.Net)

local GOLD = Color3.fromRGB(255, 200, 40)

local KingService = {
	Current = nil :: { Player: Player, Uid: string }?,
	_crown = nil :: Model?,
	_highlight = nil :: Highlight?,
}

local Data, Creatures, Fx, World

function KingService:Init(services)
	Data = services.DataService
	Creatures = services.CreatureService
	Fx = services.FxService
	World = services.WorldService
end

function KingService:Start()
	task.spawn(function()
		while true do
			task.wait(GameConfig.KingCheckInterval)
			self:Evaluate()
		end
	end)
end

local function buildCrown(size: number): Model
	local crown = Instance.new("Model")
	crown.Name = "KingCrown"
	local function piece(partSize: Vector3, cf: CFrame, shape: Enum.PartType?)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Material = Enum.Material.Foil
		p.Color = GOLD
		p.Shape = shape or Enum.PartType.Block
		p.Size = partSize
		p.CFrame = cf
		p.Parent = crown
		return p
	end
	local base = piece(Vector3.new(size * 0.35, size, size), CFrame.Angles(0, 0, math.rad(90)), Enum.PartType.Cylinder)
	crown.PrimaryPart = base
	for i = 1, 5 do
		local angle = i / 5 * math.pi * 2
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * size * 0.4
		piece(Vector3.new(size * 0.18, size * 0.45, size * 0.18), CFrame.new(offset + Vector3.new(0, size * 0.35, 0)))
		local jewel = piece(Vector3.one * size * 0.16, CFrame.new(offset + Vector3.new(0, size * 0.62, 0)), Enum.PartType.Ball)
		jewel.Material = Enum.Material.Neon
		jewel.Color = Color3.fromRGB(255, 60, 90)
	end
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Brightness = 2
	light.Range = size * 3
	light.Parent = base
	return crown
end

function KingService:_findBest()
	local best, bestLevel, bestIncome = nil, 0, -1
	for player, profile in Data.Profiles do
		if not player.Parent then
			continue
		end
		for uid, creature in profile.Data.Creatures do
			local income = CreatureMath.BaseIncome(creature)
			if creature.Level > bestLevel or (creature.Level == bestLevel and income > bestIncome) then
				best, bestLevel, bestIncome = { Player = player, Uid = uid }, creature.Level, income
			end
		end
	end
	if bestLevel < GameConfig.KingMinLevel then
		return nil
	end
	return best
end

function KingService:Evaluate()
	local best = self:_findBest()
	local current = self.Current
	local changed = (best == nil) ~= (current == nil)
		or (best and current and (best.Player ~= current.Player or best.Uid ~= current.Uid))
	if changed then
		if current and current.Player.Parent then
			current.Player:SetAttribute("IsKing", false)
			Creatures:RefreshAllTags(current.Player)
		end
		self.Current = best
		if best then
			best.Player:SetAttribute("IsKing", true)
			Creatures:RefreshAllTags(best.Player)
			local creature = Data:Get(best.Player).Creatures[best.Uid]
			local model = Creatures:GetModel(best.Player, best.Uid)
			Net.Announce(
				"👑 NEW " .. string.upper(GameConfig.CreatureName) .. " KING",
				string.format("%s's %s (Lv.%d)", best.Player.DisplayName, CreatureMath.DisplayName(creature), creature.Level),
				GOLD
			)
			Fx:PlayAll("NewKing", {
				Position = model and model:GetPivot().Position,
				Owner = best.Player.UserId,
			})
		end
	end
	self:UpdateCrown()
end

-- Puts the crown on top of the king's kaiju (called after it grows too).
function KingService:UpdateCrown()
	local current = self.Current
	local model = current and Creatures:GetModel(current.Player, current.Uid)
	if not model then
		if self._crown then
			self._crown:Destroy()
			self._crown = nil
		end
		if self._highlight then
			self._highlight:Destroy()
			self._highlight = nil
		end
		return
	end
	local extents = model:GetExtentsSize()
	local size = math.clamp(extents.X * 0.4, 2, 30)
	if not self._crown or math.abs(((self._crown.PrimaryPart :: BasePart).Size.Y) - size) > 0.01 then
		if self._crown then
			self._crown:Destroy()
		end
		self._crown = buildCrown(size)
	end
	local crown = self._crown :: Model
	crown.Parent = World.Folder
	-- The crown's base is a cylinder lying on its side, so rotate it upright.
	crown:PivotTo(CFrame.new(model:GetPivot().Position + Vector3.new(0, extents.Y + size * 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)))

	if not self._highlight or self._highlight.Parent ~= model then
		if self._highlight then
			self._highlight:Destroy()
		end
		local highlight = Instance.new("Highlight")
		highlight.FillTransparency = 1
		highlight.OutlineColor = GOLD
		highlight.Parent = model
		self._highlight = highlight
	end
end

function KingService:OnPlayerRemoving(player: Player)
	if self.Current and self.Current.Player == player then
		self.Current = nil
		task.defer(function()
			self:Evaluate()
		end)
	end
end

return KingService
