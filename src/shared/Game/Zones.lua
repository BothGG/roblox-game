--!strict
--[[
	Zones: "is this point inside this area?" for biome zones.
	A zone is round (Radius) or a box (CFrame + Size). Shared so the server
	(rules) and client (ambience, UI) agree on where each biome is.
]]

export type Zone = {
	Biome: string,
	Center: Vector3,
	Radius: number?,
	CFrame: CFrame?,
	Size: Vector3?,
}

local Zones = {}

function Zones.Contains(zone: Zone, position: Vector3): boolean
	if zone.Radius then
		local dx = position.X - zone.Center.X
		local dz = position.Z - zone.Center.Z
		return dx * dx + dz * dz <= zone.Radius * zone.Radius
	end
	if zone.CFrame and zone.Size then
		local localPos = zone.CFrame:PointToObjectSpace(position)
		local half = zone.Size / 2
		return math.abs(localPos.X) <= half.X and math.abs(localPos.Z) <= half.Z
	end
	return false
end

function Zones.Find(zones: { Zone }, position: Vector3): string?
	for _, zone in zones do
		if Zones.Contains(zone, position) then
			return zone.Biome
		end
	end
	return nil
end

-- Builds a zone from a tagged BiomeZone part.
function Zones.FromPart(part: BasePart): Zone
	local radius = part:GetAttribute("Radius")
	return {
		Biome = part:GetAttribute("Biome") :: string,
		Center = part.Position,
		Radius = if type(radius) == "number" then radius else nil,
		CFrame = part.CFrame,
		Size = part.Size,
	}
end

return Zones
