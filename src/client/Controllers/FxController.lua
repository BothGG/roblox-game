--[[
	FxController: plays effects the server asks for, and animates
	"AnimatedMutation" titan (e.g. Rainbow) on this client.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Fx = require(Shared.Fx)
local Tags = require(Shared.Game.Tags)

local FxController = {
	Priority = 5,
}

function FxController:Start()
	Net.Listen("Fx", function(name, params)
		Fx.Play(name, params)
	end)

	-- Rainbow color cycling
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.05 then
			return
		end
		elapsed = 0
		local hue = (os.clock() * 0.2) % 1
		for _, model in CollectionService:GetTagged(Tags.AnimatedMutation) do
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					local paint = d:GetAttribute("Paint")
					if paint == "Body" then
						d.Color = Color3.fromHSV(hue, 0.8, 1)
					elseif paint == "Accent" then
						d.Color = Color3.fromHSV((hue + 0.5) % 1, 0.6, 1)
					end
				end
			end
		end
	end)
end

return FxController
