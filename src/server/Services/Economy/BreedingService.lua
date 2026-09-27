--[[
	BreedingService: two titans of the same species make an egg.

	- Pick two titans on the 💞 Breed page (Remote "Breed" uidA uidB).
	- Breeding takes Breeding.Time(species) (longer for rarer titans). The
	  parents stay in their pens and keep earning; hearts float over them.
	- When it's done the egg goes to an incubator (IncubatorService:AddEgg)
	  and both parents rest for Time * CooldownMult before breeding again.
	- The egg's size tier is between the parents' tiers (rarely one higher),
	  it can inherit a mutation and gets a stat Bonus (shared/Game/Breeding).
	- One breeding at a time per player (data.Breeding). Parents can't be
	  sold while breeding. Timers use os.time(), so it finishes offline too.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Breeding = require(Shared.Game.Breeding)
local CreatureMath = require(Shared.Game.CreatureMath)
local Format = require(Shared.Lib.Format)
local Log = require(Shared.Lib.Log)
local WeightedRandom = require(Shared.Lib.WeightedRandom)
local Net = require(Shared.Net)

local GameEvents = require(ServerScriptService:WaitForChild("Server").Modules.GameEvents)

local log = Log.new("BreedingService")

local PINK = Color3.fromRGB(255, 130, 180)
local RED = Color3.fromRGB(255, 90, 90)
local HEART_EVERY = 4

local BreedingService = {
	Priority = 32, -- after IncubatorService (30)
}

local Data, Creature, Incubator, Fx

function BreedingService:Init(registry)
	Data = registry.DataService
	Creature = registry.CreatureService
	Incubator = registry.IncubatorService
	Fx = registry.FxService
end

function BreedingService:Start()
	Net.On("Breed", function(player, a, b)
		self:Begin(player, a, b)
	end)
	Net.On("BreedCancel", function(player)
		self:Cancel(player, true)
	end)
	task.spawn(function()
		local beat = 0
		while true do
			task.wait(1)
			beat += 1
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(self._tick, self, player, beat % HEART_EVERY == 0)
				if not ok then
					log:Warn("tick failed for", player.Name, err)
				end
			end
		end
	end)
end

function BreedingService:IsBreeding(player: Player, uid: string): boolean
	local data = Data:Get(player)
	return data ~= nil and data.Breeding.ReadyAt ~= nil and (data.Breeding.A == uid or data.Breeding.B == uid)
end

local function parent(creature): Breeding.Parent?
	if not creature then
		return nil
	end
	return {
		Id = creature.Id,
		Mutation = creature.Mutation,
		Size = creature.Size,
		Bonus = creature.Bonus,
		BreedReadyAt = creature.BreedReadyAt,
	}
end

function BreedingService:Begin(player: Player, a: string, b: string)
	local data = Data:Get(player)
	if not data then
		return
	end
	if data.Breeding.ReadyAt then
		Net.Notify(player, "💞 Already breeding! Wait for the egg or cancel.", RED)
		return
	end
	local now = os.time()
	if a == b then
		Net.Notify(player, "💞 Pick two different titans", RED)
		return
	end
	local ca, cb = data.Creatures[a], data.Creatures[b]
	local ok, reason = Breeding.CanBreed(parent(ca), parent(cb), now)
	if not ok then
		Net.Notify(player, "💞 " .. (reason or "Can't breed"), RED)
		return
	end
	local time = Breeding.Time(ca.Id)
	data.Breeding = { A = a, B = b, StartedAt = now, ReadyAt = now + time }
	Net.Notify(
		player,
		string.format("💞 Your %s are breeding! Egg in %s", Creatures[ca.Id].Name, Format.Time(time)),
		PINK
	)
	self:_hearts(player)
	Data:Changed(player)
end

function BreedingService:Cancel(player: Player, byPlayer: boolean?)
	local data = Data:Get(player)
	if not data or not data.Breeding.ReadyAt then
		return
	end
	data.Breeding = {}
	if byPlayer then
		Net.Notify(player, "💞 Breeding cancelled.", RED)
	end
	Data:Changed(player)
end

function BreedingService:_hearts(player: Player)
	local data = Data:Get(player)
	if not data then
		return
	end
	for _, uid in { data.Breeding.A, data.Breeding.B } do
		local model = uid and Creature:GetModel(player, uid)
		if model and not Creature:IsOut(player, uid) then
			Fx:PlayAll("Love", { Position = Creature:TopOf(model) + Vector3.new(0, 2, 0) })
		end
	end
end

local function rollPoolMutation(): string?
	local pick = WeightedRandom.Pick(Mutations.HatchPool, function(e)
		return e.Weight
	end)
	return pick and pick.Id
end

function BreedingService:_tick(player: Player, hearts: boolean)
	local data = Data:Get(player)
	local pen = data and data.Breeding
	if not data or not pen or not pen.ReadyAt then
		return
	end
	local ca = pen.A and data.Creatures[pen.A]
	local cb = pen.B and data.Creatures[pen.B]
	if not ca or not cb then
		self:Cancel(player)
		Net.Notify(player, "💞 Breeding stopped: a parent is gone.", RED)
		return
	end
	if os.time() < pen.ReadyAt then
		if hearts then
			self:_hearts(player)
		end
		return
	end
	self:_finish(player)
end

function BreedingService:_finish(player: Player)
	local data = Data:Get(player)
	if not data then
		return
	end
	local pen = data.Breeding
	local ca, cb = data.Creatures[pen.A], data.Creatures[pen.B]
	local egg = Breeding.MakeEgg(parent(ca) :: any, parent(cb) :: any, {
		Mutation = math.random(),
		PickParent = math.random(),
		Bonus = math.random(),
		Size = math.random(),
		Jump = math.random(),
		PoolMutation = rollPoolMutation(),
	})
	local uid = Incubator:AddEgg(player, {
		Species = egg.Species,
		Mutation = egg.Mutation,
		Size = egg.Size,
		Bonus = egg.Bonus,
		Source = "Breed",
	})
	if not uid then
		return -- egg storage full: try again next tick
	end
	local now = os.time()
	local rest = Breeding.Cooldown(ca.Id)
	ca.BreedReadyAt = now + rest
	cb.BreedReadyAt = now + rest
	data.Breeding = {}
	data.Stats.Bred += 1

	local def = Creatures[egg.Species]
	local color = if egg.Mutation then Mutations[egg.Mutation].Color else Rarities[def.Rarity].Color
	local model = Incubator:GetEggModel(player, uid) or Creature:GetModel(player, pen.A)
	if model then
		Fx:PlayAll("EggLaid", {
			Position = model:GetPivot().Position,
			Color = color,
			Scale = 1 + (Breeding.TierIndex(egg.Size) - 1) * 0.3,
		})
	end
	local sizeText = if Breeding.TierIndex(egg.Size) > 1 then CreatureMath.SizeLabel(egg.Size) .. " " else ""
	local mutationText = if egg.Mutation then Mutations[egg.Mutation].Name .. " " else ""
	Net.Notify(
		player,
		string.format(
			"🥚 New %s%s%s egg! (+%d%% stats)",
			sizeText,
			mutationText,
			def.Name,
			math.floor(egg.Bonus * 100)
		),
		color
	)
	GameEvents.Fire(player, "Bred", { Titan = egg.Species, Mutation = egg.Mutation, Size = egg.Size })
	log:Info(player.Name, "bred", egg.Species, egg.Size, egg.Mutation)
	Data:Changed(player)
end

return BreedingService
