--[[
	MapService: loads the map and indexes its tagged markers.

	If Workspace has no map with Plot markers, it generates Titan Island
	(Modules/Map/MapGenerator). A hand-built map works the same way as long
	as it uses the tags in shared/Game/Tags.lua (see docs/MAP_GUIDE.md).

	  MapService.PlotAnchors  -> { BasePart } sorted by PlotIndex
	  MapService.FoodSpawns   -> { BasePart }
	  MapService.WildSpawns   -> { BasePart } (falls back to FoodSpawns)
	  MapService.Arena        -> { Center: Vector3, Radius: number }
	  MapService.ArenaSpawns  -> { CFrame }
	  MapService.Stands       -> { CFrame }
	  MapService.Leaderboards -> { BasePart }
	  MapService:RandomMeteorPoint() -> Vector3
	  MapService:IsInArena(position) -> boolean
	  MapService:GroundAt(position) -> Vector3? (nil over water)
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Tags = require(Shared.Game.Tags)
local Log = require(Shared.Lib.Log)

local MapGenerator = require(ServerScriptService:WaitForChild("Server").Modules.Map.MapGenerator)

local log = Log.new("MapService")

local MapService = {
	Priority = 5,
	PlotAnchors = {} :: { BasePart },
	FoodSpawns = {} :: { BasePart },
	WildSpawns = {} :: { BasePart },
	Arena = { Center = Vector3.zero, Radius = 90 },
	ArenaSpawns = {} :: { CFrame },
	Stands = {} :: { CFrame },
	Leaderboards = {} :: { BasePart },
	MeteorZones = {} :: { BasePart },
	HubSpawn = CFrame.new(0, 5, 0),
	Map = nil :: Instance?,
}

local function ensure(className: string, parent: Instance): Instance
	local existing = parent:FindFirstChildWhichIsA(className)
	if existing then
		return existing
	end
	local inst = Instance.new(className)
	inst.Parent = parent
	return inst
end

-- Base lighting (events like Blood Moon tint it on top).
local function setupLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 160)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	local atmosphere = ensure("Atmosphere", Lighting) :: Atmosphere
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(200, 220, 255)
	atmosphere.Decay = Color3.fromRGB(110, 130, 170)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.5
	local bloom = ensure("BloomEffect", Lighting) :: BloomEffect
	-- Low threshold = Neon parts, auras and effects glow (the "shiny" look).
	bloom.Intensity = 1
	bloom.Size = 28
	bloom.Threshold = 0.95
	local color = ensure("ColorCorrectionEffect", Lighting) :: ColorCorrectionEffect
	color.Name = "BaseColor"
	color.Saturation = 0.25
	color.Contrast = 0.08
	local rays = ensure("SunRaysEffect", Lighting) :: SunRaysEffect
	rays.Intensity = 0.05
end

local function parts(tag: string): { BasePart }
	local list = {}
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsA("BasePart") then
			table.insert(list, inst)
		end
	end
	return list
end

function MapService:Start()
	setupLighting()
	if GameConfig.ReplaceBaseplate then
		-- Remove the default Baseplate template parts (the map replaces them).
		for _, name in { "Baseplate", "SpawnLocation" } do
			local part = Workspace:FindFirstChild(name)
			if part then
				part:Destroy()
			end
		end
	end
	if #CollectionService:GetTagged(Tags.Plot) == 0 then
		self.Map = MapGenerator.Generate()
	else
		self.Map = Workspace:FindFirstChild("Map")
		log:Info("using hand-built map")
	end

	self.PlotAnchors = parts(Tags.Plot)
	table.sort(self.PlotAnchors, function(a, b)
		return (a:GetAttribute("PlotIndex") or 0) < (b:GetAttribute("PlotIndex") or 0)
	end)
	self.FoodSpawns = parts(Tags.FoodSpawn)
	self.WildSpawns = parts(Tags.WildSpawn)
	if #self.WildSpawns == 0 then
		log:Warn("map has no WildSpawn markers; wild titans use food spawns")
		self.WildSpawns = self.FoodSpawns
	end
	self.MeteorZones = parts(Tags.MeteorZone)
	self.Leaderboards = parts(Tags.Leaderboard)

	local arena = parts(Tags.Arena)[1]
	if arena then
		local radius = arena:GetAttribute("Radius")
		self.Arena = { Center = arena.Position, Radius = if type(radius) == "number" then radius else 90 }
	else
		log:Warn("map has no Arena marker; battles use the map center")
	end
	for _, spawnPart in parts(Tags.ArenaSpawn) do
		table.insert(self.ArenaSpawns, spawnPart.CFrame)
	end
	if #self.ArenaSpawns < 2 then
		log:Warn("map needs at least 2 ArenaSpawn markers; making some")
		for i = 1, 8 do
			local a = i / 8 * math.pi * 2
			local p = self.Arena.Center
				+ Vector3.new(math.cos(a), 0, math.sin(a)) * self.Arena.Radius * 0.7
				+ Vector3.new(0, 3, 0)
			table.insert(self.ArenaSpawns, CFrame.lookAt(p, self.Arena.Center + Vector3.new(0, 3, 0)))
		end
	end
	for _, standPart in parts(Tags.Stands) do
		table.insert(self.Stands, standPart.CFrame)
	end
	local hub = parts(Tags.HubSpawn)[1]
	if hub then
		self.HubSpawn = hub.CFrame + Vector3.new(0, 4, 0)
	end

	if #self.PlotAnchors < GameConfig.Plots.Count then
		log:Warn(string.format("map has %d plots but Plots.Count is %d", #self.PlotAnchors, GameConfig.Plots.Count))
	end
	log:Info(
		string.format(
			"%d plots, %d food spawns, %d arena spawns",
			#self.PlotAnchors,
			#self.FoodSpawns,
			#self.ArenaSpawns
		)
	)
end

function MapService:IsInArena(position: Vector3, margin: number?): boolean
	local offset = position - self.Arena.Center
	local r = self.Arena.Radius + (margin or 0)
	return offset.X * offset.X + offset.Z * offset.Z <= r * r
end

-- Random point in the food fields (a ring around the arena).
function MapService:RandomMeteorPoint(): Vector3
	local zone = self.MeteorZones[math.random(1, math.max(1, #self.MeteorZones))]
	local center = if zone then zone.Position else Vector3.zero
	local outer = if zone then (zone:GetAttribute("Radius") or 60) else 60
	local inner = if zone then (zone:GetAttribute("InnerRadius") or 0) else 0
	local r = math.sqrt(inner * inner + math.random() * (outer * outer - inner * inner))
	local a = math.random() * math.pi * 2
	local point = center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	return self:GroundAt(point) or point
end

-- Ground surface (terrain or the stud ground) below a point, or nil over water.
function MapService:GroundAt(point: Vector3): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local filter: { Instance } = { Workspace.Terrain }
	local ground = self.Map and self.Map:FindFirstChild("Ground")
	if ground then
		table.insert(filter, ground)
	end
	params.FilterDescendantsInstances = filter
	local hit = Workspace:Raycast(point + Vector3.new(0, 300, 0), Vector3.new(0, -600, 0), params)
	if not hit or hit.Material == Enum.Material.Water then
		return nil
	end
	return hit.Position
end

return MapService
