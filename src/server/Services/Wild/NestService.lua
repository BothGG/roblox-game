--[[
	NestService: wild nests out in the fields, each with one egg and 1-2
	angry guardian titans of the same kind.

	- Grab the egg (hold) and carry it home (EggCarryService). The guardians
	  chase you, so knock them out first, sneak, or outrun them.
	- Nests expire after Nests.Lifetime and new ones appear elsewhere.
	- Bigger eggs are rarer (Nests.SizeTiers) and have bigger guardians.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Breeding = require(Shared.Game.Breeding)
local CreatureMath = require(Shared.Game.CreatureMath)
local Log = require(Shared.Lib.Log)
local Net = require(Shared.Net)

local Server = ServerScriptService:WaitForChild("Server")
local EggBuilder = require(Server.Modules.EggBuilder)

local log = Log.new("NestService")

local NEST = GameConfig.Nests
local RED = Color3.fromRGB(255, 90, 90)

type Nest = {
	Egg: { Species: string, Mutation: string?, Size: number, Bonus: number, Source: string },
	Model: Model,
	Guardians: { any },
	ExpiresAt: number,
}

local NestService = {
	Priority = 45, -- after WildService (40)
	Nests = {} :: { Nest },
}

local Wild, Carry, Fx, Map
local folder: Folder

function NestService:Init(registry)
	Wild = registry.WildService
	Carry = registry.EggCarryService
	Fx = registry.FxService
	Map = registry.MapService
end

function NestService:Start()
	folder = Instance.new("Folder")
	folder.Name = "Nests"
	folder.Parent = workspace
	task.spawn(function()
		task.wait(NEST.FirstDelay)
		while true do
			local ok, err = pcall(self._tick, self)
			if not ok then
				log:Warn("tick failed", err)
			end
			task.wait(5)
		end
	end)
end

local nextSpawnAt = 0

function NestService:_tick()
	local now = os.clock()
	for i = #self.Nests, 1, -1 do
		local nest = self.Nests[i]
		if now >= nest.ExpiresAt then
			self:_remove(nest, true)
		end
	end
	if #self.Nests < NEST.Max and now >= nextSpawnAt then
		if self:Spawn() then
			nextSpawnAt = now + NEST.RespawnDelay * 0.25
		end
	end
end

local function twig(parent: Instance, cf: CFrame, length: number)
	local p = Instance.new("Part")
	p.Name = "Twig"
	p.Anchored = true
	p.CanCollide = false
	p.Size = Vector3.new(length, 0.6, 0.6)
	p.CFrame = cf
	p.Color = Color3.fromRGB(120 + math.random(-15, 15), 85, 45)
	p.Material = Enum.Material.Wood
	p.Parent = parent
end

function NestService:_buildNest(egg, at: Vector3, scale: number): Model
	local model = Instance.new("Model")
	model.Name = "Nest"
	local radius = 4.5 * scale
	for ring = 0, 2 do
		local r = radius - ring * 0.8 * scale
		local count = 14
		for i = 1, count do
			local a = i / count * math.pi * 2 + ring * 0.3
			local pos = at + Vector3.new(math.cos(a) * r, 0.3 + ring * 0.45 * scale, math.sin(a) * r)
			twig(
				model,
				CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a)))
					* CFrame.Angles(0, math.rad(90), math.rad(math.random(-15, 15))),
				2.6 * scale
			)
		end
	end
	local bed = Instance.new("Part")
	bed.Name = "Bed"
	bed.Shape = Enum.PartType.Cylinder
	bed.Anchored = true
	bed.CanCollide = false
	bed.Size = Vector3.new(0.5, radius * 1.8, radius * 1.8)
	bed.CFrame = CFrame.new(at + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90))
	bed.Color = Color3.fromRGB(190, 160, 90)
	bed.Material = Enum.Material.Grass
	bed.Parent = model

	local eggModel = EggBuilder.Build(egg)
	eggModel:PivotTo(CFrame.new(at + Vector3.new(0, 0.5, 0)))
	eggModel.Parent = model
	local shell = eggModel:FindFirstChild("Shell") :: BasePart

	local def = Creatures[egg.Species]
	local gui = Instance.new("BillboardGui")
	gui.Name = "NestMarker"
	gui.Size = UDim2.fromOffset(220, 50)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 8 * scale + 6, 0)
	gui.MaxDistance = 450
	gui.Parent = shell
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Rarities[def.Rarity].Color
	label.Text = "🪺 "
		.. CreatureMath.DisplayName({ Id = egg.Species, Level = 1, Xp = 0, Size = egg.Size })
		.. " nest"
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = label

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "NestEggPrompt"
	prompt.ActionText = "Grab Egg"
	prompt.ObjectText = def.Name .. " egg"
	prompt.HoldDuration = 1 + (Breeding.TierIndex(egg.Size) - 1) * 0.5
	prompt.MaxActivationDistance = 10 + radius
	prompt.RequiresLineOfSight = false
	prompt.Parent = shell
	model.Parent = folder
	return model
end

function NestService:Spawn(): boolean
	local spot = Wild:_randomSpot(nil)
	if not spot then
		return false
	end
	local species = Wild:_pickSpecies()
	if not species then
		return false
	end
	local size = Breeding.RollNestSize(math.random())
	local egg = {
		Species = species,
		Mutation = nil,
		Size = size,
		Bonus = math.floor(math.random() * NEST.BonusMax * 1000) / 1000,
		Source = "Nest",
	}
	local scale = EggBuilder.Scale(size)
	local model = self:_buildNest(egg, spot, scale)
	local nest: Nest = {
		Egg = egg,
		Model = model,
		Guardians = {},
		ExpiresAt = os.clock() + NEST.Lifetime,
	}
	local count = math.random(NEST.Guardians[1], NEST.Guardians[2])
	for i = 1, count do
		local a = i / count * math.pi * 2
		local at = spot + Vector3.new(math.cos(a), 0, math.sin(a)) * (8 + scale * 4)
		local guardSize = size * (NEST.GuardianSize[1] + math.random() * (NEST.GuardianSize[2] - NEST.GuardianSize[1]))
		local guardian = Wild:SpawnGuardian(species, Map:GroundAt(at) or at, guardSize)
		if guardian then
			table.insert(nest.Guardians, guardian)
		end
	end
	local prompt = model:FindFirstChild("NestEggPrompt", true) :: ProximityPrompt
	prompt.Triggered:Connect(function(player)
		self:_grab(player, nest)
	end)
	table.insert(self.Nests, nest)
	local def = Creatures[species]
	if Breeding.TierIndex(size) >= 4 or Rarities[def.Rarity].Announce then
		Net.NotifyAll(
			"🪺 A "
				.. CreatureMath.DisplayName({ Id = species, Level = 1, Xp = 0, Size = size })
				.. " nest appeared in the wild! Watch out for its guardians!",
			Rarities[def.Rarity].Color
		)
	end
	log:Info("nest", species, size, "guardians", #nest.Guardians)
	return true
end

function NestService:_grab(player: Player, nest: Nest)
	if not table.find(self.Nests, nest) then
		return
	end
	if player:GetAttribute("CarryingEgg") or player:GetAttribute("Carrying") then
		Net.Notify(player, "🥚 Your hands are full!", RED)
		return
	end
	if not Carry:StartCarry(player, nest.Egg, nil) then
		return
	end
	local at = nest.Model:GetPivot().Position
	-- Guardians get angry at the thief.
	for _, guardian in nest.Guardians do
		if not guardian.Removed and not guardian.Asleep then
			guardian.LastAttacker = player
			guardian.LastHitAt = workspace:GetServerTimeNow()
		end
	end
	Fx:PlayAll("StealStart", { Position = at })
	Net.Notify(player, "🥚 Got the egg! Run home before the guardians catch you!", Color3.fromRGB(255, 210, 60))
	self:_remove(nest, false)
end

-- Removes a nest. Guardians leave with it when it expires; after a raid
-- they stay angry for a while and then wander off on their own.
function NestService:_remove(nest: Nest, expired: boolean)
	local index = table.find(self.Nests, nest)
	if index then
		table.remove(self.Nests, index)
	end
	local at = nest.Model:GetPivot().Position
	nest.Model:Destroy()
	for _, guardian in nest.Guardians do
		if not guardian.Removed then
			if expired then
				Wild:Remove(guardian, "Poof")
			else
				guardian.Guard = false -- normal wild titan again (despawns later)
			end
		end
	end
	if expired then
		Fx:PlayAll("Poof", { Position = at })
	end
	nextSpawnAt = os.clock() + NEST.RespawnDelay
end

return NestService
