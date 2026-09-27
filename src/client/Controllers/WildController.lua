--[[
	WildController: smoothly animates moving titans (tag "Mover": wild
	titans and followers) between the points the server picks
	(MoveFrom/MoveTo/MoveStart/MoveDuration attributes), with poses per
	State attribute:
	  walking = little hops, Flee/Chase = fast bouncy run, Graze = head down,
	  Asleep = lying on its side with a slow breathing bob.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Tags = require(ReplicatedStorage:WaitForChild("Shared").Game.Tags)

local WildController = {
	Priority = 30,
}

local MAX_DISTANCE = 450
local RUN_STATES = { Flee = true, Chase = true }

local function pose(model: Model, t: number, moving: boolean): CFrame
	local state = model:GetAttribute("State")
	local scale = model:GetScale()
	if state == "Asleep" then
		local breathe = math.sin(t * 1.6) * 0.04 * scale
		return CFrame.new(0, breathe, 0) * CFrame.Angles(0, 0, math.rad(78))
	elseif state == "Graze" then
		return CFrame.Angles(math.rad(-12 + math.sin(t * 3) * 4), 0, 0)
	elseif state == "Attack" then
		return CFrame.Angles(math.rad(math.sin(t * 14) * 8), 0, 0)
	elseif moving then
		local fast = RUN_STATES[state] == true
		local hop = math.abs(math.sin(t * (if fast then 14 else 9))) * (if fast then 1.1 else 0.6) * math.sqrt(scale)
		return CFrame.new(0, hop, 0)
	end
	return CFrame.new(0, math.sin(t * 2) * 0.05 * scale, 0)
end

function WildController:Start()
	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local now = Workspace:GetServerTimeNow()
		local t = os.clock()
		for _, model in CollectionService:GetTagged(Tags.Mover) do
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
			local alpha = math.clamp((now - start) / math.max(duration, 0.01), 0, 1)
			local moving = alpha < 1 and (to.Position - from.Position).Magnitude > 0.05
			local base = from:Lerp(to, alpha)
			model:PivotTo(base * pose(model, t, moving))
		end
	end)
end

return WildController
