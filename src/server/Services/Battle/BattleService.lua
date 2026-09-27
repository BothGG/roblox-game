--[[
	BattleService: titan fights in the arena.

	Modes
	  Duel     - 1v1 between two players (challenge -> accept)
	  Clash    - free-for-all event (join window, then everyone fights)
	  Practice - you vs a bot titan (works on an empty server)

	Piloting: the player's active titan is welded to their character, the
	character is hidden, and walk speed comes from the titan's Speed stat.
	The client only sends "Attack" / "Special"; every hit is checked here
	with the pure rules in shared/Game/Battle.lua.

	  BattleService:Challenge(from, to)
	  BattleService:IsFighting(player) / :IsBusy()
	  BattleService:RunClash()           -- called by EventService
	  BattleService:StartPractice(player)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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
local Log = require(Shared.Lib.Log)
local Net = require(Shared.Net)
local Types = require(Shared.Types)

local ServerModules = ServerScriptService:WaitForChild("Server").Modules
local CreatureBuilder = require(ServerModules.CreatureBuilder)
local GameEvents = require(ServerModules.GameEvents)

local log = Log.new("BattleService")

local BATTLE = GameConfig.Battle
local RED = Color3.fromRGB(255, 90, 90)
local GOLD = Color3.fromRGB(255, 200, 60)

type Mode = "Duel" | "Clash" | "Practice"

type Fighter = {
	Id: number, -- UserId, or negative for bots
	Name: string,
	Player: Player?,
	IsBot: boolean,
	Creature: Types.CreatureData,
	Stats: Battle.Stats,
	Special: Battle.Special,
	HP: number,
	Alive: boolean,
	Model: Model,
	HpFill: Frame?,
	HpText: TextLabel?,
	LastAttack: number,
	LastSpecial: number,
	-- humans
	Saved: { [Instance]: number }?,
	SavedMove: { WalkSpeed: number, JumpPower: number, JumpHeight: number }?,
	Connections: { RBXScriptConnection },
	-- bots
	Position: Vector3?,
	Look: Vector3?,
}

type Match = {
	Mode: Mode,
	Phase: "Countdown" | "Fight" | "Results",
	Fighters: { Fighter },
	EndsAt: number,
	Winner: Fighter?,
}

local BattleService = {
	Priority = 38,
	Match = nil :: Match?,
	ClashJoin = nil :: { Players: { Player }, EndsAt: number }?,
	Requests = {} :: { [Player]: { From: Player, ExpiresAt: number } },
	_folder = nil :: Folder?,
	_nextBotId = -1,
}

local Data, Map, Base, Fx, Food, Steal, Reward, Ride, Follower

function BattleService:Init(registry)
	Data = registry.DataService
	Map = registry.MapService
	Base = registry.BaseService
	Fx = registry.FxService
	Food = registry.FoodService
	Steal = registry.StealService
	Reward = registry.RewardService
	Ride = registry.RideService
	Follower = registry.FollowerService
end

function BattleService:Start()
	local folder = Instance.new("Folder")
	folder.Name = "BattleTitans"
	folder.Parent = Workspace
	self._folder = folder

	Net.On("Challenge", function(player, targetUserId)
		local target = Players:GetPlayerByUserId(targetUserId)
		if target then
			self:Challenge(player, target)
		end
	end)
	Net.On("DuelRespond", function(player, fromUserId, accept)
		self:Respond(player, fromUserId, accept)
	end)
	Net.On("JoinClash", function(player)
		self:JoinClash(player)
	end)
	Net.On("Practice", function(player)
		self:StartPractice(player)
	end)
	Net.On("Spectate", function(player)
		if not self:IsFighting(player) and #Map.Stands > 0 and player.Character then
			player.Character:PivotTo(Map.Stands[math.random(1, #Map.Stands)])
		end
	end)
	Net.On("BattleAction", function(player, action)
		if action == "Attack" or action == "Special" then
			self:Action(player, action)
		end
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.1 then
			local step = accumulator
			accumulator = 0
			local ok, err = pcall(self._tick, self, step)
			if not ok then
				log:Error("tick failed:", err)
			end
		end
	end)
end

function BattleService:OnPlayerRemoving(player: Player)
	self.Requests[player] = nil
	for target, request in self.Requests do
		if request.From == player then
			self.Requests[target] = nil
		end
	end
	if self.ClashJoin then
		local index = table.find(self.ClashJoin.Players, player)
		if index then
			table.remove(self.ClashJoin.Players, index)
		end
	end
	local fighter = self:_fighterOf(player)
	if fighter and fighter.Alive then
		self:_knockOut(fighter, nil)
	end
end

--------------------------------------------------------------------------
-- Queries
--------------------------------------------------------------------------

function BattleService:IsBusy(): boolean
	return self.Match ~= nil or self.ClashJoin ~= nil
end

function BattleService:_fighterOf(player: Player): Fighter?
	local match = self.Match
	if not match then
		return nil
	end
	for _, fighter in match.Fighters do
		if fighter.Player == player then
			return fighter
		end
	end
	return nil
end

function BattleService:IsFighting(player: Player): boolean
	return self:_fighterOf(player) ~= nil
end

-- "is carrying food" -> "You can't fight: you are carrying food"
local function youCant(action: string, reason: string): string
	local text = string.gsub(reason, "^is ", "are ")
	text = string.gsub(text, "^has ", "have ")
	return "You can't " .. action .. ": you " .. text
end

-- Why a player can't fight right now (nil = they can).
function BattleService:_cannotFight(player: Player): string?
	local data = Data:Get(player)
	if not data then
		return "still loading"
	end
	if not Rules.ActiveTitan(data) then
		return "has no " .. GameConfig.CreatureName
	end
	if player:GetAttribute("Carrying") then
		return "is carrying stolen food"
	end
	if self:IsFighting(player) then
		return "is already fighting"
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return "isn't spawned"
	end
	return nil
end

--------------------------------------------------------------------------
-- Duels
--------------------------------------------------------------------------

function BattleService:Challenge(from: Player, to: Player)
	if from == to then
		return
	end
	if self:IsBusy() then
		Net.Notify(from, "⚔️ The arena is busy. Try again when the fight ends!", RED)
		return
	end
	local reason = self:_cannotFight(from)
	if reason then
		Net.Notify(from, youCant("fight", reason), RED)
		return
	end
	reason = self:_cannotFight(to)
	if reason then
		Net.Notify(from, to.DisplayName .. " " .. reason .. ".", RED)
		return
	end
	if not Net.Throttle(from, "Challenge", BATTLE.ChallengeCooldown) then
		Net.Notify(from, "Wait a moment before challenging again.", RED)
		return
	end

	local fromData = Data:Get(from)
	local _, titan = Rules.ActiveTitan(fromData)
	self.Requests[to] = { From = from, ExpiresAt = os.clock() + BATTLE.RequestTimeout }
	Net.Fire(to, "DuelRequest", {
		FromUserId = from.UserId,
		FromName = from.DisplayName,
		Titan = CreatureMath.DisplayName(titan),
		Level = titan.Level,
		Trophies = fromData.Trophies,
		Timeout = BATTLE.RequestTimeout,
	})
	Net.Notify(from, "⚔️ Challenge sent to " .. to.DisplayName .. "!", GOLD)
	task.delay(BATTLE.RequestTimeout, function()
		local request = self.Requests[to]
		if request and request.From == from then
			self.Requests[to] = nil
			if from.Parent then
				Net.Notify(from, to.DisplayName .. " didn't answer.", RED)
			end
		end
	end)
end

function BattleService:Respond(player: Player, fromUserId: number, accept: boolean)
	local request = self.Requests[player]
	if not request or request.From.UserId ~= fromUserId then
		return
	end
	self.Requests[player] = nil
	local from = request.From
	if not from.Parent then
		return
	end
	if not accept then
		Net.Notify(from, "😤 " .. player.DisplayName .. " declined your challenge.", RED)
		return
	end
	if self:IsBusy() then
		Net.Notify(player, "The arena got busy. Try again soon!", RED)
		Net.Notify(from, "The arena got busy. Try again soon!", RED)
		return
	end
	for _, p in { from, player } do
		local reason = self:_cannotFight(p)
		if reason then
			Net.Notify(from, p.DisplayName .. " " .. reason .. ".", RED)
			Net.Notify(player, p.DisplayName .. " " .. reason .. ".", RED)
			return
		end
	end
	Net.Announce("⚔️ DUEL!", from.DisplayName .. " vs " .. player.DisplayName .. " in the arena!", GOLD)
	self:_startMatch("Duel", { from, player }, 0)
end

function BattleService:StartPractice(player: Player)
	if self:IsBusy() then
		Net.Notify(player, "⚔️ The arena is busy. Try again when the fight ends!", RED)
		return
	end
	local reason = self:_cannotFight(player)
	if reason then
		Net.Notify(player, youCant("fight", reason), RED)
		return
	end
	self:_startMatch("Practice", { player }, 1)
end

--------------------------------------------------------------------------
-- Titan Clash
--------------------------------------------------------------------------

function BattleService:JoinClash(player: Player)
	local join = self.ClashJoin
	if not join then
		return
	end
	if table.find(join.Players, player) then
		return
	end
	local reason = self:_cannotFight(player)
	if reason then
		Net.Notify(player, youCant("join", reason), RED)
		return
	end
	table.insert(join.Players, player)
	Net.Notify(player, "⚔️ You joined the Titan Clash!", GOLD)
	Net.NotifyAll(string.format("⚔️ %s joined the Titan Clash (%d)", player.DisplayName, #join.Players), GOLD)
end

-- Runs a whole clash: join window, fight, results. Yields until done.
function BattleService:RunClash()
	-- Wait for a running duel to finish (up to a minute)
	local waited = 0
	while self.Match and waited < 60 do
		task.wait(1)
		waited += 1
	end
	if self:IsBusy() then
		return
	end
	local endsAt = Workspace:GetServerTimeNow() + BATTLE.ClashJoinTime
	self.ClashJoin = { Players = {}, EndsAt = endsAt }
	Workspace:SetAttribute("EventEndsAt", endsAt)
	Net.Announce("⚔️ TITAN CLASH", "Everyone vs everyone in the arena! Press JOIN to fight!", GOLD)
	Net.FireAll("ClashInvite", { EndsAt = endsAt })
	task.wait(BATTLE.ClashJoinTime)

	local join = self.ClashJoin
	self.ClashJoin = nil
	local fighters = {}
	for _, player in join and join.Players or {} do
		if player.Parent and not self:_cannotFight(player) then
			table.insert(fighters, player)
		end
	end
	if #fighters == 0 then
		Net.Announce("⚔️ Titan Clash cancelled", "Nobody joined this time.", RED)
		return
	end
	-- One player alone fights a wild titan instead
	self:_startMatch("Clash", fighters, if #fighters == 1 then 1 else 0)
	while self.Match do
		task.wait(0.5)
	end
end

--------------------------------------------------------------------------
-- Match setup
--------------------------------------------------------------------------

local function hpBar(model: Model, name: string, color: Color3): (Frame, TextLabel)
	local root = model.PrimaryPart :: BasePart
	local gui = Instance.new("BillboardGui")
	gui.Name = "HpBar"
	gui.Size = UDim2.fromOffset(220, 56)
	gui.StudsOffsetWorldSpace = Vector3.new(0, model:GetExtentsSize().Y + 2, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 400
	gui.Parent = root
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 0.5)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = name
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = label
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 0.4)
	back.Position = UDim2.fromScale(0, 0.55)
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	back.BorderSizePixel = 0
	back.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = back
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 220, 110)
	fill.BorderSizePixel = 0
	fill.Parent = back
	corner:Clone().Parent = fill
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.ZIndex = 2
	text.Parent = back
	stroke:Clone().Parent = text
	return fill, text
end

function BattleService:_buildTitan(creature: Types.CreatureData, stats: Battle.Stats, pivot: CFrame): Model
	local model = CreatureBuilder.Build(creature)
	model.Name = "BattleTitan"
	model.Parent = self._folder
	if stats.Scale ~= 1 then
		model:ScaleTo(stats.Scale)
	end
	model:PivotTo(pivot)
	return model
end

function BattleService:_makeHuman(player: Player, spawnCf: CFrame): Fighter?
	local data = Data:Get(player)
	local uid, creature = Rules.ActiveTitan(data)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (uid and creature and character and root and humanoid) then
		return nil
	end
	Steal:ReturnFood(player, "left")
	-- Off your mount and followers go home before you pilot your fighter.
	Ride:Dismount(player, "battle")
	Follower:Release(player, uid, true)

	local stats = Battle.Stats(creature)
	character:PivotTo(spawnCf)
	local hip = root.Size.Y / 2 + humanoid.HipHeight
	local model = self:_buildTitan(creature, stats, root.CFrame * CFrame.new(0, -hip, 0))
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.Massless = true
		end
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = model.PrimaryPart
	weld.Parent = model.PrimaryPart

	-- Hide the player's own body while they pilot the titan
	local saved = {}
	for _, d in character:GetDescendants() do
		if (d:IsA("BasePart") and d ~= root) or d:IsA("Decal") then
			local visible: any = d
			saved[d] = visible.Transparency
			visible.Transparency = 1
		end
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	local def = Creatures[creature.Id]
	local color = if creature.Mutation then Mutations[creature.Mutation].Color else Rarities[def.Rarity].Color
	local fill, text = hpBar(model, player.DisplayName .. " · " .. CreatureMath.DisplayName(creature), color)

	local fighter: Fighter = {
		Id = player.UserId,
		Name = player.DisplayName,
		Player = player,
		IsBot = false,
		Creature = table.clone(creature),
		Stats = stats,
		Special = Battle.SpecialFor(creature.Id),
		HP = stats.MaxHP,
		Alive = true,
		Model = model,
		HpFill = fill,
		HpText = text,
		LastAttack = 0,
		LastSpecial = 0,
		Saved = saved,
		SavedMove = { WalkSpeed = humanoid.WalkSpeed, JumpPower = humanoid.JumpPower, JumpHeight = humanoid.JumpHeight },
		Connections = {},
	}
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	table.insert(
		fighter.Connections,
		humanoid.Died:Connect(function()
			if fighter.Alive then
				self:_knockOut(fighter, nil)
			end
		end)
	)
	player:SetAttribute("InBattle", true)
	return fighter
end

function BattleService:_makeBot(level: number, spawnCf: CFrame): Fighter
	-- A wild titan from the eggs, around the players' level
	local ids = {}
	for id, def in Creatures do
		if Rarities[def.Rarity].Order <= 3 then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	local creature = { Id = ids[math.random(1, #ids)], Level = math.max(1, level), Xp = 0 }
	local stats = Battle.Stats(creature)
	-- Bots are a bit weaker so practice is winnable
	stats.MaxHP = math.floor(stats.MaxHP * 0.8)
	stats.Attack = math.floor(stats.Attack * 0.7)
	local position = Vector3.new(spawnCf.Position.X, Map.Arena.Center.Y, spawnCf.Position.Z)
	local look = (Map.Arena.Center - position) * Vector3.new(1, 0, 1)
	look = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
	local model = self:_buildTitan(creature, stats, CFrame.lookAt(position, position + look))
	local name = "Wild " .. Creatures[creature.Id].Name
	local fill, text = hpBar(model, name, Color3.fromRGB(255, 140, 90))
	local id = self._nextBotId
	self._nextBotId -= 1
	return {
		Id = id,
		Name = name,
		Player = nil,
		IsBot = true,
		Creature = creature,
		Stats = stats,
		Special = Battle.SpecialFor(creature.Id),
		HP = stats.MaxHP,
		Alive = true,
		Model = model,
		HpFill = fill,
		HpText = text,
		LastAttack = 0,
		LastSpecial = os.clock() + 2,
		Connections = {},
		Position = position,
		Look = look,
	}
end

function BattleService:_startMatch(mode: Mode, players: { Player }, bots: number)
	local match: Match = {
		Mode = mode,
		Phase = "Countdown",
		Fighters = {},
		EndsAt = Workspace:GetServerTimeNow() + BATTLE.Countdown,
		Winner = nil,
	}
	self.Match = match

	local spawns = Map.ArenaSpawns
	local total = #players + bots
	local step = math.max(1, math.floor(#spawns / total))
	local levelSum = 0
	for i, player in players do
		local spawnCf = spawns[((i - 1) * step) % #spawns + 1]
		local fighter = self:_makeHuman(player, spawnCf)
		if fighter then
			table.insert(match.Fighters, fighter)
			levelSum += fighter.Creature.Level
		end
	end
	local humans = #match.Fighters
	for b = 1, bots do
		local spawnCf = spawns[((humans + b - 1) * step) % #spawns + 1]
		local level = if humans > 0 then math.floor(levelSum / humans) else 1
		table.insert(match.Fighters, self:_makeBot(level, spawnCf))
	end
	if humans == 0 or #match.Fighters < 2 then
		log:Warn("not enough fighters, cancelling match")
		self:_cleanup(match)
		return
	end
	for _, fighter in match.Fighters do
		self:_refreshHp(fighter)
	end
	self:_broadcast()

	task.delay(BATTLE.Countdown, function()
		if self.Match ~= match then
			return
		end
		match.Phase = "Fight"
		match.EndsAt = Workspace:GetServerTimeNow() + BATTLE.MaxDuration
		for _, fighter in match.Fighters do
			local humanoid = fighter.Player
				and fighter.Player.Character
				and fighter.Player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid and fighter.Alive then
				humanoid.WalkSpeed = fighter.Stats.Speed
				humanoid.JumpPower = 50
				humanoid.JumpHeight = 7.2
			end
		end
		self:_broadcast()
	end)
end

--------------------------------------------------------------------------
-- Fighting
--------------------------------------------------------------------------

local function flat(v: Vector3): Battle.Point
	return { X = v.X, Z = v.Z }
end

function BattleService:_positionOf(fighter: Fighter): (Vector3?, Vector3?)
	if fighter.IsBot then
		return fighter.Position, fighter.Look
	end
	local character = fighter.Player and fighter.Player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil, nil
	end
	return root.Position, root.CFrame.LookVector
end

function BattleService:_refreshHp(fighter: Fighter)
	if fighter.HpFill and fighter.HpText then
		local ratio = math.clamp(fighter.HP / fighter.Stats.MaxHP, 0, 1)
		fighter.HpFill.Size = UDim2.fromScale(ratio, 1)
		fighter.HpFill.BackgroundColor3 = Color3.fromRGB(255, 80, 80):Lerp(Color3.fromRGB(90, 220, 110), ratio)
		fighter.HpText.Text = string.format("%d / %d", math.max(0, fighter.HP), fighter.Stats.MaxHP)
	end
end

function BattleService:_broadcast()
	local match = self.Match
	if not match then
		Net.FireAll("BattleState", { Phase = "None" })
		return
	end
	local fighters = {}
	for _, f in match.Fighters do
		table.insert(fighters, {
			Id = f.Id,
			Name = f.Name,
			IsBot = f.IsBot,
			TitanId = f.Creature.Id,
			Titan = CreatureMath.DisplayName(f.Creature),
			Level = f.Creature.Level,
			HP = math.max(0, f.HP),
			MaxHP = f.Stats.MaxHP,
			Alive = f.Alive,
			Height = f.Model.Parent and f.Model:GetExtentsSize().Y or 10,
		})
	end
	Net.FireAll("BattleState", {
		Phase = match.Phase,
		Mode = match.Mode,
		EndsAt = match.EndsAt,
		Fighters = fighters,
		Winner = match.Winner and match.Winner.Id,
	})
end

function BattleService:Action(player: Player, action: string)
	local match = self.Match
	local fighter = self:_fighterOf(player)
	if not match or not fighter or match.Phase ~= "Fight" or not fighter.Alive then
		return
	end
	self:_act(fighter, action)
end

function BattleService:_act(fighter: Fighter, action: string)
	local match = self.Match :: Match
	local now = os.clock()
	local special = fighter.Special
	if action == "Attack" then
		if now - fighter.LastAttack < BATTLE.AttackCooldown then
			return
		end
		fighter.LastAttack = now
	else
		if now - fighter.LastSpecial < special.Cooldown then
			return
		end
		fighter.LastSpecial = now
	end
	local position, look = self:_positionOf(fighter)
	if not position or not look then
		return
	end
	local color = if fighter.Creature.Mutation
		then Mutations[fighter.Creature.Mutation].Color
		else Creatures[fighter.Creature.Id].AccentColor
	Fx:PlayAll("TitanAttack", {
		Kind = action,
		Special = if action == "Special" then special.Id else nil,
		Position = position,
		Look = look,
		Range = fighter.Stats.Range * (if action == "Special" then special.RangeMult else 1),
		Color = color,
		Owner = fighter.Id,
	})
	-- Dash / bounce moves the attacker first (on their own client)
	if action == "Special" and fighter.Player then
		if special.Shape == "Dash" then
			Fx:PlayFor(fighter.Player, "Launch", { Velocity = look * 90 + Vector3.new(0, 10, 0) })
		elseif special.Id == "Bounce" then
			Fx:PlayFor(fighter.Player, "Launch", { Velocity = Vector3.new(0, 70, 0) })
		end
	elseif action == "Special" and fighter.IsBot and special.Shape == "Dash" and fighter.Position then
		fighter.Position += look * 20
	end

	local delay = if action == "Special" then special.Delay else 0.12
	task.delay(delay, function()
		if self.Match ~= match or match.Phase ~= "Fight" or not fighter.Alive then
			return
		end
		local from, facing = self:_positionOf(fighter)
		if not from or not facing then
			return
		end
		local mult = if action == "Special" then special.Mult else 1
		for _, target in match.Fighters do
			if target ~= fighter and target.Alive then
				local targetPos = self:_positionOf(target)
				if
					targetPos
					and Battle.Hits(
						action :: any,
						if action == "Special" then special else nil,
						flat(from),
						flat(facing),
						flat(targetPos),
						fighter.Stats.Range,
						target.Stats.Scale
					)
				then
					self:_damage(fighter, target, Battle.Damage(fighter.Stats.Attack, mult, math.random()), from)
				end
			end
		end
	end)
end

function BattleService:_damage(attacker: Fighter, target: Fighter, amount: number, from: Vector3)
	target.HP -= amount
	self:_refreshHp(target)
	local position = self:_positionOf(target) or from
	local away = (position - from) * Vector3.new(1, 0, 1)
	local direction = if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 0, 1)
	local knock = math.clamp(amount / target.Stats.MaxHP * 300, 20, 90)
	Fx:PlayAll("Hit", {
		Position = position + Vector3.new(0, target.Model:GetExtentsSize().Y * 0.5, 0),
		Amount = amount,
		Target = target.Id,
		Attacker = attacker.Id,
		Velocity = direction * knock + Vector3.new(0, knock * 0.4, 0),
	})
	if target.IsBot and target.Position then
		target.Position += direction * math.min(knock / 6, 10)
	end
	if target.HP <= 0 then
		self:_knockOut(target, attacker)
	else
		self:_broadcast()
	end
end

function BattleService:_knockOut(fighter: Fighter, by: Fighter?)
	if not fighter.Alive then
		return
	end
	fighter.Alive = false
	fighter.HP = math.min(fighter.HP, 0)
	self:_refreshHp(fighter)
	local position = self:_positionOf(fighter) or fighter.Model:GetPivot().Position
	Fx:PlayAll("KO", { Position = position, Target = fighter.Id })
	if by then
		Net.NotifyAll(string.format("💥 %s knocked out %s!", by.Name, fighter.Name), GOLD)
	end
	-- Fallen titan: tip it over (bots) / freeze the pilot (humans)
	if fighter.IsBot then
		fighter.Model:PivotTo(fighter.Model:GetPivot() * CFrame.Angles(0, 0, math.rad(80)))
	elseif fighter.Player and fighter.Player.Character then
		local humanoid = fighter.Player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 0
		end
	end
	self:_broadcast()
end

--------------------------------------------------------------------------
-- Tick: arena bounds, bots, timer, end of match
--------------------------------------------------------------------------

function BattleService:_tick(dt: number)
	local match = self.Match
	if not match then
		return
	end
	local center = Map.Arena.Center
	local radius = Map.Arena.Radius

	-- Keep fighters inside, spectators out
	for _, fighter in match.Fighters do
		if fighter.Player and fighter.Alive then
			local position = self:_positionOf(fighter)
			if position and not Map:IsInArena(position, 6) then
				local offset = (position - center) * Vector3.new(1, 0, 1)
				local back = center + offset.Unit * (radius - 10) + Vector3.new(0, 4, 0)
				fighter.Player.Character:PivotTo(CFrame.lookAt(back, center + Vector3.new(0, 4, 0)))
			end
		end
	end
	if #Map.Stands > 0 then
		for _, player in Players:GetPlayers() do
			if not self:IsFighting(player) and player.Character then
				local root = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and Map:IsInArena(root.Position, -4) then
					player.Character:PivotTo(Map.Stands[math.random(1, #Map.Stands)])
				end
			end
		end
	end

	if match.Phase == "Fight" then
		for _, fighter in match.Fighters do
			if fighter.IsBot and fighter.Alive then
				self:_botStep(fighter, dt)
			end
		end
		local alive = 0
		for _, fighter in match.Fighters do
			if fighter.Alive then
				alive += 1
			end
		end
		if alive <= 1 or Workspace:GetServerTimeNow() >= match.EndsAt then
			self:_finish(match)
		end
	end
end

function BattleService:_botStep(bot: Fighter, dt: number)
	local match = self.Match :: Match
	-- Chase the nearest living human
	local target, targetPos, best = nil, nil, math.huge
	for _, fighter in match.Fighters do
		if fighter ~= bot and fighter.Alive and not fighter.IsBot then
			local position = self:_positionOf(fighter)
			if position then
				local d = (position - (bot.Position :: Vector3)).Magnitude
				if d < best then
					target, targetPos, best = fighter, position, d
				end
			end
		end
	end
	if not target or not targetPos then
		return
	end
	local position = bot.Position :: Vector3
	local toTarget = (targetPos - position) * Vector3.new(1, 0, 1)
	if toTarget.Magnitude > 0.1 then
		bot.Look = toTarget.Unit
	end
	local reach = bot.Stats.Range * 0.8 + target.Stats.Scale
	if toTarget.Magnitude > reach then
		position += (bot.Look :: Vector3) * bot.Stats.Speed * 0.8 * dt
	end
	-- Stay inside the arena
	local offset = (position - Map.Arena.Center) * Vector3.new(1, 0, 1)
	if offset.Magnitude > Map.Arena.Radius - 6 then
		position = Map.Arena.Center + offset.Unit * (Map.Arena.Radius - 6)
	end
	local grounded = Vector3.new(position.X, Map.Arena.Center.Y, position.Z)
	bot.Position = grounded
	bot.Model:PivotTo(CFrame.lookAt(grounded, grounded + (bot.Look :: Vector3)))

	local now = os.clock()
	if toTarget.Magnitude <= reach * 1.2 then
		if now - bot.LastSpecial >= bot.Special.Cooldown * 1.5 then
			self:_act(bot, "Special")
		elseif now - bot.LastAttack >= BATTLE.AttackCooldown * 1.8 then
			self:_act(bot, "Attack")
		end
	end
end

--------------------------------------------------------------------------
-- Results
--------------------------------------------------------------------------

function BattleService:_finish(match: Match)
	if match.Phase ~= "Fight" then
		return
	end
	match.Phase = "Results"
	local alive = {}
	for _, f in match.Fighters do
		if f.Alive then
			table.insert(alive, f)
		end
	end
	local winner: Fighter? = nil
	if #alive == 1 then
		winner = alive[1]
	else
		local list = {}
		for _, f in match.Fighters do
			table.insert(list, { UserId = f.Id, HP = math.max(0, f.HP), MaxHP = f.Stats.MaxHP })
		end
		local leader = Battle.Leader(list)
		for _, f in match.Fighters do
			if leader and f.Id == leader.UserId then
				winner = f
			end
		end
	end
	match.Winner = winner
	for _, f in match.Fighters do
		if f.Player and f.Alive then
			local humanoid = f.Player.Character and f.Player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = 0
			end
		end
	end

	if winner then
		Fx:PlayAll(
			"Victory",
			{ Position = self:_positionOf(winner) or winner.Model:GetPivot().Position, Owner = winner.Id }
		)
		Net.Announce(
			"🏆 " .. string.upper(winner.Name) .. " WINS!",
			CreatureMath.DisplayName(winner.Creature) .. " is the champion of the arena!",
			GOLD
		)
	else
		Net.Announce("🤝 DRAW!", "Nobody could finish the fight.", GOLD)
	end
	self:_broadcast()
	self:_giveRewards(match, winner)

	task.delay(BATTLE.ResultsTime, function()
		self:_cleanup(match)
	end)
end

function BattleService:_giveRewards(match: Match, winner: Fighter?)
	for _, f in match.Fighters do
		local player = f.Player
		local data = player and player.Parent and Data:Get(player)
		if player and data then
			data.Stats.BattlesPlayed += 1
			GameEvents.Fire(player, "BattlePlayed", { Mode = match.Mode })
		end
	end
	local winnerPlayer = winner and winner.Player
	local winnerData = winnerPlayer and winnerPlayer.Parent and Data:Get(winnerPlayer)

	if match.Mode == "Duel" then
		local loser = nil
		for _, f in match.Fighters do
			if f ~= winner then
				loser = f
			end
		end
		if winnerPlayer and winnerData then
			winnerData.Stats.BattlesWon += 1
			winnerData.Trophies += BATTLE.WinTrophies
			GameEvents.Fire(winnerPlayer, "BattleWon", { Mode = "Duel" })
			local reward = { Cash = BATTLE.WinCashBonus, CashSeconds = BATTLE.WinCashSeconds, Trophies = 0 }
			Reward:Grant(winnerPlayer, reward, "🏆 Duel won! +" .. BATTLE.WinTrophies .. " trophies", "Duel")
			-- Winner eats: take a share of the loser's food
			local loserPlayer = loser and loser.Player
			local loserData = loserPlayer and loserPlayer.Parent and Data:Get(loserPlayer)
			if loserPlayer and loserData then
				local taken = Battle.FoodShare(loserData.Food, BATTLE.WinFoodShare)
				local total = 0
				for foodId, amount in taken do
					local have = loserData.Food[foodId] or 0
					local move = math.min(have, amount)
					loserData.Food[foodId] = have - move
					total += Food:Give(winnerPlayer, foodId, move)
				end
				loserData.Trophies = Battle.TrophiesAfterLoss(loserData.Trophies)
				Food:RefreshStorage(loserPlayer)
				Data:Changed(loserPlayer)
				if total > 0 then
					Net.Notify(
						winnerPlayer,
						string.format("🍖 You took %d food from %s!", total, loserPlayer.DisplayName),
						GOLD
					)
					Net.Notify(
						loserPlayer,
						string.format("😭 %s took %d of your food!", winnerPlayer.DisplayName, total),
						RED
					)
				end
			end
			Data:Changed(winnerPlayer)
		end
	elseif match.Mode == "Clash" then
		for _, f in match.Fighters do
			if f.Player and f.Player.Parent and f ~= winner then
				Reward:Grant(
					f.Player,
					{ CashSeconds = BATTLE.ClashParticipateCashSeconds },
					"⚔️ Thanks for fighting!",
					"Clash"
				)
			end
		end
		if winnerPlayer and winnerData then
			winnerData.Stats.BattlesWon += 1
			GameEvents.Fire(winnerPlayer, "BattleWon", { Mode = "Clash" })
			Reward:Grant(winnerPlayer, {
				CashSeconds = BATTLE.ClashWinCashSeconds,
				Food = BATTLE.ClashWinFood,
				Trophies = BATTLE.ClashWinTrophies,
			}, "👑 Titan Clash champion!", "Clash")
		end
	elseif match.Mode == "Practice" then
		if winnerPlayer and winnerData then
			winnerData.Stats.BattlesWon += 1
			GameEvents.Fire(winnerPlayer, "BattleWon", { Mode = "Practice" })
			Reward:Grant(winnerPlayer, { CashSeconds = 20, Cash = 100 }, "🥊 Practice won!", "Practice")
		end
	end
end

function BattleService:_cleanup(match: Match)
	for _, fighter in match.Fighters do
		for _, connection in fighter.Connections do
			connection:Disconnect()
		end
		if fighter.Model then
			fighter.Model:Destroy()
		end
		local player = fighter.Player
		if player and player.Parent then
			player:SetAttribute("InBattle", nil)
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			for part, transparency in fighter.Saved or {} do
				if part.Parent then
					(part :: any).Transparency = transparency
				end
			end
			if humanoid then
				local saved = fighter.SavedMove
				humanoid.WalkSpeed = GameConfig.Steal.NormalWalkSpeed
				humanoid.JumpPower = saved and saved.JumpPower or 50
				humanoid.JumpHeight = saved and saved.JumpHeight or 7.2
				humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
			end
			Base:TeleportHome(player)
		end
	end
	if self.Match == match then
		self.Match = nil
	end
	self:_broadcast()
end

return BattleService
