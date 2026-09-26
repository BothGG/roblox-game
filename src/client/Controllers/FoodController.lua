--[[
	FoodController: spins and bobs food lying on the ground (client only).
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local FoodController = {
	Priority = 30,
}

local MAX_DISTANCE = 150
local bases: { [Model]: CFrame } = {}

function FoodController:Start()
	CollectionService:GetInstanceRemovedSignal("FoodPickup"):Connect(function(model)
		bases[model] = nil
	end)
	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local t = os.clock()
		for _, model in CollectionService:GetTagged("FoodPickup") do
			if not model:IsA("Model") or not model.PrimaryPart then
				continue
			end
			local base = bases[model]
			if not base then
				base = model:GetPivot()
				bases[model] = base
			end
			if (base.Position - camera.CFrame.Position).Magnitude < MAX_DISTANCE then
				local seed = base.Position.X * 0.1
				model:PivotTo(
					base * CFrame.new(0, math.sin(t * 2 + seed) * 0.4 + 0.4, 0) * CFrame.Angles(0, t * 1.5 + seed, 0)
				)
			end
		end
	end)
end

return FoodController
