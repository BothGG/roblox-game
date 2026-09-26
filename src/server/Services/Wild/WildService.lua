--[[
	WildService: wild kaiju roaming the biomes, and catching them.

	- Each biome keeps up to Biomes[id].MaxWild wild kaiju (species from
	  Biomes[id].Wild). Rare ones are announced to the whole server.
	- Hold the "Catch" prompt (longer for rarer kaiju). Success chance comes
	  from Config/Rarities.lua; if it fails, the kaiju runs away.
	- Movement: the server picks a target and writes MoveFrom / MoveTo /
	  MoveStart / MoveDuration attributes; clients animate smoothly
	  (client WildController). The server snaps the model at the end.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Biomes = require(Shared.Config.Biomes)
local Creatures = require(Shared.Config.Creatures)
local GameConfig = require(Shared.Config.GameConfig)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local CreatureMath = require(Shared.Game.CreatureMath)
local Rules = require(Shared.Game.Rules)
local Tags = require(Shared.Game.Tags)
local Log = require(Shared.Lib.Log)
local WeightedRandom = require(Shared.Lib.WeightedRandom)
local Net = require(Shared.Net)

local CreatureBuilder = require(ServerScriptService:WaitForChild("Server").Modules.CreatureBuilder)

local log = Log.new("WildService")

local RED = Color3.fromRGB(255, 90, 90)
local WILD = GameConfig.Wild

type Wild = {
	Id: string,
	Mutation: string?,
	Biome: string,
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
	Counts = {} :: { [string]: number },
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

	for _, biomeId in Biomes.Order do
		self.Counts[biomeId] = 0
		if not Map.WildSpawns[biomeId] or #Map.WildSpawns[biomeId] == 0 then
			log:Warn("biome", biomeId, "has no WildSpawn markers")
			continue
		end
		task.spawn(function()
			while true do
				if self.Counts[biomeId] < Biomes[biomeId].MaxWild then
					self:Spawn(biomeId)
				end
				task.wait(WILD.RespawnDelay * (0.7 + math.random() * 0.6))
			end
		end)
	end

	-- Movement + lifetime tick
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
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(position + Vector3.new(0, 60, 0), Vector3.new(0, -160, 0), params)
	if hit and hit.Material ~= Enum.Material.Water then
		return hit.Position
	end
	return nil
end

local function nameTag(model: Model, creatureId: string, mutation: string?)
	local def = Creatures[creatureId]
	local rarity = Rarities[def.Rarity]
	local gui = Instance.new("BillboardGui")
	gui.Name = "WildTag"
	gui.Size = UDim2.fromOffset(200, 50)
	gui.StudsOffsetWorldSpace = Vector3.new(0, model:GetExtentsSize().Y + 1.5, 0)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	gui.Parent = model.PrimaryPart
	local function line(text: string, color: Color3, y: number, h: number)
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
	end
	local name = CreatureMath.DisplayName({ Id = creatureId, Level = 1, Xp = 0, Mutation = mutation })
	line(name, if mutation then Mutations[mutation].Color else rarity.Color, 0, 0.6)
	line("Wild • " .. def.Rarity, Color3.fromRGB(220, 220, 220), 0.6, 0.4)
end

function WildService:Spawn(biomeId: string, forcedId: string?)
	local biome = Biomes[biomeId]
	local spawns = Map.WildSpawns[biomeId]
	if not biome or not spawns or #spawns == 0 then
		return
	end
	local creatureId = forcedId
	if not creatureId then
		local entry = WeightedRandom.Pick(biome.Wild, function(e)
			return e.Weight
		end)
		creatureId = entry and entry.Creature
	end
	if not creatureId then
		return
	end
	local mutation = nil
	if math.random() < WILD.MutationChance then
		local pick = WeightedRandom.Pick(Mutations.HatchPool, function(e)
			return e.Weight
		end)
		mutation = pick and pick.Id
	end

	local spawnPart = spawns[math.random(1, #spawns)]
	local home = spawnPart.Position
	local model = CreatureBuilder.Build({ Id = creatureId, Level = 1, Xp = 0, Mutation = mutation })
	model.Name = "Wild_" .. creatureId
	model:SetAttribute("Wild", true)
	model.Parent = self._folder
	local start = CFrame.new(home) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
	model:PivotTo(start)
	nameTag(model, creatureId, mutation)
	CollectionService:AddTag(model, Tags.WildCreature)

	local rarity = Rarities[Creatures[creatureId].Rarity]
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CatchPrompt"
	prompt.ActionText = "Catch"
	prompt.ObjectText = Creatures[creatureId].Name .. " (" .. rarity.Id .. ")"
	prompt.HoldDuration = Rules.CatchTime(creatureId)
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart

	local now = Workspace:GetServerTimeNow()
	local wild: Wild = {
		Id = creatureId,
		Mutation = mutation,
		Biome = biomeId,
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
	self.Counts[biomeId] += 1

	prompt.Triggered:Connect(function(player)
		self:TryCatch(player, wild)
	end)

	if rarity.Announce or mutation then
		Net.NotifyAll(
			string.format(
				"%s A %s %s appeared in the %s!",
				biome.Icon,
				string.upper(rarity.Id),
				CreatureMath.DisplayName({ Id = creatureId, Level = 1, Xp = 0, Mutation = mutation }),
				biome.Name
			),
			rarity.Color
		)
		Fx:PlayAll("RareSpawn", { Position = home, Color = rarity.Color })
	end
end

function WildService:_remove(wild: Wild)
	if not self.Wilds[wild.Model] then
		return
	end
	self.Wilds[wild.Model] = nil
	self.Counts[wild.Biome] -= 1
	wild.Model:Destroy()
end

--------------------------------------------------------------------------
-- Movement
--------------------------------------------------------------------------

-- Where the kaiju is right now (lerped along its current move).
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
		if now >= wild.ExpiresAt then
			Fx:PlayAll("Poof", { Position = wild.Model:GetPivot().Position })
			self:_remove(wild)
			continue
		end
		local arrived = now >= wild.MoveStart + wild.MoveDuration
		if arrived and wild.MoveDuration > 0 then
			-- Snap the real model to where clients animated it.
			wild.Model:PivotTo(wild.To)
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
	if not ground then
		wild.MoveStart = now + 2
		return
	end
	local from = wild.Model:GetPivot()
	local to = CFrame.lookAt(ground, ground + (ground - from.Position) * Vector3.new(1, 0, 1))
	if (ground - from.Position).Magnitude < 1 then
		to = CFrame.new(ground) * from.Rotation
	end
	local duration = math.max(0.5, (ground - from.Position).Magnitude / WILD.MoveSpeed)
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
-- Catching
--------------------------------------------------------------------------

function WildService:TryCatch(player: Player, wild: Wild)
	if wild.Taken or not self.Wilds[wild.Model] then
		return
	end
	local data = Data:Get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not data or not root then
		return
	end
	if not Rules.IsBiomeUnlocked(data, wild.Biome) then
		return
	end
	local position = self:CurrentCFrame(wild).Position
	if (root.Position - position).Magnitude > WILD.CatchDistance + wild.Model:GetExtentsSize().X then
		return
	end
	if not Rules.HasFreeSlot(data) then
		Net.Notify(
			player,
			"🏠 Your zoo is full! Sell a " .. GameConfig.CreatureName .. " or Rebirth for more room.",
			RED
		)
		return
	end

	wild.Taken = true
	local def = Creatures[wild.Id]
	local rarity = Rarities[def.Rarity]
	if math.random() > Rules.CatchChance(wild.Id) then
		Fx:PlayAll("CatchFail", { Position = position, Target = player.UserId })
		Net.Notify(player, "💨 The " .. def.Name .. " got away!", RED)
		self:_remove(wild)
		return
	end

	Fx:PlayAll("CatchSuccess", { Position = position, Color = rarity.Color, Owner = player.UserId })
	self:_remove(wild)
	local uid = Creature:Add(player, wild.Id, wild.Mutation)
	if not uid then
		return
	end
	data.Stats.Caught += 1
	Net.Fire(player, "Hatched", {
		CreatureId = wild.Id,
		Mutation = wild.Mutation,
		Source = "Catch",
	})
	if rarity.Announce or wild.Mutation then
		Net.NotifyAll(
			string.format(
				"🎯 %s caught a %s %s!",
				player.DisplayName,
				string.upper(rarity.Id),
				CreatureMath.DisplayName({ Id = wild.Id, Level = 1, Xp = 0, Mutation = wild.Mutation })
			),
			rarity.Color
		)
	end
	Data:Changed(player)
end

return WildService
