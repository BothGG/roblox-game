--[[
	EggCarryService: stealing eggs and carrying them home.

	- Hold "Steal Egg" on someone else's incubator (only while they're in the
	  server). Bigger eggs take longer to grab.
	- The carrier walks slower (Breeding.CarrySpeed: bigger = slower), can't
	  ride or battle, leaves a trail and has a marker everyone can see.
	- The owner hears an alarm and gets a guide beam to the thief (client:
	  EggAlarmController, player attribute "EggThief").
	- Anyone can "Tackle" a carrier (the owner's prompt says "Take Back" and
	  returns it straight home). A tackled or killed carrier drops the egg;
	  a dropped egg can be grabbed by anyone for DroppedTime seconds, then it
	  goes back to its owner.
	- Reach your own base with it and it's yours (IncubatorService:AddEgg).

	API (also used by nests, step 5):
	  EggCarryService:StartCarry(player, egg, owner?, fromText?) -> boolean
	  EggCarryService:Drop(player, reason)
	  EggCarryService:IsCarrying(player) -> boolean
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Creatures = require(Shared.Config.Creatures)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Breeding = require(Shared.Game.Breeding)
local CreatureMath = require(Shared.Game.CreatureMath)
local Log = require(Shared.Lib.Log)
local Net = require(Shared.Net)

local Server = ServerScriptService:WaitForChild("Server")
local EggBuilder = require(Server.Modules.EggBuilder)
local GameEvents = require(Server.Modules.GameEvents)

local log = Log.new("EggCarryService")

local BREED = GameConfig.Breeding
local RED = Color3.fromRGB(255, 80, 80)
local GREEN = Color3.fromRGB(90, 220, 120)
local GOLD = Color3.fromRGB(255, 210, 60)
local CARRY_SCALE = 0.55 -- carried eggs are shrunk a bit so they fit over your head

type Egg = {
	Species: string,
	Mutation: string?,
	Size: number,
	Bonus: number?,
	Source: string?,
}

type Carry = {
	Egg: Egg,
	Owner: Player?, -- nil = a wild nest egg
	Model: Model,
	Marker: BillboardGui,
	Trail: Trail,
	Prompt: ProximityPrompt,
	Humanoid: Humanoid,
	Died: RBXScriptConnection,
}

type Dropped = {
	Egg: Egg,
	Owner: Player?,
	Model: Model,
	Prompt: ProximityPrompt,
	Until: number,
}

local EggCarryService = {
	Priority = 36, -- after IncubatorService (30) and StealService (35)
	Carriers = {} :: { [Player]: Carry },
	Dropped = {} :: { Dropped },
}

local Data, Base, Incubator, Ride, Fx

function EggCarryService:Init(registry)
	Data = registry.DataService
	Base = registry.BaseService
	Incubator = registry.IncubatorService
	Ride = registry.RideService
	Fx = registry.FxService
end

local function eggName(egg: Egg): string
	return CreatureMath.DisplayName({ Id = egg.Species, Level = 1, Xp = 0, Mutation = egg.Mutation, Size = egg.Size })
end

local function eggColor(egg: Egg): Color3
	return if egg.Mutation then Mutations[egg.Mutation].Color else Rarities[Creatures[egg.Species].Rarity].Color
end

local function grabTime(size: number): number
	return 1.2 + (Breeding.TierIndex(size) - 1) * 0.5
end

function EggCarryService:Start()
	-- A "Steal Egg" prompt on every incubator, hidden for its owner.
	Incubator.OnEggPad(function(ownerPrompt: ProximityPrompt, plot, slot: number)
		local base = ownerPrompt.Parent :: BasePart
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "StealEggPrompt"
		prompt.ActionText = "Steal Egg"
		prompt.ObjectText = "Incubator"
		prompt.HoldDuration = 1.5
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.F
		prompt:SetAttribute("Off", true)
		prompt.Parent = base
		local function update()
			local hasEgg = base:GetAttribute("HasEgg") == true
			prompt:SetAttribute("Off", not hasEgg)
			prompt:SetAttribute("HideForUserId", base:GetAttribute("OwnerUserId"))
			local owner = plot.Owner
			local data = owner and Data:Get(owner)
			local uid = base:GetAttribute("EggUid")
			local egg = data and uid and data.Eggs[uid]
			if egg then
				prompt.ObjectText = eggName(egg)
				prompt.HoldDuration = grabTime(egg.Size)
			end
		end
		base:GetAttributeChangedSignal("HasEgg"):Connect(update)
		base:GetAttributeChangedSignal("EggUid"):Connect(update)
		base:GetAttributeChangedSignal("OwnerUserId"):Connect(update)
		prompt.Triggered:Connect(function(thief)
			self:_stealFromPad(thief, plot, slot, base)
		end)
		update()
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.2 then
			return
		end
		accumulator = 0
		self:_tick()
	end)
end

function EggCarryService:OnPlayerRemoving(player: Player)
	if self.Carriers[player] then
		self:_returnHome(player, "left")
	end
	-- Their eggs out in the world: the owner is gone, so nobody gets them back.
	for _, carry in self.Carriers do
		if carry.Owner == player then
			carry.Owner = nil
		end
	end
	for _, dropped in self.Dropped do
		if dropped.Owner == player then
			dropped.Owner = nil
		end
	end
	player:SetAttribute("EggThief", nil)
end

function EggCarryService:IsCarrying(player: Player): boolean
	return self.Carriers[player] ~= nil
end

--------------------------------------------------------------------------
-- Starting a carry
--------------------------------------------------------------------------

local function canCarry(player: Player): (boolean, string?)
	if player:GetAttribute("Carrying") then
		return false, "You're already carrying food!"
	end
	if player:GetAttribute("CarryingEgg") then
		return false, "You're already carrying an egg!"
	end
	if player:GetAttribute("InBattle") then
		return false, nil
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false, nil
	end
	return true, nil
end

function EggCarryService:_stealFromPad(thief: Player, plot, _slot: number, base: BasePart)
	local owner = plot.Owner
	if not owner or owner == thief then
		return
	end
	local ok, reason = canCarry(thief)
	if not ok then
		if reason then
			Net.Notify(thief, "🥚 " .. reason, RED)
		end
		return
	end
	local uid = base:GetAttribute("EggUid")
	if type(uid) ~= "string" then
		return
	end
	local egg = Incubator:TakeEgg(owner, uid)
	if not egg then
		return
	end
	local carryEgg: Egg = {
		Species = egg.Species,
		Mutation = egg.Mutation,
		Size = egg.Size,
		Bonus = egg.Bonus,
		Source = "Stolen",
	}
	if not self:StartCarry(thief, carryEgg, owner) then
		-- Couldn't start (e.g. died this frame): give it back.
		Incubator:AddEgg(owner, egg)
		return
	end
	Fx:PlayAll("StealStart", { Position = base.Position })
	Fx:PlayFor(owner, "StealAlert", {})
	owner:SetAttribute("EggThief", thief.UserId)
	Net.Fire(owner, "Announce", {
		Title = "🚨 EGG STOLEN!",
		Text = thief.DisplayName .. " stole your " .. eggName(carryEgg) .. " egg! Follow the beam and take it back!",
		Color = RED,
	})
	Net.Notify(thief, "😈 Got a " .. eggName(carryEgg) .. " egg! Run back to your base!", eggColor(carryEgg))
	if Breeding.ShouldAnnounce(carryEgg.Size) then
		Net.NotifyAll(
			string.format(
				"🥚 %s is running with %s's %s egg!",
				thief.DisplayName,
				owner.DisplayName,
				eggName(carryEgg)
			),
			GOLD
		)
	end
	log:Info(thief.Name, "stole", carryEgg.Species, "from", owner.Name)
end

function EggCarryService:StartCarry(player: Player, egg: Egg, owner: Player?): boolean
	local ok = canCarry(player)
	if not ok then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not root or not humanoid then
		return false
	end
	Ride:Dismount(player)

	-- The egg over your head
	local model = EggBuilder.Build(egg)
	model.Name = "CarriedEgg"
	model:ScaleTo(CARRY_SCALE)
	local height = model:GetExtentsSize().Y
	model:PivotTo(root.CFrame * CFrame.new(0, 3, 0))
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.Massless = true
			part.CanCollide = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = part
		end
	end
	model.Parent = character

	-- Marker everyone can see from far away
	local marker = Instance.new("BillboardGui")
	marker.Name = "EggThiefMarker"
	marker.Size = UDim2.fromOffset(200, 50)
	marker.StudsOffsetWorldSpace = Vector3.new(0, 4 + height, 0)
	marker.AlwaysOnTop = true
	marker.MaxDistance = 800
	marker.Parent = root
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = eggColor(egg)
	label.Text = "🥚 " .. eggName(egg)
	label.Parent = marker
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = label

	-- Trail
	local a0 = Instance.new("Attachment")
	a0.Name = "EggTrail0"
	a0.Position = Vector3.new(0, 1, 0)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = "EggTrail1"
	a1.Position = Vector3.new(0, -2, 0)
	a1.Parent = root
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(eggColor(egg))
	trail.LightEmission = 1
	trail.Lifetime = 1.6
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.FaceCamera = true
	trail.Parent = root

	-- Tackle / Take Back prompt on the carrier
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TackleEggPrompt"
	prompt.ActionText = "Tackle!"
	prompt.ObjectText = "Egg carrier"
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("HideForUserId", player.UserId)
	prompt.Parent = root
	prompt.Triggered:Connect(function(who)
		if who == player then
			return
		end
		local carry = self.Carriers[player]
		if carry and who == carry.Owner then
			self:_returnHome(player, "takeback")
		else
			self:Drop(player, "tackled")
		end
	end)

	humanoid.WalkSpeed = Breeding.CarrySpeed(egg.Size)
	self.Carriers[player] = {
		Egg = egg,
		Owner = owner,
		Model = model,
		Marker = marker,
		Trail = trail,
		Prompt = prompt,
		Humanoid = humanoid,
		Died = humanoid.Died:Connect(function()
			self:Drop(player, "died")
		end),
	}
	player:SetAttribute("CarryingEgg", eggName(egg))
	return true
end

--------------------------------------------------------------------------
-- Ending a carry
--------------------------------------------------------------------------

function EggCarryService:_clear(player: Player): Carry?
	local carry = self.Carriers[player]
	if not carry then
		return nil
	end
	self.Carriers[player] = nil
	carry.Died:Disconnect()
	carry.Model:Destroy()
	carry.Marker:Destroy()
	carry.Prompt:Destroy()
	local root = carry.Trail.Parent
	carry.Trail:Destroy()
	if root then
		for _, name in { "EggTrail0", "EggTrail1" } do
			local a = root:FindFirstChild(name)
			if a then
				a:Destroy()
			end
		end
	end
	if carry.Humanoid.Parent and carry.Humanoid.Health > 0 then
		carry.Humanoid.WalkSpeed = GameConfig.Steal.NormalWalkSpeed
	end
	if player.Parent then
		player:SetAttribute("CarryingEgg", nil)
	end
	if carry.Owner and carry.Owner.Parent then
		carry.Owner:SetAttribute("EggThief", nil)
	end
	return carry
end

local function position(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

-- Gives the egg straight back to its owner (Take Back, or the carrier left).
function EggCarryService:_returnHome(player: Player, reason: string)
	local at = position(player)
	local carry = self:_clear(player)
	if not carry then
		return
	end
	local owner = carry.Owner
	if owner and owner.Parent then
		Incubator:AddEgg(owner, carry.Egg)
		if reason == "takeback" then
			Net.Notify(owner, "✅ You got your egg back!", GREEN)
		end
	end
	if at then
		Fx:PlayAll("TakeBack", { Position = at })
	end
	if player.Parent and reason == "takeback" and owner then
		Net.Notify(player, "❌ " .. owner.DisplayName .. " took their egg back!", RED)
	end
end

-- The carrier drops the egg on the ground; anyone can grab it for a bit.
function EggCarryService:Drop(player: Player, reason: string)
	local at = position(player) or (self.Carriers[player] and self.Carriers[player].Model:GetPivot().Position)
	local carry = self:_clear(player)
	if not carry or not at then
		return
	end
	if player.Parent then
		Net.Notify(
			player,
			if reason == "tackled" then "💥 You got tackled and dropped the egg!" else "❌ You dropped the egg!",
			RED
		)
	end
	self:_spawnDropped(carry.Egg, carry.Owner, at)
end

function EggCarryService:_spawnDropped(egg: Egg, owner: Player?, at: Vector3)
	local model = EggBuilder.Build(egg)
	model.Name = "DroppedEgg"
	model:ScaleTo(CARRY_SCALE)
	model:PivotTo(CFrame.new(at.X, at.Y - 2.5, at.Z))
	local shell = model:FindFirstChild("Shell") :: BasePart
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GrabEggPrompt"
	prompt.ActionText = "Grab Egg"
	prompt.ObjectText = eggName(egg)
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = shell
	model.Parent = workspace
	local dropped: Dropped = {
		Egg = egg,
		Owner = owner,
		Model = model,
		Prompt = prompt,
		Until = os.clock() + BREED.DroppedTime,
	}
	table.insert(self.Dropped, dropped)
	prompt.Triggered:Connect(function(who)
		self:_grabDropped(who, dropped)
	end)
	Fx:PlayAll("Poof", { Position = at })
	if owner and owner.Parent then
		Net.Notify(owner, string.format("🥚 Your egg was dropped! Grab it in %ds!", BREED.DroppedTime), GOLD)
	end
end

function EggCarryService:_removeDropped(dropped: Dropped)
	local index = table.find(self.Dropped, dropped)
	if index then
		table.remove(self.Dropped, index)
	end
	dropped.Model:Destroy()
end

function EggCarryService:_grabDropped(player: Player, dropped: Dropped)
	if not table.find(self.Dropped, dropped) then
		return
	end
	if player == dropped.Owner then
		self:_removeDropped(dropped)
		Incubator:AddEgg(player, dropped.Egg)
		Net.Notify(player, "✅ You got your egg back!", GREEN)
		Fx:PlayAll("TakeBack", { Position = dropped.Model:GetPivot().Position })
		return
	end
	local ok, reason = canCarry(player)
	if not ok then
		if reason then
			Net.Notify(player, "🥚 " .. reason, RED)
		end
		return
	end
	local egg, owner = dropped.Egg, dropped.Owner
	self:_removeDropped(dropped)
	if self:StartCarry(player, egg, owner) then
		if owner and owner.Parent then
			owner:SetAttribute("EggThief", player.UserId)
			Net.Notify(owner, "🚨 " .. player.DisplayName .. " grabbed your egg!", RED)
		end
		Net.Notify(player, "😈 Got it! Run back to your base!", eggColor(egg))
	else
		self:_spawnDropped(egg, owner, dropped.Model:GetPivot().Position + Vector3.new(0, 2.5, 0))
	end
end

-- Made it home with the egg.
function EggCarryService:_deposit(player: Player)
	local carry = self.Carriers[player]
	if not carry then
		return
	end
	local egg = carry.Egg
	local data = Data:Get(player)
	if not data then
		return
	end
	local count = 0
	for _ in data.Eggs do
		count += 1
	end
	if count >= GameConfig.Data.Limits.Eggs then
		if Net.Throttle(player, "EggStorageFull", 5) then
			Net.Notify(player, "🥚 Your egg storage is full! The egg can't fit.", RED)
		end
		return
	end
	self:_clear(player)
	Incubator:AddEgg(player, egg)
	local owner = carry.Owner
	if owner then
		data.Stats.Steals += 1
		GameEvents.Fire(player, "Stole", { Egg = egg.Species })
		local ownerData = owner.Parent and Data:Get(owner)
		if ownerData then
			ownerData.Stats.Stolen += 1
			Net.Notify(owner, "😭 " .. player.DisplayName .. " stole your " .. eggName(egg) .. " egg!", RED)
		end
	end
	local at = position(player)
	if at then
		Fx:PlayAll("Deposit", { Position = at, Color = eggColor(egg), Owner = player.UserId })
	end
	Net.Notify(player, "🥚 The " .. eggName(egg) .. " egg is yours!", GREEN)
	Data:Changed(player)
end

--------------------------------------------------------------------------
-- Tick
--------------------------------------------------------------------------

function EggCarryService:_tick()
	for player in self.Carriers do
		local at = position(player)
		if not at then
			self:Drop(player, "died")
			continue
		end
		local home = Base:GetPlot(player)
		if home and Base:IsInside(home, at) then
			self:_deposit(player)
		end
	end
	local now = os.clock()
	for i = #self.Dropped, 1, -1 do
		local dropped = self.Dropped[i]
		if now >= dropped.Until then
			local at = dropped.Model:GetPivot().Position
			self:_removeDropped(dropped)
			if dropped.Owner and dropped.Owner.Parent then
				Incubator:AddEgg(dropped.Owner, dropped.Egg)
				Net.Notify(dropped.Owner, "✅ Your dropped egg rolled back home!", GREEN)
				Fx:PlayAll("TakeBack", { Position = at })
			else
				Fx:PlayAll("Poof", { Position = at })
			end
		else
			local left = math.ceil(dropped.Until - now)
			dropped.Prompt.ObjectText = string.format("%s  (%ds)", eggName(dropped.Egg), left)
		end
	end
end

return EggCarryService
