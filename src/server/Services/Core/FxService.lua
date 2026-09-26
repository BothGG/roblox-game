--[[
	FxService: tells clients to play effect presets (see shared/Fx/Presets.lua).

	  FxService:PlayAll("LevelUp", { Position = pos })
	  FxService:PlayFor(player, "StealAlert", {})
	  FxService:PlayNear(position, 200, "MeteorImpact", { Position = position })
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared").Net)

local FxService = {
	Priority = 2,
}

function FxService:PlayAll(name: string, params: { [string]: any }?)
	Net.FireAll("Fx", name, params or {})
end

function FxService:PlayFor(player: Player, name: string, params: { [string]: any }?)
	Net.Fire(player, "Fx", name, params or {})
end

-- Only sends to players whose character is within `radius` (saves bandwidth).
function FxService:PlayNear(position: Vector3, radius: number, name: string, params: { [string]: any }?)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - position).Magnitude <= radius then
			Net.Fire(player, "Fx", name, params or {})
		end
	end
end

return FxService
