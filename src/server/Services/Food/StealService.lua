--[[
	StealService: stealing food from other players' storage.

	1. Hold the "Steal Food" prompt on someone else's crate.
	2. You carry one food above your head and walk slower.
	3. Reach your own crate to keep it.
	The owner can "Take Back" by using the prompt on the thief,
	guard titan (Guard trait) can knock thieves away,
	and if the thief dies or leaves, the food goes back.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Foods = require(Shared.Config.Foods)
local CreatureMath = require(Shared.Game.CreatureMath)
local WeightedRandom = require(Shared.Lib.WeightedRandom)
local Net = require(Shared.Net)

local GameEvents = require(game:GetService("ServerScriptService"):WaitForChild("Server").Modules.GameEvents)

local RED = Color3.fromRGB(255, 80, 80)
local GREEN = Color3.fromRGB(90, 220, 120)

type Carry = {
	FoodId: string,
	Victim: Player,
	VictimPlot: any,
	Part: BasePart,
	Prompt: ProximityPrompt,
	Humanoid: Humanoid,
	DeathConnection: RBXScriptConnection,
	LastGuardCheck: number,
}

local StealService = {
	Priority = 35,
	Carriers = {} :: { [Player]: Carry },
}

local Data, Base, Fx, Food

function StealService:Init(registry)
	Data = registry.DataService
	Base = registry.BaseService
	Fx = registry.FxService
	Food = registry.FoodService
end

function StealService:Start()
	for _, plot in Base.Plots do
		plot.StealPrompt.Triggered:Connect(function(thief)
			self:TryStart(thief, plot)
		end)
	end

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

function StealService:OnPlayerRemoving(player: Player)
	if self.Carriers[player] then
		self:ReturnFood(player, "left")
	end
end

local function speedBonus(player: Player): number
	local data = Data:Get(player)
	local bonus = 0
	if data then
		for _, creature in data.Creatures do
			bonus = math.max(bonus, CreatureMath.Trait(creature, "Speed"))
		end
	end
	return bonus
end

function StealService:TryStart(thief: Player, plot)
	local victim = plot.Owner
	if not victim or victim == thief or self.Carriers[thief] or thief:GetAttribute("InBattle") then
		return
	end
	local victimData = Data:Get(victim)
	if not victimData or not Data:Get(thief) then
		return
	end
	if Food:IsLocked(plot) then
		Net.Notify(thief, "🔒 This storage is locked!", RED)
		return
	end
	if Food:SpaceLeft(thief) <= 0 then
		Net.Notify(thief, "📦 Your storage is full!", RED)
		return
	end
	local character = thief.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end

	local entries = {}
	for id, count in victimData.Food do
		if count > 0 and Foods[id] then
			table.insert(entries, { Id = id, Count = count })
		end
	end
	local pick = WeightedRandom.Pick(entries, function(e)
		return e.Count
	end)
	if not pick then
		Net.Notify(thief, "Their storage is empty!", RED)
		return
	end
	local def = Foods[pick.Id]
	victimData.Food[pick.Id] -= 1

	-- Food floating above the thief's head
	local carried = Instance.new("Part")
	carried.Name = "CarriedFood"
	carried.Shape = Enum.PartType.Ball
	carried.Size = Vector3.one * 2.5
	carried.Color = def.Color
	carried.Material = Enum.Material.Neon
	carried.CanCollide = false
	carried.CanTouch = false
	carried.CanQuery = false
	carried.Massless = true
	carried.CFrame = root.CFrame * CFrame.new(0, 4.5, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = carried
	weld.Parent = carried
	carried.Parent = character

	local takeBack = Instance.new("ProximityPrompt")
	takeBack.Name = "TakeBackPrompt"
	takeBack.ActionText = "Take Back!"
	takeBack.ObjectText = def.Name
	takeBack.HoldDuration = 0
	takeBack.MaxActivationDistance = 10
	takeBack.RequiresLineOfSight = false
	takeBack:SetAttribute("OnlyUserId", victim.UserId)
	takeBack.Parent = root
	takeBack.Triggered:Connect(function(who)
		if who == victim then
			self:ReturnFood(thief, "takeback")
		end
	end)

	humanoid.WalkSpeed = GameConfig.Steal.CarryWalkSpeed + speedBonus(thief)

	self.Carriers[thief] = {
		FoodId = pick.Id,
		Victim = victim,
		VictimPlot = plot,
		Part = carried,
		Prompt = takeBack,
		Humanoid = humanoid,
		DeathConnection = humanoid.Died:Connect(function()
			self:ReturnFood(thief, "died")
		end),
		LastGuardCheck = 0,
	}
	thief:SetAttribute("Carrying", pick.Id)

	Fx:PlayAll("StealStart", { Position = plot.Crate.Position })
	Fx:PlayFor(victim, "StealAlert", {})
	Net.Notify(victim, "🚨 " .. thief.DisplayName .. " is stealing your " .. def.Name .. "! Stop them!", RED)
	Net.Notify(thief, "😈 Got " .. def.Name .. "! Run back to your base!", def.Color)
	Food:RefreshStorage(victim)
	Data:Changed(victim)
end

function StealService:_clear(thief: Player): Carry?
	local carry = self.Carriers[thief]
	if not carry then
		return nil
	end
	self.Carriers[thief] = nil
	carry.DeathConnection:Disconnect()
	carry.Part:Destroy()
	carry.Prompt:Destroy()
	if carry.Humanoid.Parent and carry.Humanoid.Health > 0 then
		carry.Humanoid.WalkSpeed = GameConfig.Steal.NormalWalkSpeed
	end
	if thief.Parent then
		thief:SetAttribute("Carrying", nil)
	end
	return carry
end

-- Gives the food back to its owner (thief caught, died or left).
function StealService:ReturnFood(thief: Player, reason: string)
	local position = self.Carriers[thief] and self.Carriers[thief].Part.Position
	local carry = self:_clear(thief)
	if not carry then
		return
	end
	local victim = carry.Victim
	local victimData = victim.Parent and Data:Get(victim)
	if victimData then
		victimData.Food[carry.FoodId] = (victimData.Food[carry.FoodId] or 0) + 1
		Food:RefreshStorage(victim)
		Data:Changed(victim)
		if reason ~= "left" then
			Net.Notify(victim, "✅ You got your " .. Foods[carry.FoodId].Name .. " back!", GREEN)
		end
	end
	if position then
		Fx:PlayAll("TakeBack", { Position = position })
	end
	if thief.Parent then
		local message = if reason == "guard"
			then "🦍 A guard knocked you away! You dropped the food."
			elseif reason == "takeback" then "❌ " .. victim.DisplayName .. " took their food back!"
			else "❌ You dropped the food!"
		Net.Notify(thief, message, RED)
	end
end

function StealService:_deposit(thief: Player, plot)
	local carry = self:_clear(thief)
	if not carry then
		return
	end
	local data = Data:Get(thief)
	local def = Foods[carry.FoodId]
	if data then
		data.Food[carry.FoodId] = (data.Food[carry.FoodId] or 0) + 1
		data.Stats.Steals += 1
		GameEvents.Fire(thief, "Stole", { Food = carry.FoodId })
		Food:RefreshStorage(thief)
		Data:Changed(thief)
	end
	local victimData = carry.Victim.Parent and Data:Get(carry.Victim)
	if victimData then
		victimData.Stats.Stolen += 1
		Net.Notify(carry.Victim, "😭 " .. thief.DisplayName .. " stole your " .. def.Name .. "!", RED)
	end
	Fx:PlayAll("Deposit", { Position = plot.Crate.Position, Color = def.Color, Owner = thief.UserId })
end

function StealService:_guardChance(victim: Player): number
	local data = Data:Get(victim)
	if not data then
		return 0
	end
	local chance = 0
	for _, creature in data.Creatures do
		chance += CreatureMath.GuardChance(creature)
	end
	return math.min(chance, GameConfig.Steal.MaxGuardChance)
end

function StealService:_tick()
	local t = Workspace:GetServerTimeNow()
	for thief, carry in self.Carriers do
		local character = thief.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			self:ReturnFood(thief, "died")
			continue
		end
		local home = Base:GetPlot(thief)
		if home and (root.Position - home.Crate.Position).Magnitude <= GameConfig.Steal.DepositDistance then
			self:_deposit(thief, home)
			continue
		end
		local plot = carry.VictimPlot
		if
			plot.Owner == carry.Victim
			and t - carry.LastGuardCheck >= GameConfig.Steal.GuardCheckInterval
			and Base:IsInside(plot, root.Position)
		then
			carry.LastGuardCheck = t
			if math.random() < self:_guardChance(carry.Victim) then
				local away = (root.Position - plot.CFrame.Position) * Vector3.new(1, 0, 1)
				local direction = if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 0, 1)
				-- The thief's client owns its physics, so the knockback is applied
				-- there (see the GuardKnock preset).
				Fx:PlayAll("GuardKnock", {
					Position = root.Position,
					Target = thief.UserId,
					Velocity = direction * 90 + Vector3.new(0, 60, 0),
				})
				self:ReturnFood(thief, "guard")
			end
		end
	end
end

return StealService
