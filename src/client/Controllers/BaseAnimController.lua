--[[
	BaseAnimController: makes titans in bases feel alive (client only, no network).
	- gentle breathing bob + looking around
	- a bounce when fed (Fx primitive P.Bounce sets "ClientBounce")
	Only animates titan near the camera.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BaseAnimController = {
	Priority = 30,
}

local MAX_DISTANCE = 200
local BOUNCE_TIME = 0.35

function BaseAnimController:Start()
	local elapsed = 0
	RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		if elapsed < 1 / 30 then
			return
		end
		elapsed = 0
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local t = os.clock()
		for _, model in CollectionService:GetTagged("BaseTitan") do
			if not model:IsA("Model") then
				continue
			end
			local home = model:GetAttribute("Home")
			if typeof(home) ~= "CFrame" or (home.Position - camera.CFrame.Position).Magnitude > MAX_DISTANCE then
				continue
			end
			local scale = model:GetScale()
			local seed = (tonumber(model.Name) or 0) * 1.7
			local bob = (math.sin(t * 2 + seed) + 1) * 0.08 * scale
			local yaw = math.sin(t * 0.6 + seed) * 0.25
			local bounceAt = model:GetAttribute("ClientBounce")
			if type(bounceAt) == "number" and t - bounceAt < BOUNCE_TIME then
				bob += math.sin(math.pi * (t - bounceAt) / BOUNCE_TIME) * 1.2 * scale
			end
			model:PivotTo(home * CFrame.new(0, bob, 0) * CFrame.Angles(0, yaw, 0))
		end
	end)
end

return BaseAnimController
