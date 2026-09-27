--[[
	EggAlarmController: when someone steals your egg, a red guide beam runs
	from you to the thief (only you see it) until the egg is back, dropped
	or gone. The server sets your "EggThief" attribute to the thief's UserId.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Textures = require(Shared.Fx.Textures)

local player = Players.LocalPlayer

local EggAlarmController = {
	Priority = 40,
}

local beam: Beam? = nil
local from: Attachment? = nil
local highlight: Highlight? = nil

local function clear()
	for _, thing in { beam, from, highlight } :: { Instance? } do
		if thing then
			thing:Destroy()
		end
	end
	beam, from, highlight = nil, nil, nil
end

local function update()
	clear()
	local thiefId = player:GetAttribute("EggThief")
	local thief = type(thiefId) == "number" and Players:GetPlayerByUserId(thiefId)
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local theirRoot = thief and thief.Character and thief.Character:FindFirstChild("HumanoidRootPart")
	if not thief or not myRoot or not theirRoot then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "EggAlarmFrom"
	a0.Parent = myRoot
	local a1 = theirRoot:FindFirstChild("EggAlarmTo") or Instance.new("Attachment")
	a1.Name = "EggAlarmTo"
	a1.Parent = theirRoot
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1 :: Attachment
	b.Color = ColorSequence.new(Color3.fromRGB(255, 60, 60))
	b.LightEmission = 1
	b.LightInfluence = 0
	b.FaceCamera = true
	b.Width0 = 1.2
	b.Width1 = 1.2
	b.Texture = Textures.Glow
	b.TextureMode = Enum.TextureMode.Wrap
	b.TextureLength = 6
	b.TextureSpeed = 3
	b.Transparency = NumberSequence.new(0.3)
	b.Parent = Workspace.Terrain
	local h = Instance.new("Highlight")
	h.FillColor = Color3.fromRGB(255, 60, 60)
	h.FillTransparency = 0.6
	h.OutlineColor = Color3.new(1, 1, 1)
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Adornee = thief.Character
	h.Parent = Workspace.Terrain
	beam, from, highlight = b, a0, h
end

function EggAlarmController:Start()
	player:GetAttributeChangedSignal("EggThief"):Connect(update)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		update()
	end)
	update()
end

return EggAlarmController
