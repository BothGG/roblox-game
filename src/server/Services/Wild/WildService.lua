--[[
	WildService: wild titans roaming the fields. FIND them, then TAME them.

	- Up to Wild.MaxWild wild titans at once, spawned at WildSpawn markers.
	  Species odds: Rules.WildPool (rarity WildWeight, luck during Wild Rush).
	- Rare ones (Rarity.Announce) or mutated ones: server-wide message + a
	  huge light beam (Fx "WildSpawn") so everyone races to find them.
	- Hold the "Tame" prompt (Rarity.TameTime). Taming feeds it
	  Rarity.TameFood food (favorites first, which raise the chance).
	  Success -> it joins your base. Fail -> the food is eaten and it runs away.
	- Movement: the server picks a target and writes MoveFrom / MoveTo /
	  MoveStart / MoveDuration attributes; clients animate smoothly
	  (client WildController). The server snaps the model at the end.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Foods = require(Shared.Config.Foods)
local GameConfig = require(Shared.Config.GameConfig)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local CreatureMath = require(Shared.Game.CreatureMath)
local Rules = require(Shared.Game.Rules)
local Tags = require(Shared.Game.Tags)
local RarityTag = require(Shared.Fx.RarityTag)
local Log = require(Shared.Lib.Log)
local WeightedRandom = require(Shared.Lib.WeightedRandom)
local Net = require(Shared.Net)

local ServerModules = ServerScriptService:WaitForChild("Server").Modules
local CreatureBuilder = require(ServerModules.CreatureBuilder)
local GameEvents = require(ServerModules.GameEvents)

local log = Log.new("WildService")

local RED = Color3.fromRGB(255, 90, 90)
local WILD = GameConfig.Wild

type Wild = {
	Id: string,
	Mutation: string?,
	Model: Model,
	Home: Vector3,
	From: CFrame,
	To: CFrame,
	MoveStart: number,
	MoveDuration: number,
	ExpiresAt: number,
	Taken: boolean,
}

local WildService = {
	Priority = 40,
	Wilds = {} :: { [Model]: Wild },
	Count = 0,
	Luck = 1, -- raised during the Wild Rush event
	_folder = nil :: Folder?,
}

local Data, Map, Creature, Fx

function WildService:Init(registry)
	Data = registry.DataService
	Map = registry.MapService
	Creature = registry.CreatureService
	Fx = registry.FxService
end

function WildService:Start()
	local folder = Instance.new("Folder")
	folder.Name = "Wild"
	folder.Parent = Map.Map or Workspace
	self._folder = folder

	if #Map.WildSpawns == 0 then
		log:Warn("no WildSpawn (or FoodSpawn) markers: wild titans are off")
		return
	end
	task.spawn(function()
		while true do
			if self.Count < WILD.MaxWild then
				self:Spawn()
			end
			task.wait(WILD.RespawnDelay * (0.7 + math.random() * 0.6))
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			self:_tick()
		end
	end)
end

--------------------------------------------------------------------------
-- Spawning
--------------------------------------------------------------------------

local function groundAt(position: Vector3): Vector3?
	return Map:GroundAt(position)
end

local function displayName(creatureId: string, mutation: string?): string
	return CreatureMath.DisplayName({ Id = creatureId, Level = 1, Xp = 0, Mutation = mutation })
end

local function nameTag(model: Model, creatureId: string, mutation: string?)
	local def = Creatures[creatureId]
	local rarity = Rarities[def.Rarity]
	local gui = Instance.new("BillboardGui")
	gui.Name = "WildTag"
	gui.Size = UDim2.fromOffset(220, 74)
	gui.StudsOffsetWorldSpace = Vector3.new(0, model:GetExtentsSize().Y + 1.5, 0)
	gui.MaxDistance = if rarity.Order >= 4 then 400 else 140
	gui.LightInfluence = 0
	gui.Parent = model.PrimaryPart
	local function line(text: string, color: Color3, y: number, h: number): TextLabel
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, h)
		label.Position = UDim2.fromScale(0, y)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = color
		label.Text = text
		label.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Parent = label
		return label
	end
	RarityTag.Add(line("", Color3.new(1, 1, 1), 0, 0.28), def.Rarity)
	line(displayName(creatureId, mutation), if mutation then Mutations[mutation].Color else rarity.Color, 0.28, 0.42)
	line(
		string.format("🌿 WILD • needs %d food", Rules.TameFood(creatureId)),
		Color3.fromRGB(220, 255, 220),
		0.7,
		0.3
	)
end

function WildService:Spawn(forcedId: string?, forcedMutation: string?)
	local spawns = Map.WildSpawns
	local creatureId = forcedId
	if not creatureId then
		local entry = WeightedRandom.Pick(Rules.WildPool(self.Luck), function(e)
			return e.Weight
		end)
		creatureId = entry and entry.Creature
	end
	if not creatureId or not Creatures[creatureId] then
		return
	end
	local mutation = forcedMutation
	if not mutation and math.random() < WILD.MutationChance then
		local pick = WeightedRandom.Pick(Mutations.HatchPool, function(e)
			return e.Weight
		end)
		mutation = pick and pick.Id
	end

	local home = spawns[math.random(1, #spawns)].Position
	local model = CreatureBuilder.Build({ Id = creatureId, Level = 1, Xp = 0, Mutation = mutation })
	model.Name = "Wild_" .. creatureId
	model:SetAttribute("Wild", true)
	model.Parent = self._folder
	local start = CFrame.new(home) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
	model:PivotTo(start)
	nameTag(model, creatureId, mutation)
	CollectionService:AddTag(model, Tags.WildTitan)

	local def = Creatures[creatureId]
	local rarity = Rarities[def.Rarity]
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TamePrompt"
	prompt.ActionText = "Tame"
	prompt.ObjectText = string.format("%s (%s) • 🍖 x%d", def.Name, rarity.Id, Rules.TameFood(creatureId))
	prompt.HoldDuration = Rules.TameTime(creatureId)
	prompt.MaxActivationDistance = WILD.TameDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart

	local now = Workspace:GetServerTimeNow()
	local wild: Wild = {
		Id = creatureId,
		Mutation = mutation,
		Model = model,
		Home = home,
		From = start,
		To = start,
		MoveStart = now,
		MoveDuration = 0,
		ExpiresAt = now + WILD.Lifetime.Min + math.random() * (WILD.Lifetime.Max - WILD.Lifetime.Min),
		Taken = false,
	}
	self.Wilds[model] = wild
	self.Count += 1

	prompt.PromptButtonHoldBegan:Connect(function(player)
		if Net.Throttle(player, "TameStart", 1) then
			local position = self:CurrentCFrame(wild).Position
			Fx:PlayAll("TameStart", {
				Position = position + Vector3.new(0, 2, 0),
				Ground = position,
				Color = rarity.Color,
				Duration = prompt.HoldDuration,
			})
		end
	end)
	prompt.Triggered:Connect(function(player)
		self:TryTame(player, wild)
	end)

	local color = if mutation then Mutations[mutation].Color else rarity.Color
	Fx:PlayAll(
		"WildSpawn",
		{ Position = home, Color = color, RarityOrder = rarity.Order + (if mutation then 2 else 0) }
	)
	if rarity.Announce or mutation then
		Net.NotifyAll(
			string.format(
				"🌟 A wild %s %s appeared in the fields! Go find it!",
				string.upper(rarity.Id),
				displayName(creatureId, mutation)
			),
			color
		)
	end
end

function WildService:_remove(wild: Wild)
	if not self.Wilds[wild.Model] then
		return
	end
	self.Wilds[wild.Model] = nil
	self.Count -= 1
	wild.Model:Destroy()
end

-- Wild Rush event: rare titans are much more common, and a bunch appear now.
function WildService:Rush(duration: number)
	self.Luck = WILD.EventLuck
	for _ = 1, math.max(0, WILD.MaxWild + 4 - self.Count) do
		self:Spawn()
		task.wait(0.4)
	end
	task.wait(duration)
	self.Luck = 1
end

--------------------------------------------------------------------------
-- Movement
--------------------------------------------------------------------------

-- Where the titan is right now (lerped along its current move).
function WildService:CurrentCFrame(wild: Wild): CFrame
	if wild.MoveDuration <= 0 then
		return wild.To
	end
	local alpha = math.clamp((Workspace:GetServerTimeNow() - wild.MoveStart) / wild.MoveDuration, 0, 1)
	return wild.From:Lerp(wild.To, alpha)
end

function WildService:_tick()
	local now = Workspace:GetServerTimeNow()
	for _, wild in self.Wilds do
		if wild.Taken then
			continue
		end
		if now >= wild.ExpiresAt then
			Fx:PlayAll("Poof", { Position = self:CurrentCFrame(wild).Position })
			self:_remove(wild)
			continue
		end
		local arrived = now >= wild.MoveStart + wild.MoveDuration
		if arrived and wild.MoveDuration > 0 then
			wild.Model:PivotTo(wild.To) -- snap the real model to where clients animated it
			wild.MoveDuration = 0
			wild.MoveStart = now + 1 + math.random() * 4 -- idle a bit
		elseif arrived and now >= wild.MoveStart then
			self:_startMove(wild, now)
		end
	end
end

function WildService:_startMove(wild: Wild, now: number)
	local angle = math.random() * math.pi * 2
	local distance = WILD.WanderRadius * math.sqrt(math.random())
	local ground = groundAt(wild.Home + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance))
	if not ground or Map:IsInArena(ground, 6) then
		wild.MoveStart = now + 2
		return
	end
	local from = wild.Model:GetPivot()
	local flat = (ground - from.Position) * Vector3.new(1, 0, 1)
	local to = if flat.Magnitude < 1 then CFrame.new(ground) * from.Rotation else CFrame.lookAt(ground, ground + flat)
	local duration = math.max(0.5, flat.Magnitude / WILD.MoveSpeed)
	wild.From = from
	wild.To = to
	wild.MoveStart = now
	wild.MoveDuration = duration
	local model = wild.Model
	model:SetAttribute("MoveFrom", from)
	model:SetAttribute("MoveTo", to)
	model:SetAttribute("MoveStart", now)
	model:SetAttribute("MoveDuration", duration)
end

--------------------------------------------------------------------------
-- Taming
--------------------------------------------------------------------------

function WildService:TryTame(player: Player, wild: Wild)
	if wild.Taken or not self.Wilds[wild.Model] then
		return
	end
	local data = Data:Get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not data or not root then
		return
	end
	local position = self:CurrentCFrame(wild).Position
	if (root.Position - position).Magnitude > WILD.TameDistance + wild.Model:GetExtentsSize().X + 4 then
		return
	end
	if not Rules.HasFreeSlot(data) then
		Net.Notify(player, "🏠 Your base is full! Sell a titan or Rebirth for more pens.", RED)
		return
	end
	local plan, favorite = Rules.TameFoodPlan(data.Food, wild.Id)
	if not plan then
		Net.Notify(
			player,
			string.format("🍖 You need %d food to tame this titan. Grab some in the fields!", Rules.TameFood(wild.Id)),
			RED
		)
		return
	end

	wild.Taken = true
	for foodId, count in plan do
		data.Food[foodId] -= count
		if data.Food[foodId] <= 0 then
			data.Food[foodId] = nil
		end
	end
	data.Stats.FoodEaten += Rules.TameFood(wild.Id)
	Data:Changed(player)

	local def = Creatures[wild.Id]
	local rarity = Rarities[def.Rarity]
	local color = if wild.Mutation then Mutations[wild.Mutation].Color else rarity.Color
	local firstFood = next(plan)
	Fx:PlayAll("Feed", {
		Position = position + Vector3.new(0, 2, 0),
		Color = if firstFood then Foods[firstFood].Color else color,
		Favorite = favorite,
		Model = wild.Model,
	})

	if math.random() > Rules.TameChance(wild.Id, favorite) then
		Fx:PlayAll("TameFail", { Position = position, Target = player.UserId })
		Net.Notify(player, "💨 The " .. def.Name .. " ate your food and ran away!", RED)
		self:_remove(wild)
		return
	end

	Fx:PlayAll("TameSuccess", {
		Position = position + Vector3.new(0, 3, 0),
		Ground = position,
		Color = color,
		Owner = player.UserId,
		RarityOrder = rarity.Order,
	})
	self:_remove(wild)
	local uid = Creature:Add(player, wild.Id, wild.Mutation)
	if not uid then
		return
	end
	data.Stats.Tamed += 1
	GameEvents.Fire(player, "Tamed", { Titan = wild.Id, Mutation = wild.Mutation, Rarity = def.Rarity })
	Net.Fire(player, "Hatched", { CreatureId = wild.Id, Mutation = wild.Mutation, Source = "Tame" })
	if rarity.Announce or wild.Mutation then
		Net.NotifyAll(
			string.format(
				"🎯 %s tamed a %s %s!",
				player.DisplayName,
				string.upper(rarity.Id),
				displayName(wild.Id, wild.Mutation)
			),
			color
		)
	end
	Data:Changed(player)
end

return WildService
