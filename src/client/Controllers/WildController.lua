--[[
	WildController: smoothly animates wild titans between the points the
	server picks (MoveFrom/MoveTo/MoveStart/MoveDuration attributes),
	with a little hop while walking.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Tags = require(ReplicatedStorage:WaitForChild("Shared").Game.Tags)

local WildController = {
	Priority = 30,
}

local MAX_DISTANCE = 300
local moving: { [Model]: boolean } = {}

function WildController:Start()
	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local now = Workspace:GetServerTimeNow()
		for _, model in CollectionService:GetTagged(Tags.WildTitan) do
			if not model:IsA("Model") or not model.PrimaryPart then
				continue
			end
			local from = model:GetAttribute("MoveFrom")
			local to = model:GetAttribute("MoveTo")
			local start = model:GetAttribute("MoveStart")
			local duration = model:GetAttribute("MoveDuration")
			if
				typeof(from) ~= "CFrame"
				or typeof(to) ~= "CFrame"
				or type(start) ~= "number"
				or type(duration) ~= "number"
			then
				continue
			end
			if (to.Position - camera.CFrame.Position).Magnitude > MAX_DISTANCE then
				continue
			end
			local alpha = (now - start) / duration
			if alpha >= 0 and alpha < 1 then
				local hop = math.abs(math.sin(alpha * duration * 9)) * 0.7
				model:PivotTo(from:Lerp(to, alpha) + Vector3.new(0, hop, 0))
				moving[model] = true
			elseif moving[model] then
				model:PivotTo(to)
				moving[model] = nil
			end
		end
	end)
	CollectionService:GetInstanceRemovedSignal(Tags.WildTitan):Connect(function(model)
		moving[model] = nil
	end)
end

return WildController
