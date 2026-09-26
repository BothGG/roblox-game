--[[
	CreatureService: owns the kaiju in each player's zoo.
	Feeding, growing, mutating, selling, income and the 3D models.

	  CreatureService:Add(player, creatureId, mutation?) -> uid?
	  CreatureService:Feed(player, uid)
	  CreatureService:Sell(player, uid)
	  CreatureService:GetModel(player, uid)
	  CreatureService:GetIncome(player)
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Creatures = require(Shared.Config.Creatures)
local Foods = require(Shared.Config.Foods)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local CreatureMath = require(Shared.Game.CreatureMath)
local Rules = require(Shared.Game.Rules)
local Format = require(Shared.Lib.Format)
local Net = require(Shared.Net)

local CreatureBuilder = require(ServerScriptService:WaitForChild("Server").Modules.CreatureBuilder)

local CreatureService = {
	Priority = 25,
	Models = {} :: { [Player]: { [string]: Model } },
}

local Data, Zoo, Fx, Food, King

function CreatureService:Init(registry)
	Data = registry.DataService
	Zoo = registry.ZooService
	Fx = registry.FxService
	Food = registry.FoodService
	King = registry.KingService

	Data:AddSnapshotHook(function(player, snapshot)
		snapshot.Income = player:GetAttribute("Income") or 0
		snapshot.IsKing = player:GetAttribute("IsKing") == true
	end)
end

function CreatureService:Start()
	-- Income tick
	task.spawn(function()
		while true do
			task.wait(1)
			for player, profile in Data.Profiles do
				local income = self:GetIncome(player)
				profile.Data.Cash += income
				player:SetAttribute("Income", income)
				self:_updateLeaderstats(player)
				Data:Changed(player)
			end
		end
	end)
end

function CreatureService:OnPlayerReady(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local biggest = Instance.new("IntValue")
	biggest.Name = "Biggest Lv"
	biggest.Parent = leaderstats
	local cash = Instance.new("StringValue")
	cash.Name = "Cash"
	cash.Parent = leaderstats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = leaderstats
	leaderstats.Parent = player

	player:SetAttribute("SelectedFood", "Meat")
	self.Models[player] = {}
	local data = Data:Get(player)
	for uid in data.Creatures do
		self:_spawnModel(player, uid)
	end
	self:_layout(player)
	self:_updateLeaderstats(player)
end

function CreatureService:OnPlayerRemoving(player: Player)
	local models = self.Models[player]
	if models then
		for _, model in models do
			model:Destroy()
		end
	end
	self.Models[player] = nil
end

function CreatureService:_updateLeaderstats(player: Player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local data = Data:Get(player)
	if not leaderstats or not data then
		return
	end
	local biggest = 0
	for _, creature in data.Creatures do
		biggest = math.max(biggest, creature.Level)
	end
	(leaderstats:FindFirstChild("Biggest Lv") :: IntValue).Value = biggest;
	(leaderstats:FindFirstChild("Cash") :: StringValue).Value = Format.Money(data.Cash);
	(leaderstats:FindFirstChild("Rebirths") :: IntValue).Value = data.Rebirths
end

function CreatureService:GetIncome(player: Player): number
	local data = Data:Get(player)
	if not data then
		return 0
	end
	local mult = CreatureMath.PlayerMultiplier(data.Rebirths, player:GetAttribute("IsKing") == true)
	local total = 0
	for _, creature in data.Creatures do
		total += CreatureMath.BaseIncome(creature)
	end
	return total * mult
end

function CreatureService:GetModel(player: Player, uid: string): Model?
	local models = self.Models[player]
	return models and models[uid]
end

--------------------------------------------------------------------------
-- Models
--------------------------------------------------------------------------

local function sortedUids(creatures): { string }
	local uids = {}
	for uid in creatures do
		table.insert(uids, uid)
	end
	table.sort(uids, function(a, b)
		return (tonumber(a) or 0) < (tonumber(b) or 0)
	end)
	return uids
end

-- Top-center of a model, used for effects and the name tag.
function CreatureService:TopOf(model: Model): Vector3
	return model:GetPivot().Position + Vector3.new(0, model:GetExtentsSize().Y, 0)
end

function CreatureService:_spawnModel(player: Player, uid: string)
	local data = Data:Get(player)
	local plot = Zoo:GetPlot(player)
	local creature = data.Creatures[uid]
	if not plot or not creature then
		return
	end
	local model = CreatureBuilder.Build(creature)
	model.Name = uid
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("Uid", uid)
	model.Parent = plot.CreatureFolder
	CollectionService:AddTag(model, "ZooCreature") -- client idle animation
	self.Models[player][uid] = model

	local root = model.PrimaryPart :: BasePart

	local tag = Instance.new("BillboardGui")
	tag.Name = "Tag"
	tag.Size = UDim2.fromOffset(200, 70)
	tag.LightInfluence = 0
	tag.MaxDistance = 150
	tag.Adornee = root
	tag.Parent = root
	local function line(name: string, y: number, height: number)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.Size = UDim2.new(1, 0, height, 0)
		label.Position = UDim2.fromScale(0, y)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Parent = tag
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Parent = label
		return label
	end
	line("NameLabel", 0, 0.4)
	line("InfoLabel", 0.4, 0.3)
	local bar = Instance.new("Frame")
	bar.Name = "XpBar"
	bar.Size = UDim2.new(0.7, 0, 0.12, 0)
	bar.Position = UDim2.fromScale(0.15, 0.78)
	bar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	bar.BorderSizePixel = 0
	bar.Parent = tag
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = bar
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(110, 230, 120)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = bar
	corner:Clone().Parent = fill

	local feed = Instance.new("ProximityPrompt")
	feed.Name = "FeedPrompt"
	feed.ActionText = "Feed"
	feed.KeyboardKeyCode = Enum.KeyCode.E
	feed.HoldDuration = 0
	feed.RequiresLineOfSight = false
	feed:SetAttribute("OnlyUserId", player.UserId)
	feed.Parent = root
	feed.Triggered:Connect(function(who)
		if who == player then
			self:Feed(player, uid)
		end
	end)

	local sell = Instance.new("ProximityPrompt")
	sell.Name = "SellPrompt"
	sell.ActionText = "Sell"
	sell.KeyboardKeyCode = Enum.KeyCode.F
	sell.GamepadKeyCode = Enum.KeyCode.ButtonY
	sell.HoldDuration = 1.5
	sell.RequiresLineOfSight = false
	sell:SetAttribute("OnlyUserId", player.UserId)
	sell.Parent = root
	sell.Triggered:Connect(function(who)
		if who == player then
			self:Sell(player, uid)
		end
	end)

	self:_rescale(player, uid)
end

function CreatureService:_rescale(player: Player, uid: string)
	local model = self:GetModel(player, uid)
	local creature = Data:Get(player).Creatures[uid]
	if not model or not creature then
		return
	end
	local scale = CreatureMath.Scale(creature.Level)
	if math.abs(model:GetScale() - scale) > 1e-3 then
		model:ScaleTo(scale)
	end
	local root = model.PrimaryPart :: BasePart
	local height = model:GetExtentsSize().Y
	local tag = root:FindFirstChild("Tag") :: BillboardGui
	tag.StudsOffsetWorldSpace = Vector3.new(0, height + 1.5, 0)
	for _, name in { "FeedPrompt", "SellPrompt" } do
		local prompt = root:FindFirstChild(name) :: ProximityPrompt
		prompt.MaxActivationDistance = 10 + scale * 2
	end
	self:_refreshTag(player, uid)
end

function CreatureService:_refreshTag(player: Player, uid: string)
	local model = self:GetModel(player, uid)
	local data = Data:Get(player)
	local creature = data and data.Creatures[uid]
	if not model or not creature then
		return
	end
	local def = Creatures[creature.Id]
	local root = model.PrimaryPart :: BasePart
	local tag = root:FindFirstChild("Tag") :: BillboardGui
	local nameLabel = tag:FindFirstChild("NameLabel") :: TextLabel
	nameLabel.Text = CreatureMath.DisplayName(creature)
	nameLabel.TextColor3 = if creature.Mutation then Mutations[creature.Mutation].Color else Rarities[def.Rarity].Color
	local income = CreatureMath.BaseIncome(creature)
		* CreatureMath.PlayerMultiplier(data.Rebirths, player:GetAttribute("IsKing") == true)
	local info = tag:FindFirstChild("InfoLabel") :: TextLabel
	info.Text = string.format("Lv.%d • %s/s", creature.Level, Format.Money(income))
	local fill = tag:FindFirstChild("XpBar"):FindFirstChild("Fill") :: Frame
	local progress = if creature.Level >= GameConfig.MaxLevel
		then 1
		else creature.Xp / CreatureMath.XpToNext(creature.Level)
	fill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
	local sell = root:FindFirstChild("SellPrompt") :: ProximityPrompt
	sell.ObjectText = Format.Money(CreatureMath.SellPrice(creature, data.Rebirths))
	local feed = root:FindFirstChild("FeedPrompt") :: ProximityPrompt
	local loves = {}
	for _, foodId in def.Diet or {} do
		table.insert(loves, Foods[foodId].Name)
	end
	feed.ObjectText = CreatureMath.DisplayName(creature)
		.. (if #loves > 0 then " ❤️ " .. table.concat(loves, ", ") else "")
end

function CreatureService:_layout(player: Player)
	local data = Data:Get(player)
	local plot = Zoo:GetPlot(player)
	if not data or not plot then
		return
	end
	for i, uid in sortedUids(data.Creatures) do
		local model = self:GetModel(player, uid)
		local slot = plot.Slots[i]
		if model and slot then
			model:PivotTo(slot)
			model:SetAttribute("Home", slot) -- client animates around this
		end
	end
end

function CreatureService:_rebuild(player: Player, uid: string)
	local model = self:GetModel(player, uid)
	if model then
		model:Destroy()
		self.Models[player][uid] = nil
	end
	self:_spawnModel(player, uid)
	self:_layout(player)
end

--------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------

function CreatureService:Add(player: Player, creatureId: string, mutation: string?): string?
	local data = Data:Get(player)
	if not data or not Creatures[creatureId] then
		return nil
	end
	if CreatureMath.Count(data.Creatures) >= CreatureMath.MaxSlots(data.Rebirths) then
		return nil
	end
	local uid = tostring(data.NextUid)
	data.NextUid += 1
	data.Creatures[uid] = { Id = creatureId, Level = 1, Xp = 0, Mutation = mutation }
	data.Index[creatureId] = true
	if mutation then
		data.Index[creatureId .. ":" .. mutation] = true
	end
	self:_spawnModel(player, uid)
	self:_layout(player)

	local model = self:GetModel(player, uid)
	if model then
		local def = Creatures[creatureId]
		Fx:PlayAll("Spawn", {
			Position = model:GetPivot().Position,
			Color = if mutation then Mutations[mutation].Color else Rarities[def.Rarity].Color,
			Rare = Rarities[def.Rarity].Order >= Rarities.Epic.Order or mutation ~= nil,
		})
	end
	King:Evaluate()
	Data:Changed(player)
	return uid
end

function CreatureService:RemoveAll(player: Player)
	local data = Data:Get(player)
	for _, model in self.Models[player] or {} do
		model:Destroy()
	end
	self.Models[player] = {}
	data.Creatures = {}
	King:Evaluate()
end

function CreatureService:Feed(player: Player, uid: string)
	local data = Data:Get(player)
	local creature = data and data.Creatures[uid]
	if not creature or not Net.Throttle(player, "Feed", 0.15) then
		return
	end
	if creature.Level >= GameConfig.MaxLevel then
		Net.Notify(player, "This " .. GameConfig.CreatureName .. " is already max level!")
		return
	end

	local foodId = Rules.PickFood(data.Food, player:GetAttribute("SelectedFood") :: string?)
	if not foodId then
		Net.Notify(
			player,
			"No food! Explore the biomes to find some... or steal some 😈",
			Color3.fromRGB(255, 170, 60)
		)
		return
	end
	local food = Foods[foodId]

	data.Food[foodId] -= 1
	data.Stats.FoodEaten += 1

	local favorite = Rules.IsFavorite(creature.Id, foodId)
	local xp = Rules.FeedXp(creature, foodId, Workspace:GetAttribute("GrowthMult"))
	local leveledUp = Rules.AddXp(creature, xp) > 0

	local mutated = false
	if food.Mutation then
		local new = Mutations[food.Mutation.Id]
		local current = creature.Mutation and Mutations[creature.Mutation]
		if (not current or new.IncomeMult > current.IncomeMult) and math.random() < food.Mutation.Chance then
			creature.Mutation = food.Mutation.Id
			data.Index[creature.Id .. ":" .. creature.Mutation] = true
			mutated = true
		end
	end

	if mutated then
		self:_rebuild(player, uid)
	elseif leveledUp then
		self:_rescale(player, uid)
	else
		self:_refreshTag(player, uid)
	end

	local model = self:GetModel(player, uid)
	if model then
		local ground = model:GetPivot().Position
		local mid = ground + Vector3.new(0, model:GetExtentsSize().Y * 0.6, 0)
		Fx:PlayAll(
			"Feed",
			{ Position = mid, Color = food.Color, Owner = player.UserId, Xp = xp, Favorite = favorite, Model = model }
		)
		if leveledUp then
			Fx:PlayAll("LevelUp", {
				Position = mid,
				Ground = ground,
				Level = creature.Level,
				Model = model,
				Owner = player.UserId,
				Size = model:GetExtentsSize().X / 2,
			})
		end
		if mutated then
			local mutation = Mutations[creature.Mutation]
			Fx:PlayAll("Mutation", {
				Position = mid,
				Ground = ground,
				Color = mutation.Color,
				Name = mutation.Name,
				Model = model,
				Owner = player.UserId,
			})
			Net.NotifyAll(
				string.format(
					"🧬 %s's %s mutated into %s!",
					player.DisplayName,
					Creatures[creature.Id].Name,
					string.upper(mutation.Name)
				),
				mutation.Color
			)
		end
	end

	if leveledUp then
		King:Evaluate()
	end
	Food:RefreshStorage(player)
	Data:Changed(player)
end

function CreatureService:Sell(player: Player, uid: string)
	local data = Data:Get(player)
	local creature = data and data.Creatures[uid]
	if not creature or not Net.Throttle(player, "Sell", 0.5) then
		return
	end
	local price = CreatureMath.SellPrice(creature, data.Rebirths)
	local model = self:GetModel(player, uid)
	if model then
		Fx:PlayAll("Sell", {
			Position = self:TopOf(model),
			Ground = model:GetPivot().Position,
			Owner = player.UserId,
			Text = Format.Money(price),
		})
		model:Destroy()
		self.Models[player][uid] = nil
	end
	data.Creatures[uid] = nil
	data.Cash += price
	self:_layout(player)
	King:Evaluate()
	Data:Changed(player)
end

-- Refresh every name tag (e.g. when income bonuses change).
function CreatureService:RefreshAllTags(player: Player)
	local data = Data:Get(player)
	if not data then
		return
	end
	for uid in data.Creatures do
		self:_refreshTag(player, uid)
	end
end

return CreatureService
