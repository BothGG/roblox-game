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
local StudGround = require(script.Parent.StudGround)

local log = Log.new("MapGenerator")

local MapGenerator = {}

local terrain = Workspace.Terrain
local MAP = GameConfig.Map
local PLOTS = GameConfig.Plots

local GATE_ANGLES = { 0, 90, 180, 270 } -- degrees
local ROAD_RADIUS = PLOTS.RingRadius - PLOTS.Size / 2 - 16
local STONE_DARK = Color3.fromRGB(110, 100, 95)
local STUDS = MAP.Style ~= "Terrain"
local PLAZA = MAP.PlazaRadius
local ARENA_Y = MAP.ArenaHeight -- top of the floating arena block
local ARENA_HALF = MAP.ArenaSize / 2
local FIGHT_HALF = ARENA_HALF - 24 -- the square players fight in

-- Classic studded colors (like the reference: bright grass, brown dirt)
local COLORS = {
	Grass = Color3.fromRGB(75, 151, 75),
	FieldGrass = Color3.fromRGB(100, 175, 70),
	Dirt = Color3.fromRGB(160, 110, 60),
	DirtDark = Color3.fromRGB(124, 92, 70),
	Road = Color3.fromRGB(215, 190, 140),
	Sand = Color3.fromRGB(245, 220, 160),
	ArenaFloor = Color3.fromRGB(175, 125, 75),
	Plaza = Color3.fromRGB(163, 162, 165),
	PlazaEdge = Color3.fromRGB(110, 110, 118),
	Emblem = Color3.fromRGB(230, 60, 60),
	EmblemRing = Color3.fromRGB(250, 200, 50),
	Portal = Color3.fromRGB(120, 200, 255),
	Wall = Color3.fromRGB(230, 230, 235),
	Stands = { Color3.fromRGB(40, 110, 220), Color3.fromRGB(230, 60, 60), Color3.fromRGB(250, 200, 50) },
}

-- What the terrain raycasts may hit (the stud ground is added when it's built).
local groundFilter: { Instance } = { terrain }

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
	params.FilterDescendantsInstances = groundFilter
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
		local from, to = PLAZA, ROAD_RADIUS
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

-- Classic studded island: grass, dirt food fields, road, beach, and the arena
-- on its own ground in the middle with a water moat and 4 bridges.
local function onGatePath(x: number, z: number, halfWidth: number): boolean
	for _, g in GATE_ANGLES do
		local dir = polar(g, 1)
		local along = x * dir.X + z * dir.Z
		local across = math.abs(x * dir.Z - z * dir.X)
		if along > 0 and across <= halfWidth then
			return true
		end
	end
	return false
end

local function studZone(x: number, z: number): string?
	local r = math.sqrt(x * x + z * z)
	if r > MAP.IslandRadius + 22 then
		return nil -- ocean
	elseif r > MAP.IslandRadius then
		return "Sand"
	elseif r < 10 then
		return "Emblem"
	elseif r < 15 then
		return "EmblemRing"
	elseif r <= PLAZA - 5 then
		return "Plaza"
	elseif r <= PLAZA then
		return "PlazaEdge"
	elseif math.abs(r - ROAD_RADIUS) <= 8 then
		return "Road"
	elseif r < ROAD_RADIUS and onGatePath(x, z, 9) then
		return "Road"
	elseif r >= MAP.FieldInner and r <= MAP.FieldOuter then
		-- Patches of brown dirt (where food grows best) in lighter grass.
		local n = math.noise(x / 36, z / 36, MAP.Seed % 97 + 0.5)
		if n > 0.3 then
			return "DirtDark"
		elseif n > -0.05 then
			return "Dirt"
		end
		return "FieldGrass"
	end
	return "Grass"
end

local function buildStudIsland(ctx: Context)
	terrain:Clear()
	terrain.WaterColor = Color3.fromRGB(40, 150, 220)
	terrain.WaterTransparency = 0.5
	terrain.WaterWaveSize = 0.1
	terrain.WaterReflectance = 0.3
	terrain:SetMaterialColor(Enum.Material.Sand, COLORS.Sand)
	local size = (MAP.IslandRadius + 160) * 2
	terrain:FillBlock(CFrame.new(0, -18, 0), Vector3.new(size, 8, size), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(0, -8.5, 0), Vector3.new(size, 11, size), Enum.Material.Water) -- surface at y = -3

	local zones = {
		Grass = { Color = COLORS.Grass, Top = 0 },
		FieldGrass = { Color = COLORS.FieldGrass, Top = 0 },
		Dirt = { Color = COLORS.Dirt, Top = 0 },
		DirtDark = { Color = COLORS.DirtDark, Top = 0 },
		Road = { Color = COLORS.Road, Top = 0 },
		Sand = { Color = COLORS.Sand, Top = -1.5 },
		Plaza = { Color = COLORS.Plaza, Top = 0.4 },
		PlazaEdge = { Color = COLORS.PlazaEdge, Top = 0.4 },
		Emblem = { Color = COLORS.Emblem, Top = 0.4 },
		EmblemRing = { Color = COLORS.EmblemRing, Top = 0.4 },
	}
	local ground = StudGround.Build(ctx.Map, {
		Cell = 8,
		Radius = MAP.IslandRadius + 24,
		Bottom = -14,
		SideColor = COLORS.DirtDark,
		Zones = zones,
		ZoneAt = studZone,
	})
	table.insert(groundFilter, ground)

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
	log:Info("stud ground:", ground:GetAttribute("Parts"), "parts")
end

--------------------------------------------------------------------------
-- Arena
--------------------------------------------------------------------------

local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	props: { [string]: any }?
): Part
	local p = Props.Part(parent, { Name = name, Size = size, CFrame = cf, Color = color })
	local extra: { [string]: any } = props or {}
	for key, value in extra do
		(p :: any)[key] = value
	end
	return p
end

-- A glowing portal pad. Touching its trigger teleports you (PortalService).
local function portal(ctx: Context, parent: Instance, position: Vector3, to: string, label: string)
	local model = Instance.new("Model")
	model.Name = "Portal_" .. to
	model.Parent = parent
	Props.Column(model, position, 1, 18, { Name = "Pad", Color = Color3.fromRGB(70, 70, 80) })
	Props.Column(model, position + Vector3.new(0, 1, 0), 0.2, 16, {
		Name = "Glow",
		Color = COLORS.Portal,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	Props.Column(model, position + Vector3.new(0, 1.05, 0), 0.2, 13, {
		Name = "Inner",
		Color = Color3.fromRGB(40, 60, 110),
		Material = Enum.Material.Glass,
		Transparency = 0.2,
		CanCollide = false,
	})
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(COLORS.Portal)
	emitter.LightEmission = 1
	emitter.Rate = 20
	emitter.Lifetime = NumberRange.new(1, 2)
	emitter.Speed = NumberRange.new(6, 12)
	emitter.EmissionDirection = Enum.NormalId.Right -- up (cylinders lie on their side)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	emitter.Parent = model:FindFirstChild("Glow")
	local light = Instance.new("PointLight")
	light.Color = COLORS.Portal
	light.Brightness = 3
	light.Range = 20
	light.Parent = model:FindFirstChild("Glow")
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 50)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 12, 0)
	gui.MaxDistance = 200
	gui.LightInfluence = 0
	gui.Parent = model:FindFirstChild("Pad")
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(160, 220, 255)
	text.Text = label
	text.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = text
	marker(ctx, Tags.Portal, CFrame.new(position + Vector3.new(0, 4, 0)), Vector3.new(12, 6, 12), { To = to })
end

-- The arena: its own square block floating high above the island.
local function buildArena(ctx: Context)
	local arena = folder(ctx.Map, "Arena")
	local Y, H, F = ARENA_Y, ARENA_HALF, FIGHT_HALF
	local dirt = COLORS.DirtDark

	-- The block: studded dirt floor, a thick body and rock steps underneath
	block(arena, "Floor", Vector3.new(H * 2, 2, H * 2), CFrame.new(0, Y - 1, 0), COLORS.ArenaFloor)
	block(arena, "Body", Vector3.new(H * 2, 14, H * 2), CFrame.new(0, Y - 9, 0), dirt)
	for i, k in { 0.8, 0.5, 0.22 } do
		block(arena, "Rock", Vector3.new(H * 2 * k, 10, H * 2 * k), CFrame.new(0, Y - 11 - i * 10, 0), dirt)
	end
	-- Center emblem + white lines around the fighting square
	local deco = { CanCollide = false, CanQuery = false }
	block(arena, "Emblem", Vector3.new(36, 0.3, 36), CFrame.new(0, Y + 0.15, 0), COLORS.EmblemRing, deco)
	block(arena, "Emblem", Vector3.new(28, 0.4, 28), CFrame.new(0, Y + 0.2, 0), COLORS.Emblem, deco)
	for _, line in
		{
			{ F * 2 + 2, 1, 0, -F - 0.5 },
			{ F * 2 + 2, 1, 0, F + 0.5 },
			{ 1, F * 2, -F - 0.5, 0 },
			{ 1, F * 2, F + 0.5, 0 },
		}
	do
		block(
			arena,
			"Line",
			Vector3.new(line[1], 0.3, line[2]),
			CFrame.new(line[3], Y + 0.15, line[4]),
			Color3.new(1, 1, 1),
			deco
		)
	end
	-- Low wall + stepped team-color stands on all four sides
	for side = 0, 3 do
		local rot = CFrame.Angles(0, side * math.pi / 2, 0)
		block(arena, "Wall", Vector3.new(F * 2 + 8, 4, 2), rot * CFrame.new(0, Y + 2, -(F + 4)), COLORS.Wall)
		for step = 0, 2 do
			local height = 3 + step * 3
			block(
				arena,
				"Stand",
				Vector3.new(F * 2 + 8 + step * 8, height, 5),
				rot * CFrame.new(0, Y + height / 2, -(F + 7.5 + step * 5)),
				COLORS.Stands[(step + side) % 3 + 1]
			)
		end
	end
	-- Corner towers with lamps
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			local c = Vector3.new(x * (H - 5), Y, z * (H - 5))
			block(arena, "Tower", Vector3.new(8, 26, 8), CFrame.new(c + Vector3.new(0, 13, 0)), COLORS.Wall)
			block(arena, "TowerTop", Vector3.new(10, 2, 10), CFrame.new(c + Vector3.new(0, 27, 0)), COLORS.Stands[2])
			local lamp = Props.Part(arena, {
				Name = "Lamp",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 4,
				CFrame = CFrame.new(c + Vector3.new(0, 30, 0)),
				Color = Color3.fromRGB(255, 235, 180),
				Material = Enum.Material.Neon,
			})
			local light = Instance.new("PointLight")
			light.Range = 40
			light.Brightness = 2
			light.Parent = lamp
		end
	end
	-- Big sign
	local sign =
		block(arena, "Sign", Vector3.new(64, 14, 1.5), CFrame.new(0, Y + 34, -(H - 3)), Color3.fromRGB(35, 38, 55))
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Back -- faces the fighting square
	surface.CanvasSize = Vector2.new(640, 140)
	surface.LightInfluence = 0
	surface.Parent = sign
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 1)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 210, 60)
	title.Text = "⚔️ TITAN ARENA"
	title.Parent = surface
	if STUDS then
		StudGround.Style(arena)
	end

	-- Portals: plaza -> arena stands, arena -> back to the island
	portal(ctx, arena, Vector3.new(0, if STUDS then 0.4 else 0, 0), "Arena", "⚔️ ARENA · step in")
	portal(ctx, arena, Vector3.new(0, Y, H - 12), "Island", "🏝️ Back to the island")

	-- Markers
	marker(ctx, Tags.Arena, CFrame.new(0, Y + 1, 0), Vector3.new(4, 1, 4), { Radius = F - 4 })
	for i = 1, 12 do
		local p = polar(i * 30, F * 0.6, Y + 3)
		marker(ctx, Tags.ArenaSpawn, CFrame.lookAt(p, Vector3.new(0, Y + 3, 0)), Vector3.new(4, 1, 4), { Index = i })
	end
	for side = 0, 3 do
		local rot = CFrame.Angles(0, side * math.pi / 2, 0)
		local p = (rot * CFrame.new(0, Y + 12, -(F + 17.5))).Position
		marker(ctx, Tags.Stands, CFrame.lookAt(p, Vector3.new(0, p.Y, 0)), Vector3.new(4, 1, 4))
	end

	-- Leaderboards around the plaza, facing out
	for i, board in { "Trophies", "Biggest", "Rebirths" } do
		local angle = 45 + (i - 1) * 90
		local p = polar(angle, PLAZA - 9)
		local facing = polar(angle, 1)
		for _, x in { -9, 9 } do
			Props.Column(
				ctx.Props,
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
	-- Wild titan spawn spots, spread evenly around the fields.
	for i = 1, 16 do
		local angle = (i - 0.5) / 16 * 360 + ctx.Rng:NextNumber(-6, 6)
		if nearGate(angle, 6) then
			angle += 12
		end
		local p = polar(angle, ctx.Rng:NextNumber(MAP.FieldInner + 20, MAP.FieldOuter - 20))
		local ground = groundAt(p.X, p.Z)
		if ground then
			marker(ctx, Tags.WildSpawn, CFrame.new(ground + Vector3.new(0, 1, 0)), Vector3.one)
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

	if STUDS then
		buildStudIsland(ctx)
	else
		buildTerrain(ctx)
	end
	buildArena(ctx)
	buildFields(ctx)
	buildBasesAndDecor(ctx)

	map.Parent = Workspace
	log:Info(string.format("generated Titan Island in %.2fs", os.clock() - started))
	return map
end

return MapGenerator
