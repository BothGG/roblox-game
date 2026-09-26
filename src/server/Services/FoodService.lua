--[[
	FoodService: wild food in the middle, the food shop, the food storage
	(the crate on each plot) and the storage lock.

	  FoodService:Give(player, foodId, amount) -> given amount
	  FoodService:RefreshStorage(player)
	  FoodService:MeteorShower(count)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Foods = require(Shared.Config.Foods)
local Rarities = require(Shared.Config.Rarities)
local CreatureMath = require(Shared.CreatureMath)
local WeightedRandom = require(Shared.Util.WeightedRandom)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)
local Auras = require(Shared.Fx.Auras)

local FoodService = {
	_wildFolder = nil :: Folder?,
	_lockCooldown = {} :: { [Player]: number },
}

local Data, World, Fx

local function now(): number
	return Workspace:GetServerTimeNow()
end

function FoodService:Init(services)
	Data = services.DataService
	World = services.WorldService
	Fx = services.FxService

	Data:AddSnapshotHook(function(player, snapshot)
		local plot = World:GetPlot(player)
		snapshot.LockedUntil = plot and plot.Model:GetAttribute("LockedUntil") or 0
		snapshot.LockCooldownUntil = self._lockCooldown[player] or 0
	end)
end

function FoodService:Start()
	local folder = Instance.new("Folder")
	folder.Name = "WildFood"
	folder.Parent = World.Folder
	self._wildFolder = folder

	task.spawn(function()
		while true do
			task.wait(GameConfig.WildFood.Interval)
			if #folder:GetChildren() < GameConfig.WildFood.Max then
				self:SpawnWild()
			end
		end
	end)

	Net.Get("BuyFood").OnServerEvent:Connect(function(player, foodId, amount)
		self:Buy(player, foodId, amount)
	end)
	Net.Get("SelectFood").OnServerEvent:Connect(function(player, foodId)
		if type(foodId) == "string" and Foods[foodId] and foodId ~= "Order" then
			player:SetAttribute("SelectedFood", foodId)
			Data:Changed(player)
		end
	end)
	Net.Get("LockStorage").OnServerEvent:Connect(function(player)
		self:Lock(player)
	end)
end

function FoodService:OnPlayerReady(player: Player)
	local plot = World:GetPlot(player)
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
-- Storage
--------------------------------------------------------------------------

function FoodService:SpaceLeft(player: Player): number
	local data = Data:Get(player)
	if not data then
		return 0
	end
	return CreatureMath.StorageCap(data.Rebirths) - CreatureMath.CountFood(data.Food)
end

-- Adds food to the player's storage (up to the cap). Returns amount added.
function FoodService:Give(player: Player, foodId: string, amount: number): number
	local data = Data:Get(player)
	if not data or not Foods[foodId] then
		return 0
	end
	local given = math.min(amount, self:SpaceLeft(player))
	if given <= 0 then
		if Net.Throttle(player, "StorageFull", 3) then
			Net.Notify(player, "📦 Your food storage is full! Feed your " .. GameConfig.CreatureNamePlural .. ".", Color3.fromRGB(255, 170, 60))
		end
		return 0
	end
	data.Food[foodId] = (data.Food[foodId] or 0) + given
	self:RefreshStorage(player)
	Data:Changed(player)
	return given
end

function FoodService:RefreshStorage(player: Player)
	local plot = World:GetPlot(player)
	local data = Data:Get(player)
	if not plot or not data then
		return
	end
	plot.FoodLabel.Text = string.format("🍖 %d / %d", CreatureMath.CountFood(data.Food), CreatureMath.StorageCap(data.Rebirths))
end

--------------------------------------------------------------------------
-- Lock
--------------------------------------------------------------------------

function FoodService:_setLock(plot, duration: number)
	local lockedUntil = now() + duration
	plot.Model:SetAttribute("LockedUntil", lockedUntil)
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
	local plot = World:GetPlot(player)
	if not plot or not Net.Throttle(player, "Lock", 1) then
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
	Net.Notify(player, "🔒 Storage locked for " .. GameConfig.Steal.LockDuration .. "s!", Color3.fromRGB(90, 170, 255))
	Data:Changed(player)
end

--------------------------------------------------------------------------
-- Shop
--------------------------------------------------------------------------

function FoodService:Buy(player: Player, foodId: any, amount: any)
	if type(foodId) ~= "string" or not Net.Throttle(player, "BuyFood", 0.2) then
		return
	end
	local def = Foods[foodId]
	local data = Data:Get(player)
	if not def or not def.Price or not data then
		return
	end
	amount = math.clamp(math.floor(tonumber(amount) or 1), 1, 10)
	amount = math.min(amount, self:SpaceLeft(player))
	if amount <= 0 then
		Net.Notify(player, "📦 Your food storage is full!", Color3.fromRGB(255, 170, 60))
		return
	end
	local cost = def.Price * amount
	if data.Cash < cost then
		Net.Notify(player, "Not enough cash!", Color3.fromRGB(255, 90, 90))
		return
	end
	data.Cash -= cost
	self:Give(player, foodId, amount)
	Net.Notify(player, string.format("Bought %dx %s", amount, def.Name), def.Color)
end

--------------------------------------------------------------------------
-- Wild food
--------------------------------------------------------------------------

local function foodEntries(weightKey: string)
	local entries = {}
	for _, id in Foods.Order do
		table.insert(entries, { Id = id, Weight = Foods[id][weightKey] or 0 })
	end
	return entries
end

function FoodService:_makeFoodPart(foodId: string, position: Vector3): Part
	local def = Foods[foodId]
	local rarity = Rarities[def.Rarity]
	local p = Instance.new("Part")
	p.Name = foodId
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * (rarity.Order >= Rarities.Legendary.Order and 3 or 2)
	p.Color = def.Color
	p.Material = if rarity.Order >= Rarities.Epic.Order then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.Position = position
	p:SetAttribute("FoodId", foodId)
	if rarity.Order >= Rarities.Rare.Order then
		Auras.Apply(p, { Color = def.Color, Light = rarity.Order >= Rarities.Epic.Order, Particles = "Sparkles" })
	end
	if rarity.Order >= Rarities.Legendary.Order then
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromScale(8, 1.5)
		gui.StudsOffset = Vector3.new(0, 3, 0)
		gui.LightInfluence = 0
		gui.MaxDistance = 200
		gui.Parent = p
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
	return p
end

function FoodService:_hookPickup(p: Part, foodId: string)
	local taken = false
	p.Touched:Connect(function(hit)
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
		if not data then
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
				Position = p.Position,
				Color = def.Color,
				Text = string.format("+%d %s%s", given, def.Name, if given > 1 then " (x2!)" else ""),
			})
			p:Destroy()
		end
	end)
end

function FoodService:SpawnWild(foodId: string?)
	local id = foodId
	if not id then
		local pick = WeightedRandom.Pick(foodEntries("WildWeight"), function(e)
			return e.Weight
		end)
		id = pick and pick.Id
	end
	if not id then
		return
	end
	local position = World:RandomArenaPoint() + Vector3.new(0, 1.5, 0)
	local p = self:_makeFoodPart(id, position)
	p.Parent = self._wildFolder
	self:_hookPickup(p, id)
	local def = Foods[id]
	if def.Announce then
		Net.NotifyAll("⭐ A " .. def.Name .. " appeared in the middle! Go get it!", def.Color)
	end
end

-- Meteor Feast: food falls from the sky with impact effects.
function FoodService:MeteorShower(count: number)
	local entries = foodEntries("WildWeight")
	-- Meteors favour rarer food: flatten the weights.
	for _, e in entries do
		e.Weight = math.sqrt(e.Weight)
	end
	for i = 1, count do
		task.delay(i * 0.15, function()
			local pick = WeightedRandom.Pick(entries, function(e)
				return e.Weight
			end)
			if not pick then
				return
			end
			local target = World:RandomArenaPoint() + Vector3.new(0, 1.5, 0)
			local p = self:_makeFoodPart(pick.Id, target + Vector3.new(math.random(-40, 40), 150, math.random(-40, 40)))
			p.Parent = self._wildFolder
			local fire = Instance.new("Fire")
			fire.Size = 6
			fire.Heat = 15
			fire.Parent = p
			Fx:PlayNear(target, 400, "MeteorWarning", { Position = target })
			local fall = TweenService:Create(p, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = target })
			fall:Play()
			fall.Completed:Connect(function()
				fire:Destroy()
				Fx:PlayNear(target, 400, "MeteorImpact", { Position = target, Color = Foods[pick.Id].Color })
				self:_hookPickup(p, pick.Id)
			end)
		end)
	end
end

return FoodService
