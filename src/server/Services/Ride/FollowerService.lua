--[[
	FollowerService: up to GameConfig.Followers.Max of your titans walk
	with you around the island and defend you (Phase 1).

	Commands (FollowerCommand remote, Titans menu, follower bar):
	  Follow <uid>  take a titan out of its pen to follow you
	  Home <uid>    send one titan back to its pen
	  FollowAll     everyone follows again      Stay     everyone waits here
	  Attack        attack the wild titan you're facing (or the nearest one)
	  Guard         everyone goes home to guard your base
	Followers also attack wild titans that attack you or that you hit.
	If one gets stuck far away, it teleports next to you.

	Movement is like wild titans: logical position here, clients animate the
	model from MoveFrom/MoveTo attributes (client WildController).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Battle = require(Shared.Game.Battle)
local CreatureMath = require(Shared.Game.CreatureMath)
local Riding = require(Shared.Game.Riding)
local Tags = require(Shared.Game.Tags)
local Log = require(Shared.Lib.Log)
local Net = require(Shared.Net)

local CreatureBuilder = require(ServerScriptService:WaitForChild("Server").Modules.CreatureBuilder)

local log = Log.new("FollowerService")

local FOLLOW = GameConfig.Followers
local TICK = 0.25
local RED = Color3.fromRGB(255, 90, 90)

type Follower = {
	Uid: string,
	Model: Model,
	Pos: Vector3,
	Look: Vector3,
	Mode: string, -- "Follow" | "Stay" | "Attack"
	Target: any?, -- a Wild from WildService
	Stats: Battle.Stats,
	Speed: number,
	Size: number, -- model footprint for spacing
	LastAttack: number,
	LastSnap: number,
	Index: number,
}

local FollowerService = {
	Priority = 47,
	Followers = {} :: { [Player]: { [string]: Follower } },
	_folder = nil :: Folder?,
}

local Data, Creature, Wild, Fx, Map, Ride

function FollowerService:Init(registry)
	Data = registry.DataService
	Creature = registry.CreatureService
	Wild = registry.WildService
	Fx = registry.FxService
	Map = registry.MapService
	Ride = registry.RideService
end

function FollowerService:Start()
	local folder = Instance.new("Folder")
	folder.Name = "Followers"
	folder.Parent = Workspace
	self._folder = folder

	Net.On("FollowerCommand", function(player, command, uid)
		self:Command(player, command, uid)
	end)
	Data:AddSnapshotHook(function(player, snapshot)
		local following = {}
		for uid in self.Followers[player] or {} do
			following[uid] = true
		end
		snapshot.Following = following
	end)
	Wild:On("AttackedPlayer", function(wild, player)
		self:OwnerTarget(player, wild)
		return false -- the player still takes the hit
	end)
	Players.PlayerRemoving:Connect(function(player)
		for uid in table.clone(self.Followers[player] or {}) do
			self:Release(player, uid, true)
		end
		self.Followers[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(TICK)
			for player, list in self.Followers do
				local ok, err = pcall(self._tick, self, player, list)
				if not ok then
					log:Error("tick failed for", player.Name, err)
				end
			end
		end
	end)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function FollowerService:Count(player: Player): number
	local n = 0
	for _ in self.Followers[player] or {} do
		n += 1
	end
	return n
end

function FollowerService:IsFollowing(player: Player, uid: string): boolean
	return self.Followers[player] ~= nil and self.Followers[player][uid] ~= nil
end

-- Follows if a slot is free (used after taming). Returns true if it follows.
function FollowerService:TryFollow(player: Player, uid: string): boolean
	if self:Count(player) >= FOLLOW.Max then
		return false
	end
	return self:Follow(player, uid)
end

function FollowerService:Follow(player: Player, uid: string): boolean
	local data = Data:Get(player)
	local creature = data and data.Creatures[uid]
	local root = rootOf(player)
	if not creature or not root or self:IsFollowing(player, uid) then
		return false
	end
	if Ride:Get(player) and Ride:Get(player).Uid == uid then
		return false -- you're riding it
	end
	if self:Count(player) >= FOLLOW.Max then
		Net.Notify(player, string.format("🐾 Only %d titans can follow you at once.", FOLLOW.Max), RED)
		return false
	end
	self.Followers[player] = self.Followers[player] or {}
	local stats = Battle.Stats(creature)
	local model = CreatureBuilder.Build(creature)
	model.Name = "Follower_" .. uid
	if math.abs(stats.Scale - 1) > 1e-3 then
		model:ScaleTo(stats.Scale)
	end
	local start = Map:GroundAt(root.Position - root.CFrame.LookVector * 8) or root.Position
	local look = flat(root.CFrame.LookVector)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	model:PivotTo(CFrame.lookAt(start, start + look))
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("State", "Idle")
	model.Parent = self._folder
	CollectionService:AddTag(model, Tags.Mover)

	-- Name tag + ride prompt
	local primary = model.PrimaryPart :: BasePart
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 30)
	gui.StudsOffsetWorldSpace = Vector3.new(0, model:GetExtentsSize().Y + 1.5, 0)
	gui.MaxDistance = 150
	gui.LightInfluence = 0
	gui.Parent = primary
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(180, 255, 180)
	label.Text = "🐾 " .. CreatureMath.DisplayName(creature) .. " (" .. player.DisplayName .. ")"
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = label
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RidePrompt"
	prompt.ActionText = "Ride"
	prompt.KeyboardKeyCode = Enum.KeyCode.R
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10 + stats.Scale * 3
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OnlyUserId", player.UserId)
	prompt.Parent = primary
	prompt.Triggered:Connect(function(who)
		if who == player then
			Ride:Mount(player, uid)
		end
	end)

	local follower: Follower = {
		Uid = uid,
		Model = model,
		Pos = start,
		Look = look,
		Mode = "Follow",
		Target = nil,
		Stats = stats,
		Speed = math.max(20, stats.Speed * 1.3),
		Size = 5 * stats.Scale,
		LastAttack = 0,
		LastSnap = 0,
		Index = self:Count(player) + 1,
	}
	self.Followers[player][uid] = follower
	Creature:SetOut(player, uid, true)
	Fx:PlayAll("Spawn", { Position = start, Color = Color3.fromRGB(150, 255, 150) })
	player:SetAttribute("Followers", self:Count(player))
	Data:Changed(player)
	log:Info(player.Name, "is followed by", creature.Id)
	return true
end

-- Sends a follower back to its pen.
function FollowerService:Release(player: Player, uid: string, silent: boolean?)
	local list = self.Followers[player]
	local follower = list and list[uid]
	if not follower then
		return
	end
	list[uid] = nil
	if not silent then
		Fx:PlayAll("Poof", { Position = follower.Pos })
	end
	follower.Model:Destroy()
	if Data:Get(player) then
		Creature:SetOut(player, uid, false)
		Data:Changed(player)
	end
	-- Re-number the formation
	local i = 0
	for _, other in list do
		i += 1
		other.Index = i
	end
	player:SetAttribute("Followers", self:Count(player))
end

-- A wild titan attacked the owner (or the owner hit one): followers join in.
function FollowerService:OwnerTarget(player: Player, wild)
	for _, follower in self.Followers[player] or {} do
		if follower.Mode ~= "Stay" and not wild.Asleep then
			follower.Mode = "Attack"
			follower.Target = wild
		end
	end
end

function FollowerService:Command(player: Player, command: string, uid: string?)
	if command == "Follow" and uid then
		if self:IsFollowing(player, uid) then
			self:Release(player, uid)
		else
			self:Follow(player, uid)
		end
	elseif command == "Home" and uid then
		self:Release(player, uid)
	elseif command == "Guard" then
		for id in table.clone(self.Followers[player] or {}) do
			self:Release(player, id)
		end
		Net.Notify(player, "🏠 Your titans went home to guard your base.")
	elseif command == "Stay" or command == "FollowAll" then
		for _, follower in self.Followers[player] or {} do
			follower.Mode = if command == "Stay" then "Stay" else "Follow"
			follower.Target = nil
		end
	elseif command == "Attack" then
		local root = rootOf(player)
		if not root then
			return
		end
		local wild = Wild:FindNear(root.Position, root.CFrame.LookVector, 60, 0.3)
			or Wild:FindNear(root.Position, nil, FOLLOW.GuardRange)
		if wild then
			for _, follower in self.Followers[player] or {} do
				follower.Mode = "Attack"
				follower.Target = wild
			end
		else
			Net.Notify(player, "No wild titan nearby to attack.", RED)
		end
	end
end

--------------------------------------------------------------------------
-- Movement / fighting
--------------------------------------------------------------------------

function FollowerService:_move(follower: Follower, target: Vector3, now: number)
	local offset = flat(target - follower.Pos)
	local distance = offset.Magnitude
	local from = CFrame.lookAt(follower.Pos, follower.Pos + follower.Look)
	if distance < 1 then
		follower.Model:SetAttribute("State", "Idle")
		follower.Model:SetAttribute("MoveFrom", from)
		follower.Model:SetAttribute("MoveTo", from)
		follower.Model:SetAttribute("MoveStart", now)
		follower.Model:SetAttribute("MoveDuration", 0.01)
		return
	end
	local step = math.min(distance, follower.Speed * TICK)
	local nextPos = follower.Pos + offset.Unit * step
	local ground = Map:GroundAt(nextPos) or nextPos
	follower.Look = offset.Unit
	follower.Pos = ground
	local to = CFrame.lookAt(ground, ground + follower.Look)
	local model = follower.Model
	model:SetAttribute("State", if distance > 12 then "Chase" else "Wander")
	model:SetAttribute("MoveFrom", from)
	model:SetAttribute("MoveTo", to)
	model:SetAttribute("MoveStart", now)
	model:SetAttribute("MoveDuration", TICK)
	if now - follower.LastSnap > 2 then
		follower.LastSnap = now
		model:PivotTo(to)
	end
end

function FollowerService:_teleport(follower: Follower, position: Vector3)
	Fx:PlayAll("Poof", { Position = follower.Pos })
	follower.Pos = Map:GroundAt(position) or position
	local cf = CFrame.lookAt(follower.Pos, follower.Pos + follower.Look)
	follower.Model:PivotTo(cf)
	follower.Model:SetAttribute("MoveFrom", cf)
	follower.Model:SetAttribute("MoveTo", cf)
	Fx:PlayAll("Spawn", { Position = follower.Pos, Color = Color3.fromRGB(150, 255, 150) })
end

function FollowerService:_tick(player: Player, list: { [string]: Follower })
	local root = rootOf(player)
	if not root then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local look = flat(root.CFrame.LookVector)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	local right = look:Cross(Vector3.yAxis)
	for _, follower in list do
		local ownerDistance = (flat(root.Position) - flat(follower.Pos)).Magnitude
		local mode: string = follower.Mode
		local stuck = ownerDistance > FOLLOW.TeleportDistance
		if stuck and follower.Mode ~= "Stay" then
			self:_teleport(follower, root.Position - look * 10)
			continue
		end
		local target = follower.Target
		if mode == "Attack" then
			if not target or target.Removed or target.Asleep or ownerDistance > FOLLOW.TeleportDistance * 0.8 then
				follower.Mode = "Follow"
				follower.Target = nil
			else
				local reach = follower.Stats.Range + target.Radius
				local toTarget = flat(target.Pos - follower.Pos)
				if toTarget.Magnitude > reach then
					self:_move(follower, target.Pos, now)
				else
					follower.Look = if toTarget.Magnitude > 0.1 then toTarget.Unit else follower.Look
					follower.Model:SetAttribute("State", "Attack")
					if now - follower.LastAttack > GameConfig.Battle.AttackCooldown * 1.3 then
						follower.LastAttack = now
						local damage = Battle.Damage(follower.Stats.Attack, 0.6, math.random())
						Fx:PlayAll("TitanAttack", {
							Kind = "Attack",
							Position = follower.Pos + Vector3.new(0, follower.Model:GetExtentsSize().Y * 0.5, 0),
							Look = follower.Look,
							Range = follower.Stats.Range,
							Color = Color3.fromRGB(150, 255, 150),
						})
						Wild:Hit(target, player, damage, damage * 0.15)
					end
				end
				continue
			end
		end
		mode = follower.Mode
		if mode == "Follow" then
			local slot = Riding.FollowerOffset(follower.Index, 8 + follower.Size)
			local goal = root.Position - look * slot.Z + right * slot.X
			if (flat(goal) - flat(follower.Pos)).Magnitude > 4 then
				self:_move(follower, goal, now)
			else
				self:_move(follower, follower.Pos, now)
			end
		else
			self:_move(follower, follower.Pos, now) -- Stay
		end
	end
end

return FollowerService
