--[[
	FoodService: food growing across the biomes, the food shop, each zoo's
	food storage (crate) and the storage lock.

	Food grows at FoodSpawn markers. When someone picks it up, that spot
	regrows after GameConfig.Food.RespawnTime[rarity] seconds.

	  FoodService:Give(player, foodId, amount) -> amount added
	  FoodService:SpaceLeft(player)
	  FoodService:RefreshStorage(player)
	  FoodService:IsLocked(plot)
	  FoodService:MeteorShower(count)
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Biomes = require(Shared.Config.Biomes)
local Foods = require(Shared.Config.Foods)
local GameConfig = require(Shared.Config.GameConfig)
local CreatureMath = require(Shared.Game.CreatureMath)
local Rules = require(Shared.Game.Rules)
local Format = require(Shared.Lib.Format)
local Guard = require(Shared.Lib.Guard)
local Log = require(Shared.Lib.Log)
local WeightedRandom = require(Shared.Lib.WeightedRandom)
local Net = require(Shared.Net)

local FoodBuilder = require(ServerScriptService:WaitForChild("Server").Modules.FoodBuilder)

local log = Log.new("FoodService")

local ORANGE = Color3.fromRGB(255, 170, 60)
local RED = Color3.fromRGB(255, 90, 90)

local FoodService = {
	Priority = 20,
	_folder = nil :: Folder?,
	_lockCooldown = {} :: { [Player]: number },
}

local Data, Zoo, Map, Fx

local function now(): number
	return Workspace:GetServerTimeNow()
end

function FoodService:Init(registry)
	Data = registry.DataService
	Zoo = registry.ZooService
	Map = registry.MapService
	Fx = registry.FxService

	Data:AddSnapshotHook(function(player, snapshot)
		local plot = Zoo:GetPlot(player)
		snapshot.LockedUntil = plot and plot.Model:GetAttribute("LockedUntil") or 0
		snapshot.LockCooldownUntil = self._lockCooldown[player] or 0
	end)
end

function FoodService:Start()
	local folder = Instance.new("Folder")
	folder.Name = "Food"
	folder.Parent = Map.Map or Workspace
	self._folder = folder

	local spots = 0
	for biomeId, spawns in Map.FoodSpawns do
		for _, spawnPart in spawns do
			spots += 1
			task.defer(self._growAt, self, biomeId, spawnPart)
		end
	end
	log:Info("food grows at", spots, "spots")

	Net.On("BuyFood", function(player, foodId, amount)
		self:Buy(player, foodId, amount)
	end)
	Net.On("SelectFood", function(player, foodId)
		if Guard.IsConfigKey(Foods, foodId) then
			player:SetAttribute("SelectedFood", foodId)
			Data:Changed(player)
		end
	end)
	Net.On("LockStorage", function(player)
		self:Lock(player)
	end)
end

function FoodService:OnPlayerReady(player: Player)
	local plot = Zoo:GetPlot(player)
	if plot then
		-- New players get a short lock so they can't be robbed instantly.
		self:_setLock(plot, GameConfig.Steal.JoinProtection)
	end
	self:RefreshStorage(player)
end

function FoodService:OnPlayerRemoving(player: Player)
	self._lockCooldown[player] = nil
end

--------------------------------------------------------------------------
-- Growing food
--------------------------------------------------------------------------

local function pickBiomeFood(biomeId: string): string?
	local biome = Biomes[biomeId]
	if not biome then
		return nil
	end
	local entry = WeightedRandom.Pick(biome.Foods, function(e)
		return e.Weight
	end)
	return entry and entry.Food
end

-- Grows one food at a spawn spot; when it's picked, schedules the regrow.
function FoodService:_growAt(biomeId: string, spawnPart: BasePart)
	local foodId = pickBiomeFood(biomeId)
	if not foodId then
		return
	end
	local model = self:_spawnFood(foodId, spawnPart.Position, biomeId, function()
		local rarity = Foods[foodId].Rarity
		local delay = (GameConfig.Food.RespawnTime[rarity] or 30) * (0.8 + math.random() * 0.4)
		task.delay(delay, self._growAt, self, biomeId, spawnPart)
	end)
	local def = Foods[foodId]
	if def.Rarity == "Mythic" or def.Rarity == "Secret" then
		local biome = Biomes[biomeId]
		Net.NotifyAll(string.format("%s A %s appeared in the %s!", biome.Icon, def.Name, biome.Name), def.Color)
	end
	return model
end

-- Creates a pickup. onTaken runs after someone collects it.
function FoodService:_spawnFood(foodId: string, position: Vector3, biomeId: string?, onTaken: (() -> ())?): Model
	local model = FoodBuilder.Build(foodId, position)
	model.Parent = self._folder
	CollectionService:AddTag(model, "FoodPickup") -- client spin/bob
	local hitbox = model.PrimaryPart :: BasePart
	local taken = false
	hitbox.Touched:Connect(function(hit)
		if taken then
			return
		end
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not player or not humanoid or humanoid.Health <= 0 then
			return
		end
		local data = Data:Get(player)
		if not data or (biomeId and not Rules.IsBiomeUnlocked(data, biomeId)) then
			return
		end
		-- Forage trait (e.g. Kraken): chance for double food
		local forage = 0
		for _, creature in data.Creatures do
			forage += CreatureMath.Trait(creature, "Forage")
		end
		local amount = if math.random() < math.min(forage, 0.75) then 2 else 1
		local given = self:Give(player, foodId, amount)
		if given > 0 then
			taken = true
			local def = Foods[foodId]
			Fx:PlayFor(player, "Pickup", {
				Position = hitbox.Position,
				Color = def.Color,
				Text = string.format("+%d %s%s", given, def.Name, if given > 1 then " (x2!)" else ""),
			})
			model:Destroy()
			if onTaken then
				onTaken()
			end
		end
	end)
	return model
end

--------------------------------------------------------------------------
-- Storage
--------------------------------------------------------------------------

function FoodService:SpaceLeft(player: Player): number
	local data = Data:Get(player)
	return if data then Rules.StorageSpace(data) else 0
end

function FoodService:Give(player: Player, foodId: string, amount: number): number
	local data = Data:Get(player)
	if not data or not Guard.IsConfigKey(Foods, foodId) then
		return 0
	end
	local given = math.min(amount, self:SpaceLeft(player))
	if given <= 0 then
		if Net.Throttle(player, "StorageFull", 3) then
			Net.Notify(
				player,
				"📦 Your food storage is full! Feed your " .. GameConfig.CreatureNamePlural .. ".",
				ORANGE
			)
		end
		return 0
	end
	data.Food[foodId] = (data.Food[foodId] or 0) + given
	self:RefreshStorage(player)
	Data:Changed(player)
	return given
end

function FoodService:RefreshStorage(player: Player)
	local plot = Zoo:GetPlot(player)
	local data = Data:Get(player)
	if plot and data then
		plot.FoodLabel.Text =
			string.format("🍖 %d / %d", CreatureMath.CountFood(data.Food), CreatureMath.StorageCap(data.Rebirths))
	end
end

--------------------------------------------------------------------------
-- Lock
--------------------------------------------------------------------------

function FoodService:_setLock(plot, duration: number)
	plot.Model:SetAttribute("LockedUntil", now() + duration)
	plot.LockBubble.Transparency = 0.4
	plot.LockLabel.Text = "🔒 Locked"
	task.delay(duration, function()
		if (plot.Model:GetAttribute("LockedUntil") or 0) <= now() + 0.05 then
			plot.LockBubble.Transparency = 1
			plot.LockLabel.Text = ""
		end
	end)
end

function FoodService:IsLocked(plot): boolean
	return (plot.Model:GetAttribute("LockedUntil") or 0) > now()
end

function FoodService:Lock(player: Player)
	local plot = Zoo:GetPlot(player)
	if not plot then
		return
	end
	local cooldownUntil = self._lockCooldown[player] or 0
	if now() < cooldownUntil then
		Net.Notify(player, "⏳ Lock is recharging: " .. Format.Time(cooldownUntil - now()))
		return
	end
	self:_setLock(plot, GameConfig.Steal.LockDuration)
	self._lockCooldown[player] = now() + GameConfig.Steal.LockDuration + GameConfig.Steal.LockCooldown
	Fx:PlayAll("Lock", { Position = plot.Crate.Position })
	Net.Notify(
		player,
		"🔒 Storage locked for " .. GameConfig.Steal.LockDuration .. "s!",
		Color3.fromRGB(90, 170, 255)
	)
	Data:Changed(player)
end

--------------------------------------------------------------------------
-- Shop
--------------------------------------------------------------------------

function FoodService:Buy(player: Player, foodId: string, amount: number)
	local data = Data:Get(player)
	if not data or not Guard.IsConfigKey(Foods, foodId) then
		return
	end
	local def = Foods[foodId]
	if not def.Price then
		return
	end
	amount = math.min(math.clamp(amount, 1, 10), self:SpaceLeft(player))
	if amount <= 0 then
		Net.Notify(player, "📦 Your food storage is full!", ORANGE)
		return
	end
	local cost = def.Price * amount
	if data.Cash < cost then
		Net.Notify(player, "Not enough cash!", RED)
		return
	end
	data.Cash -= cost
	self:Give(player, foodId, amount)
	Net.Notify(player, string.format("Bought %dx %s", amount, def.Name), def.Color)
end

--------------------------------------------------------------------------
-- Meteor Feast
--------------------------------------------------------------------------

function FoodService:MeteorShower(count: number)
	-- Meteors favour rarer food: flatten the spawn weights of all biomes.
	local entries = {}
	for _, id in Foods.Order do
		table.insert(entries, { Id = id, Weight = math.sqrt(GameConfig.Food.RespawnTime[Foods[id].Rarity] or 1) })
	end
	for i = 1, count do
		task.delay(i * 0.15, function()
			local pick = WeightedRandom.Pick(entries, function(e)
				return 1 / e.Weight
			end)
			if not pick then
				return
			end
			local target = Map:RandomMeteorPoint() + Vector3.new(0, 2, 0)
			local model =
				FoodBuilder.Build(pick.Id, target + Vector3.new(math.random(-40, 40), 150, math.random(-40, 40)))
			model.Parent = self._folder
			local hitbox = model.PrimaryPart :: BasePart
			local fire = Instance.new("Fire")
			fire.Size = 6
			fire.Heat = 15
			fire.Parent = hitbox
			Fx:PlayNear(target, 400, "MeteorWarning", { Position = target })
			local value = Instance.new("CFrameValue")
			value.Value = model:GetPivot()
			value.Changed:Connect(function(cf)
				if model.Parent then
					model:PivotTo(cf)
				end
			end)
			local fall =
				TweenService:Create(value, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Value = CFrame.new(target),
				})
			fall:Play()
			fall.Completed:Connect(function()
				value:Destroy()
				model:Destroy()
				Fx:PlayNear(target, 400, "MeteorImpact", { Position = target, Color = Foods[pick.Id].Color })
				local landed = self:_spawnFood(pick.Id, target)
				task.delay(90, function()
					if landed.Parent then
						landed:Destroy()
					end
				end)
			end)
		end)
	end
end

return FoodService
