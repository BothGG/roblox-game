--[[
	RideService: ride any of your titans around the whole island (Phase 1).

	Mount: hold R next to a titan in your base, R on a follower, or the
	"Ride" button in the Titans menu. The titan model is welded to your
	character (same piloting trick as battles) and your body is hidden.

	Movement per style (shared/Game/Riding.lua):
	  runners sprint (Shift) with stamina, flyers fly (hold Space in the air),
	  blobs bounce (big jumps). Click = attack, Q = special, X = dismount.
	The client only asks (RideAction); stamina, cooldowns and hits are here.

	Wild titans that attack a rider hit the titan instead; at 0 HP you get
	knocked off and that titan needs a rest before you can ride it again.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Battle = require(Shared.Game.Battle)
local CreatureMath = require(Shared.Game.CreatureMath)
local Riding = require(Shared.Game.Riding)
local Log = require(Shared.Lib.Log)
local Net = require(Shared.Net)
local Types = require(Shared.Types)

local CreatureBuilder = require(ServerScriptService:WaitForChild("Server").Modules.CreatureBuilder)

local log = Log.new("RideService")

local RIDE = GameConfig.Riding
local BATTLE = GameConfig.Battle
local RED = Color3.fromRGB(255, 90, 90)
local TICK = 0.1
local TIRED_TIME = 30

type Ride = {
	Uid: string,
	Creature: Types.CreatureData,
	Stats: Riding.RideStats,
	Battle: Battle.Stats,
	Special: Battle.Special,
	Model: Model,
	Stamina: number,
	Mode: Riding.Mode,
	Hp: number,
	LastAttack: number,
	LastSpecial: number,
	LastCombat: number,
	Saved: { [Instance]: number },
	SavedMove: { WalkSpeed: number, JumpPower: number, UseJumpPower: boolean },
	Connections: { RBXScriptConnection },
}

local RideService = {
	Priority = 48,
	Rides = {} :: { [Player]: Ride },
	Tired = {} :: { [Player]: { [string]: number } },
}

local Data, Creature, Wild, Fx, Battles, Follower

local ATTRIBUTES = {
	"Riding",
	"RideName",
	"RideHp",
	"RideHpMax",
	"RideStamina",
	"RideStaminaMax",
	"RideCanFly",
	"RideCanSprint",
	"RideMode",
	"RideScale",
	"RideSpecial",
	"RideSpecialCd",
	"RideFlySpeed",
}

function RideService:Init(registry)
	Data = registry.DataService
	Creature = registry.CreatureService
	Wild = registry.WildService
	Fx = registry.FxService
	Battles = registry.BattleService
	Follower = registry.FollowerService
end

function RideService:Start()
	Net.On("Ride", function(player, uid)
		self:Mount(player, uid)
	end)
	Net.On("RideAction", function(player, action, on)
		self:Action(player, action, on)
	end)
	Wild:On("AttackedPlayer", function(wild, player, damage)
		return self:_onAttacked(wild, player, damage)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:Dismount(player, "left")
		self.Tired[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(TICK)
			for player, ride in self.Rides do
				local ok, err = pcall(self._tick, self, player, ride)
				if not ok then
					log:Error("tick failed for", player.Name, err)
				end
			end
		end
	end)
end

function RideService:IsRiding(player: Player): boolean
	return self.Rides[player] ~= nil
end

function RideService:Get(player: Player): Ride?
	return self.Rides[player]
end

--------------------------------------------------------------------------
-- Mount / dismount
--------------------------------------------------------------------------

local function setAttributes(player: Player, ride: Ride?)
	if not ride then
		for _, name in ATTRIBUTES do
			player:SetAttribute(name, nil)
		end
		return
	end
	player:SetAttribute("Riding", ride.Uid)
	player:SetAttribute("RideName", CreatureMath.DisplayName(ride.Creature))
	player:SetAttribute("RideHpMax", ride.Stats.MaxHP)
	player:SetAttribute("RideStaminaMax", ride.Stats.StaminaMax)
	player:SetAttribute("RideCanFly", ride.Stats.CanFly)
	player:SetAttribute("RideCanSprint", ride.Stats.CanSprint)
	player:SetAttribute("RideScale", ride.Battle.Scale)
	player:SetAttribute("RideSpecial", ride.Special.Name)
	player:SetAttribute("RideSpecialCd", ride.Special.Cooldown)
	player:SetAttribute("RideFlySpeed", ride.Stats.FlySpeed)
end

function RideService:Mount(player: Player, uid: string)
	local data = Data:Get(player)
	local creature = data and data.Creatures[uid]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not creature or not character or not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	if Battles:IsFighting(player) then
		return
	end
	if RIDE.RequireSaddle and not creature.Saddle then
		Net.Notify(player, "🐎 This titan needs a saddle to ride.", RED)
		return
	end
	local tiredUntil = self.Tired[player] and self.Tired[player][uid]
	if tiredUntil and os.clock() < tiredUntil then
		Net.Notify(
			player,
			string.format("😴 It's tired! Ride again in %ds.", math.ceil(tiredUntil - os.clock())),
			RED
		)
		return
	end
	if player:GetAttribute("Carrying") then
		Net.Notify(player, "You can't ride while carrying stolen food!", RED)
		return
	end
	if self.Rides[player] then
		local same = self.Rides[player].Uid == uid
		self:Dismount(player, "switch")
		if same then
			return
		end
	end
	if Follower then
		Follower:Release(player, uid, true)
	end
	humanoid:UnequipTools()

	local stats = Riding.Stats(creature)
	local battle = Battle.Stats(creature)
	local model = CreatureBuilder.Build(creature)
	model.Name = "Mount"
	if math.abs(battle.Scale - 1) > 1e-3 then
		model:ScaleTo(battle.Scale)
	end
	local hip = root.Size.Y / 2 + humanoid.HipHeight
	model:PivotTo(root.CFrame * CFrame.new(0, -hip, 0))
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
		end
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = model.PrimaryPart
	weld.Parent = model.PrimaryPart

	-- Hide the rider's own body (the titan is what everyone sees)
	local saved = {}
	for _, d in character:GetDescendants() do
		if (d:IsA("BasePart") and d ~= root) or d:IsA("Decal") then
			local visible: any = d
			saved[d] = visible.Transparency
			visible.Transparency = 1
		end
	end
	model.Parent = character

	local ride: Ride = {
		Uid = uid,
		Creature = table.clone(creature),
		Stats = stats,
		Battle = battle,
		Special = Battle.SpecialFor(creature.Id),
		Model = model,
		Stamina = stats.StaminaMax,
		Mode = "Walk",
		Hp = stats.MaxHP,
		LastAttack = 0,
		LastSpecial = 0,
		LastCombat = 0,
		Saved = saved,
		SavedMove = {
			WalkSpeed = humanoid.WalkSpeed,
			JumpPower = humanoid.JumpPower,
			UseJumpPower = humanoid.UseJumpPower,
		},
		Connections = {},
	}
	humanoid.UseJumpPower = true
	humanoid.JumpPower = stats.JumpPower
	humanoid.WalkSpeed = stats.WalkSpeed
	table.insert(
		ride.Connections,
		humanoid.Died:Connect(function()
			self:Dismount(player, "died")
		end)
	)
	table.insert(
		ride.Connections,
		player.CharacterRemoving:Connect(function()
			self:Dismount(player, "respawn")
		end)
	)
	self.Rides[player] = ride
	Creature:SetOut(player, uid, true)
	setAttributes(player, ride)
	self:_sync(player, ride)
	Fx:PlayAll("MountDust", { Position = root.Position - Vector3.new(0, hip, 0), Size = math.sqrt(battle.Scale) })
	log:Info(player.Name, "mounted", creature.Id)
end

function RideService:Dismount(player: Player, reason: string?)
	local ride = self.Rides[player]
	if not ride then
		return
	end
	self.Rides[player] = nil
	for _, connection in ride.Connections do
		connection:Disconnect()
	end
	local position = ride.Model.PrimaryPart and ride.Model.PrimaryPart.Position
	ride.Model:Destroy()
	for instance, transparency in ride.Saved do
		if instance.Parent then
			(instance :: any).Transparency = transparency
		end
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = ride.SavedMove.WalkSpeed
		humanoid.JumpPower = ride.SavedMove.JumpPower
		humanoid.UseJumpPower = ride.SavedMove.UseJumpPower
	end
	setAttributes(player, nil)
	if Data:Get(player) then
		Creature:SetOut(player, ride.Uid, false)
	end
	if position and reason ~= "left" then
		Fx:PlayAll("MountDust", { Position = position, Size = math.sqrt(ride.Battle.Scale) })
	end
	if reason == "knocked" then
		self.Tired[player] = self.Tired[player] or {}
		self.Tired[player][ride.Uid] = os.clock() + TIRED_TIME
		Net.Notify(player, "💥 You got knocked off! Your titan needs " .. TIRED_TIME .. "s to rest.", RED)
	end
	log:Info(player.Name, "dismounted", ride.Creature.Id, reason or "")
end

--------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------

function RideService:Action(player: Player, action: string, on: boolean?)
	local ride = self.Rides[player]
	if not ride then
		return
	end
	if action == "Dismount" then
		self:Dismount(player, "button")
	elseif action == "Sprint" then
		ride.Mode = if on
				and ride.Stats.CanSprint
				and Riding.CanUse(ride.Stamina, "Sprint", ride.Mode == "Sprint")
			then "Sprint"
			else "Walk"
		self:_sync(player, ride)
	elseif action == "Fly" then
		ride.Mode = if on
				and ride.Stats.CanFly
				and Riding.CanUse(ride.Stamina, "Fly", ride.Mode == "Fly")
			then "Fly"
			else "Walk"
		self:_sync(player, ride)
	elseif action == "Attack" then
		self:_attack(player, ride, "Attack")
	elseif action == "Special" then
		self:_attack(player, ride, "Special")
	end
end

function RideService:_attack(player: Player, ride: Ride, kind: "Attack" | "Special")
	local now = os.clock()
	if kind == "Attack" then
		if now - ride.LastAttack < BATTLE.AttackCooldown then
			return
		end
		ride.LastAttack = now
	else
		if now - ride.LastSpecial < ride.Special.Cooldown then
			return
		end
		ride.LastSpecial = now
	end
	ride.LastCombat = now
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	local center = root.Position + Vector3.new(0, ride.Model:GetExtentsSize().Y * 0.3, 0)
	Fx:PlayAll("TitanAttack", {
		Kind = kind,
		Special = ride.Special.Id,
		Position = center,
		Look = look,
		Range = ride.Battle.Range,
		Color = Color3.fromRGB(255, 220, 150),
	})
	if kind == "Special" and ride.Special.Id == "Charge" then
		Fx:PlayFor(player, "Launch", { Velocity = look * 90 + Vector3.new(0, 10, 0) })
	elseif kind == "Special" and ride.Special.Id == "Bounce" then
		Fx:PlayFor(player, "Launch", { Velocity = Vector3.new(0, 70, 0) })
	end
	local delay = if kind == "Special" then ride.Special.Delay else 0.12
	task.delay(delay, function()
		if self.Rides[player] ~= ride then
			return
		end
		local from = root.Position
		local mult = if kind == "Special" then ride.Special.Mult else 1
		for _, wild in table.clone(Wild.Wilds) do
			if
				Battle.Hits(
					kind,
					if kind == "Special" then ride.Special else nil,
					{ X = from.X, Z = from.Z },
					{ X = look.X, Z = look.Z },
					{ X = wild.Pos.X, Z = wild.Pos.Z },
					ride.Battle.Range,
					wild.Radius
				)
			then
				local damage = Battle.Damage(ride.Battle.Attack, mult, math.random())
				-- Titan hits are strong but only lightly knock out (use tools to tame).
				Wild:Hit(wild, player, damage, damage * 0.3)
				if Follower then
					Follower:OwnerTarget(player, wild)
				end
			end
		end
	end)
end

function RideService:_onAttacked(wild, player: Player, damage: number): boolean
	local ride = self.Rides[player]
	if not ride then
		return false
	end
	ride.Hp -= damage
	ride.LastCombat = os.clock()
	local root = ride.Model.PrimaryPart
	if root then
		Fx:PlayAll("Hit", {
			Position = root.Position + Vector3.new(0, ride.Model:GetExtentsSize().Y * 0.5, 0),
			Amount = math.floor(damage),
			Model = ride.Model,
			Target = player.UserId,
		})
	end
	if Follower then
		Follower:OwnerTarget(player, wild)
	end
	if ride.Hp <= 0 and RIDE.KnockOffDamage then
		self:Dismount(player, "knocked")
	else
		self:_sync(player, ride)
	end
	return true
end

--------------------------------------------------------------------------
-- Tick: stamina, speed, HP regen
--------------------------------------------------------------------------

function RideService:_sync(player: Player, ride: Ride)
	player:SetAttribute("RideHp", math.max(0, math.floor(ride.Hp)))
	player:SetAttribute("RideStamina", math.floor(ride.Stamina))
	player:SetAttribute("RideMode", ride.Mode)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = if ride.Mode == "Sprint" then ride.Stats.SprintSpeed else ride.Stats.WalkSpeed
	end
end

function RideService:_tick(player: Player, ride: Ride)
	local before = ride.Mode
	ride.Stamina = Riding.UpdateStamina(ride.Stamina, ride.Stats.StaminaMax, TICK, ride.Mode)
	if ride.Mode ~= "Walk" and ride.Stamina <= 0 then
		ride.Mode = "Walk"
	end
	if os.clock() - ride.LastCombat > 5 and ride.Hp < ride.Stats.MaxHP then
		ride.Hp = math.min(ride.Stats.MaxHP, ride.Hp + ride.Stats.MaxHP * RIDE.HpRegen * TICK)
	end
	-- Attributes replicate to everyone: only send them when they change.
	if
		before ~= ride.Mode
		or math.floor(ride.Stamina) ~= player:GetAttribute("RideStamina")
		or math.floor(ride.Hp) ~= player:GetAttribute("RideHp")
	then
		self:_sync(player, ride)
	end
	-- Fell off the world: get off
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and root.Position.Y < Workspace.FallenPartsDestroyHeight + 50 then
		self:Dismount(player, "fell")
	end
end

return RideService
