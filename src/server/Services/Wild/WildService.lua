--[[
	WildService: wild titans living on the island (Phase 1: Living island).

	- Up to Wild.MaxWild titans. New ones spawn near players (in the wild
	  areas), far-away ones despawn after a while. Pack titans spawn in
	  groups of 3-5 that move together.
	- Each titan runs shared/Game/WildBrain.lua: idle / graze / wander,
	  passive ones flee when hit, aggressive ones chase and attack players.
	- Knock-out taming: WildService:Hit() adds damage + torpor. At full
	  torpor the titan sleeps (TameService handles feeding it).
	- Movement is logical on the server (wild.Pos); clients animate the
	  model from MoveFrom/MoveTo/MoveStart/MoveDuration attributes
	  (client WildController). The server model is snapped now and then.

	API
	  WildService:Spawn(id?, mutation?, near?: Vector3, size?) -> Wild?
	  WildService:Hit(wild, attacker: Player?, damage, torpor, fromPosition?)
	  WildService:FindRay(origin, direction, range) -> Wild?
	  WildService:FindNear(position, look?, range, minDot?) -> Wild?
	  WildService:Remove(wild, effect?)
	  WildService:Rush(duration)
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local GameConfig = require(Shared.Config.GameConfig)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Battle = require(Shared.Game.Battle)
local CreatureMath = require(Shared.Game.CreatureMath)
local Rules = require(Shared.Game.Rules)
local Tags = require(Shared.Game.Tags)
local Taming = require(Shared.Game.Taming)
local WildBrain = require(Shared.Game.WildBrain)
local RarityTag = require(Shared.Fx.RarityTag)
local Log = require(Shared.Lib.Log)
local WeightedRandom = require(Shared.Lib.WeightedRandom)
local Net = require(Shared.Net)

local ServerModules = ServerScriptService:WaitForChild("Server").Modules
local CreatureBuilder = require(ServerModules.CreatureBuilder)

local log = Log.new("WildService")

local WILD = GameConfig.Wild
local TICK = 0.25
local FOOTPRINT = { Biped = 4.5, Quad = 5, Blob = 5.5, Winged = 8 }

export type Wild = {
	Id: string,
	Mutation: string?,
	Size: number,
	Level: number,
	Model: Model,
	Temper: WildBrain.Temper,
	Home: Vector3,
	Pos: Vector3,
	Look: Vector3,
	Height: number,
	Radius: number,
	Reach: number,
	Speed: number,
	State: WildBrain.State,
	StateSince: number,
	StateDuration: number,
	WanderTo: Vector3?,
	Hp: number,
	MaxHp: number,
	Attack: number,
	Torpor: number,
	MaxTorpor: number,
	Asleep: boolean,
	SleepUntil: number,
	HitsAsleep: number,
	Progress: Taming.Progress,
	LastHitAt: number?,
	LastAttacker: Player?,
	LastAttackAt: number,
	Leader: any?, -- pack leader (Wild), nil for leaders/solo
	PackOffset: Vector3,
	LonelySince: number?,
	ExpiresAt: number,
	LastSnap: number,
	Bars: { [string]: any },
	Removed: boolean,
	Guard: boolean, -- nest guardian: always aggressive, never despawns on its own
}

local WildService = {
	Priority = 40,
	Wilds = {} :: { Wild },
	Luck = 1, -- raised during the Wild Rush event
	Hooks = {} :: { [string]: { (...any) -> () } }, -- "Asleep", "Woke", "AttackedPlayer", "Died"
	_folder = nil :: Folder?,
}

local Data, Map, Fx, Food

function WildService:Init(registry)
	Data = registry.DataService
	Map = registry.MapService
	Fx = registry.FxService
	Food = registry.FoodService
end

function WildService:On(event: string, fn: (...any) -> ())
	self.Hooks[event] = self.Hooks[event] or {}
	table.insert(self.Hooks[event], fn)
end

function WildService:_emit(event: string, ...)
	for _, fn in self.Hooks[event] or {} do
		task.spawn(fn, ...)
	end
end

function WildService:Start()
	local folder = Instance.new("Folder")
	folder.Name = "Wild"
	folder.Parent = Map.Map or Workspace
	self._folder = folder

	task.spawn(function()
		while true do
			task.wait(WILD.RespawnDelay * (0.7 + math.random() * 0.6))
			local ok, err = pcall(function()
				self:_spawnTick()
			end)
			if not ok then
				log:Error("spawn tick failed:", err)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(TICK)
			local ok, err = pcall(function()
				self:_tick()
			end)
			if not ok then
				log:Error("tick failed:", err)
			end
		end
	end)
end

--------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		return root :: BasePart
	end
	return nil
end

-- Nearest living player (and distance) to a position.
local function nearestPlayer(position: Vector3): (Player?, number)
	local best, bestDistance = nil, math.huge
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and not player:GetAttribute("InBattle") then
			local d = (flat(root.Position) - flat(position)).Magnitude
			if d < bestDistance then
				best, bestDistance = player, d
			end
		end
	end
	return best, bestDistance
end

-- A spot in the wild areas (the food fields ring, outside bases/plaza).
function WildService:_isWildArea(position: Vector3): boolean
	local r = flat(position).Magnitude
	return r >= GameConfig.Map.FieldInner - 5 and r <= GameConfig.Map.FieldOuter + 10
end

function WildService:_randomSpot(near: Vector3?): Vector3?
	for _ = 1, 12 do
		local candidate
		if near then
			local a = math.random() * math.pi * 2
			local d = WILD.SpawnNear.Min + math.random() * (WILD.SpawnNear.Max - WILD.SpawnNear.Min)
			candidate = near + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		else
			local spawns = Map.WildSpawns
			if #spawns == 0 then
				return nil
			end
			candidate = spawns[math.random(1, #spawns)].Position
		end
		if self:_isWildArea(candidate) then
			local ground = Map:GroundAt(candidate)
			if ground then
				return ground
			end
		end
	end
	return nil
end

--------------------------------------------------------------------------
-- Bars over the titan (name, HP, torpor, taming)
--------------------------------------------------------------------------

local function bar(parent: Instance, y: number, color: Color3, height: number): (Frame, Frame)
	local back = Instance.new("Frame")
	back.Size = UDim2.new(1, 0, height, 0)
	back.Position = UDim2.fromScale(0, y)
	back.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	back.BorderSizePixel = 0
	back.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = back
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = back
	corner:Clone().Parent = fill
	return back, fill
end

local function text(parent: Instance, value: string, color: Color3, y: number, h: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, h)
	label.Position = UDim2.fromScale(0, y)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = value
	label.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = label
	return label
end

function WildService:_buildBars(wild: Wild)
	local def = Creatures[wild.Id]
	local rarity = Rarities[def.Rarity]
	local gui = Instance.new("BillboardGui")
	gui.Name = "WildTag"
	gui.Size = UDim2.fromOffset(230, 104)
	gui.StudsOffsetWorldSpace = Vector3.new(0, wild.Height + 2, 0)
	gui.MaxDistance = if rarity.Order >= 4 then 450 else 160
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Parent = wild.Model.PrimaryPart
	RarityTag.Add(text(gui, "", Color3.new(1, 1, 1), 0, 0.18), def.Rarity)
	local creature = { Id = wild.Id, Level = wild.Level, Xp = 0, Mutation = wild.Mutation, Size = wild.Size }
	local tier = CreatureMath.SizeTier(wild.Size)
	text(
		gui,
		CreatureMath.DisplayName(creature) .. "  Lv." .. wild.Level,
		if wild.Mutation then Mutations[wild.Mutation].Color else rarity.Color,
		0.18,
		0.26
	)
	local info = text(
		gui,
		string.format(
			"%s %s • %s",
			tier.Id,
			CreatureMath.SizeLabel(wild.Size),
			if wild.Temper == "Aggressive" then "😠 Aggressive" else "🌿 Passive"
		),
		Color3.fromRGB(230, 230, 240),
		0.44,
		0.17
	)
	local _, hpFill = bar(gui, 0.64, Color3.fromRGB(90, 220, 110), 0.1)
	local _, torporFill = bar(gui, 0.77, Color3.fromRGB(170, 110, 255), 0.08)
	torporFill.Size = UDim2.fromScale(0, 1)
	local tameBack, tameFill = bar(gui, 0.88, Color3.fromRGB(255, 200, 60), 0.12)
	tameFill.Size = UDim2.fromScale(0, 1)
	tameBack.Visible = false
	local tameText = text(tameBack, "", Color3.new(1, 1, 1), 0, 1)
	tameText.ZIndex = 3
	local zzz = text(gui, "💤 Zzz", Color3.fromRGB(200, 220, 255), -0.3, 0.28)
	zzz.Visible = false
	wild.Bars = {
		Gui = gui,
		Hp = hpFill,
		Torpor = torporFill,
		TameBack = tameBack,
		Tame = tameFill,
		TameText = tameText,
		Zzz = zzz,
		Info = info,
	}
end

function WildService:RefreshBars(wild: Wild)
	local bars = wild.Bars
	if not bars.Gui then
		return
	end
	bars.Hp.Size = UDim2.fromScale(math.clamp(wild.Hp / wild.MaxHp, 0, 1), 1)
	bars.Torpor.Size = UDim2.fromScale(math.clamp(wild.Torpor / wild.MaxTorpor, 0, 1), 1)
	bars.Zzz.Visible = wild.Asleep
	bars.TameBack.Visible = wild.Asleep
	if wild.Asleep then
		local needed = Taming.FoodNeeded({ Id = wild.Id, Size = wild.Size })
		local leader, points = Taming.Leader(wild.Progress)
		bars.Tame.Size = UDim2.fromScale(math.clamp(points / needed, 0, 1), 1)
		local who = leader and Players:GetPlayerByUserId(leader)
		local left = math.max(0, math.ceil(wild.SleepUntil - Workspace:GetServerTimeNow()))
		bars.TameText.Text = string.format(
			"Taming %d%%%s • %ds",
			math.floor(points / needed * 100),
			if who then " (" .. who.DisplayName .. ")" else "",
			left
		)
	end
end

--------------------------------------------------------------------------
-- Spawning / removing
--------------------------------------------------------------------------

function WildService:_pickSpecies(): string?
	local entry = WeightedRandom.Pick(Rules.WildPool(self.Luck), function(e)
		return e.Weight
	end)
	return entry and entry.Creature
end

function WildService:Spawn(forcedId: string?, forcedMutation: string?, near: Vector3?, forcedSize: number?): Wild?
	local creatureId = forcedId or self:_pickSpecies()
	if not creatureId or not Creatures[creatureId] then
		return nil
	end
	local home = if near then (self:_randomSpot(near) or Map:GroundAt(near)) else self:_randomSpot(nil)
	if not home then
		return nil
	end
	local def = Creatures[creatureId]
	local leader = self:_spawnOne(creatureId, forcedMutation, home, forcedSize, nil, Vector3.zero)
	if not leader then
		return nil
	end
	if def.Pack and not forcedId then
		local extra = math.random(WILD.PackSize[1], WILD.PackSize[2]) - 1
		for i = 1, extra do
			if #self.Wilds >= WILD.MaxWild then
				break
			end
			local angle = i / extra * math.pi * 2
			local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (leader.Radius * 2.2 + 4)
			self:_spawnOne(creatureId, nil, home + offset, nil, leader, offset)
		end
	end
	local rarity = Rarities[def.Rarity]
	local color = if leader.Mutation then Mutations[leader.Mutation].Color else rarity.Color
	Fx:PlayAll(
		"WildSpawn",
		{ Position = home, Color = color, RarityOrder = rarity.Order + (if leader.Mutation then 2 else 0) }
	)
	if rarity.Announce or leader.Mutation or leader.Size >= 1000 then
		Net.NotifyAll(
			string.format(
				"🌟 A wild %s %s appeared! Go find it!",
				string.upper(rarity.Id),
				CreatureMath.DisplayName({
					Id = creatureId,
					Level = 1,
					Xp = 0,
					Mutation = leader.Mutation,
					Size = leader.Size,
				})
			),
			color
		)
	end
	return leader
end

function WildService:_spawnOne(
	creatureId: string,
	mutation: string?,
	position: Vector3,
	forcedSize: number?,
	leader: Wild?,
	offset: Vector3
): Wild?
	local def = Creatures[creatureId]
	if not mutation and math.random() < WILD.MutationChance then
		local pick = WeightedRandom.Pick(Mutations.HatchPool, function(e)
			return e.Weight
		end)
		mutation = pick and pick.Id
	end
	local size = CreatureMath.ClampSize(forcedSize or WildBrain.RollSize(math.random(), math.random()))
	local level = math.random(1, 5)
	local creature = { Id = creatureId, Level = level, Xp = 0, Mutation = mutation, Size = size }
	local ground = Map:GroundAt(position) or position
	local model = CreatureBuilder.Build(creature)
	model.Name = "Wild_" .. creatureId
	local scale = CreatureMath.VisualScale(creature)
	if math.abs(scale - 1) > 1e-3 then
		model:ScaleTo(scale)
	end
	model:SetAttribute("Wild", true)
	model:SetAttribute("State", "Idle")
	local look = Vector3.new(math.cos(math.random() * 6.28), 0, math.sin(math.random() * 6.28)).Unit
	model:PivotTo(CFrame.lookAt(ground, ground + look))
	model.Parent = self._folder
	CollectionService:AddTag(model, Tags.WildTitan)
	CollectionService:AddTag(model, Tags.Mover)

	local stats = Battle.Stats(creature)
	local now = Workspace:GetServerTimeNow()
	local wild: Wild = {
		Id = creatureId,
		Mutation = mutation,
		Size = size,
		Level = level,
		Model = model,
		Temper = def.Temper or "Passive",
		Home = ground,
		Pos = ground,
		Look = look,
		Height = model:GetExtentsSize().Y,
		Radius = (FOOTPRINT[def.Style] or 5) * scale * 0.5,
		Reach = WILD.AttackRange + (FOOTPRINT[def.Style] or 5) * scale * 0.5,
		Speed = stats.Speed,
		State = "Idle",
		StateSince = now,
		StateDuration = WildBrain.DurationFor("Idle", math.random()),
		WanderTo = nil,
		Hp = stats.MaxHP,
		MaxHp = stats.MaxHP,
		Attack = stats.Attack,
		Torpor = 0,
		MaxTorpor = Taming.MaxTorpor(creature),
		Asleep = false,
		SleepUntil = 0,
		HitsAsleep = 0,
		Progress = Taming.NewProgress(),
		LastHitAt = nil,
		LastAttacker = nil,
		LastAttackAt = 0,
		Leader = leader,
		PackOffset = offset,
		LonelySince = nil,
		ExpiresAt = now + WILD.Lifetime.Min + math.random() * (WILD.Lifetime.Max - WILD.Lifetime.Min),
		LastSnap = now,
		Bars = {},
		Removed = false,
		Guard = false,
	}
	self:_buildBars(wild)
	self:RefreshBars(wild)
	table.insert(self.Wilds, wild)
	model:SetAttribute("Temper", wild.Temper)
	log:Debug("spawned", creatureId, "size", size, if leader then "(pack)" else "")
	return wild
end

-- A nest guardian: always aggressive, stays near `at` and never despawns
-- by itself (NestService removes it).
function WildService:SpawnGuardian(creatureId: string, at: Vector3, size: number?): Wild?
	if not Creatures[creatureId] then
		return nil
	end
	local wild = self:_spawnOne(creatureId, nil, at, size, nil, Vector3.zero)
	if wild then
		wild.Temper = "Aggressive"
		wild.Guard = true
		wild.Model:SetAttribute("Temper", "Aggressive")
		wild.Model:SetAttribute("Guardian", true)
	end
	return wild
end

function WildService:Remove(wild: Wild, effect: string?)
	if wild.Removed then
		return
	end
	wild.Removed = true
	local index = table.find(self.Wilds, wild)
	if index then
		table.remove(self.Wilds, index)
	end
	for _, other in self.Wilds do
		if other.Leader == wild then
			other.Leader = nil -- the pack scatters
		end
	end
	if effect then
		Fx:PlayAll(effect, { Position = wild.Pos + Vector3.new(0, 2, 0) })
	end
	wild.Model:Destroy()
end

function WildService:_spawnTick()
	if #self.Wilds >= WILD.MaxWild then
		return
	end
	local players = Players:GetPlayers()
	local near = nil
	if #players > 0 then
		local root = rootOf(players[math.random(1, #players)])
		near = root and root.Position
	end
	self:Spawn(nil, nil, near)
end

-- Wild Rush event: rare titans are much more common, and a crowd appears.
function WildService:Rush(duration: number)
	self.Luck = WILD.EventLuck
	for _ = 1, 8 do
		if #self.Wilds >= WILD.MaxWild + 6 then
			break
		end
		local players = Players:GetPlayers()
		local root = if #players > 0 then rootOf(players[math.random(1, #players)]) else nil
		self:Spawn(nil, nil, root and root.Position)
		task.wait(0.4)
	end
	task.wait(duration)
	self.Luck = 1
end

--------------------------------------------------------------------------
-- Hitting / sleeping
--------------------------------------------------------------------------

function WildService:Hit(wild: Wild, attacker: Player?, damage: number, torpor: number)
	if wild.Removed then
		return
	end
	local now = Workspace:GetServerTimeNow()
	wild.LastHitAt = now
	wild.LastAttacker = attacker
	wild.Hp -= damage
	if wild.Asleep then
		wild.HitsAsleep += 1
	else
		local slept
		wild.Torpor, slept = Taming.AddTorpor(wild.Torpor, torpor, wild.MaxTorpor)
		if slept then
			self:_fallAsleep(wild, attacker)
		end
	end
	-- The rest of the pack reacts too
	for _, other in self.Wilds do
		if
			other ~= wild
			and (other.Leader == wild or other == wild.Leader or (wild.Leader and other.Leader == wild.Leader))
		then
			other.LastHitAt = now
			other.LastAttacker = attacker
		end
	end
	Fx:PlayAll("Hit", {
		Position = wild.Pos + Vector3.new(0, wild.Height * 0.5, 0),
		Amount = math.floor(damage),
		Model = wild.Model,
	})
	if wild.Hp <= 0 then
		self:_die(wild, attacker)
		return
	end
	self:RefreshBars(wild)
end

function WildService:_fallAsleep(wild: Wild, by: Player?)
	local now = Workspace:GetServerTimeNow()
	wild.Asleep = true
	wild.SleepUntil = now + GameConfig.Tame.SleepTime
	wild.HitsAsleep = 0
	wild.Progress = Taming.NewProgress()
	wild.State = "Asleep"
	wild.StateSince = now
	wild.Model:SetAttribute("State", "Asleep")
	wild.Model:SetAttribute("Asleep", true)
	self:_stop(wild)
	Fx:PlayAll("KnockOut", {
		Position = wild.Pos + Vector3.new(0, wild.Height, 0),
		Color = Rarities[Creatures[wild.Id].Rarity].Color,
		Owner = by and by.UserId,
	})
	if by then
		Net.Notify(by, "💤 Knocked out! Feed it (hold E) to tame it before it wakes up.")
	end
	log:Info(Creatures[wild.Id].Name, "knocked out by", by and by.Name or "?")
	self:RefreshBars(wild)
	self:_emit("Asleep", wild, by)
end

function WildService:_wake(wild: Wild)
	wild.Asleep = false
	wild.Torpor = 0
	wild.Progress = Taming.NewProgress()
	wild.Model:SetAttribute("Asleep", false)
	wild.State = "Idle"
	wild.StateSince = Workspace:GetServerTimeNow()
	wild.Model:SetAttribute("State", "Idle")
	Fx:PlayAll("Poof", { Position = wild.Pos + Vector3.new(0, 2, 0) })
	self:RefreshBars(wild)
	self:_emit("Woke", wild)
end

function WildService:_die(wild: Wild, killer: Player?)
	log:Info(Creatures[wild.Id].Name, "defeated by", killer and killer.Name or "?")
	-- Defeating a wild titan drops meat for the hunter
	if killer then
		local data = Data:Get(killer)
		if data then
			local order = Rarities[Creatures[wild.Id].Rarity].Order
			local amount = order + math.floor(math.log10(wild.Size) * 2)
			local space = Rules.StorageSpace(data)
			local got = math.max(0, math.min(amount, space))
			if got > 0 then
				data.Food.Meat = (data.Food.Meat or 0) + got
				Food:RefreshStorage(killer)
				Data:Changed(killer)
				Net.Notify(killer, "🍖 +" .. got .. " Meat from the wild " .. Creatures[wild.Id].Name)
			end
		end
	end
	self:_emit("Died", wild, killer)
	self:Remove(wild, "Poof")
end

--------------------------------------------------------------------------
-- Finding titans (for tools, riding attacks, followers)
--------------------------------------------------------------------------

function WildService:Center(wild: Wild): Vector3
	return wild.Pos + Vector3.new(0, wild.Height * 0.5, 0)
end

-- First wild titan hit by a ray (sphere test around each titan's body).
function WildService:FindRay(origin: Vector3, direction: Vector3, range: number): Wild?
	local dir = direction.Unit
	local best, bestT = nil, range
	for _, wild in self.Wilds do
		local center = self:Center(wild)
		local radius = math.max(wild.Radius, wild.Height * 0.45)
		local toCenter = center - origin
		local t = toCenter:Dot(dir)
		if t > 0 and t < bestT + radius then
			local closest = origin + dir * t
			if (closest - center).Magnitude <= radius then
				best, bestT = wild, t
			end
		end
	end
	return best
end

-- Nearest wild titan within range (optionally in front: dot >= minDot).
function WildService:FindNear(position: Vector3, look: Vector3?, range: number, minDot: number?): Wild?
	local best, bestD = nil, math.huge
	for _, wild in self.Wilds do
		local offset = flat(wild.Pos - position)
		local d = offset.Magnitude - wild.Radius
		if d <= range and d < bestD then
			local inFront = true
			if look and offset.Magnitude > 0.5 then
				inFront = offset.Unit:Dot(flat(look).Unit) >= (minDot or 0.2)
			end
			if inFront then
				best, bestD = wild, d
			end
		end
	end
	return best
end

--------------------------------------------------------------------------
-- Brain + movement
--------------------------------------------------------------------------

function WildService:_stop(wild: Wild)
	local cf = CFrame.lookAt(wild.Pos, wild.Pos + wild.Look)
	wild.Model:SetAttribute("MoveFrom", cf)
	wild.Model:SetAttribute("MoveTo", cf)
	wild.Model:SetAttribute("MoveStart", Workspace:GetServerTimeNow())
	wild.Model:SetAttribute("MoveDuration", 0.01)
	wild.Model:PivotTo(cf)
end

function WildService:_moveToward(wild: Wild, target: Vector3, speed: number, now: number)
	local offset = flat(target - wild.Pos)
	local distance = offset.Magnitude
	if distance < 0.5 then
		return
	end
	local step = math.min(distance, speed * TICK)
	local nextPos = wild.Pos + offset.Unit * step
	local ground = Map:GroundAt(nextPos)
	if not ground then
		return -- water or off the map: stop here
	end
	local from = CFrame.lookAt(wild.Pos, wild.Pos + wild.Look)
	wild.Look = offset.Unit
	wild.Pos = ground
	local to = CFrame.lookAt(ground, ground + wild.Look)
	local model = wild.Model
	model:SetAttribute("MoveFrom", from)
	model:SetAttribute("MoveTo", to)
	model:SetAttribute("MoveStart", now)
	model:SetAttribute("MoveDuration", TICK)
	-- Keep the real model roughly in place (for new clients); clients animate it smoothly.
	if now - wild.LastSnap > 2 then
		wild.LastSnap = now
		model:PivotTo(to)
	end
end

function WildService:_setState(wild: Wild, state: WildBrain.State, now: number)
	if wild.State == state then
		return
	end
	wild.State = state
	wild.StateSince = now
	wild.StateDuration = WildBrain.DurationFor(state, math.random())
	wild.WanderTo = nil
	wild.Model:SetAttribute("State", state)
	if state == "Idle" or state == "Graze" then
		self:_stop(wild)
	end
end

function WildService:_attackPlayer(wild: Wild, player: Player, now: number)
	if now - wild.LastAttackAt < WILD.AttackCooldown then
		return
	end
	wild.LastAttackAt = now
	local root = rootOf(player)
	if not root then
		return
	end
	local toPlayer = flat(root.Position - wild.Pos)
	if toPlayer.Magnitude > 0.1 then
		wild.Look = toPlayer.Unit
		self:_stop(wild)
	end
	local damage = math.max(4, wild.Attack * WILD.AttackDamage * 5)
	Fx:PlayAll("TitanAttack", {
		Kind = "Attack",
		Position = self:Center(wild),
		Look = wild.Look,
		Range = wild.Reach,
		Color = Color3.fromRGB(255, 90, 90),
	})
	-- RideService / FollowerService listen: riders' titans take the hit instead.
	local handled = false
	for _, fn in self.Hooks.AttackedPlayer or {} do
		if fn(wild, player, damage) then
			handled = true
		end
	end
	if not handled then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:TakeDamage(damage)
			Fx:PlayAll("Hit", {
				Position = root.Position,
				Amount = math.floor(damage),
				Target = player.UserId,
				Velocity = toPlayer.Unit * 40 + Vector3.new(0, 25, 0),
			})
		end
	end
end

function WildService:_tick()
	local now = Workspace:GetServerTimeNow()
	for _, wild in table.clone(self.Wilds) do
		if wild.Removed then
			continue
		end
		-- Sleep / torpor
		if wild.Asleep then
			if now >= wild.SleepUntil then
				self:_wake(wild)
			else
				self:RefreshBars(wild)
				continue
			end
		elseif wild.Torpor > 0 then
			wild.Torpor = Taming.Drain(wild.Torpor, wild.MaxTorpor, TICK)
			self:RefreshBars(wild)
		end

		-- Despawn when alone for a while or too old (not nest guardians)
		local target, targetDistance = nearestPlayer(wild.Pos)
		if wild.Guard then
			wild.LonelySince = nil
		elseif targetDistance > WILD.DespawnDistance then
			wild.LonelySince = wild.LonelySince or now
			if now - wild.LonelySince > WILD.DespawnAfter then
				self:Remove(wild, nil)
				continue
			end
		else
			wild.LonelySince = nil
		end
		if not wild.Guard and now > wild.ExpiresAt and targetDistance > 120 then
			self:Remove(wild, "Poof")
			continue
		end

		-- Brain
		local chaseTarget = target
		if wild.LastAttacker and wild.LastAttacker.Parent and rootOf(wild.LastAttacker) then
			local attackerRoot = rootOf(wild.LastAttacker) :: BasePart
			if wild.LastHitAt and now - wild.LastHitAt < WILD.FleeTime * 2 then
				chaseTarget = wild.LastAttacker
				targetDistance = (flat(attackerRoot.Position) - flat(wild.Pos)).Magnitude
			end
		end
		local state = WildBrain.Decide({
			State = wild.State,
			StateSince = wild.StateSince,
			StateDuration = wild.StateDuration,
			Now = now,
			Temper = wild.Temper,
			Asleep = wild.Asleep,
			LastHitAt = wild.LastHitAt,
			TargetDistance = targetDistance,
			HomeDistance = (flat(wild.Pos) - flat(wild.Home)).Magnitude,
			Reach = wild.Reach,
			Roll = math.random(),
		})
		self:_setState(wild, state, now)

		-- Act
		if state == "Wander" then
			if wild.Leader and not wild.Leader.Removed then
				-- pack members stay around their leader
				self:_moveToward(wild, wild.Leader.Pos + wild.PackOffset, WILD.MoveSpeed * 1.2, now)
			else
				if not wild.WanderTo then
					local a = math.random() * math.pi * 2
					local d = WILD.WanderRadius * math.sqrt(math.random())
					wild.WanderTo = wild.Home + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
				end
				self:_moveToward(wild, wild.WanderTo :: Vector3, WILD.MoveSpeed, now)
			end
		elseif state == "Return" then
			self:_moveToward(wild, wild.Home, WILD.MoveSpeed * 1.5, now)
		elseif state == "Flee" then
			local from = wild.LastAttacker and rootOf(wild.LastAttacker)
			local away = if from then flat(wild.Pos - from.Position) else wild.Look
			if away.Magnitude < 0.1 then
				away = Vector3.new(1, 0, 0)
			end
			self:_moveToward(wild, wild.Pos + away.Unit * 20, WILD.RunSpeed, now)
		elseif state == "Chase" and chaseTarget then
			local root = rootOf(chaseTarget)
			if root then
				self:_moveToward(wild, root.Position, math.max(WILD.RunSpeed, wild.Speed), now)
			end
		elseif state == "Attack" and chaseTarget then
			self:_attackPlayer(wild, chaseTarget, now)
		end
	end
end

return WildService
