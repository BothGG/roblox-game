--[[
	MapGenerator: builds the placeholder Titan Island from code.

	  Arena in the middle (walls, 4 gates, stands for spectators)
	  Food fields in a ring around the arena
	  Ring road + 12 bases on the outside, facing the arena
	  Beach and ocean around the island

	It also creates the tagged MARKERS (see shared/Game/Tags.lua) that the
	rest of the game uses. A hand-built map only needs those markers.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Tags = require(Shared.Game.Tags)
local Log = require(Shared.Lib.Log)

local Props = require(script.Parent.Props)

local log = Log.new("MapGenerator")

local MapGenerator = {}

local terrain = Workspace.Terrain
local MAP = GameConfig.Map
local PLOTS = GameConfig.Plots

local GATE_ANGLES = { 0, 90, 180, 270 } -- degrees
local GATE_WIDTH = 26
local ROAD_RADIUS = PLOTS.RingRadius - PLOTS.Size / 2 - 16
local STONE = Color3.fromRGB(150, 140, 130)
local STONE_DARK = Color3.fromRGB(110, 100, 95)

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

local function polar(angleDeg: number, radius: number, y: number?): Vector3
	local a = math.rad(angleDeg)
	return Vector3.new(math.cos(a) * radius, y or 0, math.sin(a) * radius)
end

local function nearGate(angleDeg: number, slack: number): boolean
	for _, g in GATE_ANGLES do
		local diff = math.abs(((angleDeg - g) + 180) % 360 - 180)
		if diff < slack then
			return true
		end
	end
	return false
end

local function disc(center: Vector3, radius: number, topY: number, depth: number, material: Enum.Material)
	terrain:FillCylinder(CFrame.new(center.X, topY - depth / 2, center.Z), depth, radius, material)
end

-- Terrain surface height at (x, z), ignoring water. nil if nothing there.
local function groundAt(x: number, z: number): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { terrain }
	local result = Workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), params)
	if not result or result.Material == Enum.Material.Water then
		return nil
	end
	return result.Position
end

--------------------------------------------------------------------------
-- Island terrain
--------------------------------------------------------------------------

local function buildTerrain(ctx: Context)
	terrain:Clear()
	terrain.WaterColor = Color3.fromRGB(40, 150, 200)
	terrain.WaterTransparency = 0.6
	terrain.WaterWaveSize = 0.15
	terrain.WaterReflectance = 0.4
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(110, 185, 85))
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(95, 170, 75))
	terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(240, 215, 150))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(165, 130, 90))

	local size = (MAP.IslandRadius + 160) * 2
	terrain:FillBlock(CFrame.new(0, -18, 0), Vector3.new(size, 8, size), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(0, -7, 0), Vector3.new(size, 14, size), Enum.Material.Water)
	disc(Vector3.zero, MAP.IslandRadius + 22, -0.6, 14, Enum.Material.Sand)
	disc(Vector3.zero, MAP.IslandRadius, 0, 14, Enum.Material.Grass)
	-- Food fields: slightly different grass
	for r = MAP.FieldInner, MAP.FieldOuter, 4 do
		local steps = math.floor(2 * math.pi * r / 8)
		for i = 1, steps do
			local p = polar(i / steps * 360, r)
			terrain:FillBlock(CFrame.new(p.X, -1, p.Z), Vector3.new(8, 2, 8), Enum.Material.LeafyGrass)
		end
	end
	-- Ring road
	for r = ROAD_RADIUS - 8, ROAD_RADIUS + 8, 4 do
		local steps = math.floor(2 * math.pi * r / 6)
		for i = 1, steps do
			local p = polar(i / steps * 360, r)
			terrain:FillBlock(CFrame.new(p.X, -0.5, p.Z), Vector3.new(6, 2, 6), Enum.Material.Ground)
		end
	end
	-- Paths from the arena gates to the road
	for _, angle in GATE_ANGLES do
		local from, to = MAP.ArenaRadius, ROAD_RADIUS
		local mid = polar(angle, (from + to) / 2, -0.5)
		local dir = polar(angle, 1)
		terrain:FillBlock(CFrame.lookAt(mid, mid + dir), Vector3.new(18, 2, to - from + 6), Enum.Material.Ground)
	end

	-- Invisible walls at the edge of the world
	local edge = size / 2
	for _, info in
		{
			{ Vector3.new(0, 100, edge), Vector3.new(size, 200, 2) },
			{ Vector3.new(0, 100, -edge), Vector3.new(size, 200, 2) },
			{ Vector3.new(edge, 100, 0), Vector3.new(2, 200, size) },
			{ Vector3.new(-edge, 100, 0), Vector3.new(2, 200, size) },
		}
	do
		Props.Part(
			ctx.Map,
			{ Name = "EdgeWall", Size = info[2], CFrame = CFrame.new(info[1]), Transparency = 1, CanQuery = false }
		)
	end
end

--------------------------------------------------------------------------
-- Arena
--------------------------------------------------------------------------

-- A ring of box segments (walls, stand steps), leaving gaps at the gates.
local function ringSegments(
	parent: Instance,
	radius: number,
	depth: number,
	height: number,
	baseY: number,
	color: Color3,
	material: Enum.Material,
	name: string
)
	local circumference = 2 * math.pi * radius
	local count = math.floor(circumference / 8)
	local segLength = circumference / count + 0.4
	for i = 0, count - 1 do
		local angle = (i + 0.5) / count * 360
		local gapDeg = math.deg(GATE_WIDTH / 2 / radius) + 1
		if not nearGate(angle, gapDeg) then
			local p = polar(angle, radius, baseY + height / 2)
			Props.Part(parent, {
				Name = name,
				Size = Vector3.new(segLength, height, depth),
				CFrame = CFrame.lookAt(p, Vector3.new(0, p.Y, 0)),
				Color = color,
				Material = material,
			})
		end
	end
end

local function buildArena(ctx: Context)
	local arena = folder(ctx.Map, "Arena")
	local R = MAP.ArenaRadius

	-- Floor
	Props.Column(
		arena,
		Vector3.new(0, -0.5, 0),
		1.2,
		R * 2,
		{ Name = "Floor", Color = Color3.fromRGB(225, 200, 150), Material = Enum.Material.Sand }
	)
	Props.Column(arena, Vector3.new(0, 0.7, 0), 0.1, 30, {
		Name = "CenterMark",
		Color = Color3.fromRGB(200, 60, 60),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})

	-- Wall (inner edge at R) and stands behind it
	ringSegments(arena, R + 2, 3, 10, 0, STONE, Enum.Material.Cobblestone, "Wall")
	for step = 1, 3 do
		ringSegments(
			arena,
			R + 3.5 + step * 7,
			7,
			3 * step + 7,
			0,
			if step % 2 == 0 then STONE_DARK else STONE,
			Enum.Material.Slate,
			"Stand"
		)
	end

	-- Gate arches + torches
	for _, angle in GATE_ANGLES do
		local dir = polar(angle, 1)
		local gatePos = polar(angle, R + 12)
		Props.GateArch(arena, CFrame.lookAt(gatePos, gatePos + dir), GATE_WIDTH, STONE_DARK)
		for _, side in { -1, 1 } do
			local side3 = dir:Cross(Vector3.yAxis) * side * (GATE_WIDTH / 2 + 5)
			Props.Torch(arena, polar(angle, R + 1) + side3)
		end
	end

	-- Markers
	marker(ctx, Tags.Arena, CFrame.new(0, 1, 0), Vector3.new(4, 1, 4), { Radius = R - 4 })
	for i = 1, 12 do
		local p = polar(i * 30, R * 0.7, 3)
		marker(ctx, Tags.ArenaSpawn, CFrame.lookAt(p, Vector3.new(0, 3, 0)), Vector3.new(4, 1, 4), { Index = i })
	end
	for _, angle in { 45, 135, 225, 315 } do
		local p = polar(angle, R + 3.5 + 21, 3 * 3 + 7 + 3)
		marker(ctx, Tags.Stands, CFrame.lookAt(p, Vector3.new(0, p.Y, 0)), Vector3.new(4, 1, 4))
	end

	-- Leaderboards facing the fields, next to three of the gates
	for i, board in { "Trophies", "Biggest", "Rebirths" } do
		local angle = GATE_ANGLES[i] + 18
		local p = polar(angle, R + 36)
		local facing = polar(angle, 1)
		for _, x in { -9, 9 } do
			Props.Column(
				arena,
				CFrame.lookAt(p, p + facing) * CFrame.new(x, 0, 0).Position,
				16,
				1.2,
				{ Color = STONE_DARK, Material = Enum.Material.Slate }
			)
		end
		local part = Props.Part(ctx.Markers, {
			Name = "Leaderboard_" .. board,
			Size = Vector3.new(20, 13, 1),
			CFrame = CFrame.lookAt(p + Vector3.new(0, 10, 0), p + Vector3.new(0, 10, 0) + facing),
			Color = Color3.fromRGB(35, 38, 55),
			Material = Enum.Material.SmoothPlastic,
		})
		part:SetAttribute("Board", board)
		CollectionService:AddTag(part, Tags.Leaderboard)
	end
end

--------------------------------------------------------------------------
-- Fields, bases, decoration
--------------------------------------------------------------------------

local function buildFields(ctx: Context)
	local fields = folder(ctx.Props, "Fields")
	local spawned = 0
	local tries = 0
	while spawned < GameConfig.Food.FieldSpawns and tries < GameConfig.Food.FieldSpawns * 10 do
		tries += 1
		local angle = ctx.Rng:NextNumber(0, 360)
		if not nearGate(angle, 5) then
			local r = ctx.Rng:NextNumber(MAP.FieldInner + 6, MAP.FieldOuter - 6)
			local p = polar(angle, r)
			local ground = groundAt(p.X, p.Z)
			if ground then
				marker(ctx, Tags.FoodSpawn, CFrame.new(ground + Vector3.new(0, 1.5, 0)), Vector3.one)
				spawned += 1
			end
		end
	end
	for _ = 1, 40 do
		local angle = ctx.Rng:NextNumber(0, 360)
		if not nearGate(angle, 6) then
			local p = polar(angle, ctx.Rng:NextNumber(MAP.FieldInner, MAP.FieldOuter))
			Props.Flowers(fields, p, ctx.Rng)
		end
	end
	for _ = 1, 14 do
		local angle = ctx.Rng:NextNumber(0, 360)
		if not nearGate(angle, 8) then
			Props.Bush(fields, polar(angle, ctx.Rng:NextNumber(MAP.FieldInner + 10, MAP.FieldOuter - 10)), ctx.Rng)
		end
	end
	marker(
		ctx,
		Tags.MeteorZone,
		CFrame.new(0, 1, 0),
		Vector3.one,
		{ Radius = MAP.FieldOuter - 8, InnerRadius = MAP.FieldInner + 8 }
	)
end

local function buildBasesAndDecor(ctx: Context)
	local decor = folder(ctx.Props, "Decor")
	local count = PLOTS.Count
	for i = 1, count do
		local angle = (i - 0.5) / count * 360
		local p = polar(angle, PLOTS.RingRadius)
		marker(
			ctx,
			Tags.Plot,
			CFrame.lookAt(p, Vector3.zero),
			Vector3.new(PLOTS.Size, 1, PLOTS.Size),
			{ PlotIndex = i }
		)
		-- Trees between neighbouring bases
		local between = i / count * 360
		for _ = 1, 3 do
			local tp = polar(between + ctx.Rng:NextNumber(-3, 3), PLOTS.RingRadius + ctx.Rng:NextNumber(-25, 25))
			local ground = groundAt(tp.X, tp.Z)
			if ground then
				Props.Tree(decor, ground, ctx.Rng)
			end
		end
	end
	-- Lamps along the ring road
	for i = 1, 24 do
		local p = polar(i / 24 * 360 + 7.5, ROAD_RADIUS - 11)
		Props.Lamp(decor, p)
	end
	-- Palms and rocks on the beach
	for _ = 1, 45 do
		local angle = ctx.Rng:NextNumber(0, 360)
		local p = polar(angle, ctx.Rng:NextNumber(MAP.IslandRadius - 25, MAP.IslandRadius + 8))
		local ground = groundAt(p.X, p.Z)
		if ground then
			if ctx.Rng:NextNumber() < 0.7 then
				Props.Palm(decor, ground, ctx.Rng)
			else
				Props.Rock(decor, ground, ctx.Rng, Color3.fromRGB(200, 180, 140))
			end
		end
	end

	-- Spawn point in the fields (players are sent to their base right away)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(polar(45, (MAP.FieldInner + MAP.FieldOuter) / 2, 1))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = ctx.Map
	CollectionService:AddTag(spawn, Tags.HubSpawn)
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
		Rng = Random.new(MAP.Seed),
	}

	buildTerrain(ctx)
	buildArena(ctx)
	buildFields(ctx)
	buildBasesAndDecor(ctx)

	map.Parent = Workspace
	log:Info(string.format("generated Titan Island in %.2fs", os.clock() - started))
	return map
end

return MapGenerator
