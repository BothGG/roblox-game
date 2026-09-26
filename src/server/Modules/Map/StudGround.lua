--[[
	StudGround: ground made of Parts in the classic Roblox look: bright
	Plastic colors, Studs on top and Inlets on the sides (like a Lego
	baseplate), instead of smooth Terrain.

	The ground is a grid of Cell x Cell squares. ZoneAt(x, z) names the zone
	of each square (nil = nothing there, e.g. water). Squares next to each
	other in a row with the same zone are merged into one long part, so a
	whole island is only a few hundred parts.

	  StudGround.Build(parent, {
		Cell = 8, Radius = 360, Bottom = -14, SideColor = dirtColor,
		Zones = { Grass = { Color = green, Top = 0 }, Sand = { Color = sand, Top = -1.5 } },
		ZoneAt = function(x, z) return "Grass" end,
	  }) -> Folder

	StudGround.Style(instance) gives existing parts the same look (used for
	bases, arena walls and stands).
]]

local StudGround = {}

export type Zone = { Color: Color3, Top: number, Material: Enum.Material? }
export type Options = {
	Cell: number,
	Radius: number,
	Bottom: number,
	SideColor: Color3,
	Zones: { [string]: Zone },
	ZoneAt: (x: number, z: number) -> string?,
}

local SIDES = { "LeftSurface", "RightSurface", "FrontSurface", "BackSurface" }

local function stud(part: BasePart, sides: Enum.SurfaceType)
	part.Material = Enum.Material.Plastic
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Inlet
	for _, side in SIDES do
		(part :: any)[side] = sides
	end
end

-- Classic look for parts that are already built (skips glass/neon/effects).
local KEEP = {
	[Enum.Material.Neon] = true,
	[Enum.Material.Glass] = true,
	[Enum.Material.ForceField] = true,
	[Enum.Material.Wood] = true,
	[Enum.Material.WoodPlanks] = true,
}
function StudGround.Style(root: Instance)
	local parts = if root:IsA("BasePart") then { root } else root:GetDescendants()
	for _, d in parts do
		if
			d:IsA("Part")
			and d.Shape == Enum.PartType.Block
			and not KEEP[d.Material]
			and d.Transparency < 0.5
			and d:GetAttribute("Paint") == nil
		then
			stud(d, Enum.SurfaceType.Inlet)
		end
	end
end

local function newPart(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Position = position
	p.Color = color
	p.Parent = parent
	return p
end

function StudGround.Build(parent: Instance, opts: Options): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Ground"
	local cell = opts.Cell
	local count = math.ceil(opts.Radius * 2 / cell)
	local origin = -count * cell / 2
	local parts = 0

	for row = 0, count - 1 do
		local z = origin + (row + 0.5) * cell
		-- Collect runs of equal zones in this row.
		local runs = {}
		local current: { Zone: string, From: number, To: number }? = nil
		for column = 0, count - 1 do
			local x = origin + (column + 0.5) * cell
			local zone = opts.ZoneAt(x, z)
			if zone and not opts.Zones[zone] then
				zone = nil
			end
			if current and current.Zone == zone and current.To == column - 1 then
				current.To = column
			else
				if current then
					table.insert(runs, current)
				end
				current = if zone then { Zone = zone, From = column, To = column } else nil
			end
		end
		if current then
			table.insert(runs, current)
		end

		-- One dirt body under each stretch of touching runs, one colored top per run.
		local i = 1
		while i <= #runs do
			local j = i
			local lowest = opts.Zones[runs[i].Zone].Top
			while j < #runs and runs[j + 1].From == runs[j].To + 1 do
				j += 1
				lowest = math.min(lowest, opts.Zones[runs[j].Zone].Top)
			end
			local bodyTop = lowest - 2
			local fromX = origin + runs[i].From * cell
			local toX = origin + (runs[j].To + 1) * cell
			if bodyTop > opts.Bottom then
				local body = newPart(
					folder,
					"Dirt",
					Vector3.new(toX - fromX, bodyTop - opts.Bottom, cell),
					Vector3.new((fromX + toX) / 2, (bodyTop + opts.Bottom) / 2, z),
					opts.SideColor
				)
				stud(body, Enum.SurfaceType.Inlet)
				parts += 1
			end
			for k = i, j do
				local run = runs[k]
				local zone = opts.Zones[run.Zone]
				local x0 = origin + run.From * cell
				local x1 = origin + (run.To + 1) * cell
				local top = newPart(
					folder,
					run.Zone,
					Vector3.new(x1 - x0, zone.Top - bodyTop, cell),
					Vector3.new((x0 + x1) / 2, (zone.Top + bodyTop) / 2, z),
					zone.Color
				)
				stud(top, Enum.SurfaceType.Inlet)
				if zone.Material then
					top.Material = zone.Material
				end
				parts += 1
			end
			i = j + 1
		end
	end
	folder:SetAttribute("Parts", parts)
	folder.Parent = parent
	return folder
end

return StudGround
