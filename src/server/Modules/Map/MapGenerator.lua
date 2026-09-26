--[[
	MapGenerator: builds the placeholder big land from code.

	  Zoo hub in the middle (plaza, fountain, zoo plots, ring road)
	  6 biomes in a circle around it, each with its own terrain + props
	  Paths from the ring road to each biome, with a gate at the entrance

	It also creates the tagged MARKERS (see shared/Game/Tags.lua) that the
	rest of the game uses. A hand-built map only needs those markers.

	Layout numbers come from GameConfig.Map / GameConfig.Zoo.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Biomes = require(Shared.Config.Biomes)
local Tags = require(Shared.Game.Tags)
local Log = require(Shared.Lib.Log)

local Props = require(script.Parent.Props)

local log = Log.new("MapGenerator")

local MapGenerator = {}

local terrain = Workspace.Terrain
local MAP = GameConfig.Map
local ZOO = GameConfig.Zoo

local PLAZA_RADIUS = 60
local RING_ROAD_RADIUS = ZOO.RingRadius + ZOO.PlotSize / 2 + 30
local PATH_WIDTH = 20

type Context = {
	Map: Folder,
	Markers: Folder,
	Props: Folder,
	Rng: Random,
}

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function marker(ctx: Context, tag: string, cf: CFrame, size: Vector3, attributes: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Name = tag
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = size
	p.CFrame = cf
	local attrs: { [string]: any } = attributes or {}
	for key, value in attrs do
		p:SetAttribute(key, value)
	end
	CollectionService:AddTag(p, tag)
	p.Parent = ctx.Markers
	return p
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function biomeCenter(index: number): (Vector3, Vector3)
	local angle = (index - 1) / #Biomes.Order * math.pi * 2
	local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
	return dir * MAP.BiomeDistance, dir
end

-- Finds the terrain surface at (x, z). Returns nil over water.
local function groundAt(x: number, z: number): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { terrain }
	params.IgnoreWater = false
	local result = Workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), params)
	if not result or result.Material == Enum.Material.Water then
		return nil
	end
	return result.Position
end

-- Random ground point inside a ring (minRadius..maxRadius) around center.
-- maxY skips high spots (mountain tops) so gameplay things stay reachable.
local function randomGround(
	ctx: Context,
	center: Vector3,
	minRadius: number,
	maxRadius: number,
	maxY: number?
): Vector3?
	for _ = 1, 16 do
		local r = math.sqrt(ctx.Rng:NextNumber((minRadius / maxRadius) ^ 2, 1)) * maxRadius
		local a = ctx.Rng:NextNumber(0, math.pi * 2)
		local ground = groundAt(center.X + math.cos(a) * r, center.Z + math.sin(a) * r)
		if ground and ground.Y <= (maxY or math.huge) then
			return ground
		end
	end
	return nil
end

local SPAWN_MAX_Y = 14

local function disc(center: Vector3, radius: number, topY: number, depth: number, material: Enum.Material)
	terrain:FillCylinder(CFrame.new(center.X, topY - depth / 2, center.Z), depth, radius, material)
end

--------------------------------------------------------------------------
-- Base land
--------------------------------------------------------------------------

local function buildBase(ctx: Context)
	terrain:Clear()
	terrain.WaterColor = Color3.fromRGB(40, 150, 200)
	terrain.WaterTransparency = 0.6
	terrain.WaterWaveSize = 0.1
	terrain.WaterReflectance = 0.4
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(110, 185, 85))
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(85, 160, 70))
	terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(240, 215, 150))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(165, 130, 90))
	terrain:SetMaterialColor(Enum.Material.Pavement, Color3.fromRGB(190, 185, 180))
	terrain:SetMaterialColor(Enum.Material.Snow, Color3.fromRGB(240, 245, 255))
	terrain:SetMaterialColor(Enum.Material.Basalt, Color3.fromRGB(60, 55, 55))

	local size = MAP.Size
	terrain:FillBlock(CFrame.new(0, -8, 0), Vector3.new(size, 16, size), Enum.Material.Grass)
	-- Ocean border so the land looks like an island
	local border = 70
	for _, info in
		{
			{ Vector3.new(0, 0, size / 2 - border / 2), Vector3.new(size, 1, border) },
			{ Vector3.new(0, 0, -size / 2 + border / 2), Vector3.new(size, 1, border) },
			{ Vector3.new(size / 2 - border / 2, 0, 0), Vector3.new(border, 1, size) },
			{ Vector3.new(-size / 2 + border / 2, 0, 0), Vector3.new(border, 1, size) },
		}
	do
		terrain:FillBlock(
			CFrame.new(info[1] - Vector3.new(0, 6, 0)),
			info[2] + Vector3.new(0, 11, 0),
			Enum.Material.Water
		)
	end
	-- Invisible walls at the edge
	for _, info in
		{
			{ Vector3.new(0, 100, size / 2), Vector3.new(size, 200, 2) },
			{ Vector3.new(0, 100, -size / 2), Vector3.new(size, 200, 2) },
			{ Vector3.new(size / 2, 100, 0), Vector3.new(2, 200, size) },
			{ Vector3.new(-size / 2, 100, 0), Vector3.new(2, 200, size) },
		}
	do
		Props.Part(ctx.Map, {
			Name = "EdgeWall",
			Size = info[2],
			CFrame = CFrame.new(info[1]),
			Transparency = 1,
			CanQuery = false,
		})
	end
end

--------------------------------------------------------------------------
-- Hub (zoo area)
--------------------------------------------------------------------------

local function buildHub(ctx: Context)
	local hub = folder(ctx.Map, "Hub")
	disc(Vector3.zero, PLAZA_RADIUS, 0.5, 3, Enum.Material.Pavement)
	-- Ring road around the zoos
	for r = RING_ROAD_RADIUS - PATH_WIDTH / 2, RING_ROAD_RADIUS + PATH_WIDTH / 2, 4 do
		local steps = math.floor(2 * math.pi * r / 6)
		for i = 1, steps do
			local a = i / steps * math.pi * 2
			terrain:FillBlock(
				CFrame.new(math.cos(a) * r, -0.5, math.sin(a) * r),
				Vector3.new(6, 2, 6),
				Enum.Material.Ground
			)
		end
	end

	Props.Fountain(hub, Vector3.new(0, 0.5, 0))
	for i = 1, 8 do
		local a = (i + 0.5) / 8 * math.pi * 2
		Props.Lamp(hub, Vector3.new(math.cos(a), 0, math.sin(a)) * (PLAZA_RADIUS - 6) + Vector3.new(0, 0.5, 0))
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, 1, 30)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = hub
	CollectionService:AddTag(spawn, Tags.HubSpawn)

	-- Zoo plot anchors: the ZooService builds each zoo on these.
	for i = 1, ZOO.PlotCount do
		local a = (i - 0.5) / ZOO.PlotCount * math.pi * 2
		local position = Vector3.new(math.cos(a), 0, math.sin(a)) * ZOO.RingRadius
		local cf = CFrame.lookAt(position, Vector3.zero)
		disc(position, ZOO.PlotSize * 0.72, 0.5, 3, Enum.Material.Grass)
		marker(ctx, Tags.ZooPlot, cf, Vector3.new(ZOO.PlotSize, 1, ZOO.PlotSize), { PlotIndex = i })
	end
end

--------------------------------------------------------------------------
-- Paths, gates and signposts
--------------------------------------------------------------------------

local function buildPath(ctx: Context, biomeId: string, index: number)
	local biome = Biomes[biomeId]
	local _, dir = biomeCenter(index)
	local startR = RING_ROAD_RADIUS
	local endR = MAP.BiomeDistance - MAP.BiomeRadius
	local length = endR - startR
	local mid = dir * (startR + length / 2)
	local cf = CFrame.lookAt(mid, mid + dir)
	terrain:FillBlock(cf * CFrame.new(0, -0.5, 0), Vector3.new(PATH_WIDTH, 2, length + 10), Enum.Material.Ground)

	local paths = ctx.Map:FindFirstChild("Paths") or folder(ctx.Map, "Paths")
	Props.Signpost(
		paths,
		dir * (startR + 14) + Vector3.new(0, 0, 0) + dir:Cross(Vector3.yAxis) * (PATH_WIDTH / 2 + 3),
		-dir,
		biome.Icon .. " " .. biome.Name,
		biome.Color:Lerp(Color3.new(0, 0, 0), 0.3)
	)

	-- Gate at the biome entrance
	local gatePos = dir * (endR - 6)
	local gateCf = CFrame.lookAt(gatePos, gatePos + dir)
	Props.GateArch(paths, gateCf, PATH_WIDTH, biome.Color:Lerp(Color3.new(0, 0, 0), 0.4))
	local barrier = Props.Part(ctx.Markers, {
		Name = "Gate_" .. biomeId,
		Size = Vector3.new(PATH_WIDTH, 16, 1),
		CFrame = gateCf * CFrame.new(0, 8, 0),
		Color = biome.Color,
		Material = Enum.Material.ForceField,
		Transparency = 0.2,
	})
	barrier:SetAttribute("Biome", biomeId)
	CollectionService:AddTag(barrier, Tags.BiomeGate)

	-- Bridge over any water between the gate and the biome (e.g. Star Island)
	local bridge = folder(paths, "Bridge_" .. biomeId)
	for d = endR - 4, MAP.BiomeDistance, 4 do
		local p = dir * d
		if not groundAt(p.X, p.Z) then
			Props.Part(bridge, {
				Name = "Plank",
				Size = Vector3.new(PATH_WIDTH - 4, 1, 4.2),
				CFrame = CFrame.lookAt(p + Vector3.new(0, 1, 0), p + Vector3.new(0, 1, 0) + dir),
				Color = Color3.fromRGB(140, 100, 60),
				Material = Enum.Material.WoodPlanks,
			})
		end
	end
	if #bridge:GetChildren() == 0 then
		bridge:Destroy()
	end
end

--------------------------------------------------------------------------
-- Biomes
--------------------------------------------------------------------------

local BIOME_TERRAIN = {}

function BIOME_TERRAIN.Forest(ctx: Context, center: Vector3, radius: number, biome)
	disc(center, radius, 0.5, 4, biome.Terrain.Ground)
	for _ = 1, 8 do
		local offset = Vector3.new(ctx.Rng:NextNumber(-1, 1), 0, ctx.Rng:NextNumber(-1, 1)) * radius * 0.7
		terrain:FillBall(center + offset - Vector3.new(0, 20, 0), ctx.Rng:NextNumber(24, 32), biome.Terrain.Detail)
	end
end

function BIOME_TERRAIN.Beach(ctx: Context, center: Vector3, radius: number, biome, dir: Vector3)
	disc(center, radius, 0.5, 4, biome.Terrain.Ground)
	-- Sea on the far side
	disc(center + dir * radius * 0.85, radius * 0.75, 0, 12, Enum.Material.Water)
	for _ = 1, 6 do
		local p = center + Vector3.new(ctx.Rng:NextNumber(-1, 1), 0, ctx.Rng:NextNumber(-1, 1)) * radius * 0.5
		terrain:FillBall(p - Vector3.new(0, 6, 0), ctx.Rng:NextNumber(8, 12), biome.Terrain.Detail)
	end
end

function BIOME_TERRAIN.Snow(ctx: Context, center: Vector3, radius: number, biome, dir: Vector3)
	disc(center, radius, 0.5, 4, biome.Terrain.Ground)
	-- Mountains at the back
	for i = -1, 1 do
		local side = dir:Cross(Vector3.yAxis) * i * radius * 0.45
		local p = center + dir * radius * 0.55 + side
		local r = ctx.Rng:NextNumber(55, 75)
		terrain:FillBall(p - Vector3.new(0, r * 0.45, 0), r, Enum.Material.Rock)
		terrain:FillBall(p - Vector3.new(0, r * 0.4, 0), r * 0.92, biome.Terrain.Ground)
	end
	for _ = 1, 5 do
		local p = center + Vector3.new(ctx.Rng:NextNumber(-1, 1), 0, ctx.Rng:NextNumber(-1, 1)) * radius * 0.5
		terrain:FillBall(p - Vector3.new(0, 10, 0), ctx.Rng:NextNumber(12, 18), biome.Terrain.Detail)
	end
end

function BIOME_TERRAIN.Volcano(ctx: Context, center: Vector3, radius: number, biome, dir: Vector3)
	disc(center, radius, 0.5, 4, biome.Terrain.Ground)
	local peak = center + dir * radius * 0.35
	-- Stepped cone (4 stud steps, so players can climb it)
	local layers = 18
	for i = 0, layers - 1 do
		local r = 70 - i * 3.3
		disc(peak, r, 4 + i * 4, 4, if i % 4 == 3 then Enum.Material.Rock else biome.Terrain.Ground)
	end
	disc(peak, 10, 4 + layers * 4 - 1, 4, biome.Terrain.Detail)
	for _ = 1, 6 do
		local p = center + Vector3.new(ctx.Rng:NextNumber(-1, 1), 0, ctx.Rng:NextNumber(-1, 1)) * radius * 0.6
		disc(p, ctx.Rng:NextNumber(6, 12), 0.6, 2, biome.Terrain.Detail)
	end
end

function BIOME_TERRAIN.Caves(ctx: Context, center: Vector3, radius: number, biome)
	disc(center, radius, 0.5, 4, biome.Terrain.Ground)
	-- Rocky walls around the edge (gap facing the hub is kept by the path)
	for i = 1, 16 do
		local a = i / 16 * math.pi * 2
		local p = center + Vector3.new(math.cos(a), 0, math.sin(a)) * radius * 0.92
		if flat(p).Magnitude > MAP.BiomeDistance - radius * 0.6 then
			terrain:FillBall(p - Vector3.new(0, 8, 0), ctx.Rng:NextNumber(26, 36), biome.Terrain.Detail)
		end
	end
end

function BIOME_TERRAIN.Island(_ctx: Context, center: Vector3, radius: number, biome)
	disc(center, radius, 0, 12, Enum.Material.Water)
	disc(center, radius * 0.72, 1, 14, biome.Terrain.Detail)
	disc(center, radius * 0.62, 1.5, 4, biome.Terrain.Ground)
	terrain:FillBall(center - Vector3.new(0, 18, 0), 34, biome.Terrain.Ground)
end

local BIOME_PROPS = {
	Trees = function(ctx: Context, parent: Instance, center: Vector3, radius: number)
		for _ = 1, 45 do
			local p = randomGround(ctx, center, 25, radius * 0.95)
			if p then
				Props.Tree(parent, p, ctx.Rng)
			end
		end
		for _ = 1, 25 do
			local p = randomGround(ctx, center, 10, radius * 0.95)
			if p then
				Props.Bush(parent, p, ctx.Rng)
			end
		end
	end,
	Palms = function(ctx: Context, parent: Instance, center: Vector3, radius: number)
		for _ = 1, 22 do
			local p = randomGround(ctx, center, 15, radius * 0.9)
			if p then
				Props.Palm(parent, p, ctx.Rng)
			end
		end
		for _ = 1, 10 do
			local p = randomGround(ctx, center, 10, radius * 0.9)
			if p then
				Props.Rock(parent, p, ctx.Rng, Color3.fromRGB(200, 180, 140))
			end
		end
	end,
	Pines = function(ctx: Context, parent: Instance, center: Vector3, radius: number)
		for _ = 1, 40 do
			local p = randomGround(ctx, center, 20, radius * 0.95)
			if p then
				Props.Pine(parent, p, ctx.Rng)
			end
		end
	end,
	Lava = function(ctx: Context, parent: Instance, center: Vector3, radius: number)
		for _ = 1, 12 do
			local p = randomGround(ctx, center, 30, radius * 0.9)
			if p then
				Props.LavaVent(parent, p, ctx.Rng)
			end
		end
		for _ = 1, 25 do
			local p = randomGround(ctx, center, 20, radius * 0.95)
			if p then
				Props.Rock(parent, p, ctx.Rng, Color3.fromRGB(45, 40, 40))
			end
		end
	end,
	Crystals = function(ctx: Context, parent: Instance, center: Vector3, radius: number)
		for _ = 1, 35 do
			local p = randomGround(ctx, center, 10, radius * 0.9)
			if p then
				Props.Crystal(parent, p, ctx.Rng)
			end
		end
		for _ = 1, 20 do
			local p = randomGround(ctx, center, 10, radius * 0.9)
			if p then
				Props.Mushroom(parent, p, ctx.Rng)
			end
		end
	end,
}

local function buildBiome(ctx: Context, biomeId: string, index: number)
	local biome = Biomes[biomeId]
	local center, dir = biomeCenter(index)
	local radius = MAP.BiomeRadius
	local shape = BIOME_TERRAIN[biomeId] or BIOME_TERRAIN.Forest
	shape(ctx, center, radius, biome, dir)

	local propFolder = folder(ctx.Props, biomeId)
	local builder = BIOME_PROPS[biome.Props]
	if builder then
		builder(ctx, propFolder, center, radius)
	end

	-- Boundary posts (gap where the path comes in)
	local posts = folder(propFolder, "Boundary")
	local steps = math.floor(2 * math.pi * radius / 14)
	for i = 1, steps do
		local a = i / steps * math.pi * 2
		local offset = Vector3.new(math.cos(a), 0, math.sin(a))
		if offset:Dot(-dir) < 0.985 then
			local ground = groundAt(center.X + offset.X * radius, center.Z + offset.Z * radius)
			if ground then
				Props.FencePost(posts, ground, biome.Color:Lerp(Color3.new(0, 0, 0), 0.45))
			end
		end
	end

	-- Markers
	marker(ctx, Tags.BiomeZone, CFrame.new(center + Vector3.new(0, 50, 0)), Vector3.new(radius * 2, 100, radius * 2), {
		Biome = biomeId,
		Radius = radius,
	})
	for _ = 1, biome.FoodSpawns do
		local p = randomGround(ctx, center, 8, radius * 0.88, SPAWN_MAX_Y)
		if p then
			marker(ctx, Tags.FoodSpawn, CFrame.new(p + Vector3.new(0, 1.5, 0)), Vector3.one, { Biome = biomeId })
		end
	end
	for _ = 1, math.max(4, biome.MaxWild + 2) do
		local p = randomGround(ctx, center, 15, radius * 0.7, SPAWN_MAX_Y)
		if p then
			marker(ctx, Tags.WildSpawn, CFrame.new(p), Vector3.one, { Biome = biomeId })
		end
	end
end

--------------------------------------------------------------------------

function MapGenerator.Generate(): Folder
	local started = os.clock()
	local map = Instance.new("Folder")
	map.Name = "Map"
	map:SetAttribute("Generated", true)
	local ctx: Context = {
		Map = map,
		Markers = folder(map, "Markers"),
		Props = folder(map, "Props"),
		Rng = Random.new(GameConfig.Map.Seed),
	}

	buildBase(ctx)
	buildHub(ctx)
	-- Terrain first (props raycast onto it), then paths on top
	for index, biomeId in Biomes.Order do
		buildBiome(ctx, biomeId, index)
	end
	for index, biomeId in Biomes.Order do
		buildPath(ctx, biomeId, index)
	end

	-- Meteors land in the first (free) biome
	local firstCenter = biomeCenter(1)
	marker(ctx, Tags.MeteorZone, CFrame.new(firstCenter), Vector3.one, { Radius = MAP.BiomeRadius * 0.8 })

	map.Parent = Workspace
	log:Info(string.format("generated map in %.2fs", os.clock() - started))
	return map
end

return MapGenerator
