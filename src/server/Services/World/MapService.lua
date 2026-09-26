--[[
	MapService: loads the map and indexes its tagged markers.

	If Workspace has no map with ZooPlot markers, it generates one
	(Modules/Map/MapGenerator). A hand-built map works the same way as long
	as it uses the tags in shared/Game/Tags.lua (see docs/MAP_GUIDE.md).

	  MapService:GetBiomeAt(position) -> biomeId or nil (hub / outside)
	  MapService.FoodSpawns[biomeId], .WildSpawns[biomeId] -> { BasePart }
	  MapService.Gates[biomeId] -> { Part, Outside: CFrame }
	  MapService.PlotAnchors -> { BasePart } sorted by PlotIndex
	  MapService:RandomMeteorPoint() -> Vector3
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Tags = require(Shared.Game.Tags)
local Zones = require(Shared.Game.Zones)
local Log = require(Shared.Lib.Log)

local MapGenerator = require(ServerScriptService:WaitForChild("Server").Modules.Map.MapGenerator)

local log = Log.new("MapService")

local MapService = {
	Priority = 5,
	Zones = {} :: { Zones.Zone },
	FoodSpawns = {} :: { [string]: { BasePart } },
	WildSpawns = {} :: { [string]: { BasePart } },
	Gates = {} :: { [string]: { Part: BasePart, Outside: CFrame } },
	PlotAnchors = {} :: { BasePart },
	MeteorZones = {} :: { BasePart },
	HubSpawn = CFrame.new(0, 5, 0),
	Map = nil :: Instance?,
}

local function byBiome(tag: string): { [string]: { BasePart } }
	local result = {}
	for _, part in CollectionService:GetTagged(tag) do
		local biome = part:GetAttribute("Biome")
		if part:IsA("BasePart") and type(biome) == "string" then
			result[biome] = result[biome] or {}
			table.insert(result[biome], part)
		end
	end
	return result
end

local function ensure(className: string, parent: Instance): Instance
	local existing = parent:FindFirstChildWhichIsA(className)
	if existing then
		return existing
	end
	local inst = Instance.new(className)
	inst.Parent = parent
	return inst
end

-- Base lighting. The client BiomeController fades per-biome ambience on top.
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
	bloom.Intensity = 0.8
	bloom.Size = 24
	bloom.Threshold = 1.2
	local color = ensure("ColorCorrectionEffect", Lighting) :: ColorCorrectionEffect
	color.Name = "BaseColor"
	color.Saturation = 0.15
	color.Contrast = 0.05
	local rays = ensure("SunRaysEffect", Lighting) :: SunRaysEffect
	rays.Intensity = 0.05
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
	if #CollectionService:GetTagged(Tags.ZooPlot) == 0 then
		self.Map = MapGenerator.Generate()
	else
		self.Map = Workspace:FindFirstChild("Map")
		log:Info("using hand-built map")
	end

	for _, part in CollectionService:GetTagged(Tags.BiomeZone) do
		if part:IsA("BasePart") then
			table.insert(self.Zones, Zones.FromPart(part))
		end
	end
	self.FoodSpawns = byBiome(Tags.FoodSpawn)
	self.WildSpawns = byBiome(Tags.WildSpawn)

	for _, gate in CollectionService:GetTagged(Tags.BiomeGate) do
		local biome = gate:GetAttribute("Biome")
		if gate:IsA("BasePart") and type(biome) == "string" then
			-- The gate's front (-Z) faces INTO the biome; "outside" is behind it.
			local outside = gate.Position - gate.CFrame.LookVector * 14
			outside = Vector3.new(outside.X, gate.Position.Y - gate.Size.Y / 2 + 4, outside.Z)
			self.Gates[biome] = { Part = gate, Outside = CFrame.lookAt(outside, outside - gate.CFrame.LookVector) }
		end
	end

	for _, anchor in CollectionService:GetTagged(Tags.ZooPlot) do
		if anchor:IsA("BasePart") then
			table.insert(self.PlotAnchors, anchor)
		end
	end
	table.sort(self.PlotAnchors, function(a, b)
		return (a:GetAttribute("PlotIndex") or 0) < (b:GetAttribute("PlotIndex") or 0)
	end)

	self.MeteorZones = CollectionService:GetTagged(Tags.MeteorZone)
	local hub = CollectionService:GetTagged(Tags.HubSpawn)[1]
	if hub and hub:IsA("BasePart") then
		self.HubSpawn = hub.CFrame + Vector3.new(0, 4, 0)
	end

	self:_publishZones()

	if #self.PlotAnchors < GameConfig.Zoo.PlotCount then
		log:Warn(
			string.format("map has %d zoo plots but Zoo.PlotCount is %d", #self.PlotAnchors, GameConfig.Zoo.PlotCount)
		)
	end
	log:Info(string.format("%d biome zones, %d zoo plots", #self.Zones, #self.PlotAnchors))
end

-- Copies zone shapes to ReplicatedStorage so clients know them even when
-- StreamingEnabled hasn't sent the far-away marker parts.
function MapService:_publishZones()
	local info = Instance.new("Folder")
	info.Name = "MapInfo"
	for i, zone in self.Zones do
		local entry = Instance.new("Configuration")
		entry.Name = "Zone" .. i
		entry:SetAttribute("Biome", zone.Biome)
		entry:SetAttribute("Center", zone.Center)
		entry:SetAttribute("Radius", zone.Radius)
		entry:SetAttribute("CFrame", zone.CFrame)
		entry:SetAttribute("Size", zone.Size)
		entry.Parent = info
	end
	info.Parent = ReplicatedStorage
end

function MapService:GetBiomeAt(position: Vector3): string?
	return Zones.Find(self.Zones, position)
end

function MapService:RandomMeteorPoint(): Vector3
	local zone = self.MeteorZones[math.random(1, math.max(1, #self.MeteorZones))]
	local center = if zone then zone.Position else Vector3.zero
	local radius = if zone then (zone:GetAttribute("Radius") or 60) else 60
	local r = radius * math.sqrt(math.random())
	local a = math.random() * math.pi * 2
	local point = center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(point + Vector3.new(0, 300, 0), Vector3.new(0, -600, 0), params)
	return if hit then hit.Position else point
end

return MapService
