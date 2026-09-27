--[[
	TameService: knock-out taming (Phase 1), ARK style.

	When WildService puts a titan to sleep, a "Feed to tame" prompt appears
	on it. Every feed uses one food from your storage (favorites count
	double, see shared/Game/Taming.lua) and fills YOUR taming bar. Whoever
	fills their bar first gets the titan - so other players can steal a
	tame by feeding faster. Hitting it while it sleeps lowers effectiveness
	(fewer bonus levels). It wakes up after GameConfig.Tame.SleepTime.

	A tamed titan joins your base and follows you if you have a follower
	slot free (FollowerService).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Foods = require(Shared.Config.Foods)
local GameConfig = require(Shared.Config.GameConfig)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local CreatureMath = require(Shared.Game.CreatureMath)
local Rules = require(Shared.Game.Rules)
local Taming = require(Shared.Game.Taming)
local Log = require(Shared.Lib.Log)
local Net = require(Shared.Net)

local GameEvents = require(ServerScriptService:WaitForChild("Server").Modules.GameEvents)

local log = Log.new("TameService")

local RED = Color3.fromRGB(255, 90, 90)
local TAME = GameConfig.Tame

local TameService = {
	Priority = 46,
}

local Data, Wild, Creature, Food, Fx, Follower

function TameService:Init(registry)
	Data = registry.DataService
	Wild = registry.WildService
	Creature = registry.CreatureService
	Food = registry.FoodService
	Fx = registry.FxService
	Follower = registry.FollowerService
end

function TameService:Start()
	Wild:On("Asleep", function(wild)
		self:_addPrompt(wild)
	end)
	Wild:On("Woke", function(wild)
		local prompt = wild.Model.PrimaryPart and wild.Model.PrimaryPart:FindFirstChild("FeedPrompt")
		if prompt then
			prompt:Destroy()
		end
	end)
end

function TameService:_addPrompt(wild)
	local root = wild.Model.PrimaryPart
	if not root or root:FindFirstChild("FeedPrompt") then
		return
	end
	local def = Creatures[wild.Id]
	local loves = {}
	for _, foodId in def.Diet or {} do
		table.insert(loves, Foods[foodId].Name)
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FeedPrompt"
	prompt.ActionText = "Feed to tame"
	prompt.ObjectText = def.Name .. (if #loves > 0 then " ❤️ " .. table.concat(loves, ", ") else "")
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = TAME.FeedDistance + wild.Radius
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function(player)
		self:Feed(player, wild)
	end)
end

-- Picks the food to feed: favorites first, then the selected food, then any.
local function pickFood(data, creatureId: string, selected: string?): string?
	for _, foodId in Creatures[creatureId].Diet or {} do
		if (data.Food[foodId] or 0) > 0 then
			return foodId
		end
	end
	return Rules.PickFood(data.Food, selected)
end

function TameService:Feed(player: Player, wild)
	if wild.Removed or not wild.Asleep then
		return
	end
	local data = Data:Get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not data or not root then
		return
	end
	local flat = Vector3.new(root.Position.X - wild.Pos.X, 0, root.Position.Z - wild.Pos.Z)
	if flat.Magnitude > TAME.FeedDistance + wild.Radius + 6 then
		return
	end
	if not Rules.HasFreeSlot(data) then
		Net.Notify(player, "🏠 Your base is full! Upgrade pens or sell a titan first.", RED)
		return
	end
	local selected = player:GetAttribute("SelectedFood")
	local foodId = pickFood(data, wild.Id, if type(selected) == "string" then selected else nil)
	if not foodId then
		Net.Notify(player, "🍖 You have no food! Grab some in the fields.", RED)
		return
	end
	data.Food[foodId] -= 1
	if data.Food[foodId] <= 0 then
		data.Food[foodId] = nil
	end
	Food:RefreshStorage(player)
	Data:Changed(player)

	local points = Taming.FoodPoints(wild.Id, foodId)
	local needed = Taming.FoodNeeded({ Id = wild.Id, Size = wild.Size })
	local done = Taming.Feed(wild.Progress, player.UserId, points, needed)
	local mine = wild.Progress.Points[player.UserId] or 0
	Fx:PlayAll("TameFeed", {
		Position = Wild:Center(wild) + Vector3.new(0, wild.Height * 0.3, 0),
		Favorite = points > 1,
		Owner = player.UserId,
		Text = string.format(
			"%s %d%%",
			if points > 1 then "❤️❤️" else "❤️",
			math.floor(math.min(1, mine / needed) * 100)
		),
	})
	Wild:RefreshBars(wild)
	if done then
		self:_complete(player, wild)
	end
end

function TameService:_complete(player: Player, wild)
	local data = Data:Get(player)
	if not data or wild.Removed then
		return
	end
	local def = Creatures[wild.Id]
	local rarity = Rarities[def.Rarity]
	local effectiveness = Taming.Effectiveness(wild.HitsAsleep)
	local level = Taming.TamedLevel(effectiveness)
	local position = wild.Pos
	local color = if wild.Mutation then Mutations[wild.Mutation].Color else rarity.Color
	local uid = Creature:Add(player, wild.Id, wild.Mutation, wild.Size)
	if not uid then
		Net.Notify(player, "🏠 Your base is full!", RED)
		return
	end
	Wild:Remove(wild, nil)
	Creature:SetLevel(player, uid, level)
	data.Stats.Tamed += 1
	Fx:PlayAll("TameSuccess", {
		Position = position + Vector3.new(0, wild.Height * 0.6, 0),
		Ground = position,
		Color = color,
		Owner = player.UserId,
		RarityOrder = rarity.Order,
	})
	local creature = data.Creatures[uid]
	GameEvents.Fire(player, "Tamed", { Titan = wild.Id, Mutation = wild.Mutation, Rarity = def.Rarity })
	Net.Fire(player, "Hatched", { CreatureId = wild.Id, Mutation = wild.Mutation, Source = "Tame" })
	Net.Notify(
		player,
		string.format(
			"🎉 Tamed %s! Lv.%d (%d%% effective)",
			CreatureMath.DisplayName(creature),
			level,
			math.floor(effectiveness * 100)
		),
		color
	)
	if rarity.Announce or wild.Mutation or (creature.Size or 1) >= 1000 then
		Net.NotifyAll(
			string.format(
				"🎯 %s tamed a %s %s!",
				player.DisplayName,
				string.upper(rarity.Id),
				CreatureMath.DisplayName(creature)
			),
			color
		)
	end
	log:Info(player.Name, "tamed", wild.Id, "size", creature.Size, "level", level)
	-- Follows you if a follower slot is free, otherwise it goes to your base.
	if Follower then
		Follower:TryFollow(player, uid)
	end
	Data:Changed(player)
end

return TameService
